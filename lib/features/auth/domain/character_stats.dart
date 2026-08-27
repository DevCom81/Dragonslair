class CharacterStats {
  const CharacterStats({
    required this.strength,
    required this.dexterity,
    required this.constitution,
    required this.intelligence,
    required this.wisdom,
    required this.charisma,
  });

  static const minValue = 8;
  static const maxValue = 18;
  static const defaultValue = 10;

  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;

  static const defaults = CharacterStats(
    strength: defaultValue,
    dexterity: defaultValue,
    constitution: defaultValue,
    intelligence: defaultValue,
    wisdom: defaultValue,
    charisma: defaultValue,
  );

  int scoreFor(String key) {
    return switch (key) {
      'strength' => strength,
      'dexterity' => dexterity,
      'constitution' => constitution,
      'intelligence' => intelligence,
      'wisdom' => wisdom,
      'charisma' => charisma,
      _ => defaultValue,
    };
  }

  int modifierFor(String key) {
    return (scoreFor(key) - 10) ~/ 2;
  }

  CharacterStats copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) {
    return CharacterStats(
      strength: strength ?? this.strength,
      dexterity: dexterity ?? this.dexterity,
      constitution: constitution ?? this.constitution,
      intelligence: intelligence ?? this.intelligence,
      wisdom: wisdom ?? this.wisdom,
      charisma: charisma ?? this.charisma,
    );
  }

  static int _stat(Map<String, dynamic> json, String key) {
    final value = (json[key] as num?)?.toInt() ?? defaultValue;
    if (value < minValue || value > maxValue) {
      throw ArgumentError('$key must be between $minValue and $maxValue');
    }
    return value;
  }

  factory CharacterStats.fromJson(Map<String, dynamic> json) {
    return CharacterStats(
      strength: _stat(json, 'strength'),
      dexterity: _stat(json, 'dexterity'),
      constitution: _stat(json, 'constitution'),
      intelligence: _stat(json, 'intelligence'),
      wisdom: _stat(json, 'wisdom'),
      charisma: _stat(json, 'charisma'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
    };
  }

  static int clampValue(int value) {
    if (value < minValue) {
      return minValue;
    }
    if (value > maxValue) {
      return maxValue;
    }
    return value;
  }

  factory CharacterStats.fromRolls(List<int> rolls) {
    if (rolls.length != 6) {
      throw ArgumentError('Expected 6 rolls.');
    }
    return CharacterStats(
      strength: clampValue(rolls[0]),
      dexterity: clampValue(rolls[1]),
      constitution: clampValue(rolls[2]),
      intelligence: clampValue(rolls[3]),
      wisdom: clampValue(rolls[4]),
      charisma: clampValue(rolls[5]),
    );
  }

  CharacterStats withPrimaryBonus(String statKey, {int bonus = 2}) {
    int apply(String key, int value) {
      return clampValue(value + (key == statKey ? bonus : 0));
    }

    return CharacterStats(
      strength: apply('strength', strength),
      dexterity: apply('dexterity', dexterity),
      constitution: apply('constitution', constitution),
      intelligence: apply('intelligence', intelligence),
      wisdom: apply('wisdom', wisdom),
      charisma: apply('charisma', charisma),
    );
  }
}

class CharacterStatField {
  const CharacterStatField({
    required this.key,
    required this.label,
    required this.read,
    required this.write,
  });

  final String key;
  final String label;
  final int Function(CharacterStats stats) read;
  final CharacterStats Function(CharacterStats stats, int value) write;
}

const characterStatFields = [
  CharacterStatField(
    key: 'strength',
    label: 'Force',
    read: _strength,
    write: _setStrength,
  ),
  CharacterStatField(
    key: 'dexterity',
    label: 'Dexterite',
    read: _dexterity,
    write: _setDexterity,
  ),
  CharacterStatField(
    key: 'constitution',
    label: 'Constitution',
    read: _constitution,
    write: _setConstitution,
  ),
  CharacterStatField(
    key: 'intelligence',
    label: 'Intelligence',
    read: _intelligence,
    write: _setIntelligence,
  ),
  CharacterStatField(
    key: 'wisdom',
    label: 'Sagesse',
    read: _wisdom,
    write: _setWisdom,
  ),
  CharacterStatField(
    key: 'charisma',
    label: 'Charisme',
    read: _charisma,
    write: _setCharisma,
  ),
];

int _strength(CharacterStats stats) => stats.strength;
int _dexterity(CharacterStats stats) => stats.dexterity;
int _constitution(CharacterStats stats) => stats.constitution;
int _intelligence(CharacterStats stats) => stats.intelligence;
int _wisdom(CharacterStats stats) => stats.wisdom;
int _charisma(CharacterStats stats) => stats.charisma;

CharacterStats _setStrength(CharacterStats stats, int value) =>
    stats.copyWith(strength: value);
CharacterStats _setDexterity(CharacterStats stats, int value) =>
    stats.copyWith(dexterity: value);
CharacterStats _setConstitution(CharacterStats stats, int value) =>
    stats.copyWith(constitution: value);
CharacterStats _setIntelligence(CharacterStats stats, int value) =>
    stats.copyWith(intelligence: value);
CharacterStats _setWisdom(CharacterStats stats, int value) =>
    stats.copyWith(wisdom: value);
CharacterStats _setCharisma(CharacterStats stats, int value) =>
    stats.copyWith(charisma: value);
