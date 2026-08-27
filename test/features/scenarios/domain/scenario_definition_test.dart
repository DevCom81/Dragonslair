import 'package:dragons_lair/features/scenarios/domain/scenario_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes the 12 D&D classes', () {
    expect(CharacterClassCatalog.all, hasLength(12));
    expect(CharacterClassCatalog.fighter.primaryStatKey, 'strength');
    expect(CharacterClassCatalog.cleric.primaryStatKey, 'wisdom');
    expect(CharacterClassCatalog.wizard.primaryStatKey, 'intelligence');
  });

  test('requires a cleric in dungeon and forest', () {
    expect(ScenarioCatalog.dungeon.requiredClassIds, ['cleric']);
    expect(ScenarioCatalog.forest.requiredClassIds, ['cleric']);
    expect(ScenarioCatalog.siege.requiredClassIds, ['fighter', 'cleric']);
  });
}
