import unittest

from finish_game import parse_finish_game
from models import FinishGamePayload, GameMasterAction
from state_effects import has_request_roll


class _Action:
    def __init__(self, type_name: str) -> None:
        self.type = type_name


class FinishGameTest(unittest.TestCase):
    def test_parse_finish_game_defaults_to_neutral(self) -> None:
        parsed = parse_finish_game({})
        self.assertEqual(parsed["result"], "neutral")
        self.assertEqual(parsed["summary"], "")
        self.assertEqual(parsed["epilogue"], "")

    def test_parse_finish_game_rejects_unknown_result(self) -> None:
        parsed = parse_finish_game(
            {
                "result": "draw",
                "summary": "Le prince est a l abri.",
                "epilogue": "La route se tait.",
            }
        )
        self.assertEqual(parsed["result"], "neutral")
        self.assertEqual(parsed["summary"], "Le prince est a l abri.")

    def test_parse_finish_game_keeps_victory(self) -> None:
        parsed = parse_finish_game({"result": "VICTORY", "summary": "ok"})
        self.assertEqual(parsed["result"], "victory")

    def test_finish_payload_accepts_empty_and_rejects_long_summary(self) -> None:
        empty = FinishGamePayload.model_validate({})
        self.assertEqual(empty.result, "neutral")
        with self.assertRaises(Exception):
            FinishGamePayload.model_validate({"summary": "x" * 2001})

    def test_request_roll_still_detected_with_finish_game(self) -> None:
        self.assertTrue(
            has_request_roll(
                [_Action("finish_game"), _Action("request_roll")]
            )
        )

    def test_gm_action_accepts_finish_game(self) -> None:
        action = GameMasterAction.model_validate(
            {
                "type": "finish_game",
                "payload": {"result": "defeat", "summary": "La porte cede."},
            }
        )
        self.assertEqual(action.type, "finish_game")


if __name__ == "__main__":
    unittest.main()
