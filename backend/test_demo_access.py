import unittest
from datetime import datetime, timedelta, timezone

from demo_access import (
    canned_demo_ending,
    ensure_finish_action,
    evaluate_demo_play,
    next_demo_clock,
    normalize_access_level,
)
from openrouter_client import build_user_prompt
from models import GameMasterRequest


class DemoAccessTest(unittest.TestCase):
    def test_missing_entitlement_is_demo(self) -> None:
        self.assertEqual(normalize_access_level(None), "demo")
        self.assertEqual(normalize_access_level("FULL"), "full")

    def test_clock_starts_on_first_play(self) -> None:
        now = datetime(2026, 8, 27, 10, 0, tzinfo=timezone.utc)
        start, end, status = next_demo_clock(
            now=now,
            started_at=None,
            expires_at=None,
            completed_at=None,
        )
        self.assertEqual(status, "ok")
        self.assertEqual(start, now)
        self.assertEqual(end, now + timedelta(minutes=10))

    def test_clock_expires_after_ten_minutes(self) -> None:
        start = datetime(2026, 8, 27, 10, 0, tzinfo=timezone.utc)
        _, _, status = next_demo_clock(
            now=start + timedelta(minutes=10),
            started_at=start,
            expires_at=start + timedelta(minutes=10),
            completed_at=None,
        )
        self.assertEqual(status, "expired")

    def test_full_access_skips_demo_room_rules(self) -> None:
        status = evaluate_demo_play(
            access_level="full",
            room_status="playing",
            room_scenario_id="dungeon",
            room_host_id="host",
            user_id="other",
            started_at=None,
            expires_at=None,
            completed_at=None,
        )
        self.assertEqual(status, "ok")

    def test_demo_cannot_play_catalog_room(self) -> None:
        status = evaluate_demo_play(
            access_level="demo",
            room_status="playing",
            room_scenario_id="dungeon",
            room_host_id="user",
            user_id="user",
            started_at=None,
            expires_at=None,
            completed_at=None,
        )
        self.assertEqual(status, "forbidden")

    def test_closed_room_is_closed_even_for_full(self) -> None:
        status = evaluate_demo_play(
            access_level="full",
            room_status="demo_finished",
            room_scenario_id="demo",
            room_host_id="user",
            user_id="user",
            started_at=None,
            expires_at=None,
            completed_at=None,
        )
        self.assertEqual(status, "closed")

    def test_canned_ending_has_finish_game(self) -> None:
        payload = canned_demo_ending("fr")
        self.assertIn("wyrm", payload["narration"].lower())
        self.assertEqual(payload["actions"][0]["type"], "finish_game")

    def test_ensure_finish_action_appends_when_missing(self) -> None:
        payload = ensure_finish_action(
            {"narration": "Suite.", "actions": [{"type": "narrate"}]},
            "en",
        )
        types = [action["type"] for action in payload["actions"]]
        self.assertIn("finish_game", types)

    def test_prompt_includes_demo_end_required(self) -> None:
        request = GameMasterRequest(
            room_id="room-1",
            player_id="player-1",
            action="I open the door",
            demo_end_required=True,
            locale="en",
        )
        prompt = build_user_prompt(request)
        self.assertIn("DEMO END REQUIRED", prompt)
        self.assertIn("finish_game", prompt)

    def test_demo_scenario_is_allowed_for_the_host(self) -> None:
        now = datetime(2026, 8, 27, 10, 5, tzinfo=timezone.utc)
        status = evaluate_demo_play(
            access_level="demo",
            room_status="playing",
            room_scenario_id="demo",
            room_host_id="user",
            user_id="user",
            started_at=datetime(2026, 8, 27, 10, 0, tzinfo=timezone.utc),
            expires_at=datetime(2026, 8, 27, 10, 10, tzinfo=timezone.utc),
            completed_at=None,
            now=now,
        )
        self.assertEqual(status, "ok")

    def test_custom_and_multiplayer_are_forbidden_in_demo(self) -> None:
        self.assertEqual(
            evaluate_demo_play(
                access_level="demo",
                room_status="playing",
                room_scenario_id="custom",
                room_host_id="user",
                user_id="user",
                started_at=None,
                expires_at=None,
                completed_at=None,
            ),
            "forbidden",
        )
        self.assertEqual(
            evaluate_demo_play(
                access_level="demo",
                room_status="playing",
                room_scenario_id="demo",
                room_host_id="host",
                user_id="other",
                started_at=None,
                expires_at=None,
                completed_at=None,
            ),
            "forbidden",
        )

    def test_clock_does_not_depend_on_character_sheet_fields(self) -> None:
        now = datetime(2026, 8, 27, 10, 0, tzinfo=timezone.utc)
        start, end, status = next_demo_clock(
            now=now,
            started_at=None,
            expires_at=None,
            completed_at=None,
        )
        self.assertEqual(status, "ok")
        self.assertEqual(end - start, timedelta(minutes=10))

    def test_expired_clock_is_expired_not_ok(self) -> None:
        start = datetime(2026, 8, 27, 10, 0, tzinfo=timezone.utc)
        status = evaluate_demo_play(
            access_level="demo",
            room_status="playing",
            room_scenario_id="demo",
            room_host_id="user",
            user_id="user",
            started_at=start,
            expires_at=start + timedelta(minutes=10),
            completed_at=None,
            now=start + timedelta(minutes=10),
        )
        self.assertEqual(status, "expired")


if __name__ == "__main__":
    unittest.main()
