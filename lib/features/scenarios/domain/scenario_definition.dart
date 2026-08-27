class CharacterClass {
  const CharacterClass({
    required this.id,
    required this.label,
    required this.primaryStatKey,
    required this.primaryStatLabel,
  });

  final String id;
  final String label;
  final String primaryStatKey;
  final String primaryStatLabel;
}

class CharacterClassCatalog {
  const CharacterClassCatalog._();

  static const barbarian = CharacterClass(
    id: 'barbarian',
    label: 'Barbare',
    primaryStatKey: 'strength',
    primaryStatLabel: 'Force',
  );
  static const bard = CharacterClass(
    id: 'bard',
    label: 'Barde',
    primaryStatKey: 'charisma',
    primaryStatLabel: 'Charisme',
  );
  static const cleric = CharacterClass(
    id: 'cleric',
    label: 'Clerc',
    primaryStatKey: 'wisdom',
    primaryStatLabel: 'Sagesse',
  );
  static const druid = CharacterClass(
    id: 'druid',
    label: 'Druide',
    primaryStatKey: 'wisdom',
    primaryStatLabel: 'Sagesse',
  );
  static const fighter = CharacterClass(
    id: 'fighter',
    label: 'Guerrier',
    primaryStatKey: 'strength',
    primaryStatLabel: 'Force',
  );
  static const monk = CharacterClass(
    id: 'monk',
    label: 'Moine',
    primaryStatKey: 'dexterity',
    primaryStatLabel: 'Dexterite',
  );
  static const paladin = CharacterClass(
    id: 'paladin',
    label: 'Paladin',
    primaryStatKey: 'strength',
    primaryStatLabel: 'Force',
  );
  static const ranger = CharacterClass(
    id: 'ranger',
    label: 'Rodeur',
    primaryStatKey: 'dexterity',
    primaryStatLabel: 'Dexterite',
  );
  static const rogue = CharacterClass(
    id: 'rogue',
    label: 'Roublard',
    primaryStatKey: 'dexterity',
    primaryStatLabel: 'Dexterite',
  );
  static const sorcerer = CharacterClass(
    id: 'sorcerer',
    label: 'Ensorceleur',
    primaryStatKey: 'charisma',
    primaryStatLabel: 'Charisme',
  );
  static const warlock = CharacterClass(
    id: 'warlock',
    label: 'Occultiste',
    primaryStatKey: 'charisma',
    primaryStatLabel: 'Charisme',
  );
  static const wizard = CharacterClass(
    id: 'wizard',
    label: 'Magicien',
    primaryStatKey: 'intelligence',
    primaryStatLabel: 'Intelligence',
  );

  static const all = [
    barbarian,
    bard,
    cleric,
    druid,
    fighter,
    monk,
    paladin,
    ranger,
    rogue,
    sorcerer,
    warlock,
    wizard,
  ];

  static const allIds = [
    'barbarian',
    'bard',
    'cleric',
    'druid',
    'fighter',
    'monk',
    'paladin',
    'ranger',
    'rogue',
    'sorcerer',
    'warlock',
    'wizard',
  ];

  static const classBonus = 2;

  static CharacterClass byId(String id) {
    return all.firstWhere(
      (item) => item.id == id,
      orElse: () => CharacterClass(
        id: id,
        label: id,
        primaryStatKey: 'strength',
        primaryStatLabel: 'Force',
      ),
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
    description: 'Exploration souterraine. Un clerc est obligatoire.',
    minPlayers: 3,
    allowedClassIds: CharacterClassCatalog.allIds,
    requiredClassIds: ['cleric'],
  );

  static const forest = ScenarioDefinition(
    id: 'forest',
    name: 'Foret',
    description: 'Piste et embuscades. Un clerc est obligatoire.',
    minPlayers: 2,
    allowedClassIds: CharacterClassCatalog.allIds,
    requiredClassIds: ['cleric'],
  );

  static const siege = ScenarioDefinition(
    id: 'siege',
    name: 'Siege',
    description: 'Defense d une place forte. Guerrier et clerc obligatoires.',
    minPlayers: 4,
    allowedClassIds: CharacterClassCatalog.allIds,
    requiredClassIds: ['fighter', 'cleric'],
  );

  static const custom = ScenarioDefinition(
    id: 'custom',
    name: 'Aventure',
    description: '',
    minPlayers: 1,
    allowedClassIds: CharacterClassCatalog.allIds,
    requiredClassIds: [],
  );

  static const all = [dungeon, forest, siege];

  static ScenarioDefinition byId(String? id) {
    if (id == custom.id) {
      return custom;
    }
    return all.firstWhere(
      (item) => item.id == id,
      orElse: () => dungeon,
    );
  }
}
