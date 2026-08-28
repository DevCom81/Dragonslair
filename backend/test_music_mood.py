import unittest

from models import GameMasterAction, GameMasterResponse


class MusicMoodContractTest(unittest.TestCase):
    def test_accepts_set_music_mood_with_payload(self) -> None:
        action = GameMasterAction.model_validate(
            {"type": "set_music_mood", "payload": {"mood": "exploration"}}
        )
        self.assertEqual(action.type, "set_music_mood")
        self.assertEqual(action.payload.get("mood"), "exploration")

    def test_folds_top_level_mood_into_payload(self) -> None:
        action = GameMasterAction.model_validate(
            {"type": "set_music_mood", "mood": "tension"}
        )
        self.assertEqual(action.payload.get("mood"), "tension")

    def test_drops_invalid_music_mood_without_failing_the_turn(self) -> None:
        response = GameMasterResponse.model_validate(
            {
                "narration": "Un vent froid passe.",
                "actions": [
                    {"type": "set_music_mood", "mood": "epic_orchestra"},
                    {
                        "type": "system_message",
                        "payload": {"message": "ok"},
                    },
                ],
                "choices": [],
            }
        )
        self.assertEqual(len(response.actions), 1)
        self.assertEqual(response.actions[0].type, "system_message")

    def test_keeps_valid_music_mood(self) -> None:
        response = GameMasterResponse.model_validate(
            {
                "narration": "Les torches vacillent.",
                "actions": [{"type": "set_music_mood", "mood": "mystery"}],
                "choices": [],
            }
        )
        self.assertEqual(response.actions[0].type, "set_music_mood")
        self.assertEqual(response.actions[0].payload.get("mood"), "mystery")


if __name__ == "__main__":
    unittest.main()
