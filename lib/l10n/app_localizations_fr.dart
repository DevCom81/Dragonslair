// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'DragonsLair';

  @override
  String get appTagline => 'Jeu de role multijoueur avec maitre du jeu IA.';

  @override
  String get emblemSemantic => 'Embleme DragonsLair';

  @override
  String get playAsGuest => 'Jouer sans s\'inscrire';

  @override
  String get logIn => 'Connexion';

  @override
  String get signUp => 'Inscription';

  @override
  String get continuePlay => 'Continuer';

  @override
  String get signOut => 'Se deconnecter';

  @override
  String get language => 'Langue';

  @override
  String get preferences => 'Preferences';

  @override
  String get supabaseMissing =>
      'Configuration Supabase absente. L app compile en mode local.';

  @override
  String get sessionClosed => 'Session non ouverte.';

  @override
  String get sessionConnected => 'Compte connecte.';

  @override
  String get sessionGuest => 'Session invitee sur cet appareil.';

  @override
  String get guestWarningTitle => 'Jouer sans compte';

  @override
  String get guestWarningBody =>
      'Ton pseudo et ta fiche restent uniquement sur cet appareil. Si tu desinstalles l app ou te deconnectes, ils sont perdus. Tu pourras quand meme reprendre une partie en pause depuis cet appareil.';

  @override
  String get guestWarningConfirm => 'Jouer en invite';

  @override
  String get guestWarningCancel => 'Annuler';

  @override
  String guestSuggestedName(String suffix) {
    return 'Voyageur-$suffix';
  }

  @override
  String get authSignUpTitle => 'Creer un compte';

  @override
  String get authLogInTitle => 'Connexion';

  @override
  String get authAccountHint =>
      'Ton pseudo et ta fiche restent lies a ce compte.';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Email invalide.';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordTooShort => 'Au moins 6 caracteres.';

  @override
  String get createAccount => 'Creer le compte';

  @override
  String get alreadyHaveAccount => 'Deja un compte ? Se connecter';

  @override
  String get newPlayerSignUp => 'Nouveau joueur ? Creer un compte';

  @override
  String get authRequired => 'Authentification requise.';

  @override
  String get displayNameTitle => 'Ton pseudo';

  @override
  String get displayNameHint =>
      'Choisis un nom visible par les autres joueurs de ta partie.';

  @override
  String get displayNameLabel => 'Pseudo';

  @override
  String get minTwoChars => 'Au moins 2 caracteres.';

  @override
  String get save => 'Enregistrer';

  @override
  String get sheetTitle => 'Fiche de personnage';

  @override
  String get sheetIntro =>
      'Choisis une classe, puis lance 1d20 par caracteristique. Un 1 a 7 devient 8, un 19 ou 20 devient 18. La classe ajoute +2 (max 18) a sa caracteristique principale.';

  @override
  String get classLabel => 'Classe';

  @override
  String classBonusChip(String className, String statName) {
    return '$className (+2 $statName)';
  }

  @override
  String get rollAbilities => 'Lancer les des (6d20)';

  @override
  String get saveSheet => 'Enregistrer la fiche';

  @override
  String get sheetRequiresAccount => 'Compte et pseudo requis avant la fiche.';

  @override
  String statLine(String statName, int value) {
    return '$statName : $value';
  }

  @override
  String statLineBonus(
    String statName,
    int raw,
    int finalValue,
    String className,
  ) {
    return '$statName : $raw → $finalValue (+2 $className)';
  }

  @override
  String get tavernTitle => 'Taverne';

  @override
  String get welcome => 'Bienvenue.';

  @override
  String welcomeNamed(String name) {
    return 'Bienvenue, $name.';
  }

  @override
  String welcomeNamedClass(String name, String className) {
    return 'Bienvenue, $name ($className).';
  }

  @override
  String get hubSubtitle => 'Cree une partie ou rejoins tes compagnons.';

  @override
  String get createGame => 'Creer une partie';

  @override
  String get joinGame => 'Rejoindre une partie';

  @override
  String get joinByCode => 'Rejoindre par code';

  @override
  String get mySheet => 'Ma fiche';

  @override
  String get guestBanner =>
      'Mode invite : ce personnage existe seulement sur cet appareil.';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String get roomNotFound => 'Partie introuvable.';

  @override
  String codeLabel(String code) {
    return 'Code : $code';
  }

  @override
  String scenarioMinPlayersLine(String scenario, int count) {
    return '$scenario · min $count joueurs';
  }

  @override
  String get players => 'Joueurs';

  @override
  String get waitingForPlayers => 'En attente de joueurs.';

  @override
  String hpLabel(int hp) {
    return 'PV $hp';
  }

  @override
  String get startGame => 'Demarrer la partie';

  @override
  String get pauseGame => 'Pause';

  @override
  String get resumeGame => 'Reprendre';

  @override
  String get gamePaused => 'Partie en pause';

  @override
  String combatRoundBanner(int round) {
    return 'Combat — round $round';
  }

  @override
  String get waitingForHostResume => 'En attente de la reprise par le host';

  @override
  String get continueGames => 'Continuer une partie';

  @override
  String get roomPausedBadge => 'En pause';

  @override
  String get roomPlayingBadge => 'En cours';

  @override
  String get cannotJoinInProgress =>
      'Cette partie a deja commence. Pas de nouveaux joueurs.';

  @override
  String get cannotJoinFinished => 'Cette partie est terminee.';

  @override
  String get finishGame => 'Terminer';

  @override
  String get finishGameTitle => 'Terminer la partie ?';

  @override
  String get finishGameBody => 'Tous les joueurs verront l ecran de resume.';

  @override
  String get gameSummaryTitle => 'Fin de l aventure';

  @override
  String get gameResultVictory => 'Victoire';

  @override
  String get gameResultDefeat => 'Defaite';

  @override
  String get gameResultNeutral => 'Conclusion';

  @override
  String get gameSummaryCharacters => 'Personnages';

  @override
  String get gameSummaryNarrative => 'Resume';

  @override
  String get gameSummaryEpilogue => 'Epilogue';

  @override
  String get gameSummaryEvents => 'Evenements marquants';

  @override
  String get gameSummaryEnemies => 'Ennemis vaincus';

  @override
  String get gameSummaryItems => 'Objets obtenus';

  @override
  String get gameSummaryCriticals => 'Jets critiques';

  @override
  String get gameSummaryEmpty => 'Aucun';

  @override
  String gameDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String gameDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String get backToTavern => 'Retour a la taverne';

  @override
  String get waitingForHost => 'En attente du host';

  @override
  String notEnoughPlayers(int current, int minimum) {
    return 'Joueurs insuffisants ($current / $minimum).';
  }

  @override
  String missingRequiredClass(String className) {
    return 'Classe obligatoire manquante : $className.';
  }

  @override
  String get createRoomTitle => 'Creer une partie';

  @override
  String get newAdventureTitle => 'Nouvelle aventure';

  @override
  String get createMyAdventure => 'Creer mon aventure';

  @override
  String get readyAdventures => 'Aventures pretes a jouer';

  @override
  String get adventurePromptLabel =>
      'Decrivez l aventure que vous souhaitez vivre';

  @override
  String get adventurePromptHint =>
      'Nous sommes quatre mercenaires charges d escorter un prince a travers un royaume en guerre.';

  @override
  String get adventurePromptTooShort =>
      'Decris l aventure en quelques phrases.';

  @override
  String get adventureTitleOptional => 'Titre (optionnel)';

  @override
  String get adventureToneOptional => 'Ambiance (optionnel)';

  @override
  String get adventureDifficulty => 'Difficulte';

  @override
  String get difficultyEasy => 'Facile';

  @override
  String get difficultyStandard => 'Standard';

  @override
  String get difficultyHard => 'Difficile';

  @override
  String get adventureDuration => 'Duree estimee';

  @override
  String get durationShort => 'Courte';

  @override
  String get durationMedium => 'Moyenne';

  @override
  String get durationLong => 'Longue';

  @override
  String get adventureOrientation => 'Orientation';

  @override
  String get orientationCombat => 'Combat';

  @override
  String get orientationExploration => 'Exploration';

  @override
  String get orientationInvestigation => 'Enquete';

  @override
  String get orientationRoleplay => 'Roleplay';

  @override
  String get orientationSurvival => 'Survie';

  @override
  String get optionImprovise => 'MJ libre d improviser';

  @override
  String get optionPermadeath => 'Permadeath';

  @override
  String get optionPvp => 'PvP autorise';

  @override
  String get optionBetrayals => 'Trahisons possibles';

  @override
  String get scenarioCustomName => 'Aventure libre';

  @override
  String get generatingAdventure => 'Creer et generer';

  @override
  String get roomName => 'Nom de la partie';

  @override
  String get adventureLanguage => 'Langue de l\'aventure';

  @override
  String get fieldRequired => 'Champ obligatoire.';

  @override
  String get scenario => 'Scenario';

  @override
  String scenarioMinPlayers(String name, int count) {
    return '$name (min $count)';
  }

  @override
  String get create => 'Creer';

  @override
  String get joinCodeTitle => 'Rejoindre par code';

  @override
  String get joinCodeLabel => 'Code de partie';

  @override
  String get joinCodeInvalid => 'Le code doit contenir 6 caracteres.';

  @override
  String get join => 'Rejoindre';

  @override
  String get noRoomForCode => 'Aucune partie trouvee pour ce code.';

  @override
  String get openGames => 'Parties ouvertes';

  @override
  String get noWaitingGames => 'Aucune partie en attente.';

  @override
  String get chooseFigurine => 'Choisir une figurine';

  @override
  String get completeSheetFirst => 'Complete ta fiche avant de rejoindre.';

  @override
  String classAlreadyTaken(String className) {
    return 'Ta classe ($className) est deja prise.';
  }

  @override
  String yourClass(String className) {
    return 'Classe : $className';
  }

  @override
  String get classNotAllowed =>
      'Ta classe n est pas autorisee pour ce scenario.';

  @override
  String get joinLobby => 'Rejoindre le lobby';

  @override
  String get taken => 'Prise';

  @override
  String get statStrength => 'Force';

  @override
  String get statDexterity => 'Dexterite';

  @override
  String get statConstitution => 'Constitution';

  @override
  String get statIntelligence => 'Intelligence';

  @override
  String get statWisdom => 'Sagesse';

  @override
  String get statCharisma => 'Charisme';

  @override
  String get classBarbarian => 'Barbare';

  @override
  String get classBard => 'Barde';

  @override
  String get classCleric => 'Clerc';

  @override
  String get classDruid => 'Druide';

  @override
  String get classFighter => 'Guerrier';

  @override
  String get classMonk => 'Moine';

  @override
  String get classPaladin => 'Paladin';

  @override
  String get classRanger => 'Rodeur';

  @override
  String get classRogue => 'Roublard';

  @override
  String get classSorcerer => 'Ensorceleur';

  @override
  String get classWarlock => 'Occultiste';

  @override
  String get classWizard => 'Magicien';

  @override
  String get scenarioDungeonName => 'Donjon';

  @override
  String get scenarioDungeonDescription =>
      'Exploration souterraine. Un clerc est obligatoire.';

  @override
  String get scenarioForestName => 'Foret';

  @override
  String get scenarioForestDescription =>
      'Piste et embuscades. Un clerc est obligatoire.';

  @override
  String get scenarioSiegeName => 'Siege';

  @override
  String get scenarioSiegeDescription =>
      'Defense d une place forte. Guerrier et clerc obligatoires.';

  @override
  String get scenarioDemoName => 'La porte du wyrm';

  @override
  String get scenarioDemoDescription =>
      'Solo, 10 minutes. Un secret s agite sous la taverne.';

  @override
  String get startDemo => 'Commencer la demo';

  @override
  String get resumeDemo => 'Reprendre la demo';

  @override
  String get demoSeeEnding => 'Voir la fin de la demo';

  @override
  String get demoHubHint =>
      'La demo est solo, 10 minutes de jeu, un scenario dedie. Pas de partie multijoueur ni de scenario libre.';

  @override
  String get demoAlreadyUsed => 'Cette demo a deja ete jouee sur ce compte.';

  @override
  String get demoCannotCreateRoom =>
      'La demo ne permet pas de creer une partie libre.';

  @override
  String get demoCannotJoin =>
      'La demo est solo. Rejoindre une partie n est pas disponible.';

  @override
  String get demoAdventureBegins => 'L aventure ne fait que commencer.';

  @override
  String get unlockDragonsLair => 'Debloquer DragonsLair';

  @override
  String get unlockBenefitCustom => 'Scenarios personnalises illimites';

  @override
  String get unlockBenefitSolo => 'Solo complet';

  @override
  String get unlockBenefitMultiplayer => 'Multijoueur';

  @override
  String get unlockBenefitSave => 'Parties sauvegardees';

  @override
  String get unlockBenefitUnlimited => 'Aventures sans limite de 10 minutes';

  @override
  String get demoPurchaseLater => 'L achat n est pas encore disponible.';

  @override
  String get boardTitle => 'Plateau';

  @override
  String get journalTitle => 'Histoire';

  @override
  String get journalEmpty => 'Aucun evenement pour le moment.';

  @override
  String get gmChoices => 'Le MJ propose :';

  @override
  String get actionHint => 'Precise ton action...';

  @override
  String get sendToGm => 'Envoyer au MJ';

  @override
  String get actionExamine => 'Examiner';

  @override
  String get actionInteract => 'Interagir';

  @override
  String get actionAttack => 'Attaquer';

  @override
  String get actionDefend => 'Defendre';

  @override
  String get actionUseItem => 'Utiliser un objet';

  @override
  String get actionFree => 'Action libre';

  @override
  String get hudSheet => 'Fiche';

  @override
  String get hudInventory => 'Inventaire';

  @override
  String get hudJournal => 'Livre';

  @override
  String get inGameSheetTitle => 'Fiche de personnage';

  @override
  String get inGameInventoryTitle => 'Inventaire';

  @override
  String get emptyInventory => 'Aucun objet pour le moment.';

  @override
  String itemQuantity(int count) {
    return 'x$count';
  }

  @override
  String pendingRollBody(String ability, int dc) {
    return 'Jet de $ability, DD $dc';
  }

  @override
  String get pendingRollCta => 'Lancer 1d20';

  @override
  String get pendingRollSuccess => 'Succes';

  @override
  String get pendingRollFailure => 'Echec';

  @override
  String pendingRollWaiting(String name) {
    return 'En attente du jet de $name.';
  }

  @override
  String get pendingRollUnknownPlayer => 'un joueur';

  @override
  String statLineEffective(String statName, int effective, int base) {
    return '$statName : $effective ($base)';
  }

  @override
  String get effectsTitle => 'Effets';

  @override
  String get emptyEffects => 'Aucun effet actif.';

  @override
  String get effectPermanent => 'permanent';

  @override
  String effectRemaining(int count) {
    return '$count scenes';
  }

  @override
  String get effectKindBuff => 'bonus';

  @override
  String get effectKindDebuff => 'malus';

  @override
  String get effectKindWound => 'blessure';

  @override
  String get effectKindSpell => 'sort';

  @override
  String get itemEquip => 'Equiper';

  @override
  String get itemUnequip => 'Retirer';

  @override
  String get itemUse => 'Utiliser';

  @override
  String get itemEquipped => 'Equipe';

  @override
  String get itemTypeWeapon => 'Arme';

  @override
  String get itemTypeArmor => 'Armure';

  @override
  String get itemTypeShield => 'Bouclier';

  @override
  String get itemTypeAccessory => 'Accessoire';

  @override
  String get itemTypePotion => 'Potion';

  @override
  String get itemTypeScroll => 'Parchemin';

  @override
  String get itemTypeTool => 'Outil';

  @override
  String get enemyDefeated => 'Vaincu';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageGerman => 'Deutsch';
}
