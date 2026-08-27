// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'DragonsLair';

  @override
  String get appTagline => 'Mehrspieler-Rollenspiel mit einem KI-Spielleiter.';

  @override
  String get emblemSemantic => 'DragonsLair-Wappen';

  @override
  String get playAsGuest => 'Ohne Anmeldung spielen';

  @override
  String get logIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get continuePlay => 'Weiter';

  @override
  String get signOut => 'Abmelden';

  @override
  String get language => 'Sprache';

  @override
  String get preferences => 'Einstellungen';

  @override
  String get supabaseMissing =>
      'Supabase-Konfiguration fehlt. Die App laeuft im lokalen Modus.';

  @override
  String get sessionClosed => 'Keine Sitzung.';

  @override
  String get sessionConnected => 'Angemeldet.';

  @override
  String get sessionGuest => 'Gastsitzung auf diesem Geraet.';

  @override
  String get guestWarningTitle => 'Ohne Konto spielen';

  @override
  String get guestWarningBody =>
      'Name und Charakterbogen bleiben nur auf diesem Geraet. Bei Deinstallation oder Abmeldung gehen sie verloren. Eine pausierte Partie kannst du von diesem Geraet trotzdem fortsetzen.';

  @override
  String get guestWarningConfirm => 'Als Gast spielen';

  @override
  String get guestWarningCancel => 'Abbrechen';

  @override
  String guestSuggestedName(String suffix) {
    return 'Wanderer-$suffix';
  }

  @override
  String get authSignUpTitle => 'Konto erstellen';

  @override
  String get authLogInTitle => 'Anmelden';

  @override
  String get authAccountHint =>
      'Name und Charakterbogen bleiben mit diesem Konto verbunden.';

  @override
  String get email => 'E-Mail';

  @override
  String get emailInvalid => 'Ungueltige E-Mail.';

  @override
  String get password => 'Passwort';

  @override
  String get passwordTooShort => 'Mindestens 6 Zeichen.';

  @override
  String get createAccount => 'Konto erstellen';

  @override
  String get alreadyHaveAccount => 'Schon ein Konto? Anmelden';

  @override
  String get newPlayerSignUp => 'Neuer Spieler? Registrieren';

  @override
  String get authRequired => 'Authentifizierung erforderlich.';

  @override
  String get displayNameTitle => 'Dein Name';

  @override
  String get displayNameHint =>
      'Waehle einen Namen, den die anderen in deiner Gruppe sehen.';

  @override
  String get displayNameLabel => 'Name';

  @override
  String get minTwoChars => 'Mindestens 2 Zeichen.';

  @override
  String get save => 'Speichern';

  @override
  String get sheetTitle => 'Charakterbogen';

  @override
  String get sheetIntro =>
      'Waehle eine Klasse und wuerfle 1W20 pro Eigenschaft. 1 bis 7 werden zu 8, 19 oder 20 zu 18. Die Klasse gibt +2 (max. 18) auf ihre Haupteigenschaft.';

  @override
  String get classLabel => 'Klasse';

  @override
  String classBonusChip(String className, String statName) {
    return '$className (+2 $statName)';
  }

  @override
  String get rollAbilities => 'Wuerfeln (6W20)';

  @override
  String get saveSheet => 'Bogen speichern';

  @override
  String get sheetRequiresAccount =>
      'Konto und Name sind vor dem Bogen noetig.';

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
  String get tavernTitle => 'Taverne';

  @override
  String get welcome => 'Willkommen.';

  @override
  String welcomeNamed(String name) {
    return 'Willkommen, $name.';
  }

  @override
  String welcomeNamedClass(String name, String className) {
    return 'Willkommen, $name ($className).';
  }

  @override
  String get hubSubtitle =>
      'Erstelle eine Partie oder tritt deinen Gefaehrten bei.';

  @override
  String get createGame => 'Partie erstellen';

  @override
  String get joinGame => 'Partie beitreten';

  @override
  String get joinByCode => 'Mit Code beitreten';

  @override
  String get mySheet => 'Mein Bogen';

  @override
  String get guestBanner =>
      'Gastmodus: Dieser Charakter existiert nur auf diesem Geraet.';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String get roomNotFound => 'Partie nicht gefunden.';

  @override
  String codeLabel(String code) {
    return 'Code: $code';
  }

  @override
  String scenarioMinPlayersLine(String scenario, int count) {
    return '$scenario · min. $count Spieler';
  }

  @override
  String get players => 'Spieler';

  @override
  String get waitingForPlayers => 'Warte auf Spieler.';

  @override
  String hpLabel(int hp) {
    return 'TP $hp';
  }

  @override
  String get startGame => 'Partie starten';

  @override
  String get waitingForHost => 'Warte auf den Host';

  @override
  String notEnoughPlayers(int current, int minimum) {
    return 'Nicht genug Spieler ($current / $minimum).';
  }

  @override
  String missingRequiredClass(String className) {
    return 'Pflichtklasse fehlt: $className.';
  }

  @override
  String get createRoomTitle => 'Partie erstellen';

  @override
  String get roomName => 'Name der Partie';

  @override
  String get fieldRequired => 'Pflichtfeld.';

  @override
  String get scenario => 'Szenario';

  @override
  String scenarioMinPlayers(String name, int count) {
    return '$name (min. $count)';
  }

  @override
  String get create => 'Erstellen';

  @override
  String get joinCodeTitle => 'Mit Code beitreten';

  @override
  String get joinCodeLabel => 'Partiecode';

  @override
  String get joinCodeInvalid => 'Der Code muss 6 Zeichen haben.';

  @override
  String get join => 'Beitreten';

  @override
  String get noRoomForCode => 'Keine Partie fuer diesen Code.';

  @override
  String get openGames => 'Offene Partien';

  @override
  String get noWaitingGames => 'Keine wartenden Partien.';

  @override
  String get chooseFigurine => 'Figur waehlen';

  @override
  String get completeSheetFirst =>
      'Vervollstaendige deinen Bogen vor dem Beitritt.';

  @override
  String classAlreadyTaken(String className) {
    return 'Deine Klasse ($className) ist bereits vergeben.';
  }

  @override
  String yourClass(String className) {
    return 'Klasse: $className';
  }

  @override
  String get classNotAllowed =>
      'Deine Klasse ist in diesem Szenario nicht erlaubt.';

  @override
  String get joinLobby => 'Der Lobby beitreten';

  @override
  String get taken => 'Belegt';

  @override
  String get statStrength => 'Staerke';

  @override
  String get statDexterity => 'Geschicklichkeit';

  @override
  String get statConstitution => 'Konstitution';

  @override
  String get statIntelligence => 'Intelligenz';

  @override
  String get statWisdom => 'Weisheit';

  @override
  String get statCharisma => 'Charisma';

  @override
  String get classBarbarian => 'Barbar';

  @override
  String get classBard => 'Barde';

  @override
  String get classCleric => 'Kleriker';

  @override
  String get classDruid => 'Druide';

  @override
  String get classFighter => 'Kaempfer';

  @override
  String get classMonk => 'Moench';

  @override
  String get classPaladin => 'Paladin';

  @override
  String get classRanger => 'Waldlaeufer';

  @override
  String get classRogue => 'Schurke';

  @override
  String get classSorcerer => 'Zauberer';

  @override
  String get classWarlock => 'Hexenmeister';

  @override
  String get classWizard => 'Magier';

  @override
  String get scenarioDungeonName => 'Kerker';

  @override
  String get scenarioDungeonDescription =>
      'Unterirdische Erkundung. Ein Kleriker ist Pflicht.';

  @override
  String get scenarioForestName => 'Wald';

  @override
  String get scenarioForestDescription =>
      'Spuren und Hinterhalte. Ein Kleriker ist Pflicht.';

  @override
  String get scenarioSiegeName => 'Belagerung';

  @override
  String get scenarioSiegeDescription =>
      'Verteidigung einer Festung. Kaempfer und Kleriker sind Pflicht.';

  @override
  String get boardTitle => 'Spielfeld';

  @override
  String get journalTitle => 'Geschichte';

  @override
  String get journalEmpty => 'Noch keine Ereignisse.';

  @override
  String get gmChoices => 'Der SL schlaegt vor:';

  @override
  String get actionHint => 'Beschreibe deine Aktion...';

  @override
  String get sendToGm => 'An den SL senden';

  @override
  String get actionExamine => 'Untersuchen';

  @override
  String get actionInteract => 'Interagieren';

  @override
  String get actionAttack => 'Angreifen';

  @override
  String get actionDefend => 'Verteidigen';

  @override
  String get actionUseItem => 'Gegenstand nutzen';

  @override
  String get actionFree => 'Freie Aktion';

  @override
  String get hudSheet => 'Bogen';

  @override
  String get hudInventory => 'Inventar';

  @override
  String get hudJournal => 'Buch';

  @override
  String get inGameSheetTitle => 'Charakterbogen';

  @override
  String get inGameInventoryTitle => 'Inventar';

  @override
  String get emptyInventory => 'Noch keine Gegenstaende.';

  @override
  String itemQuantity(int count) {
    return 'x$count';
  }

  @override
  String pendingRollBody(String ability, int dc) {
    return '$ability-Probe, SG $dc';
  }

  @override
  String get pendingRollCta => '1W20 wuerfeln';

  @override
  String get pendingRollSuccess => 'Erfolg';

  @override
  String get pendingRollFailure => 'Misserfolg';

  @override
  String pendingRollWaiting(String name) {
    return 'Warte auf den Wurf von $name.';
  }

  @override
  String get pendingRollUnknownPlayer => 'einem Spieler';

  @override
  String statLineEffective(String statName, int effective, int base) {
    return '$statName: $effective ($base)';
  }

  @override
  String get effectsTitle => 'Effekte';

  @override
  String get emptyEffects => 'Keine aktiven Effekte.';

  @override
  String get effectPermanent => 'dauerhaft';

  @override
  String effectRemaining(int count) {
    return '$count Szenen';
  }

  @override
  String get effectKindBuff => 'Bonus';

  @override
  String get effectKindDebuff => 'Malus';

  @override
  String get effectKindWound => 'Wunde';

  @override
  String get effectKindSpell => 'Zauber';

  @override
  String get itemEquip => 'Anlegen';

  @override
  String get itemUnequip => 'Ablegen';

  @override
  String get itemUse => 'Benutzen';

  @override
  String get itemEquipped => 'Angelegt';

  @override
  String get itemTypeWeapon => 'Waffe';

  @override
  String get itemTypeArmor => 'Ruestung';

  @override
  String get itemTypeShield => 'Schild';

  @override
  String get itemTypeAccessory => 'Accessoire';

  @override
  String get itemTypePotion => 'Trank';

  @override
  String get itemTypeScroll => 'Schriftrolle';

  @override
  String get itemTypeTool => 'Werkzeug';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageGerman => 'Deutsch';
}
