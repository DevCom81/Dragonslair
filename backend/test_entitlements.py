import unittest
from datetime import datetime, timedelta, timezone

from entitlements import (
    compute_global_entitlement,
    entitlement_row_is_full,
    source_grants_full,
)
from purchases import already_has_full_access


def _source(
    provider: str,
    *,
    status: str = "active",
    period_end: datetime | None = None,
) -> dict:
    return {
        "provider": provider,
        "status": status,
        "current_period_end": period_end.isoformat() if period_end else None,
    }


class EntitlementModelTest(unittest.TestCase):
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
        self.assertEqual(row["source"], "purchase")
        self.assertIsNone(row["expires_at"])
        self.assertEqual(row["metadata"]["active_sources"], ["stripe"])

    def test_google_only_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play", period_end=self.future)],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["google_play"])
        self.assertEqual(row["expires_at"], self.future.isoformat())

    def test_stripe_and_google_are_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe"),
                _source("google_play", period_end=self.future),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["google_play", "stripe"])
        self.assertIsNone(row["expires_at"])

    def test_expired_stripe_with_active_google_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe", status="expired", period_end=self.past),
                _source("google_play", period_end=self.future),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["google_play"])

    def test_expired_google_with_active_stripe_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe"),
                _source("google_play", status="expired", period_end=self.past),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")
        self.assertEqual(row["metadata"]["active_sources"], ["stripe"])

    def test_all_expired_is_demo(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[
                _source("stripe", status="expired", period_end=self.past),
                _source("google_play", status="expired", period_end=self.past),
            ],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "demo")
        self.assertEqual(row["metadata"]["active_sources"], [])

    def test_pending_does_not_grant_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play", status="pending")],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "demo")
        self.assertFalse(source_grants_full(_source("google_play", status="pending")))

    def test_canceled_until_period_end_is_full(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play", status="canceled", period_end=self.future)],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "full")

    def test_canceled_after_period_end_is_demo(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play", status="canceled", period_end=self.past)],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "demo")

    def test_revoked_is_demo(self) -> None:
        row = compute_global_entitlement(
            user_id="u1",
            sources=[_source("google_play", status="revoked")],
            now=self.now,
        )
        self.assertEqual(row["access_level"], "demo")

    def test_cached_row_honors_expires_at(self) -> None:
        self.assertTrue(already_has_full_access({"access_level": "full"}))
        self.assertTrue(
            entitlement_row_is_full(
                {"access_level": "full", "expires_at": self.future.isoformat()},
                now=self.now,
            )
        )
        self.assertFalse(
            entitlement_row_is_full(
                {"access_level": "full", "expires_at": self.past.isoformat()},
                now=self.now,
            )
        )


if __name__ == "__main__":
    unittest.main()
