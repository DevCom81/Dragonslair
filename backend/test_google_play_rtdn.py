import base64
import json
import os
import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from fastapi.testclient import TestClient

import main
from google_play import play_obfuscated_account_id, purchase_token_fingerprint
from google_play_rtdn import (
    decode_pubsub_push,
    is_rtdn_configured,
    parse_developer_notification,
    process_rtdn_notification,
)


_PLAY_ENV = {
    "GOOGLE_PLAY_PACKAGE_NAME": "com.devcom81.dragons_lair",
    "GOOGLE_PLAY_PRODUCT_ID": "dragonslair_full",
    "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": json.dumps(
        {"type": "service_account", "private_key": "dummy", "client_email": "a@b.c"}
    ),
    "GOOGLE_PLAY_RTDN_AUDIENCE": "https://api.example.com/v1/purchases/google-rtdn",
}


def _pubsub(payload: dict, message_id: str = "msg-1") -> dict:
    return {
        "message": {
            "data": base64.b64encode(json.dumps(payload).encode("utf-8")).decode("ascii"),
            "messageId": message_id,
        },
        "subscription": "projects/test/subscriptions/play-rtdn",
    }


def _one_time_payload(
    *,
    token: str = "product-token",
    notification_type: int = 1,
) -> dict:
    return {
        "packageName": "com.devcom81.dragons_lair",
        "oneTimeProductNotification": {
            "notificationType": notification_type,
            "purchaseToken": token,
            "sku": "dragonslair_full",
        },
    }


class GooglePlayRtdnModelTest(unittest.TestCase):
    def test_parse_subscription_notification_is_ignored(self) -> None:
        parsed = parse_developer_notification(
            {
                "packageName": "com.devcom81.dragons_lair",
                "subscriptionNotification": {
                    "notificationType": 2,
                    "purchaseToken": "sub-token",
                    "subscriptionId": "dragonslair_full",
                },
            }
        )
        self.assertEqual(parsed, {"kind": "ignored_subscription"})

    def test_parse_one_time_product_notification(self) -> None:
        parsed = parse_developer_notification(_one_time_payload())
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed["kind"], "product")
        self.assertEqual(parsed["purchase_token"], "product-token")
        self.assertEqual(parsed["product_id"], "dragonslair_full")

    def test_parse_test_notification(self) -> None:
        parsed = parse_developer_notification({"testNotification": {"version": "1.0"}})
        self.assertEqual(parsed, {"kind": "test"})

    def test_decode_pubsub_push(self) -> None:
        envelope = decode_pubsub_push(_pubsub(_one_time_payload()))
        self.assertEqual(envelope["message_id"], "msg-1")
        self.assertIn("oneTimeProductNotification", envelope["payload"])


class GooglePlayRtdnProcessTest(unittest.IsolatedAsyncioTestCase):
    async def test_test_notification_is_ignored(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            result = await process_rtdn_notification(
                _pubsub({"testNotification": {"version": "1.0"}})
            )
        self.assertEqual(result, {"status": "ignored", "reason": "test"})

    async def test_subscription_notification_is_ignored(self) -> None:
        payload = {
            "packageName": "com.devcom81.dragons_lair",
            "subscriptionNotification": {
                "notificationType": 2,
                "purchaseToken": "sub-token",
                "subscriptionId": "dragonslair_full",
            },
        }
        sync = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch(
                "google_play_rtdn.GooglePlayBillingService.sync_entitlement",
                sync,
            ):
                result = await process_rtdn_notification(_pubsub(payload))
        self.assertEqual(result["status"], "ignored")
        self.assertEqual(result["reason"], "subscription_not_supported")
        sync.assert_not_awaited()

    async def test_one_time_purchased_resyncs_entitlement(self) -> None:
        find_ref = AsyncMock(return_value="user-1")
        sync = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "full",
                "source": "purchase",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play_rtdn.find_entitlement_user_by_google_play_ref", find_ref):
                with patch(
                    "google_play_rtdn.GooglePlayBillingService.sync_entitlement",
                    sync,
                ):
                    result = await process_rtdn_notification(
                        _pubsub(_one_time_payload(token="buy-token", notification_type=1))
                    )
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["access_level"], "full")
        find_ref.assert_awaited_once_with(purchase_token_fingerprint("buy-token"))
        sync.assert_awaited_once()

    async def test_one_time_canceled_resyncs_and_can_revoke(self) -> None:
        find_ref = AsyncMock(return_value="user-1")
        sync = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "demo",
                "source": "default",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play_rtdn.find_entitlement_user_by_google_play_ref", find_ref):
                with patch(
                    "google_play_rtdn.GooglePlayBillingService.sync_entitlement",
                    sync,
                ):
                    result = await process_rtdn_notification(
                        _pubsub(
                            _one_time_payload(
                                token="cancel-token",
                                notification_type=2,
                            )
                        )
                    )
        self.assertEqual(result["status"], "ok")
        self.assertEqual(result["access_level"], "demo")
        sync.assert_awaited_once()

    async def test_unlinked_token_is_ignored_without_grant(self) -> None:
        find_ref = AsyncMock(return_value=None)
        find_account = AsyncMock(return_value=None)
        empty_record = MagicMock()
        empty_record.payload = {}
        inspect = AsyncMock(return_value=empty_record)
        sync = AsyncMock()
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play_rtdn.find_entitlement_user_by_google_play_ref", find_ref):
                with patch(
                    "google_play_rtdn.find_entitlement_user_by_play_account_id",
                    find_account,
                ):
                    with patch(
                        "google_play_rtdn.GooglePlayBillingService.inspect",
                        inspect,
                    ):
                        with patch(
                            "google_play_rtdn.GooglePlayBillingService.sync_entitlement",
                            sync,
                        ):
                            result = await process_rtdn_notification(
                                _pubsub(_one_time_payload(token="orphan-token"))
                            )
        self.assertEqual(result["status"], "ignored")
        self.assertEqual(result["reason"], "user_not_linked")
        sync.assert_not_awaited()

    async def test_duplicate_message_is_idempotent(self) -> None:
        find_ref = AsyncMock(return_value="user-1")
        sync = AsyncMock(
            return_value={
                "user_id": "user-1",
                "access_level": "full",
                "source": "purchase",
            }
        )
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("google_play_rtdn.find_entitlement_user_by_google_play_ref", find_ref):
                with patch(
                    "google_play_rtdn.GooglePlayBillingService.sync_entitlement",
                    sync,
                ):
                    body = _pubsub(_one_time_payload(token="dup-token"), message_id="dup-1")
                    first = await process_rtdn_notification(body)
                    second = await process_rtdn_notification(body)
        self.assertEqual(first["status"], "ok")
        self.assertEqual(second["status"], "ok")
        self.assertEqual(sync.await_count, 2)


class GooglePlayRtdnHttpTest(unittest.TestCase):
    def test_endpoint_returns_503_when_not_configured(self) -> None:
        env = {
            "GOOGLE_PLAY_PACKAGE_NAME": "com.devcom81.dragons_lair",
            "GOOGLE_PLAY_PRODUCT_ID": "dragonslair_full",
            "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON": json.dumps(
                {"type": "service_account", "private_key": "dummy", "client_email": "a@b.c"}
            ),
        }
        with patch.dict(os.environ, env, clear=False):
            os.environ.pop("GOOGLE_PLAY_RTDN_AUDIENCE", None)
            client = TestClient(main.app)
            response = client.post(
                "/v1/purchases/google-rtdn",
                json=_pubsub({"testNotification": {"version": "1.0"}}),
            )
        self.assertEqual(response.status_code, 503)
        self.assertFalse(is_rtdn_configured())

    def test_endpoint_accepts_verified_push(self) -> None:
        with patch.dict(os.environ, _PLAY_ENV):
            with patch("main.verify_pubsub_push_jwt"):
                with patch(
                    "main.process_rtdn_notification",
                    new=AsyncMock(return_value={"status": "ignored", "reason": "test"}),
                ) as process:
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/google-rtdn",
                        json=_pubsub({"testNotification": {"version": "1.0"}}),
                        headers={"Authorization": "Bearer jwt"},
                    )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "ignored")
        process.assert_awaited_once()


if __name__ == "__main__":
    unittest.main()
