import unittest

from pydantic import ValidationError

from models import StartCombatPayload
from state_effects import combat_context_from_row, has_request_roll, next_combat_state


class _Action:
    def __init__(self, type_name: str) -> None:
        self.type = type_name


class CombatStateTest(unittest.TestCase):
    def test_start_from_inactive_is_round_one(self) -> None:
        state = next_combat_state(
            current_active=False,
            current_round=0,
            starting=True,
            requested_round=None,
        )
        self.assertTrue(state["active"])
        self.assertEqual(state["round"], 1)

    def test_start_while_active_increments_round(self) -> None:
        state = next_combat_state(
            current_active=True,
            current_round=1,
            starting=True,
            requested_round=None,
        )
        self.assertTrue(state["active"])
        self.assertEqual(state["round"], 2)

    def test_explicit_round_overrides_increment(self) -> None:
        state = next_combat_state(
            current_active=True,
            current_round=2,
            starting=True,
            requested_round=4,
        )
        self.assertEqual(state["round"], 4)

    def test_end_keeps_round_and_deactivates(self) -> None:
        state = next_combat_state(
            current_active=True,
            current_round=3,
            starting=False,
            requested_round=None,
        )
        self.assertFalse(state["active"])
        self.assertEqual(state["round"], 3)

    def test_start_payload_accepts_empty_and_rejects_zero(self) -> None:
        empty = StartCombatPayload.model_validate({})
        self.assertIsNone(empty.round)
        with self.assertRaises(ValidationError):
            StartCombatPayload.model_validate({"round": 0})

    def test_combat_context_from_missing_row(self) -> None:
        self.assertEqual(
            combat_context_from_row(None),
            {"active": False, "round": 0},
        )

    def test_request_roll_still_detected_with_start_combat(self) -> None:
        self.assertTrue(
            has_request_roll(
                [_Action("start_combat"), _Action("request_roll")]
            )
        )


if __name__ == "__main__":
    unittest.main()
