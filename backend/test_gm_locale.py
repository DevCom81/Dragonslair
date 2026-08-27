import unittest

from gm_locale import (
    FALLBACK_LOCALE,
    locale_language_name,
    normalize_locale,
)
from models import GameMasterRequest, GenerateScenarioRequest
from openrouter_client import build_user_prompt, build_system_prompt
from scenario_generator import build_scenario_system_prompt


class GmLocaleTest(unittest.TestCase):
    def test_unknown_locale_falls_back_to_english(self) -> None:
        self.assertEqual(normalize_locale(None), FALLBACK_LOCALE)
        self.assertEqual(normalize_locale(""), "en")
        self.assertEqual(normalize_locale("pt"), "en")
        self.assertEqual(normalize_locale("zz-ZZ"), "en")

    def test_normalizes_region_and_case(self) -> None:
        self.assertEqual(normalize_locale("FR"), "fr")
        self.assertEqual(normalize_locale("en-US"), "en")
        self.assertEqual(normalize_locale("de_DE"), "de")
        self.assertEqual(normalize_locale("es"), "es")

    def test_gm_prompt_asks_for_german_not_french(self) -> None:
        request = GameMasterRequest(
            room_id="room-1",
            player_id="p1",
            action="Inspects the barrel.",
            locale="de",
        )
        system = build_system_prompt(request.locale)
        user = build_user_prompt(request)
        self.assertIn("German", system)
        self.assertIn("German", user)
        self.assertIn("OUTPUT LANGUAGE", user)
        self.assertIn("JSON keys", system)
        self.assertNotIn("en francais", system.lower())

    def test_client_locale_is_normalized_on_the_request_model(self) -> None:
        request = GameMasterRequest(
            room_id="room-1",
            player_id="p1",
            action="Look around.",
            locale="en-GB",
        )
        self.assertEqual(request.locale, "en")

    def test_scenario_prompt_follows_room_locale(self) -> None:
        prompt = build_scenario_system_prompt("es")
        self.assertIn("Spanish", prompt)
        self.assertNotIn("langue francaise", prompt.lower())

    def test_generate_request_falls_back_to_english(self) -> None:
        payload = GenerateScenarioRequest.model_validate(
            {
                "room_id": "r1",
                "prompt": "Four mercenaries escort a prince through a kingdom at war.",
                "locale": "it",
            }
        )
        self.assertEqual(payload.locale, "en")
        self.assertEqual(locale_language_name("it"), "English")


if __name__ == "__main__":
    unittest.main()
