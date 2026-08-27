import unittest

from pydantic import ValidationError

from models import ResolveRollRequest
from state_effects import (
    can_resolve_pending_roll,
    effective_modifier_from_row,
    parse_request_roll,
    resolve_roll_total,
)


class PendingRollsTest(unittest.TestCase):
    def test_parse_request_roll_accepts_target_id(self) -> None:
        parsed = parse_request_roll(
            {
                "target_id": "player-b",
                "ability": "dexterity",
                "dc": 14,
                "reason": "esquiver le piege",
            }
        )
        self.assertIsNotNone(parsed)
        assert parsed is not None
        self.assertEqual(parsed["player_id"], "player-b")
        self.assertEqual(parsed["ability"], "dexterity")
        self.assertEqual(parsed["dc"], 14)
        self.assertEqual(parsed["reason"], "esquiver le piege")

    def test_parse_request_roll_clamps_dc(self) -> None:
        low = parse_request_roll(
            {"player_id": "p1", "stat": "wisdom", "difficulty": 2}
        )
        high = parse_request_roll(
            {"player_id": "p1", "ability": "wisdom", "dc": 40}
        )
        self.assertEqual(low["dc"], 5)
        self.assertEqual(high["dc"], 25)

    def test_parse_request_roll_rejects_unknown_ability(self) -> None:
        self.assertIsNone(
            parse_request_roll(
                {"player_id": "p1", "ability": "luck", "dc": 12}
            )
        )

    def test_other_player_cannot_resolve(self) -> None:
        self.assertTrue(
            can_resolve_pending_roll(
                status="pending",
                roll_player_id="p1",
                actor_player_id="p1",
            )
        )
        self.assertFalse(
            can_resolve_pending_roll(
                status="pending",
                roll_player_id="p1",
                actor_player_id="p2",
            )
        )
        self.assertFalse(
            can_resolve_pending_roll(
                status="resolved",
                roll_player_id="p1",
                actor_player_id="p1",
            )
        )

    def test_modifier_includes_equipped_bonus_and_effects(self) -> None:
        row = {
            "strength": 16,
            "inventory": [
                {
                    "id": "sword",
                    "equipped": True,
                    "bonuses": {"strength": 2},
                },
                {
                    "id": "ring",
                    "equipped": False,
                    "bonuses": {"strength": 4},
                },
            ],
            "effects": [
                {"stat": "strength", "delta": 2},
                {"ability": "dexterity", "delta": 6},
            ],
        }
        # 16 + 2 (equipped) + 2 (effect) = 20 → modifier +5
        self.assertEqual(effective_modifier_from_row(row, "strength"), 5)

    def test_success_when_total_meets_dc(self) -> None:
        success = resolve_roll_total(raw=12, modifier=2, dc=14)
        self.assertEqual(success["raw"], 12)
        self.assertEqual(success["total"], 14)
        self.assertTrue(success["success"])

        failure = resolve_roll_total(raw=11, modifier=2, dc=14)
        self.assertEqual(failure["total"], 13)
        self.assertFalse(failure["success"])

    def test_raw_is_clamped_to_d20(self) -> None:
        high = resolve_roll_total(raw=40, modifier=0, dc=10)
        low = resolve_roll_total(raw=0, modifier=0, dc=10)
        self.assertEqual(high["raw"], 20)
        self.assertEqual(low["raw"], 1)

    def test_resolve_request_accepts_raw_only(self) -> None:
        payload = ResolveRollRequest.model_validate(
            {"pending_roll_id": "roll-1", "raw": 17}
        )
        self.assertEqual(payload.raw, 17)
        self.assertNotIn("modifier", ResolveRollRequest.model_fields)
        with self.assertRaises(ValidationError):
            ResolveRollRequest.model_validate(
                {"pending_roll_id": "roll-1", "raw": 21}
            )


if __name__ == "__main__":
    unittest.main()
