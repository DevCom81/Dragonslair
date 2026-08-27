import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clamps a d20 roll into 8-18', () {
    expect(CharacterStats.clampValue(1), 8);
    expect(CharacterStats.clampValue(7), 8);
    expect(CharacterStats.clampValue(12), 12);
    expect(CharacterStats.clampValue(19), 18);
    expect(CharacterStats.clampValue(20), 18);
  });

  test('computes 5e ability modifiers', () {
    expect(const CharacterStats(
      strength: 8,
      dexterity: 10,
      constitution: 12,
      intelligence: 13,
      wisdom: 18,
      charisma: 9,
    ).modifierFor('strength'), -1);
    expect(CharacterStats.defaults.modifierFor('dexterity'), 0);
    expect(const CharacterStats(
      strength: 10,
      dexterity: 12,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    ).modifierFor('dexterity'), 1);
    expect(const CharacterStats(
      strength: 10,
      dexterity: 10,
      constitution: 10,
      intelligence: 10,
      wisdom: 18,
      charisma: 10,
    ).modifierFor('wisdom'), 4);
  });

  test('applies class bonus then clamps at 18', () {
    final rolled = CharacterStats.fromRolls(const [17, 10, 10, 10, 10, 10]);
    final withBonus = rolled.withPrimaryBonus('strength');

    expect(withBonus.strength, 18);
    expect(withBonus.dexterity, 10);
  });
}
