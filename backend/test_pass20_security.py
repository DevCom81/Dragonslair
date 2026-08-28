"""
PASS 20 — security guard tests for Google Play monetization.
Static checks; no production behavior change unless a rule is violated.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "backend"
LIB = ROOT / "lib"


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


class Pass20BackendSecurityTest(unittest.TestCase):
    def test_google_play_never_logs_raw_purchase_token(self) -> None:
        src = _read(BACKEND / "google_play.py")
        for line in src.splitlines():
            if "logger." not in line:
                continue
            self.assertNotIn("purchase_token", line.lower())

    def test_google_play_stores_token_fingerprint_not_raw_token(self) -> None:
        src = _read(BACKEND / "google_play.py")
        self.assertIn("provider_ref=purchase_token_fingerprint(token)", src)
        self.assertNotIn("provider_ref=token", src)

    def test_no_order_id_as_business_key(self) -> None:
        pattern = re.compile(r"orderId|order_id", re.IGNORECASE)
        for path in BACKEND.glob("*.py"):
            if path.name.startswith("test_"):
                continue
            src = _read(path)
            self.assertIsNone(pattern.search(src), msg=f"order id found in {path.name}")

    def test_revoke_provider_recomputes_global_entitlement(self) -> None:
        src = _read(BACKEND / "supabase_admin.py")
        body = src.split("async def revoke_provider_entitlement")[1].split(
            "async def ", 1
        )[0]
        self.assertIn("refresh_user_entitlement", body)
        self.assertNotIn("access_level", body.split("refresh_user_entitlement")[0])

    def test_grant_full_entitlement_recomputes_from_sources(self) -> None:
        src = _read(BACKEND / "supabase_admin.py")
        body = src.split("async def grant_full_entitlement")[1].split("async def ", 1)[0]
        self.assertIn("upsert_entitlement_source", body)
        self.assertIn("refresh_user_entitlement", body)
        self.assertNotIn("'access_level', 'full'", body)

    def test_entitlement_merge_never_uses_platform(self) -> None:
        src = _read(BACKEND / "entitlements.py")
        self.assertNotIn("platform", src.lower())

    def test_single_entitlement_tables_without_client_write_policies(self) -> None:
        sources_sql = _read(
            ROOT / "supabase/migrations/20260828_entitlement_sources.sql"
        )
        demo_sql = _read(ROOT / "supabase/migrations/20260827_demo_access.sql")
        self.assertIn("entitlement_sources", sources_sql)
        self.assertNotIn("create table if not exists user_full", sources_sql)
        self.assertNotIn("on user_entitlements for update", demo_sql)
        self.assertNotIn("on user_entitlements for insert", demo_sql)

    def test_stripe_webhook_revokes_provider_not_global_demo_directly(self) -> None:
        src = _read(BACKEND / "main.py")
        webhook = src.split("async def purchase_stripe_webhook")[1].split("@app.", 1)[0]
        self.assertIn("revoke_provider_entitlement", webhook)
        self.assertNotIn("access_level", webhook)
        self.assertNotIn("'demo'", webhook)


if __name__ == "__main__":
    unittest.main()
