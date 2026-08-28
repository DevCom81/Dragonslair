import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'DragonsLair'**
  String get appTitle;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Multiplayer role-playing game with an AI game master.'**
  String get appTagline;

  /// No description provided for @emblemSemantic.
  ///
  /// In en, this message translates to:
  /// **'DragonsLair emblem'**
  String get emblemSemantic;

  /// No description provided for @playAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Play without signing up'**
  String get playAsGuest;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @continuePlay.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continuePlay;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @musicToggle.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get musicToggle;

  /// No description provided for @musicVolume.
  ///
  /// In en, this message translates to:
  /// **'Music volume'**
  String get musicVolume;

  /// No description provided for @supabaseMissing.
  ///
  /// In en, this message translates to:
  /// **'Supabase configuration is missing. The app runs in local mode.'**
  String get supabaseMissing;

  /// No description provided for @sessionClosed.
  ///
  /// In en, this message translates to:
  /// **'No session.'**
  String get sessionClosed;

  /// No description provided for @sessionConnected.
  ///
  /// In en, this message translates to:
  /// **'Signed in.'**
  String get sessionConnected;

  /// No description provided for @sessionGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest session on this device.'**
  String get sessionGuest;

  /// No description provided for @guestWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Play without an account'**
  String get guestWarningTitle;

  /// No description provided for @guestWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Your display name and character sheet stay on this device only. If you uninstall the app or sign out, they are lost. You can still rejoin a paused game from this device.'**
  String get guestWarningBody;

  /// No description provided for @guestWarningConfirm.
  ///
  /// In en, this message translates to:
  /// **'Play as guest'**
  String get guestWarningConfirm;

  /// No description provided for @guestWarningCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get guestWarningCancel;

  /// No description provided for @guestSuggestedName.
  ///
  /// In en, this message translates to:
  /// **'Wanderer-{suffix}'**
  String guestSuggestedName(String suffix);

  /// No description provided for @authSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authSignUpTitle;

  /// No description provided for @authLogInTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogInTitle;

  /// No description provided for @authAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name and character sheet stay linked to this account.'**
  String get authAccountHint;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email.'**
  String get emailInvalid;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters.'**
  String get passwordTooShort;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Log in'**
  String get alreadyHaveAccount;

  /// No description provided for @newPlayerSignUp.
  ///
  /// In en, this message translates to:
  /// **'New player? Sign up'**
  String get newPlayerSignUp;

  /// No description provided for @authRequired.
  ///
  /// In en, this message translates to:
  /// **'Authentication required.'**
  String get authRequired;

  /// No description provided for @displayNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Your display name'**
  String get displayNameTitle;

  /// No description provided for @displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a name other players will see in your party.'**
  String get displayNameHint;

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @minTwoChars.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters.'**
  String get minTwoChars;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileHint.
  ///
  /// In en, this message translates to:
  /// **'Your display name is shown in play. The figurine is your token on the board.'**
  String get profileHint;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Your figurine'**
  String get chooseAvatar;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved.'**
  String get profileSaved;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get myProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @sheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Character sheet'**
  String get sheetTitle;

  /// No description provided for @sheetIntro.
  ///
  /// In en, this message translates to:
  /// **'Pick a class, then roll 1d20 per ability. Rolls from 1 to 7 become 8, 19 or 20 become 18. The class adds +2 (max 18) to its primary ability.'**
  String get sheetIntro;

  /// No description provided for @classLabel.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classLabel;

  /// No description provided for @classBonusChip.
  ///
  /// In en, this message translates to:
  /// **'{className} (+2 {statName})'**
  String classBonusChip(String className, String statName);

  /// No description provided for @rollAbilities.
  ///
  /// In en, this message translates to:
  /// **'Roll dice (6d20)'**
  String get rollAbilities;

  /// No description provided for @saveSheet.
  ///
  /// In en, this message translates to:
  /// **'Save sheet'**
  String get saveSheet;

  /// No description provided for @sheetRequiresAccount.
  ///
  /// In en, this message translates to:
  /// **'Account and display name are required before the sheet.'**
  String get sheetRequiresAccount;

  /// No description provided for @statLine.
  ///
  /// In en, this message translates to:
  /// **'{statName}: {value}'**
  String statLine(String statName, int value);

  /// No description provided for @statLineBonus.
  ///
  /// In en, this message translates to:
  /// **'{statName}: {raw} → {finalValue} (+2 {className})'**
  String statLineBonus(
    String statName,
    int raw,
    int finalValue,
    String className,
  );

  /// No description provided for @tavernTitle.
  ///
  /// In en, this message translates to:
  /// **'Tavern'**
  String get tavernTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome.'**
  String get welcome;

  /// No description provided for @welcomeNamed.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}.'**
  String welcomeNamed(String name);

  /// No description provided for @welcomeNamedClass.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name} ({className}).'**
  String welcomeNamedClass(String name, String className);

  /// No description provided for @hubSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a game or join your companions.'**
  String get hubSubtitle;

  /// No description provided for @createGame.
  ///
  /// In en, this message translates to:
  /// **'Create a game'**
  String get createGame;

  /// No description provided for @joinGame.
  ///
  /// In en, this message translates to:
  /// **'Join a game'**
  String get joinGame;

  /// No description provided for @joinByCode.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get joinByCode;

  /// No description provided for @mySheet.
  ///
  /// In en, this message translates to:
  /// **'My sheet'**
  String get mySheet;

  /// No description provided for @guestBanner.
  ///
  /// In en, this message translates to:
  /// **'Guest mode: this character exists on this device only.'**
  String get guestBanner;

  /// No description provided for @lobbyTitle.
  ///
  /// In en, this message translates to:
  /// **'Lobby'**
  String get lobbyTitle;

  /// No description provided for @roomNotFound.
  ///
  /// In en, this message translates to:
  /// **'Game not found.'**
  String get roomNotFound;

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String codeLabel(String code);

  /// No description provided for @scenarioMinPlayersLine.
  ///
  /// In en, this message translates to:
  /// **'{scenario} · min {count} players'**
  String scenarioMinPlayersLine(String scenario, int count);

  /// No description provided for @players.
  ///
  /// In en, this message translates to:
  /// **'Players'**
  String get players;

  /// No description provided for @waitingForPlayers.
  ///
  /// In en, this message translates to:
  /// **'Waiting for players.'**
  String get waitingForPlayers;

  /// No description provided for @hpLabel.
  ///
  /// In en, this message translates to:
  /// **'HP {hp}'**
  String hpLabel(int hp);

  /// No description provided for @startGame.
  ///
  /// In en, this message translates to:
  /// **'Start the game'**
  String get startGame;

  /// No description provided for @pauseGame.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pauseGame;

  /// No description provided for @resumeGame.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resumeGame;

  /// No description provided for @gamePaused.
  ///
  /// In en, this message translates to:
  /// **'Game paused'**
  String get gamePaused;

  /// No description provided for @combatRoundBanner.
  ///
  /// In en, this message translates to:
  /// **'Combat — round {round}'**
  String combatRoundBanner(int round);

  /// No description provided for @waitingForHostResume.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host to resume'**
  String get waitingForHostResume;

  /// No description provided for @continueGames.
  ///
  /// In en, this message translates to:
  /// **'Continue a game'**
  String get continueGames;

  /// No description provided for @roomPausedBadge.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get roomPausedBadge;

  /// No description provided for @roomPlayingBadge.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get roomPlayingBadge;

  /// No description provided for @cannotJoinInProgress.
  ///
  /// In en, this message translates to:
  /// **'This game already started. New players cannot join.'**
  String get cannotJoinInProgress;

  /// No description provided for @cannotJoinFinished.
  ///
  /// In en, this message translates to:
  /// **'This game is finished.'**
  String get cannotJoinFinished;

  /// No description provided for @finishGame.
  ///
  /// In en, this message translates to:
  /// **'End game'**
  String get finishGame;

  /// No description provided for @finishGameTitle.
  ///
  /// In en, this message translates to:
  /// **'End this adventure?'**
  String get finishGameTitle;

  /// No description provided for @finishGameBody.
  ///
  /// In en, this message translates to:
  /// **'Every player will see the recap screen.'**
  String get finishGameBody;

  /// No description provided for @gameSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Adventure over'**
  String get gameSummaryTitle;

  /// No description provided for @gameResultVictory.
  ///
  /// In en, this message translates to:
  /// **'Victory'**
  String get gameResultVictory;

  /// No description provided for @gameResultDefeat.
  ///
  /// In en, this message translates to:
  /// **'Defeat'**
  String get gameResultDefeat;

  /// No description provided for @gameResultNeutral.
  ///
  /// In en, this message translates to:
  /// **'Closing'**
  String get gameResultNeutral;

  /// No description provided for @gameSummaryCharacters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get gameSummaryCharacters;

  /// No description provided for @gameSummaryNarrative.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get gameSummaryNarrative;

  /// No description provided for @gameSummaryEpilogue.
  ///
  /// In en, this message translates to:
  /// **'Epilogue'**
  String get gameSummaryEpilogue;

  /// No description provided for @gameSummaryEvents.
  ///
  /// In en, this message translates to:
  /// **'Notable events'**
  String get gameSummaryEvents;

  /// No description provided for @gameSummaryEnemies.
  ///
  /// In en, this message translates to:
  /// **'Defeated enemies'**
  String get gameSummaryEnemies;

  /// No description provided for @gameSummaryItems.
  ///
  /// In en, this message translates to:
  /// **'Items found'**
  String get gameSummaryItems;

  /// No description provided for @gameSummaryCriticals.
  ///
  /// In en, this message translates to:
  /// **'Critical rolls'**
  String get gameSummaryCriticals;

  /// No description provided for @gameSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get gameSummaryEmpty;

  /// No description provided for @gameDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String gameDurationMinutes(int minutes);

  /// No description provided for @gameDurationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String gameDurationHoursMinutes(int hours, int minutes);

  /// No description provided for @backToTavern.
  ///
  /// In en, this message translates to:
  /// **'Back to the tavern'**
  String get backToTavern;

  /// No description provided for @waitingForHost.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the host'**
  String get waitingForHost;

  /// No description provided for @notEnoughPlayers.
  ///
  /// In en, this message translates to:
  /// **'Not enough players ({current} / {minimum}).'**
  String notEnoughPlayers(int current, int minimum);

  /// No description provided for @missingRequiredClass.
  ///
  /// In en, this message translates to:
  /// **'Required class missing: {className}.'**
  String missingRequiredClass(String className);

  /// No description provided for @createRoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a game'**
  String get createRoomTitle;

  /// No description provided for @newAdventureTitle.
  ///
  /// In en, this message translates to:
  /// **'New adventure'**
  String get newAdventureTitle;

  /// No description provided for @createMyAdventure.
  ///
  /// In en, this message translates to:
  /// **'Create my adventure'**
  String get createMyAdventure;

  /// No description provided for @readyAdventures.
  ///
  /// In en, this message translates to:
  /// **'Ready to play'**
  String get readyAdventures;

  /// No description provided for @adventurePromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Describe the adventure you want to live'**
  String get adventurePromptLabel;

  /// No description provided for @adventurePromptHint.
  ///
  /// In en, this message translates to:
  /// **'Four mercenaries escort a prince through a kingdom at war. Dark tone, moral choices.'**
  String get adventurePromptHint;

  /// No description provided for @adventurePromptTooShort.
  ///
  /// In en, this message translates to:
  /// **'Write a few sentences about the adventure.'**
  String get adventurePromptTooShort;

  /// No description provided for @adventureTitleOptional.
  ///
  /// In en, this message translates to:
  /// **'Title (optional)'**
  String get adventureTitleOptional;

  /// No description provided for @adventureToneOptional.
  ///
  /// In en, this message translates to:
  /// **'Tone (optional)'**
  String get adventureToneOptional;

  /// No description provided for @adventureDifficulty.
  ///
  /// In en, this message translates to:
  /// **'Difficulty'**
  String get adventureDifficulty;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get difficultyEasy;

  /// No description provided for @difficultyStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get difficultyStandard;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get difficultyHard;

  /// No description provided for @adventureDuration.
  ///
  /// In en, this message translates to:
  /// **'Estimated length'**
  String get adventureDuration;

  /// No description provided for @durationShort.
  ///
  /// In en, this message translates to:
  /// **'Short'**
  String get durationShort;

  /// No description provided for @durationMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get durationMedium;

  /// No description provided for @durationLong.
  ///
  /// In en, this message translates to:
  /// **'Long'**
  String get durationLong;

  /// No description provided for @adventureOrientation.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get adventureOrientation;

  /// No description provided for @orientationCombat.
  ///
  /// In en, this message translates to:
  /// **'Combat'**
  String get orientationCombat;

  /// No description provided for @orientationExploration.
  ///
  /// In en, this message translates to:
  /// **'Exploration'**
  String get orientationExploration;

  /// No description provided for @orientationInvestigation.
  ///
  /// In en, this message translates to:
  /// **'Investigation'**
  String get orientationInvestigation;

  /// No description provided for @orientationRoleplay.
  ///
  /// In en, this message translates to:
  /// **'Roleplay'**
  String get orientationRoleplay;

  /// No description provided for @orientationSurvival.
  ///
  /// In en, this message translates to:
  /// **'Survival'**
  String get orientationSurvival;

  /// No description provided for @optionImprovise.
  ///
  /// In en, this message translates to:
  /// **'GM may improvise freely'**
  String get optionImprovise;

  /// No description provided for @optionPermadeath.
  ///
  /// In en, this message translates to:
  /// **'Permadeath'**
  String get optionPermadeath;

  /// No description provided for @optionPvp.
  ///
  /// In en, this message translates to:
  /// **'PvP allowed'**
  String get optionPvp;

  /// No description provided for @optionBetrayals.
  ///
  /// In en, this message translates to:
  /// **'Betrayals possible'**
  String get optionBetrayals;

  /// No description provided for @scenarioCustomName.
  ///
  /// In en, this message translates to:
  /// **'Custom adventure'**
  String get scenarioCustomName;

  /// No description provided for @generatingAdventure.
  ///
  /// In en, this message translates to:
  /// **'Create and generate'**
  String get generatingAdventure;

  /// No description provided for @roomName.
  ///
  /// In en, this message translates to:
  /// **'Game name'**
  String get roomName;

  /// No description provided for @adventureLanguage.
  ///
  /// In en, this message translates to:
  /// **'Adventure language'**
  String get adventureLanguage;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required field.'**
  String get fieldRequired;

  /// No description provided for @scenario.
  ///
  /// In en, this message translates to:
  /// **'Scenario'**
  String get scenario;

  /// No description provided for @scenarioMinPlayers.
  ///
  /// In en, this message translates to:
  /// **'{name} (min {count})'**
  String scenarioMinPlayers(String name, int count);

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @joinCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Join with a code'**
  String get joinCodeTitle;

  /// No description provided for @joinCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Game code'**
  String get joinCodeLabel;

  /// No description provided for @joinCodeInvalid.
  ///
  /// In en, this message translates to:
  /// **'The code must contain 6 characters.'**
  String get joinCodeInvalid;

  /// No description provided for @join.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get join;

  /// No description provided for @noRoomForCode.
  ///
  /// In en, this message translates to:
  /// **'No game found for this code.'**
  String get noRoomForCode;

  /// No description provided for @openGames.
  ///
  /// In en, this message translates to:
  /// **'Open games'**
  String get openGames;

  /// No description provided for @noWaitingGames.
  ///
  /// In en, this message translates to:
  /// **'No games waiting.'**
  String get noWaitingGames;

  /// No description provided for @chooseFigurine.
  ///
  /// In en, this message translates to:
  /// **'Choose a figurine'**
  String get chooseFigurine;

  /// No description provided for @completeSheetFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete your sheet before joining.'**
  String get completeSheetFirst;

  /// No description provided for @classAlreadyTaken.
  ///
  /// In en, this message translates to:
  /// **'Your class ({className}) is already taken.'**
  String classAlreadyTaken(String className);

  /// No description provided for @yourClass.
  ///
  /// In en, this message translates to:
  /// **'Class: {className}'**
  String yourClass(String className);

  /// No description provided for @classNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Your class is not allowed in this scenario.'**
  String get classNotAllowed;

  /// No description provided for @joinLobby.
  ///
  /// In en, this message translates to:
  /// **'Join the lobby'**
  String get joinLobby;

  /// No description provided for @taken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get taken;

  /// No description provided for @statStrength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get statStrength;

  /// No description provided for @statDexterity.
  ///
  /// In en, this message translates to:
  /// **'Dexterity'**
  String get statDexterity;

  /// No description provided for @statConstitution.
  ///
  /// In en, this message translates to:
  /// **'Constitution'**
  String get statConstitution;

  /// No description provided for @statIntelligence.
  ///
  /// In en, this message translates to:
  /// **'Intelligence'**
  String get statIntelligence;

  /// No description provided for @statWisdom.
  ///
  /// In en, this message translates to:
  /// **'Wisdom'**
  String get statWisdom;

  /// No description provided for @statCharisma.
  ///
  /// In en, this message translates to:
  /// **'Charisma'**
  String get statCharisma;

  /// No description provided for @classBarbarian.
  ///
  /// In en, this message translates to:
  /// **'Barbarian'**
  String get classBarbarian;

  /// No description provided for @classBard.
  ///
  /// In en, this message translates to:
  /// **'Bard'**
  String get classBard;

  /// No description provided for @classCleric.
  ///
  /// In en, this message translates to:
  /// **'Cleric'**
  String get classCleric;

  /// No description provided for @classDruid.
  ///
  /// In en, this message translates to:
  /// **'Druid'**
  String get classDruid;

  /// No description provided for @classFighter.
  ///
  /// In en, this message translates to:
  /// **'Fighter'**
  String get classFighter;

  /// No description provided for @classMonk.
  ///
  /// In en, this message translates to:
  /// **'Monk'**
  String get classMonk;

  /// No description provided for @classPaladin.
  ///
  /// In en, this message translates to:
  /// **'Paladin'**
  String get classPaladin;

  /// No description provided for @classRanger.
  ///
  /// In en, this message translates to:
  /// **'Ranger'**
  String get classRanger;

  /// No description provided for @classRogue.
  ///
  /// In en, this message translates to:
  /// **'Rogue'**
  String get classRogue;

  /// No description provided for @classSorcerer.
  ///
  /// In en, this message translates to:
  /// **'Sorcerer'**
  String get classSorcerer;

  /// No description provided for @classWarlock.
  ///
  /// In en, this message translates to:
  /// **'Warlock'**
  String get classWarlock;

  /// No description provided for @classWizard.
  ///
  /// In en, this message translates to:
  /// **'Wizard'**
  String get classWizard;

  /// No description provided for @scenarioDungeonName.
  ///
  /// In en, this message translates to:
  /// **'Dungeon'**
  String get scenarioDungeonName;

  /// No description provided for @scenarioDungeonDescription.
  ///
  /// In en, this message translates to:
  /// **'Underground exploration. A cleric is required.'**
  String get scenarioDungeonDescription;

  /// No description provided for @scenarioForestName.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get scenarioForestName;

  /// No description provided for @scenarioForestDescription.
  ///
  /// In en, this message translates to:
  /// **'Tracks and ambushes. A cleric is required.'**
  String get scenarioForestDescription;

  /// No description provided for @scenarioSiegeName.
  ///
  /// In en, this message translates to:
  /// **'Siege'**
  String get scenarioSiegeName;

  /// No description provided for @scenarioSiegeDescription.
  ///
  /// In en, this message translates to:
  /// **'Defense of a stronghold. Fighter and cleric are required.'**
  String get scenarioSiegeDescription;

  /// No description provided for @scenarioDemoName.
  ///
  /// In en, this message translates to:
  /// **'The Wyrm Gate'**
  String get scenarioDemoName;

  /// No description provided for @scenarioDemoDescription.
  ///
  /// In en, this message translates to:
  /// **'Solo, 10 minutes. Something stirs beneath the tavern.'**
  String get scenarioDemoDescription;

  /// No description provided for @startDemo.
  ///
  /// In en, this message translates to:
  /// **'Start the demo'**
  String get startDemo;

  /// No description provided for @resumeDemo.
  ///
  /// In en, this message translates to:
  /// **'Resume the demo'**
  String get resumeDemo;

  /// No description provided for @demoSeeEnding.
  ///
  /// In en, this message translates to:
  /// **'See the demo ending'**
  String get demoSeeEnding;

  /// No description provided for @demoHubHint.
  ///
  /// In en, this message translates to:
  /// **'The demo is solo, 10 minutes of play, one dedicated scenario. No multiplayer or custom adventures.'**
  String get demoHubHint;

  /// No description provided for @demoAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This account has already used the demo.'**
  String get demoAlreadyUsed;

  /// No description provided for @demoCannotCreateRoom.
  ///
  /// In en, this message translates to:
  /// **'The demo cannot create a free adventure.'**
  String get demoCannotCreateRoom;

  /// No description provided for @demoCannotJoin.
  ///
  /// In en, this message translates to:
  /// **'The demo is solo. Joining a game is not available.'**
  String get demoCannotJoin;

  /// No description provided for @demoAdventureBegins.
  ///
  /// In en, this message translates to:
  /// **'The adventure is only beginning.'**
  String get demoAdventureBegins;

  /// No description provided for @tryDragonsLairFree.
  ///
  /// In en, this message translates to:
  /// **'Try DragonsLair for free'**
  String get tryDragonsLairFree;

  /// No description provided for @unlockDragonsLairTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock DragonsLair'**
  String get unlockDragonsLairTitle;

  /// No description provided for @unlockTheGame.
  ///
  /// In en, this message translates to:
  /// **'Unlock the game'**
  String get unlockTheGame;

  /// No description provided for @demoBenefitMinutes.
  ///
  /// In en, this message translates to:
  /// **'10 minutes'**
  String get demoBenefitMinutes;

  /// No description provided for @demoBenefitSoloPlay.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get demoBenefitSoloPlay;

  /// No description provided for @demoBenefitAiGm.
  ///
  /// In en, this message translates to:
  /// **'AI game master'**
  String get demoBenefitAiGm;

  /// No description provided for @demoBenefitCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character creation'**
  String get demoBenefitCharacter;

  /// No description provided for @demoBenefitDice.
  ///
  /// In en, this message translates to:
  /// **'Dice'**
  String get demoBenefitDice;

  /// No description provided for @demoBenefitCombat.
  ///
  /// In en, this message translates to:
  /// **'Combat'**
  String get demoBenefitCombat;

  /// No description provided for @unlockDragonsLair.
  ///
  /// In en, this message translates to:
  /// **'Unlock DragonsLair'**
  String get unlockDragonsLair;

  /// No description provided for @unlockBenefitCustom.
  ///
  /// In en, this message translates to:
  /// **'Create your own adventures'**
  String get unlockBenefitCustom;

  /// No description provided for @unlockBenefitSolo.
  ///
  /// In en, this message translates to:
  /// **'Full solo play'**
  String get unlockBenefitSolo;

  /// No description provided for @unlockBenefitMultiplayer.
  ///
  /// In en, this message translates to:
  /// **'Play with friends'**
  String get unlockBenefitMultiplayer;

  /// No description provided for @unlockBenefitSave.
  ///
  /// In en, this message translates to:
  /// **'Save your games'**
  String get unlockBenefitSave;

  /// No description provided for @unlockBenefitUnlimited.
  ///
  /// In en, this message translates to:
  /// **'Play with no time limit'**
  String get unlockBenefitUnlimited;

  /// No description provided for @demoPurchaseLater.
  ///
  /// In en, this message translates to:
  /// **'Purchasing is not available yet.'**
  String get demoPurchaseLater;

  /// No description provided for @purchaseUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Purchasing is not available yet.'**
  String get purchaseUnavailable;

  /// No description provided for @restorePurchase.
  ///
  /// In en, this message translates to:
  /// **'Restore my purchase'**
  String get restorePurchase;

  /// No description provided for @purchaseRestored.
  ///
  /// In en, this message translates to:
  /// **'Your license is active on this account.'**
  String get purchaseRestored;

  /// No description provided for @purchaseNotFound.
  ///
  /// In en, this message translates to:
  /// **'No purchase found for this account.'**
  String get purchaseNotFound;

  /// No description provided for @boardTitle.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get boardTitle;

  /// No description provided for @journalTitle.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get journalTitle;

  /// No description provided for @journalEmpty.
  ///
  /// In en, this message translates to:
  /// **'No events yet.'**
  String get journalEmpty;

  /// No description provided for @gmChoices.
  ///
  /// In en, this message translates to:
  /// **'The GM offers:'**
  String get gmChoices;

  /// No description provided for @actionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your action...'**
  String get actionHint;

  /// No description provided for @sendToGm.
  ///
  /// In en, this message translates to:
  /// **'Send to GM'**
  String get sendToGm;

  /// No description provided for @actionExamine.
  ///
  /// In en, this message translates to:
  /// **'Examine'**
  String get actionExamine;

  /// No description provided for @actionInteract.
  ///
  /// In en, this message translates to:
  /// **'Interact'**
  String get actionInteract;

  /// No description provided for @actionAttack.
  ///
  /// In en, this message translates to:
  /// **'Attack'**
  String get actionAttack;

  /// No description provided for @actionDefend.
  ///
  /// In en, this message translates to:
  /// **'Defend'**
  String get actionDefend;

  /// No description provided for @actionUseItem.
  ///
  /// In en, this message translates to:
  /// **'Use an item'**
  String get actionUseItem;

  /// No description provided for @actionFree.
  ///
  /// In en, this message translates to:
  /// **'Free action'**
  String get actionFree;

  /// No description provided for @hudSheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get hudSheet;

  /// No description provided for @hudInventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get hudInventory;

  /// No description provided for @hudJournal.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get hudJournal;

  /// No description provided for @demoTimer.
  ///
  /// In en, this message translates to:
  /// **'Demo {time}'**
  String demoTimer(String time);

  /// No description provided for @demoTimerPaused.
  ///
  /// In en, this message translates to:
  /// **'Demo paused {time}'**
  String demoTimerPaused(String time);

  /// No description provided for @demoKeepOnUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlocking keeps this adventure.'**
  String get demoKeepOnUnlock;

  /// No description provided for @inGameSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Character sheet'**
  String get inGameSheetTitle;

  /// No description provided for @inGameInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inGameInventoryTitle;

  /// No description provided for @emptyInventory.
  ///
  /// In en, this message translates to:
  /// **'No items yet.'**
  String get emptyInventory;

  /// No description provided for @itemQuantity.
  ///
  /// In en, this message translates to:
  /// **'x{count}'**
  String itemQuantity(int count);

  /// No description provided for @pendingRollBody.
  ///
  /// In en, this message translates to:
  /// **'{ability} check, DC {dc}'**
  String pendingRollBody(String ability, int dc);

  /// No description provided for @pendingRollCta.
  ///
  /// In en, this message translates to:
  /// **'Roll 1d20'**
  String get pendingRollCta;

  /// No description provided for @pendingRollSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get pendingRollSuccess;

  /// No description provided for @pendingRollFailure.
  ///
  /// In en, this message translates to:
  /// **'Failure'**
  String get pendingRollFailure;

  /// No description provided for @pendingRollWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for {name}\'s roll.'**
  String pendingRollWaiting(String name);

  /// No description provided for @pendingRollUnknownPlayer.
  ///
  /// In en, this message translates to:
  /// **'a player'**
  String get pendingRollUnknownPlayer;

  /// No description provided for @statLineEffective.
  ///
  /// In en, this message translates to:
  /// **'{statName}: {effective} ({base})'**
  String statLineEffective(String statName, int effective, int base);

  /// No description provided for @effectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Effects'**
  String get effectsTitle;

  /// No description provided for @emptyEffects.
  ///
  /// In en, this message translates to:
  /// **'No active effects.'**
  String get emptyEffects;

  /// No description provided for @effectPermanent.
  ///
  /// In en, this message translates to:
  /// **'permanent'**
  String get effectPermanent;

  /// No description provided for @effectRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} scenes'**
  String effectRemaining(int count);

  /// No description provided for @effectKindBuff.
  ///
  /// In en, this message translates to:
  /// **'buff'**
  String get effectKindBuff;

  /// No description provided for @effectKindDebuff.
  ///
  /// In en, this message translates to:
  /// **'debuff'**
  String get effectKindDebuff;

  /// No description provided for @effectKindWound.
  ///
  /// In en, this message translates to:
  /// **'wound'**
  String get effectKindWound;

  /// No description provided for @effectKindSpell.
  ///
  /// In en, this message translates to:
  /// **'spell'**
  String get effectKindSpell;

  /// No description provided for @itemEquip.
  ///
  /// In en, this message translates to:
  /// **'Equip'**
  String get itemEquip;

  /// No description provided for @itemUnequip.
  ///
  /// In en, this message translates to:
  /// **'Unequip'**
  String get itemUnequip;

  /// No description provided for @itemUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get itemUse;

  /// No description provided for @itemEquipped.
  ///
  /// In en, this message translates to:
  /// **'Equipped'**
  String get itemEquipped;

  /// No description provided for @itemTypeWeapon.
  ///
  /// In en, this message translates to:
  /// **'Weapon'**
  String get itemTypeWeapon;

  /// No description provided for @itemTypeArmor.
  ///
  /// In en, this message translates to:
  /// **'Armor'**
  String get itemTypeArmor;

  /// No description provided for @itemTypeShield.
  ///
  /// In en, this message translates to:
  /// **'Shield'**
  String get itemTypeShield;

  /// No description provided for @itemTypeAccessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get itemTypeAccessory;

  /// No description provided for @itemTypePotion.
  ///
  /// In en, this message translates to:
  /// **'Potion'**
  String get itemTypePotion;

  /// No description provided for @itemTypeScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get itemTypeScroll;

  /// No description provided for @itemTypeTool.
  ///
  /// In en, this message translates to:
  /// **'Tool'**
  String get itemTypeTool;

  /// No description provided for @enemyDefeated.
  ///
  /// In en, this message translates to:
  /// **'Defeated'**
  String get enemyDefeated;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
