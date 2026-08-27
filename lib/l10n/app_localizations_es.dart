// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'DragonsLair';

  @override
  String get appTagline =>
      'Juego de rol multijugador con un director de juego de IA.';

  @override
  String get emblemSemantic => 'Emblema de DragonsLair';

  @override
  String get playAsGuest => 'Jugar sin registrarse';

  @override
  String get logIn => 'Iniciar sesion';

  @override
  String get signUp => 'Registrarse';

  @override
  String get continuePlay => 'Continuar';

  @override
  String get signOut => 'Cerrar sesion';

  @override
  String get language => 'Idioma';

  @override
  String get preferences => 'Preferencias';

  @override
  String get supabaseMissing =>
      'Falta la configuracion de Supabase. La app funciona en modo local.';

  @override
  String get sessionClosed => 'Sin sesion.';

  @override
  String get sessionConnected => 'Sesion iniciada.';

  @override
  String get sessionGuest => 'Sesion de invitado en este dispositivo.';

  @override
  String get guestWarningTitle => 'Jugar sin cuenta';

  @override
  String get guestWarningBody =>
      'Tu nombre y tu ficha permanecen solo en este dispositivo. Si desinstalas la app o cierras sesion, se pierden. Aun podras retomar una partida en pausa desde este dispositivo.';

  @override
  String get guestWarningConfirm => 'Jugar como invitado';

  @override
  String get guestWarningCancel => 'Cancelar';

  @override
  String guestSuggestedName(String suffix) {
    return 'Viajero-$suffix';
  }

  @override
  String get authSignUpTitle => 'Crear una cuenta';

  @override
  String get authLogInTitle => 'Iniciar sesion';

  @override
  String get authAccountHint =>
      'Tu nombre y tu ficha quedan vinculados a esta cuenta.';

  @override
  String get email => 'Correo';

  @override
  String get emailInvalid => 'Correo no valido.';

  @override
  String get password => 'Contrasena';

  @override
  String get passwordTooShort => 'Al menos 6 caracteres.';

  @override
  String get createAccount => 'Crear cuenta';

  @override
  String get alreadyHaveAccount => 'Ya tienes cuenta? Inicia sesion';

  @override
  String get newPlayerSignUp => 'Jugador nuevo? Registrate';

  @override
  String get authRequired => 'Se requiere autenticacion.';

  @override
  String get displayNameTitle => 'Tu nombre';

  @override
  String get displayNameHint =>
      'Elige un nombre visible para los demas jugadores de tu partida.';

  @override
  String get displayNameLabel => 'Nombre';

  @override
  String get minTwoChars => 'Al menos 2 caracteres.';

  @override
  String get save => 'Guardar';

  @override
  String get sheetTitle => 'Ficha de personaje';

  @override
  String get sheetIntro =>
      'Elige una clase y lanza 1d20 por caracteristica. Un 1 a 7 se convierte en 8; un 19 o 20, en 18. La clase suma +2 (max. 18) a su caracteristica principal.';

  @override
  String get classLabel => 'Clase';

  @override
  String classBonusChip(String className, String statName) {
    return '$className (+2 $statName)';
  }

  @override
  String get rollAbilities => 'Lanzar dados (6d20)';

  @override
  String get saveSheet => 'Guardar ficha';

  @override
  String get sheetRequiresAccount =>
      'Se requieren cuenta y nombre antes de la ficha.';

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
  String get tavernTitle => 'Taberna';

  @override
  String get welcome => 'Bienvenido.';

  @override
  String welcomeNamed(String name) {
    return 'Bienvenido, $name.';
  }

  @override
  String welcomeNamedClass(String name, String className) {
    return 'Bienvenido, $name ($className).';
  }

  @override
  String get hubSubtitle => 'Crea una partida o unete a tus companeros.';

  @override
  String get createGame => 'Crear una partida';

  @override
  String get joinGame => 'Unirse a una partida';

  @override
  String get joinByCode => 'Unirse con codigo';

  @override
  String get mySheet => 'Mi ficha';

  @override
  String get guestBanner =>
      'Modo invitado: este personaje existe solo en este dispositivo.';

  @override
  String get lobbyTitle => 'Lobby';

  @override
  String get roomNotFound => 'Partida no encontrada.';

  @override
  String codeLabel(String code) {
    return 'Codigo: $code';
  }

  @override
  String scenarioMinPlayersLine(String scenario, int count) {
    return '$scenario · min. $count jugadores';
  }

  @override
  String get players => 'Jugadores';

  @override
  String get waitingForPlayers => 'Esperando jugadores.';

  @override
  String hpLabel(int hp) {
    return 'PV $hp';
  }

  @override
  String get startGame => 'Empezar la partida';

  @override
  String get waitingForHost => 'Esperando al anfitrion';

  @override
  String notEnoughPlayers(int current, int minimum) {
    return 'Jugadores insuficientes ($current / $minimum).';
  }

  @override
  String missingRequiredClass(String className) {
    return 'Falta la clase obligatoria: $className.';
  }

  @override
  String get createRoomTitle => 'Crear una partida';

  @override
  String get roomName => 'Nombre de la partida';

  @override
  String get fieldRequired => 'Campo obligatorio.';

  @override
  String get scenario => 'Escenario';

  @override
  String scenarioMinPlayers(String name, int count) {
    return '$name (min. $count)';
  }

  @override
  String get create => 'Crear';

  @override
  String get joinCodeTitle => 'Unirse con codigo';

  @override
  String get joinCodeLabel => 'Codigo de partida';

  @override
  String get joinCodeInvalid => 'El codigo debe tener 6 caracteres.';

  @override
  String get join => 'Unirse';

  @override
  String get noRoomForCode => 'No hay partida para este codigo.';

  @override
  String get openGames => 'Partidas abiertas';

  @override
  String get noWaitingGames => 'No hay partidas en espera.';

  @override
  String get chooseFigurine => 'Elige una figurita';

  @override
  String get completeSheetFirst => 'Completa tu ficha antes de unirte.';

  @override
  String classAlreadyTaken(String className) {
    return 'Tu clase ($className) ya esta ocupada.';
  }

  @override
  String yourClass(String className) {
    return 'Clase: $className';
  }

  @override
  String get classNotAllowed => 'Tu clase no esta permitida en este escenario.';

  @override
  String get joinLobby => 'Unirse al lobby';

  @override
  String get taken => 'Ocupada';

  @override
  String get statStrength => 'Fuerza';

  @override
  String get statDexterity => 'Destreza';

  @override
  String get statConstitution => 'Constitucion';

  @override
  String get statIntelligence => 'Inteligencia';

  @override
  String get statWisdom => 'Sabiduria';

  @override
  String get statCharisma => 'Carisma';

  @override
  String get classBarbarian => 'Barbaro';

  @override
  String get classBard => 'Bardo';

  @override
  String get classCleric => 'Clerigo';

  @override
  String get classDruid => 'Druida';

  @override
  String get classFighter => 'Guerrero';

  @override
  String get classMonk => 'Monje';

  @override
  String get classPaladin => 'Paladin';

  @override
  String get classRanger => 'Explorador';

  @override
  String get classRogue => 'Picaro';

  @override
  String get classSorcerer => 'Hechicero';

  @override
  String get classWarlock => 'Brujo';

  @override
  String get classWizard => 'Mago';

  @override
  String get scenarioDungeonName => 'Mazmorra';

  @override
  String get scenarioDungeonDescription =>
      'Exploracion subterranea. Se requiere un clerigo.';

  @override
  String get scenarioForestName => 'Bosque';

  @override
  String get scenarioForestDescription =>
      'Pistas y emboscadas. Se requiere un clerigo.';

  @override
  String get scenarioSiegeName => 'Asedio';

  @override
  String get scenarioSiegeDescription =>
      'Defensa de una fortaleza. Guerrero y clerigo son obligatorios.';

  @override
  String get boardTitle => 'Tablero';

  @override
  String get journalTitle => 'Historia';

  @override
  String get journalEmpty => 'Todavia no hay sucesos.';

  @override
  String get gmChoices => 'El DJ propone:';

  @override
  String get actionHint => 'Describe tu accion...';

  @override
  String get sendToGm => 'Enviar al DJ';

  @override
  String get actionExamine => 'Examinar';

  @override
  String get actionInteract => 'Interactuar';

  @override
  String get actionAttack => 'Atacar';

  @override
  String get actionDefend => 'Defender';

  @override
  String get actionUseItem => 'Usar un objeto';

  @override
  String get actionFree => 'Accion libre';

  @override
  String get hudSheet => 'Ficha';

  @override
  String get hudInventory => 'Inventario';

  @override
  String get hudJournal => 'Libro';

  @override
  String get inGameSheetTitle => 'Ficha de personaje';

  @override
  String get inGameInventoryTitle => 'Inventario';

  @override
  String get emptyInventory => 'Todavia no hay objetos.';

  @override
  String itemQuantity(int count) {
    return 'x$count';
  }

  @override
  String pendingRollBody(String ability, int dc) {
    return 'Tirada de $ability, CD $dc';
  }

  @override
  String get pendingRollCta => 'Tirar 1d20';

  @override
  String get pendingRollSuccess => 'Exito';

  @override
  String get pendingRollFailure => 'Fallo';

  @override
  String pendingRollWaiting(String name) {
    return 'Esperando la tirada de $name.';
  }

  @override
  String get pendingRollUnknownPlayer => 'un jugador';

  @override
  String statLineEffective(String statName, int effective, int base) {
    return '$statName: $effective ($base)';
  }

  @override
  String get effectsTitle => 'Efectos';

  @override
  String get emptyEffects => 'Ningun efecto activo.';

  @override
  String get effectPermanent => 'permanente';

  @override
  String effectRemaining(int count) {
    return '$count escenas';
  }

  @override
  String get effectKindBuff => 'bono';

  @override
  String get effectKindDebuff => 'penalizacion';

  @override
  String get effectKindWound => 'herida';

  @override
  String get effectKindSpell => 'hechizo';

  @override
  String get itemEquip => 'Equipar';

  @override
  String get itemUnequip => 'Quitar';

  @override
  String get itemUse => 'Usar';

  @override
  String get itemEquipped => 'Equipado';

  @override
  String get itemTypeWeapon => 'Arma';

  @override
  String get itemTypeArmor => 'Armadura';

  @override
  String get itemTypeShield => 'Escudo';

  @override
  String get itemTypeAccessory => 'Accesorio';

  @override
  String get itemTypePotion => 'Pocion';

  @override
  String get itemTypeScroll => 'Pergamino';

  @override
  String get itemTypeTool => 'Herramienta';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageGerman => 'Deutsch';
}
