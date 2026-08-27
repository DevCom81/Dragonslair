import '../../l10n/app_localizations.dart';

String localizedClassLabel(AppLocalizations l10n, String id) {
  return switch (id) {
    'barbarian' => l10n.classBarbarian,
    'bard' => l10n.classBard,
    'cleric' => l10n.classCleric,
    'druid' => l10n.classDruid,
    'fighter' => l10n.classFighter,
    'monk' => l10n.classMonk,
    'paladin' => l10n.classPaladin,
    'ranger' => l10n.classRanger,
    'rogue' => l10n.classRogue,
    'sorcerer' => l10n.classSorcerer,
    'warlock' => l10n.classWarlock,
    'wizard' => l10n.classWizard,
    _ => id,
  };
}

String localizedStatLabel(AppLocalizations l10n, String key) {
  return switch (key) {
    'strength' => l10n.statStrength,
    'dexterity' => l10n.statDexterity,
    'constitution' => l10n.statConstitution,
    'intelligence' => l10n.statIntelligence,
    'wisdom' => l10n.statWisdom,
    'charisma' => l10n.statCharisma,
    _ => key,
  };
}

String localizedScenarioName(AppLocalizations l10n, String? id) {
  return switch (id) {
    'forest' => l10n.scenarioForestName,
    'siege' => l10n.scenarioSiegeName,
    _ => l10n.scenarioDungeonName,
  };
}

String localizedScenarioDescription(AppLocalizations l10n, String? id) {
  return switch (id) {
    'forest' => l10n.scenarioForestDescription,
    'siege' => l10n.scenarioSiegeDescription,
    _ => l10n.scenarioDungeonDescription,
  };
}

String localizedItemType(AppLocalizations l10n, String type) {
  return switch (type) {
    'weapon' => l10n.itemTypeWeapon,
    'armor' => l10n.itemTypeArmor,
    'shield' => l10n.itemTypeShield,
    'accessory' => l10n.itemTypeAccessory,
    'potion' || 'consumable' => l10n.itemTypePotion,
    'scroll' => l10n.itemTypeScroll,
    'tool' => l10n.itemTypeTool,
    'unknown' => '',
    _ => type,
  };
}

String localizedEffectKind(AppLocalizations l10n, String kind) {
  return switch (kind) {
    'buff' => l10n.effectKindBuff,
    'debuff' => l10n.effectKindDebuff,
    'wound' => l10n.effectKindWound,
    _ => l10n.effectKindSpell,
  };
}
