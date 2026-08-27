class CharacterClass {
  const CharacterClass({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class CharacterClassCatalog {
  const CharacterClassCatalog._();

  static const warrior = CharacterClass(id: 'warrior', label: 'Guerrier');
  static const healer = CharacterClass(id: 'healer', label: 'Soigneur');
  static const mage = CharacterClass(id: 'mage', label: 'Mage');
  static const rogue = CharacterClass(id: 'rogue', label: 'Voleur');
  static const ranger = CharacterClass(id: 'ranger', label: 'Rodeur');

  static const all = [warrior, healer, mage, rogue, ranger];

  static CharacterClass byId(String id) {
    return all.firstWhere(
      (item) => item.id == id,
      orElse: () => CharacterClass(id: id, label: id),
    );
  }
}

class ScenarioDefinition {
  const ScenarioDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.minPlayers,
    required this.allowedClassIds,
    required this.requiredClassIds,
  });

  final String id;
  final String name;
  final String description;
  final int minPlayers;
  final List<String> allowedClassIds;
  final List<String> requiredClassIds;
}

class ScenarioCatalog {
  const ScenarioCatalog._();

  static const dungeon = ScenarioDefinition(
    id: 'dungeon',
    name: 'Donjon',
    description: 'Exploration souterraine. Un soigneur est obligatoire.',
    minPlayers: 3,
    allowedClassIds: ['warrior', 'healer', 'mage', 'rogue'],
    requiredClassIds: ['healer'],
  );

  static const forest = ScenarioDefinition(
    id: 'forest',
    name: 'Foret',
    description: 'Piste et embuscades. Un soigneur est obligatoire.',
    minPlayers: 2,
    allowedClassIds: ['warrior', 'ranger', 'healer'],
    requiredClassIds: ['healer'],
  );

  static const siege = ScenarioDefinition(
    id: 'siege',
    name: 'Siege',
    description: 'Defense d une place forte. Guerrier et soigneur obligatoires.',
    minPlayers: 4,
    allowedClassIds: ['warrior', 'healer', 'mage'],
    requiredClassIds: ['warrior', 'healer'],
  );

  static const all = [dungeon, forest, siege];

  static ScenarioDefinition byId(String? id) {
    return all.firstWhere(
      (item) => item.id == id,
      orElse: () => dungeon,
    );
  }
}
