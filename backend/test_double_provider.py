import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from entitlements import compute_global_entitlement
from supabase_admin import revoke_provider_entitlement


def _source(
    provider: str,
    *,
    status: str = "active",
    provider_ref: str = "ref",
    period_end: datetime | None = None,
) -> dict:
    return {
        "provider": provider,
        "provider_ref": provider_ref,
        "status": status,
        "current_period_end": period_end.isoformat() if period_end else None,
        "metadata": {},
    }


class DoubleProviderModelTest(unittest.TestCase):
  """PASS 16 — entitlement is recomputed from all sources, never last-webhook wins."""

  def setUp(self) -> None:
    self.now = datetime(2026, 8, 28, 12, tzinfo=timezone.utc)
    self.future = self.now + timedelta(days=14)
    self.past = self.now - timedelta(days=2)

  def test_both_providers_active_is_full(self) -> None:
    row = compute_global_entitlement(
      user_id="u1",
      sources=[
        _source("stripe", provider_ref="stripe-1"),
        _source("google_play", provider_ref="play-1"),
      ],
      now=self.now,
    )
    self.assertEqual(row["access_level"], "full")
    self.assertEqual(row["metadata"]["active_sources"], ["google_play", "stripe"])

  def test_stripe_revoked_google_active_stays_full(self) -> None:
    row = compute_global_entitlement(
      user_id="u1",
      sources=[
        _source("stripe", status="revoked", provider_ref="stripe-1"),
        _source("google_play", provider_ref="play-1"),
      ],
      now=self.now,
    )
    self.assertEqual(row["access_level"], "full")
    self.assertEqual(row["metadata"]["active_sources"], ["google_play"])

  def test_google_revoked_stripe_active_stays_full(self) -> None:
    row = compute_global_entitlement(
      user_id="u1",
      sources=[
        _source("stripe", provider_ref="stripe-1"),
        _source("google_play", status="revoked", provider_ref="play-1"),
      ],
      now=self.now,
    )
    self.assertEqual(row["access_level"], "full")
    self.assertEqual(row["metadata"]["active_sources"], ["stripe"])

  def test_both_revoked_is_demo(self) -> None:
    row = compute_global_entitlement(
      user_id="u1",
      sources=[
        _source("stripe", status="revoked", provider_ref="stripe-1"),
        _source("google_play", status="revoked", provider_ref="play-1"),
      ],
      now=self.now,
    )
    self.assertEqual(row["access_level"], "demo")
    self.assertEqual(row["metadata"]["active_sources"], [])


class RevokeProviderRefreshTest(unittest.IsolatedAsyncioTestCase):
  async def _revoke_with_sources(self, *, provider: str, sources: list[dict]) -> dict:
    async def upsert(**kwargs) -> dict:
      for row in sources:
        if row.get("provider") == kwargs.get("provider"):
          row["status"] = kwargs.get("status")
          if kwargs.get("current_period_end") is not None:
            row["current_period_end"] = kwargs.get("current_period_end")
      return row

    with patch(
      "supabase_admin.fetch_entitlement_sources",
      new=AsyncMock(return_value=sources),
    ):
      with patch("supabase_admin.upsert_entitlement_source", new=upsert):
        with patch(
          "supabase_admin.persist_computed_entitlement",
          new=AsyncMock(side_effect=lambda **kwargs: kwargs["computed"]),
        ) as persist:
          row = await revoke_provider_entitlement(user_id="u1", provider=provider)
    return row, persist.await_args.kwargs["computed"]

  async def test_stripe_revoke_recomputes_full_from_google(self) -> None:
    sources = [
      _source("stripe", provider_ref="cs_test"),
      _source("google_play", provider_ref="fp_play"),
    ]
    row, computed = await self._revoke_with_sources(provider="stripe", sources=sources)
    self.assertEqual(computed["access_level"], "full")
    self.assertEqual(computed["metadata"]["active_sources"], ["google_play"])
    self.assertEqual(row["access_level"], "full")

  async def test_google_revoke_recomputes_full_from_stripe(self) -> None:
    sources = [
      _source("stripe", provider_ref="cs_test"),
      _source("google_play", provider_ref="fp_play"),
    ]
    row, computed = await self._revoke_with_sources(
      provider="google_play",
      sources=sources,
    )
    self.assertEqual(computed["access_level"], "full")
    self.assertEqual(computed["metadata"]["active_sources"], ["stripe"])
    self.assertEqual(row["access_level"], "full")

  async def test_revoke_last_provider_falls_back_to_demo(self) -> None:
    sources = [_source("stripe", provider_ref="cs_only")]
    row, computed = await self._revoke_with_sources(provider="stripe", sources=sources)
    self.assertEqual(computed["access_level"], "demo")
    self.assertEqual(row["access_level"], "demo")


if __name__ == "__main__":
  unittest.main()
