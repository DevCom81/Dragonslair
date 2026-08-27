// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DragonsLair';

  @override
  String get appTagline =>
      'Multiplayer role-playing game with an AI game master.';

  @override
  String get emblemSemantic => 'DragonsLair emblem';

  @override
  String get playAsGuest => 'Play without signing up';

  @override
  String get logIn => 'Log in';

  @override
  String get signUp => 'Sign up';

  @override
  String get continuePlay => 'Continue';

  @override
  String get signOut => 'Sign out';

  @override
  String get language => 'Language';

  @override
  String get preferences => 'Preferences';

  @override
  String get supabaseMissing =>
      'Supabase configuration is missing. The app runs in local mode.';

  @override
  String get sessionClosed => 'No session.';

  @override
  String get sessionConnected => 'Signed in.';

  @override
  String get sessionGuest => 'Guest session on this device.';

  @override
  String get guestWarningTitle => 'Play without an account';

  @override
  String get guestWarningBody =>
      'Your display name and character sheet stay on this device only. If you uninstall the app or sign out, they are lost. You can still rejoin a paused game from this device.';

  @override
  String get guestWarningConfirm => 'Play as guest';

  @override
  String get guestWarningCancel => 'Cancel';

  @override
  String guestSuggestedName(String suffix) {
    return 'Wanderer-$suffix';
  }

  @override
  String get authSignUpTitle => 'Create an account';

  @override
  String get authLogInTitle => 'Log in';

  @override
  String get authAccountHint =>
      'Your display name and character sheet stay linked to this account.';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Invalid email.';

  @override
  String get password => 'Password';

  @override
  String get passwordTooShort => 'At least 6 characters.';

  @override
  String get createAccount => 'Create account';

  @override
  String get alreadyHaveAccount => 'Already have an account? Log in';

  @override
  String get newPlayerSignUp => 'New player? Sign up';

  @override
  String get authRequired => 'Authentication required.';

  @override
  String get displayNameTitle => 'Your display name';

  @override
  String get displayNameHint =>
      'Choose a name other players will see in your party.';

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get minTwoChars => 'At least 2 characters.';

  @override
  String get save => 'Save';

  @override
  String get sheetTitle => 'Character sheet';

  @override
  String get sheetIntro =>
      'Pick a class, then roll 1d20 per ability. Rolls from 1 to 7 become 8, 19 or 20 become 18. The class adds +2 (max 18) to its primary ability.';

  @override
  String get classLabel => 'Class';

  @override
  String classBonusChip(String className, String statName) {
    return '$className (+2 $statName)';
  }

  @override
  String get rollAbilities => 'Roll dice (6d20)';

  @override
  String get saveSheet => 'Save sheet';

  @override
  String get sheetRequiresAccount =>
      'Account and display name are required before the sheet.';

  @override
  String statLine(String statName, int value) {
    return '$statName: $value';
  }

  @override
  String statLineBonus(
    String statName,
    int raw,
    int finalValue,
    String className,
  ) {
    return '$statName: $raw → $finalValue (+2 $className)';
  }

  @override
  String get tavernTitle => 'Tavern';

  @override
  String get welcome => 'Welcome.';

  @override
  String welcomeNamed(String name) {
    return 'Welcome, $name.';
  }

  @override
  String welcomeNamedClass(String name, String className) {
    return 'Welcome, $name ($className).';
  }

  @override
  String get hubSubtitle => 'Create a game or join your companions.';

  @override
  String get createGame => 'Create a game';

  @override
  String get joinGame => 'Join a game';

  @override
  String get joinByCode => 'Join with a code';

  @override
  String get mySheet => 'My sheet';

  @override
  String get guestBanner =>
      'Guest mode: this character exists on this device only.';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String get roomNotFound => 'Game not found.';

  @override
  String codeLabel(String code) {
    return 'Code: $code';
  }

  @override
  String scenarioMinPlayersLine(String scenario, int count) {
    return '$scenario · min $count players';
  }

  @override
  String get players => 'Players';

  @override
  String get waitingForPlayers => 'Waiting for players.';

  @override
  String hpLabel(int hp) {
    return 'HP $hp';
  }

  @override
  String get startGame => 'Start the game';

  @override
  String get waitingForHost => 'Waiting for the host';

  @override
  String notEnoughPlayers(int current, int minimum) {
    return 'Not enough players ($current / $minimum).';
  }

  @override
  String missingRequiredClass(String className) {
    return 'Required class missing: $className.';
  }

  @override
  String get createRoomTitle => 'Create a game';

  @override
  String get roomName => 'Game name';

  @override
  String get fieldRequired => 'Required field.';

  @override
  String get scenario => 'Scenario';

  @override
  String scenarioMinPlayers(String name, int count) {
    return '$name (min $count)';
  }

  @override
  String get create => 'Create';

  @override
  String get joinCodeTitle => 'Join with a code';

  @override
  String get joinCodeLabel => 'Game code';

  @override
  String get joinCodeInvalid => 'The code must contain 6 characters.';

  @override
  String get join => 'Join';

  @override
  String get noRoomForCode => 'No game found for this code.';

  @override
  String get openGames => 'Open games';

  @override
  String get noWaitingGames => 'No games waiting.';

  @override
  String get chooseFigurine => 'Choose a figurine';

  @override
  String get completeSheetFirst => 'Complete your sheet before joining.';

  @override
  String classAlreadyTaken(String className) {
    return 'Your class ($className) is already taken.';
  }

  @override
  String yourClass(String className) {
    return 'Class: $className';
  }

  @override
  String get classNotAllowed => 'Your class is not allowed in this scenario.';

  @override
  String get joinLobby => 'Join the lobby';

  @override
  String get taken => 'Taken';

  @override
  String get statStrength => 'Strength';

  @override
  String get statDexterity => 'Dexterity';

  @override
  String get statConstitution => 'Constitution';

  @override
  String get statIntelligence => 'Intelligence';

  @override
  String get statWisdom => 'Wisdom';

  @override
  String get statCharisma => 'Charisma';

  @override
  String get classBarbarian => 'Barbarian';

  @override
  String get classBard => 'Bard';

  @override
  String get classCleric => 'Cleric';

  @override
  String get classDruid => 'Druid';

  @override
  String get classFighter => 'Fighter';

  @override
  String get classMonk => 'Monk';

  @override
  String get classPaladin => 'Paladin';

  @override
  String get classRanger => 'Ranger';

  @override
  String get classRogue => 'Rogue';

  @override
  String get classSorcerer => 'Sorcerer';

  @override
  String get classWarlock => 'Warlock';

  @override
  String get classWizard => 'Wizard';

  @override
  String get scenarioDungeonName => 'Dungeon';

  @override
  String get scenarioDungeonDescription =>
      'Underground exploration. A cleric is required.';

  @override
  String get scenarioForestName => 'Forest';

  @override
  String get scenarioForestDescription =>
      'Tracks and ambushes. A cleric is required.';

  @override
  String get scenarioSiegeName => 'Siege';

  @override
  String get scenarioSiegeDescription =>
      'Defense of a stronghold. Fighter and cleric are required.';

  @override
  String get boardTitle => 'Board';

  @override
  String get journalTitle => 'Story';

  @override
  String get journalEmpty => 'No events yet.';

  @override
  String get gmChoices => 'The GM offers:';

  @override
  String get actionHint => 'Describe your action...';

  @override
  String get sendToGm => 'Send to GM';

  @override
  String get actionExamine => 'Examine';

  @override
  String get actionInteract => 'Interact';

  @override
  String get actionAttack => 'Attack';

  @override
  String get actionDefend => 'Defend';

  @override
  String get actionUseItem => 'Use an item';

  @override
  String get actionFree => 'Free action';

  @override
  String get hudSheet => 'Sheet';

  @override
  String get hudInventory => 'Inventory';

  @override
  String get hudJournal => 'Book';

  @override
  String get inGameSheetTitle => 'Character sheet';

  @override
  String get inGameInventoryTitle => 'Inventory';

  @override
  String get emptyInventory => 'No items yet.';

  @override
  String itemQuantity(int count) {
    return 'x$count';
  }

  @override
  String pendingRollBody(String ability, int dc) {
    return '$ability check, DC $dc';
  }

  @override
  String get pendingRollCta => 'Roll 1d20';

  @override
  String get pendingRollSuccess => 'Success';

  @override
  String get pendingRollFailure => 'Failure';

  @override
  String pendingRollWaiting(String name) {
    return 'Waiting for $name\'s roll.';
  }

  @override
  String get pendingRollUnknownPlayer => 'a player';

  @override
  String statLineEffective(String statName, int effective, int base) {
    return '$statName: $effective ($base)';
  }

  @override
  String get effectsTitle => 'Effects';

  @override
  String get emptyEffects => 'No active effects.';

  @override
  String get effectPermanent => 'permanent';

  @override
  String effectRemaining(int count) {
    return '$count scenes';
  }

  @override
  String get effectKindBuff => 'buff';

  @override
  String get effectKindDebuff => 'debuff';

  @override
  String get effectKindWound => 'wound';

  @override
  String get effectKindSpell => 'spell';

  @override
  String get itemEquip => 'Equip';

  @override
  String get itemUnequip => 'Unequip';

  @override
  String get itemUse => 'Use';

  @override
  String get itemEquipped => 'Equipped';

  @override
  String get itemTypeWeapon => 'Weapon';

  @override
  String get itemTypeArmor => 'Armor';

  @override
  String get itemTypeShield => 'Shield';

  @override
  String get itemTypeAccessory => 'Accessory';

  @override
  String get itemTypePotion => 'Potion';

  @override
  String get itemTypeScroll => 'Scroll';

  @override
  String get itemTypeTool => 'Tool';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageGerman => 'Deutsch';
}
