import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(relative: str) -> str:
    return (ROOT / relative).read_text(encoding="utf-8")


class SqlContractTest(unittest.TestCase):
    def test_new_profile_is_demo_not_full(self) -> None:
        sql = _read("supabase/migrations/20260827_demo_access.sql")
        self.assertIn(
            "insert into user_entitlements (user_id, access_level, source)",
            sql,
        )
        self.assertIn("values (new.id, 'demo', 'default')", sql)
        self.assertNotIn("values (new.id, 'full'", sql)
        self.assertIn("user_entitlements_select", sql)
        self.assertNotIn('on user_entitlements for update', sql)
        self.assertNotIn('on user_entitlements for insert', sql)

    def test_enemies_rls_is_select_only_for_clients(self) -> None:
        sql = _read("supabase/migrations/20260827_enemies.sql")
        self.assertIn("create policy \"enemies_select\"", sql)
        self.assertIn("on enemies for select", sql)
        self.assertNotIn("on enemies for insert", sql)
        self.assertNotIn("on enemies for update", sql)
        self.assertNotIn("on enemies for delete", sql)
        self.assertIn("Mutations INSERT/UPDATE/DELETE : service role", sql)

    def test_sql_contracts_music_mood_is_narrative_only(self) -> None:
        sql = _read("supabase/migrations/20260828_room_music_mood.sql")
        self.assertIn("add column if not exists music_mood", sql)
        self.assertIn("tavern", sql)
        self.assertIn("exploration", sql)
        self.assertNotIn("'combat'", sql)

    def test_entitlement_sources_are_service_role_only(self) -> None:
        sql = _read("supabase/migrations/20260828_entitlement_sources.sql")
        self.assertIn("create table if not exists entitlement_sources", sql)
        self.assertIn("revoke all on table entitlement_sources from anon, authenticated", sql)
        self.assertNotIn("on entitlement_sources for select", sql)
        self.assertNotIn("on entitlement_sources for insert", sql)
        self.assertIn("expires_at is null or expires_at > now()", sql)
        self.assertIn("from user_entitlements", sql)

    def test_ai_usage_is_not_readable_by_clients(self) -> None:
        sql = _read("supabase/migrations/20260827_ai_usage.sql")
        self.assertIn("revoke all on table ai_usage_events from anon, authenticated", sql)
        self.assertNotIn("on ai_usage_events for select", sql)
