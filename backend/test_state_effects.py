import unittest

from state_effects import apply_damage, apply_heal, give_item, remove_item, tick_effects


class StateEffectsTest(unittest.TestCase):
    def test_damage_and_heal_are_clamped(self) -> None:
        self.assertEqual(apply_damage(10, 4), 6)
        self.assertEqual(apply_damage(3, 10), 0)
        self.assertEqual(apply_heal(90, 20), 100)

    def test_give_item_stacks_same_id(self) -> None:
        inventory = give_item([], {"id": "torch", "name": "Torche", "quantity": 1})
        inventory = give_item(inventory, {"id": "torch", "name": "Torche", "quantity": 2})
        self.assertEqual(len(inventory), 1)
        self.assertEqual(inventory[0]["quantity"], 3)

    def test_remove_item_decreases_quantity(self) -> None:
        inventory = [{"id": "potion", "name": "Potion", "quantity": 2, "type": "consumable"}]
        next_inventory = remove_item(inventory, "potion", 1)
        self.assertEqual(next_inventory[0]["quantity"], 1)
        self.assertEqual(remove_item(next_inventory, "potion", 1), [])

    def test_give_item_keeps_bonuses(self) -> None:
        inventory = give_item(
            [],
            {
                "id": "sword",
                "name": "Epee",
                "type": "weapon",
                "bonuses": {"strength": 2},
            },
        )
        self.assertEqual(inventory[0]["bonuses"]["strength"], 2)
        self.assertFalse(inventory[0]["equipped"])

    def test_tick_effects_expires_and_keeps_permanent(self) -> None:
        kept, expired = tick_effects(
            [
                {"id": "bless", "name": "Bless", "remaining": 1},
                {"id": "mark", "name": "Marque", "remaining": None},
            ]
        )
        self.assertEqual(len(expired), 1)
        self.assertEqual(expired[0]["id"], "bless")
        self.assertEqual(kept[0]["id"], "mark")


if __name__ == "__main__":
    unittest.main()
