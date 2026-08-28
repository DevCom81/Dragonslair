import unittest

from models import GameMasterAction, GameMasterResponse
from music_mood import last_narrative_music_mood


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

    def test_last_narrative_mood_ignores_combat_and_keeps_place(self) -> None:
        actions = [
            GameMasterAction.model_validate(
                {"type": "set_music_mood", "mood": "tavern"}
            ),
            GameMasterAction.model_validate({"type": "start_combat"}),
            GameMasterAction.model_validate(
                {"type": "set_music_mood", "mood": "combat"}
            ),
        ]
        self.assertEqual(last_narrative_music_mood(actions), "tavern")

    def test_last_narrative_mood_uses_the_latest_place(self) -> None:
        actions = [
            GameMasterAction.model_validate(
                {"type": "set_music_mood", "mood": "exploration"}
            ),
            GameMasterAction.model_validate(
                {"type": "set_music_mood", "mood": "tavern"}
            ),
        ]
        self.assertEqual(last_narrative_music_mood(actions), "tavern")

    def test_user_prompt_includes_current_scene_music(self) -> None:
        from models import GameMasterRequest
        from openrouter_client import build_user_prompt

        request = GameMasterRequest(
            room_id="room-1",
            player_id="p1",
            action="Entre dans l auberge.",
            music_mood="tavern",
        )
        prompt = build_user_prompt(request)
        self.assertIn("CURRENT SCENE MUSIC", prompt)
        self.assertIn("tavern", prompt)


if __name__ == "__main__":
    unittest.main()
