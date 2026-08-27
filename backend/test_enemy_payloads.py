import unittest

from pydantic import ValidationError

from models import EnemyHpPayload, SpawnEnemyPayload
from state_effects import flatten_position_payload


class EnemyPayloadTest(unittest.TestCase):
    def test_spawn_payload_requires_name_and_clamps_position(self) -> None:
        payload = SpawnEnemyPayload.model_validate(
            flatten_position_payload(
                {
                    "name": "Gobelin",
                    "position": {"x": 0.25, "y": 0.75},
                    "hp": 12,
                }
            )
        )
        self.assertEqual(payload.name, "Gobelin")
        self.assertEqual(payload.x, 0.25)
        self.assertEqual(payload.y, 0.75)
        self.assertEqual(payload.hp, 12)
        self.assertEqual(payload.enemy_type, "enemy")

    def test_spawn_rejects_hp_zero_and_out_of_board(self) -> None:
        with self.assertRaises(ValidationError):
            SpawnEnemyPayload.model_validate({"name": "X", "hp": 0})
        with self.assertRaises(ValidationError):
            SpawnEnemyPayload.model_validate({"name": "X", "x": 1.4, "y": 0.5})

    def test_damage_payload_requires_non_negative_amount(self) -> None:
        payload = EnemyHpPayload.model_validate(
            flatten_position_payload({"name": "Gobelin", "damage": 6})
        )
        self.assertEqual(payload.amount, 6)
        with self.assertRaises(ValidationError):
            EnemyHpPayload.model_validate({"name": "Gobelin", "amount": -1})

    def test_move_payload_clamps_to_the_board(self) -> None:
        from models import MoveEnemyPayload

        payload = MoveEnemyPayload.model_validate(
            flatten_position_payload(
                {"enemy_id": "e1", "position": {"x": 0.1, "y": 0.9}}
            )
        )
        self.assertEqual(payload.enemy_id, "e1")
        self.assertEqual(payload.x, 0.1)
        self.assertEqual(payload.y, 0.9)
        with self.assertRaises(ValidationError):
            MoveEnemyPayload.model_validate({"name": "Gobelin", "x": -0.1, "y": 0.5})

    def test_defeat_payload_needs_id_or_name(self) -> None:
        from models import DefeatEnemyPayload

        by_id = DefeatEnemyPayload.model_validate({"enemy_id": "e1"})
        self.assertEqual(by_id.enemy_id, "e1")
        by_name = DefeatEnemyPayload.model_validate({"name": "Gobelin"})
        self.assertEqual(by_name.name, "Gobelin")


if __name__ == "__main__":
    unittest.main()
