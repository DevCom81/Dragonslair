import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:dragons_lair/features/players/domain/inventory_item.dart';
import 'package:dragons_lair/features/players/domain/inventory_rules.dart';
import 'package:dragons_lair/features/players/domain/player_effect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stats = CharacterStats(
    strength: 12,
    dexterity: 10,
    constitution: 10,
    intelligence: 10,
    wisdom: 10,
    charisma: 10,
  );

  test('equips one item per slot', () {
    const sword = InventoryItem(
      id: 'sword',
      name: 'Epee',
      description: '',
      quantity: 1,
      type: 'weapon',
      bonuses: {'strength': 1},
    );
    const axe = InventoryItem(
      id: 'axe',
      name: 'Hache',
      description: '',
      quantity: 1,
      type: 'weapon',
      bonuses: {'strength': 2},
    );

    final equippedSword = setEquipped(
      inventory: [sword, axe],
      itemId: 'sword',
      equipped: true,
    );
    expect(equippedSword[0].equipped, isTrue);
    expect(equippedSword[1].equipped, isFalse);

    final equippedAxe = setEquipped(
      inventory: equippedSword,
      itemId: 'axe',
      equipped: true,
    );
    expect(equippedAxe[0].equipped, isFalse);
    expect(equippedAxe[1].equipped, isTrue);
  });

  test('potion consumes one and heals', () {
    const potion = InventoryItem(
      id: 'potion',
      name: 'Potion',
      description: '',
      quantity: 2,
      type: 'potion',
      heal: 20,
    );
    final result = consumePotion(inventory: [potion], itemId: 'potion');
    expect(result.heal, 20);
    expect(result.inventory.single.quantity, 1);
  });

  test('effective score adds equipped bonus and effect', () {
    const sword = InventoryItem(
      id: 'sword',
      name: 'Epee',
      description: '',
      quantity: 1,
      type: 'weapon',
      equipped: true,
      bonuses: {'strength': 2},
    );
    const bless = PlayerEffect(
      id: 'bless',
      name: 'Benediction',
      kind: 'buff',
      stat: 'strength',
      delta: 1,
    );

    expect(
      effectiveScore(
        stats: stats,
        inventory: [sword],
        effects: [bless],
        key: 'strength',
      ),
      15,
    );
    expect(
      effectiveModifier(
        stats: stats,
        inventory: [sword],
        effects: [bless],
        key: 'strength',
      ),
      2,
    );
  });
}
