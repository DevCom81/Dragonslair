import hashlib
import hmac
import json
import os
import time
import unittest
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

import main


def _sign(secret: str, timestamp: int, payload: bytes) -> str:
    signed = f"{timestamp}.".encode("utf-8") + payload
    digest = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return f"t={timestamp},v1={digest}"


def _paid_event(user_id: str = "user-1") -> bytes:
    return json.dumps(
        {
            "type": "checkout.session.completed",
            "data": {
                "object": {
                    "id": "cs_test",
                    "payment_status": "paid",
                    "client_reference_id": user_id,
                }
            },
        }
    ).encode("utf-8")


class PurchaseWebhookHttpTest(unittest.TestCase):
    def test_invalid_webhook_is_rejected(self) -> None:
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            client = TestClient(main.app)
            response = client.post(
                "/v1/purchases/stripe-webhook",
                content=b"{}",
                headers={"Stripe-Signature": "t=1,v1=deadbeef"},
            )
        self.assertEqual(response.status_code, 400)

    def test_successful_webhook_grants_full(self) -> None:
        payload = _paid_event()
        timestamp = int(time.time())
        header = _sign("whsec_test", timestamp, payload)
        grant = AsyncMock(return_value={"access_level": "full"})
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            with patch("main.grant_full_entitlement", grant):
                client = TestClient(main.app)
                response = client.post(
                    "/v1/purchases/stripe-webhook",
                    content=payload,
                    headers={"Stripe-Signature": header},
                )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        grant.assert_awaited_once()
        kwargs = grant.await_args.kwargs
        self.assertEqual(kwargs["user_id"], "user-1")
        self.assertEqual(kwargs["source"], "purchase")
        self.assertEqual(kwargs["metadata"]["provider"], "stripe")
        self.assertEqual(kwargs["metadata"]["stripe_session_id"], "cs_test")

    def test_refund_webhook_revokes_stripe_not_global_demo(self) -> None:
        payload = json.dumps(
            {
                "type": "charge.refunded",
                "data": {
                    "object": {
                        "id": "ch_test",
                        "refunded": True,
                        "metadata": {"user_id": "user-1"},
                    }
                },
            }
        ).encode("utf-8")
        timestamp = int(time.time())
        header = _sign("whsec_test", timestamp, payload)
        revoke = AsyncMock(return_value={"access_level": "full"})
        grant = AsyncMock()
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            with patch("main.grant_full_entitlement", grant):
                with patch("main.revoke_provider_entitlement", revoke):
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/stripe-webhook",
                        content=payload,
                        headers={"Stripe-Signature": header},
                    )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})
        grant.assert_not_awaited()
        revoke.assert_awaited_once()
        self.assertEqual(revoke.await_args.kwargs["user_id"], "user-1")
        self.assertEqual(revoke.await_args.kwargs["provider"], "stripe")

    def test_partial_refund_is_ignored(self) -> None:
        payload = json.dumps(
            {
                "type": "charge.refunded",
                "data": {
                    "object": {
                        "refunded": False,
                        "metadata": {"user_id": "user-1"},
                    }
                },
            }
        ).encode("utf-8")
        timestamp = int(time.time())
        header = _sign("whsec_test", timestamp, payload)
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            with patch("main.grant_full_entitlement") as grant:
                with patch("main.revoke_provider_entitlement") as revoke:
                    client = TestClient(main.app)
                    response = client.post(
                        "/v1/purchases/stripe-webhook",
                        content=payload,
                        headers={"Stripe-Signature": header},
                    )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ignored"})
        grant.assert_not_awaited()
        revoke.assert_not_awaited()

    def test_duplicate_webhook_is_idempotent(self) -> None:
        payload = _paid_event()
        timestamp = int(time.time())
        header = _sign("whsec_test", timestamp, payload)
        grant = AsyncMock(return_value={"access_level": "full"})
        with patch.dict(os.environ, {"STRIPE_WEBHOOK_SECRET": "whsec_test"}):
            with patch("main.grant_full_entitlement", grant):
                client = TestClient(main.app)
                first = client.post(
                    "/v1/purchases/stripe-webhook",
                    content=payload,
                    headers={"Stripe-Signature": header},
                )
                second = client.post(
                    "/v1/purchases/stripe-webhook",
                    content=payload,
                    headers={"Stripe-Signature": header},
                )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(second.status_code, 200)
        self.assertEqual(grant.await_count, 2)
        self.assertEqual(grant.await_args.kwargs["source"], "purchase")
