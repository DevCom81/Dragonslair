import json
import os
import unittest
from pathlib import Path
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

import main
from entitlements import compute_global_entitlement
from google_play import (
    GooglePlayBillingService,
    GooglePlayPendingError,
    GooglePlayPurchaseError,
    assert_play_account_binding,
    interpret_product_lifecycle,
    interpret_product_purchase,
    needs_play_acknowledgement,
    play_obfuscated_account_id,
    purchase_token_fingerprint,
    redeem_google_play_purchase,
)


_PLAY_ENV = {
    "GOOGLE_PLAY_PACKAGE_NAME": "com.devcom81.dragons_lair",
    "GOOGLE_PLAY_PRODUCT_ID": "dragonslair_full",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": json.dumps(
        {"type": "service_account", "private_key": "dummy", "client_email": "a@b.c"}
    ),
}


def _google_source(*, status: str = "active", provider_ref: str = "fp_play") -> dict:
    return {
        "provider": "google_play",
        "provider_ref": provider_ref,
        "status": status,
        "current_period_end": None,
        "metadata": {},
    }


def _stripe_source(*, status: str = "active", provider_ref: str = "cs_test") -> dict:
    return {
        "provider": "stripe",
        "provider_ref": provider_ref,
        "status": status,
        "current_period_end": None,
        "metadata": {},
    }


class GooglePlayModelTest(unittest.TestCase):
    def test_purchase_state_mapping(self) -> None:
        self.assertEqual(interpret_product_purchase({"purchaseState": 0}), "purchased")
        self.assertEqual(interpret_product_purchase({"purchaseState": 2}), "pending")
        self.assertEqual(interpret_product_purchase({"purchaseState": 1}), "invalid")
        self.assertEqual(interpret_product_purchase({}), "invalid")

    def test_lifecycle_maps_purchase_state_to_status(self) -> None:
        self.assertEqual(interpret_product_lifecycle({"purchaseState": 0}), "active")
        self.assertEqual(interpret_product_lifecycle({"purchaseState": 2}), "pending")
        self.assertEqual(interpret_product_lifecycle({"purchaseState": 1}), "revoked")

    def test_token_fingerprint_is_not_the_raw_token(self) -> None:
        token = "play-token-secret"
        fingerprint = purchase_token_fingerprint(token)
        self.assertNotEqual(fingerprint, token)
        self.assertEqual(fingerprint, purchase_token_fingerprint(token))

    def test_obfuscated_account_id_is_sha256_of_uuid_never_email(self) -> None:
        user_id = "11111111-1111-1111-1111-111111111111"
        account_id = play_obfuscated_account_id(user_id)
        self.assertEqual(len(account_id), 64)
        self.assertEqual(
            account_id,
            "fb6a91d8f279ffe254ec44fbd79f829197d217f4d56e588b96d4bf816d6f88a0",
        )
        self.assertNotIn(user_id, account_id)
        self.assertNotEqual(
            play_obfuscated_account_id("player@example.com"),
            "player@example.com",
        )
        self.assertEqual(play_obfuscated_account_id(""), "")

    def test_acknowledgement_only_for_unacked_purchases(self) -> None:
        self.assertTrue(needs_play_acknowledgement({"acknowledgementState": 0}))
        self.assertTrue(needs_play_acknowledgement({"purchaseState": 0}))
        self.assertFalse(needs_play_acknowledgement({"acknowledgementState": 1}))

    def test_active_product_without_expiry_is_full_permanent(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_google_source()],
        )
        self.assertEqual(row["access_level"], "full")
        self.assertIsNone(row["expires_at"])

    def test_google_revoked_with_stripe_active_stays_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _stripe_source(),
                _google_source(status="revoked"),
            ],
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["stripe"])

    def test_stripe_revoked_with_google_active_stays_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _stripe_source(status="revoked"),
                _google_source(),
            ],
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["google_play"])

    def test_billing_service_lives_outside_http_routes(self) -> None:
        src = Path(__file__).with_name("google_play.py").read_text(encoding="utf-8")
        self.assertIn("class GooglePlayBillingService", src)
        self.assertNotIn("@app.", src)
        self.assertNotIn("purchase_token=%", src)
        self.assertNotIn("subscriptions", src)
        example = Path(__file__).resolve().parents[1].joinpath("backend", ".env.example")
        if not example.exists():
            example = Path(__file__).with_name(".env.example")
        env = example.read_text(encoding="utf-8")
        self.assertIn("GOOGLE_PLAY_PACKAGE_NAME", env)
        self.assertIn("GOOGLE_PLAY_PRODUCT_ID", env)
        self.assertIn("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON", env)

    def test_account_mismatch_is_rejected(self) -> None:
        payload = {
            "purchaseState": 0,
            "obfuscatedExternalAccountId": play_obfuscated_account_id("other-user"),
        }
        with self.assertRaises(GooglePlayPurchaseError) as raised:
            assert_play_account_binding(payload, "user-1")
        self.assertEqual(str(raised.exception), "GOOGLE_PLAY_ACCOUNT_MISMATCH")

    def test_missing_account_id_is_rejected(self) -> None:
        with self.assertRaises(GooglePlayPurchaseError):
            assert_play_account_binding({"purchaseState": 0}, "user-1")


class GooglePlayRedeemTest(unittest.IsolatedAsyncioTestCase):
    async def test_wrong_product_is_rejected_without_google_lookup(self) -> None:
        lookup = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with self.assertRaises(GooglePlayPurchaseError) as raised:
                await redeem_google_play_purchase(
                    user_id="user-1",
                    product_id="other_sku",
                    purchase_token="token",
                    fetch_purchase=lookup,
                )
        self.assertEqual(str(raised.exception), "GOOGLE_PLAY_PRODUCT_MISMATCH")
        lookup.assert_not_awaited()

    async def test_invalid_token_does_not_grant(self) -> None:
        async def invalid(package: str, product: str, token: str) -> dict:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")

        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with self.assertRaises(GooglePlayPurchaseError):
                    await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="bad-token",
                        fetch_purchase=invalid,
                    )
        upsert.assert_not_awaited()

    async def test_pending_does_not_upsert(self) -> None:
        async def pending(package: str, product: str, token: str) -> dict:
            return {"purchaseState": 2}

        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with patch(
                    "google_play.refresh_user_entitlement", new=AsyncMock()
                ) as refresh:
                    with self.assertRaises(GooglePlayPendingError):
                        await redeem_google_play_purchase(
                            user_id="user-1",
                            product_id="dragonslair_full",
                            purchase_token="token",
                            fetch_purchase=pending,
                            acknowledge=ack,
                        )
        upsert.assert_not_awaited()
        refresh.assert_not_awaited()
        ack.assert_not_awaited()

    async def test_pending_is_demo_without_other_source(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_google_source(status="pending")],
        )
        self.assertEqual(row["access_level"], "demo")

    async def test_account_mismatch_does_not_upsert(self) -> None:
        async def other_account(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("other-user"),
            }

        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with self.assertRaises(GooglePlayPurchaseError) as raised:
                    await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=other_account,
                    )
        self.assertEqual(str(raised.exception), "GOOGLE_PLAY_ACCOUNT_MISMATCH")
        upsert.assert_not_awaited()

    async def test_revoked_product_is_persisted_without_granting(self) -> None:
        async def revoked(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 1,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        ack = AsyncMock()
        refresh = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "demo",
                "source": "default",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with patch("google_play.refresh_user_entitlement", refresh):
                    row = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=revoked,
                        acknowledge=ack,
                    )
        self.assertEqual(row["access_level"], "demo")
        upsert.assert_awaited_once()
        self.assertEqual(upsert.await_args.kwargs["status"], "revoked")
        self.assertIsNone(upsert.await_args.kwargs.get("current_period_end"))
        ack.assert_not_awaited()

    async def test_purchased_records_google_play_source(self) -> None:
        async def purchased(package: str, product: str, token: str) -> dict:
            self.assertEqual(package, "com.devcom81.dragons_lair")
            self.assertEqual(product, "dragonslair_full")
            return {
                "purchaseState": 0,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        upsert = AsyncMock()
        refresh = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "full",
                "source": "purchase",
            }
        )
        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with patch("google_play.refresh_user_entitlement", refresh):
                    row = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=purchased,
                        acknowledge=ack,
                    )
        self.assertEqual(row["access_level"], "full")
        upsert.assert_awaited_once()
        ack.assert_awaited_once()
        self.assertEqual(ack.await_args.kwargs["product_id"], "dragonslair_full")
        self.assertEqual(ack.await_args.kwargs["purchase_token"], "token")
        self.assertEqual(upsert.await_args.kwargs["status"], "active")
        self.assertEqual(upsert.await_args.kwargs["provider"], "google_play")
        self.assertEqual(
            upsert.await_args.kwargs["provider_ref"],
            purchase_token_fingerprint("token"),
        )
        self.assertNotEqual(upsert.await_args.kwargs["provider_ref"], "token")
        self.assertIsNone(upsert.await_args.kwargs.get("current_period_end"))

    async def test_package_mismatch_does_not_upsert(self) -> None:
        async def wrong_package(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "packageName": "com.other.app",
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with self.assertRaises(GooglePlayPurchaseError) as raised:
                    await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=wrong_package,
                    )
        self.assertEqual(str(raised.exception), "GOOGLE_PLAY_PACKAGE_MISMATCH")
        upsert.assert_not_awaited()

    async def test_restore_purchase_valid_grants_full(self) -> None:
        async def restored(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "acknowledgementState": 1,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        refresh = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "full",
                "source": "purchase",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with patch("google_play.refresh_user_entitlement", refresh):
                    row = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="restore-token",
                        fetch_purchase=restored,
                    )
        self.assertEqual(row["access_level"], "full")
        upsert.assert_awaited_once()

    async def test_already_processed_token_is_idempotent(self) -> None:
        async def purchased(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "acknowledgementState": 1,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        upsert = AsyncMock()
        refresh = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "full",
                "source": "purchase",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with patch("google_play.refresh_user_entitlement", refresh):
                    first = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="same-token",
                        fetch_purchase=purchased,
                    )
                    second = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="same-token",
                        fetch_purchase=purchased,
                    )
        self.assertEqual(first["access_level"], "full")
        self.assertEqual(second["access_level"], "full")
        self.assertEqual(upsert.await_count, 2)

    async def test_already_acknowledged_purchase_is_not_acked_again(self) -> None:
        async def purchased(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "acknowledgementState": 1,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with patch(
                    "google_play.refresh_user_entitlement",
                    new=AsyncMock(
                        return_value={
                            "user_id": "user-1",
                            "access_level": "full",
                            "source": "purchase",
                        }
                    ),
                ):
                    await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=purchased,
                        acknowledge=ack,
                    )
        upsert.assert_awaited_once()
        ack.assert_not_awaited()

    async def test_sync_revoked_after_refund(self) -> None:
        async def revoked(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 1,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        refresh = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "demo",
                "source": "default",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", new=AsyncMock()) as upsert:
                with patch("google_play.refresh_user_entitlement", refresh):
                    row = await GooglePlayBillingService().sync_entitlement(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="token",
                        fetch_purchase=revoked,
                    )
        self.assertEqual(row["access_level"], "demo")
        self.assertEqual(upsert.await_args.kwargs["status"], "revoked")


class GooglePlayHttpTest(unittest.TestCase):
    def test_endpoint_rejects_missing_jwt(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            client = TestClient(main.app)
            response = client.post(
                "/v1/purchases/google",
                json={"product_id": "dragonslair_full", "purchase_token": "token"},
            )
        self.assertEqual(response.status_code, 401)

    def test_endpoint_pending_returns_409(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            with patch(
                "main.get_user_id_from_access_token",
                new=AsyncMock(return_value="user-1"),
            ):
                with patch(
                    "main.redeem_google_play_purchase",
                    new=AsyncMock(side_effect=GooglePlayPendingError("PURCHASE_PENDING")),
                ) as redeem:
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/google",
                        json={
                            "product_id": "dragonslair_full",
                            "purchase_token": "token",
                        },
                        headers={"Authorization": "Bearer test-token"},
                    )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.json(), {"detail": "PURCHASE_PENDING"})
        redeem.assert_awaited_once()

    def test_endpoint_purchased_returns_full(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            with patch(
                "main.get_user_id_from_access_token",
                new=AsyncMock(return_value="user-1"),
            ):
                with patch(
                    "main.redeem_google_play_purchase",
                    new=AsyncMock(
                        return_value={
                            "user_id": "user-1",
                            "access_level": "full",
                            "source": "purchase",
                        }
                    ),
                ):
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/google",
                        json={
                            "product_id": "dragonslair_full",
                            "purchase_token": "token",
                        },
                        headers={"Authorization": "Bearer test-token"},
                    )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["access_level"], "full")


if __name__ == "__main__":
    unittest.main()
