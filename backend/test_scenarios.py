import unittest

from models import GeneratedScenario, GenerateScenarioRequest
from scenario_state import public_world_state


class CustomScenarioTest(unittest.TestCase):
    def test_public_world_state_strips_secrets(self) -> None:
        public = public_world_state(
            {
                "title": "La Route",
                "gm_secrets": ["le prince est un usurateur"],
                "gm_state": {"hidden": True},
                "secrets": ["nope"],
                "setting": "Un royaume en guerre",
            }
        )
        self.assertEqual(public["title"], "La Route")
        self.assertEqual(public["setting"], "Un royaume en guerre")
        self.assertNotIn("gm_secrets", public)
        self.assertNotIn("gm_state", public)
        self.assertNotIn("secrets", public)

    def test_generated_scenario_public_dict_hides_secrets(self) -> None:
        generated = GeneratedScenario.model_validate(
            {
                "title": "Escorte",
                "setting": "Royaume fracture",
                "tone": "sombre",
                "public_objective": "Conduire le prince a la capitale",
                "starting_location": {
                    "name": "Auberge",
                    "description": "Une salle enfumee",
                },
                "initial_situation": "La pluie tombe.",
                "known_facts": ["Le prince voyage incognito"],
                "gm_secrets": ["Un assassin est deja a table"],
                "opening_narration": "La porte claque. Un jeune homme trempe entre.",
            }
        )
        public = generated.public_dict()
        self.assertEqual(public["title"], "Escorte")
        self.assertNotIn("gm_secrets", public)
        self.assertEqual(generated.gm_secrets, ["Un assassin est deja a table"])

    def test_generate_request_requires_a_real_prompt(self) -> None:
        with self.assertRaises(Exception):
            GenerateScenarioRequest.model_validate(
                {"room_id": "r1", "prompt": "trop court"}
            )
        payload = GenerateScenarioRequest.model_validate(
            {
                "room_id": "r1",
                "prompt": "Quatre mercenaires escortent un prince en terre hostile.",
            }
        )
        self.assertTrue(payload.improvise)
        self.assertFalse(payload.pvp)


if __name__ == "__main__":
    unittest.main()
