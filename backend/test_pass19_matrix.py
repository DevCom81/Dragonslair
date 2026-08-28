"""
PASS 19 — consolidated entitlement and purchase matrix (backend).
Maps each mandatory scenario from the Google Play monetization spec.
"""

import json
import os
import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from entitlements import compute_global_entitlement
from google_play import (
    GooglePlayPendingError,
    GooglePlayPurchaseError,
    play_obfuscated_account_id,
    purchase_token_fingerprint,
    redeem_google_play_purchase,
)


def _source(
    provider: str,
    *,
    status: str = "active",
    period_end: datetime | None = None,
    provider_ref: str = "ref",
) -> dict:
    return {
        "provider": provider,
        "provider_ref": provider_ref,
        "status": status,
        "current_period_end": period_end.isoformat() if period_end else None,
    }


_PLAY_ENV = {
    "GOOGLE_PLAY_PACKAGE_NAME": "com.devcom81.dragons_lair",
    "GOOGLE_PLAY_PRODUCT_ID": "dragonslair_full",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": json.dumps(
        {"type": "service_account", "private_key": "dummy", "client_email": "a@b.c"}
    ),
}


class Pass19EntitlementMatrixTest(unittest.TestCase):
    def setUp(self) -> None:
        self.now = datetime(2026, 8, 28, 12, tzinfo=timezone.utc)
        self.future = self.now + timedelta(days=10)
        self.past = self.now - timedelta(days=1)

    def test_stripe_only_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("stripe")],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")

    def test_google_only_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play")],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")

    def test_stripe_and_google_active_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe"),
                _source("google_play"),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(
            row["metadata"]["active_sources"],
            ["google_play", "stripe"],
        )

    def test_stripe_revoked_google_active_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe", status="revoked"),
                _source("google_play"),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")

    def test_google_revoked_stripe_active_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe"),
                _source("google_play", status="revoked"),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")

    def test_all_revoked_is_demo(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe", status="revoked"),
                _source("google_play", status="revoked"),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "demo")


class Pass19GooglePlayMatrixTest(unittest.IsolatedAsyncioTestCase):
    async def test_invalid_token_does_not_grant_entitlement(self) -> None:
        async def invalid_product(package: str, product: str, token: str) -> dict:
            raise GooglePlayPurchaseError("GOOGLE_PLAY_PURCHASE_INVALID")

        upsert = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with self.assertRaises(GooglePlayPurchaseError):
                    await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="bad-token",
                        fetch_purchase=invalid_product,
                    )
        upsert.assert_not_awaited()

    async def test_pending_play_purchase_does_not_grant_full(self) -> None:
        async def pending_product(package: str, product: str, token: str) -> dict:
            return {"purchaseState": 2}

        upsert = AsyncMock()
        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with patch("google_play.refresh_user_entitlement", new=AsyncMock()) as refresh:
                    with self.assertRaises(GooglePlayPendingError):
                        await redeem_google_play_purchase(
                            user_id="user-1",
                            product_id="dragonslair_full",
                            purchase_token="pending-token",
                            fetch_purchase=pending_product,
                            acknowledge=ack,
                        )
        upsert.assert_not_awaited()
        refresh.assert_not_awaited()
        ack.assert_not_awaited()

    async def test_purchased_play_purchase_grants_full(self) -> None:
        async def purchased(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        upsert = AsyncMock()
        refresh = AsyncMock(
            return_value={"user_id": "user-1", "access_level": "full"},
        )
        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with patch("google_play.refresh_user_entitlement", refresh):
                    row = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="good-token",
                        fetch_purchase=purchased,
                        acknowledge=ack,
                    )
        self.assertEqual(row["access_level"], "full")
        upsert.assert_awaited_once()
        refresh.assert_awaited_once()
        ack.assert_awaited_once()

    async def test_wrong_package_name_is_refused(self) -> None:
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

    async def test_wrong_product_id_is_refused(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            with self.assertRaises(GooglePlayPurchaseError) as raised:
                await redeem_google_play_purchase(
                    user_id="user-1",
                    product_id="other_product",
                    purchase_token="token",
                )
        self.assertIn("PRODUCT", str(raised.exception))

    async def test_duplicate_play_token_is_idempotent(self) -> None:
        async def purchased(package: str, product: str, token: str) -> dict:
            return {
                "purchaseState": 0,
                "obfuscatedExternalAccountId": play_obfuscated_account_id("user-1"),
            }

        upsert = AsyncMock()
        refresh = AsyncMock(
            return_value={"user_id": "user-1", "access_level": "full"},
        )
        ack = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play.upsert_entitlement_source", upsert):
                with patch("google_play.refresh_user_entitlement", refresh):
                    first = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="dup-token",
                        fetch_purchase=purchased,
                        acknowledge=ack,
                    )
                    second = await redeem_google_play_purchase(
                        user_id="user-1",
                        product_id="dragonslair_full",
                        purchase_token="dup-token",
                        fetch_purchase=purchased,
                        acknowledge=ack,
                    )
        self.assertEqual(first["access_level"], "full")
        self.assertEqual(second["access_level"], "full")
        self.assertEqual(upsert.await_count, 2)
        self.assertEqual(refresh.await_count, 2)
        self.assertEqual(
            upsert.await_args_list[0].kwargs["provider_ref"],
            purchase_token_fingerprint("dup-token"),
        )


if __name__ == "__main__":
    unittest.main()
