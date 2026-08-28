import hashlib
import hmac
import json
import unittest

from purchases import (
    already_has_full_access,
    grant_metadata,
    is_checkout_configured,
    normalize_purchase_source,
    offer_from_stripe_price,
    parse_checkout_user_id,
    parse_stripe_inactive_user_id,
    verify_stripe_signature,
)


def _sign(secret: str, timestamp: int, payload: bytes) -> str:
    signed = f"{timestamp}.".encode("utf-8") + payload
    digest = hmac.new(secret.encode("utf-8"), signed, hashlib.sha256).hexdigest()
    return f"t={timestamp},v1={digest}"


class PurchasesTest(unittest.TestCase):
    def test_checkout_is_not_configured_without_env(self) -> None:
        self.assertFalse(is_checkout_configured())

    def test_source_from_client_cannot_become_full_shortcut(self) -> None:
        self.assertEqual(normalize_purchase_source("full"), "purchase")
        self.assertEqual(normalize_purchase_source("admin"), "admin")

    def test_offer_uses_stripe_amount_not_a_hardcoded_price(self) -> None:
        offer = offer_from_stripe_price(
            {"id": "price_test", "unit_amount": 2450, "currency": "eur"}
        )
        self.assertEqual(offer["unit_amount"], 2450)
        self.assertEqual(offer["currency"], "eur")
        self.assertNotIn("19.99", json.dumps(offer))

    def test_checkout_completed_reads_user_from_session(self) -> None:
        user_id = parse_checkout_user_id(
            {
                "type": "checkout.session.completed",
                "data": {
                    "object": {
                        "id": "cs_test",
                        "payment_status": "paid",
                        "client_reference_id": "user-1",
                    }
                },
            }
        )
        self.assertEqual(user_id, "user-1")

    def test_unrelated_event_is_ignored(self) -> None:
        self.assertIsNone(
            parse_checkout_user_id({"type": "invoice.paid", "data": {"object": {}}})
        )
        self.assertIsNone(
            parse_stripe_inactive_user_id(
                {"type": "invoice.paid", "data": {"object": {}}}
            )
        )

    def test_full_refund_maps_user_from_charge_metadata(self) -> None:
        user_id = parse_stripe_inactive_user_id(
            {
                "type": "charge.refunded",
                "data": {
                    "object": {
                        "refunded": True,
                        "metadata": {"user_id": "user-1"},
                    }
                },
            }
        )
        self.assertEqual(user_id, "user-1")

    def test_partial_refund_does_not_inactivate(self) -> None:
        self.assertIsNone(
            parse_stripe_inactive_user_id(
                {
                    "type": "charge.refunded",
                    "data": {
                        "object": {
                            "refunded": False,
                            "metadata": {"user_id": "user-1"},
                        }
                    },
                }
            )
        )

    def test_unpaid_or_processing_checkout_is_ignored(self) -> None:
        for status in ("unpaid", "processing", "failed"):
            self.assertIsNone(
                parse_checkout_user_id(
                    {
                        "type": "checkout.session.completed",
                        "data": {
                            "object": {
                                "payment_status": status,
                                "client_reference_id": "user-1",
                            }
                        },
                    }
                )
            )

    def test_metadata_access_level_without_user_is_ignored(self) -> None:
        self.assertIsNone(
            parse_checkout_user_id(
                {
                    "type": "checkout.session.completed",
                    "data": {
                        "object": {
                            "payment_status": "paid",
                            "metadata": {"access_level": "full"},
                        }
                    },
                }
            )
        )

    def test_completed_without_user_is_ignored(self) -> None:
        self.assertIsNone(
            parse_checkout_user_id(
                {
                    "type": "checkout.session.completed",
                    "data": {"object": {"payment_status": "paid"}},
                }
            )
        )

    def test_valid_signature_is_accepted(self) -> None:
        payload = b'{"type":"checkout.session.completed"}'
        header = _sign("whsec_test", 1_700_000_000, payload)
        verify_stripe_signature(
            payload=payload,
            header=header,
            secret="whsec_test",
            now=1_700_000_000,
        )

    def test_invalid_signature_is_rejected(self) -> None:
        payload = b'{"type":"checkout.session.completed"}'
        with self.assertRaises(Exception):
            verify_stripe_signature(
                payload=payload,
                header="t=1700000000,v1=deadbeef",
                secret="whsec_test",
                now=1_700_000_000,
            )

    def test_grant_metadata_does_not_include_access_level(self) -> None:
        meta = grant_metadata(session_id="cs_test")
        self.assertEqual(meta["provider"], "stripe")
        self.assertNotIn("access_level", meta)
        self.assertNotIn("full", meta.values())

    def test_full_grant_is_idempotent(self) -> None:
        self.assertTrue(
            already_has_full_access({"access_level": "full", "source": "purchase"})
        )
        self.assertFalse(already_has_full_access({"access_level": "demo"}))
        self.assertFalse(already_has_full_access({"access_level": "full_access"}))


if __name__ == "__main__":
    unittest.main()
