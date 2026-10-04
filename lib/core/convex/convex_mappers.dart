import '../../features/access/domain/game_access.dart';
import '../../features/access/domain/purchase_provider.dart';
import '../../features/auth/domain/character_stats.dart';
import '../../features/auth/domain/player_profile.dart';
import '../../features/combat/domain/combat_session.dart';
import '../../features/enemies/domain/enemy.dart';
import '../../features/events/domain/game_event.dart';
import '../../features/game/presentation/pending_ability_roll.dart';
import '../../features/music/domain/music_mood.dart';
import '../../features/players/domain/inventory_item.dart';
import '../../features/players/domain/player.dart';
import '../../features/players/domain/player_effect.dart';
import '../../features/rooms/domain/game_ending.dart';
import '../../features/rooms/domain/room.dart';
import '../../features/rooms/domain/room_locale.dart';
import '../../features/scenarios/domain/world_state.dart';
import '../errors/app_exception.dart';
import 'convex_document.dart';

PlayerProfile profileFromConvex(Object? value) {
  final json = convexObject(value, label: 'profile');
  return PlayerProfile(
    id: convexId(json),
    displayName: convexString(json['displayName'], label: 'displayName'),
    createdAt: convexDateTime(json['createdAt'], label: 'createdAt'),
    stats: CharacterStats.fromJson(json),
    sheetConfirmed: json['sheetConfirmed'] == true,
    classId: convexOptionalString(json['classId']),
    avatarFigurineId: _avatarId(json['avatarFigurineId']),
  );
}

PlayerProfile? profileFromConvexOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return profileFromConvex(value);
}

Room roomFromConvex(Object? value) {
  final json = convexObject(value, label: 'room');
  return Room(
    id: convexId(json),
    name: convexString(json['name'], label: 'name'),
    scenario: convexOptionalString(json['scenario']),
    scenarioId: convexOptionalString(json['scenarioId']),
    status: RoomStatus.fromJson(json['status']),
    createdAt: convexDateTime(json['createdAt'], label: 'createdAt'),
    hostId: convexOptionalId(json['hostUserId']),
    joinCode: convexOptionalString(json['joinCode']),
    minPlayers: convexInt(json['minPlayers'], fallback: 1),
    requiredClassIds: convexStringList(json['requiredClassIds']),
    scenarioPrompt: convexOptionalString(json['scenarioPrompt']) ?? '',
    worldState: sanitizePublicWorldState(json['worldState']),
    locale: normalizeRoomLocale(json['locale']),
    startedAt: convexOptionalDateTime(json['startedAt']),
    finishedAt: convexOptionalDateTime(json['finishedAt']),
    ending: GameEnding.fromJson(json['ending']),
    musicMood: MusicMood.parseNarrative(json['musicMood']),
  );
}

List<Room> roomsFromConvex(Object? value) {
  return [
    for (final row in convexObjectList(value, label: 'rooms'))
      roomFromConvex(row),
  ];
}

Room? roomFromConvexOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return roomFromConvex(value);
}

Player playerFromConvex(Object? value) {
  final json = convexObject(value, label: 'player');
  return Player(
    id: convexId(json),
    roomId: convexOptionalId(json['roomId']) ?? '',
    userId: convexOptionalId(json['userId']),
    figurineId: convexInt(json['figurineId']),
    figurineName: convexString(json['figurineName'], label: 'figurineName'),
    positionX: convexDouble(json['positionX'], label: 'positionX'),
    positionY: convexDouble(json['positionY'], label: 'positionY'),
    hp: convexInt(json['hp']),
    inventory: _inventory(json['inventory']),
    joinedAt: convexDateTime(json['joinedAt'], label: 'joinedAt'),
    classId: convexOptionalString(json['classId']),
    stats: CharacterStats.fromJson(json),
    effects: PlayerEffect.listFromJson(json['effects']),
  );
}

List<Player> playersFromConvex(Object? value) {
  return [
    for (final row in convexObjectList(value, label: 'players'))
      playerFromConvex(row),
  ];
}

GameEvent gameEventFromConvex(Object? value) {
  final json = convexObject(value, label: 'gameEvent');
  return GameEvent(
    id: convexId(json),
    roomId: convexOptionalId(json['roomId']) ?? '',
    playerId: convexOptionalId(json['playerId']),
    type: GameEventType.fromJson(json['type']),
    content: convexString(json['content'], label: 'content'),
    createdAt: convexDateTime(json['createdAt'], label: 'createdAt'),
  );
}

List<GameEvent> gameEventsFromConvex(Object? value) {
  return [
    for (final row in convexObjectList(value, label: 'gameEvents'))
      gameEventFromConvex(row),
  ];
}

Enemy enemyFromConvex(Object? value) {
  final json = convexObject(value, label: 'enemy');
  return Enemy(
    id: convexId(json),
    roomId: convexOptionalId(json['roomId']) ?? '',
    name: convexString(json['name'], label: 'name'),
    enemyType: convexOptionalString(json['enemyType']) ?? 'enemy',
    positionX: convexDouble(json['positionX'], label: 'positionX'),
    positionY: convexDouble(json['positionY'], label: 'positionY'),
    hp: convexInt(json['hp']),
    maxHp: convexInt(json['maxHp'], fallback: 1),
    status: EnemyStatusJson.fromJson(json['status']),
    metadata: convexNestedMap(json['metadata']),
    createdAt: convexOptionalDateTime(json['createdAt']),
    updatedAt: convexOptionalDateTime(json['updatedAt']),
  );
}

List<Enemy> enemiesFromConvex(Object? value) {
  return [
    for (final row in convexObjectList(value, label: 'enemies'))
      enemyFromConvex(row),
  ];
}

CombatSession combatSessionFromConvex(Object? value) {
  final json = convexObjectOrNull(value);
  if (json == null) {
    return CombatSession.inactive();
  }
  final parsed = CombatSession.tryParse({
    'id': convexId(json),
    'room_id': convexOptionalId(json['roomId']),
    'active': json['active'],
    'round': json['round'],
  });
  return parsed ?? CombatSession.inactive();
}

PendingAbilityRoll pendingRollFromConvex(Object? value) {
  final json = convexObject(value, label: 'pendingRoll');
  final parsed = PendingAbilityRoll.tryParse({
    'id': convexId(json),
    'player_id': convexOptionalId(json['playerId']),
    'ability': json['ability'],
    'dc': json['dc'],
    'reason': json['reason'],
    'status': json['status'],
    'result': json['result'],
    'modifier': json['modifier'],
    'total': json['total'],
    'success': json['success'],
  });
  if (parsed == null) {
    throw const GameException('Invalid pending roll row.');
  }
  return parsed;
}

List<PendingAbilityRoll> pendingRollsFromConvex(Object? value) {
  return [
    for (final row in convexObjectList(value, label: 'pendingRolls'))
      pendingRollFromConvex(row),
  ];
}

UserEntitlement entitlementFromConvex(Object? value, {required String userId}) {
  final json = convexObject(value, label: 'entitlement');
  return UserEntitlement(
    userId: userId,
    level: GameAccessLevel.fromJson(json['accessLevel']),
    source: json['source']?.toString() ?? 'default',
  );
}

DemoSession? demoSessionFromConvex(Object? value, {required String userId}) {
  if (value == null) {
    return null;
  }
  final json = convexObject(value, label: 'demoSession');
  return DemoSession(
    userId: userId,
    roomId: convexOptionalId(json['roomId']),
    startedAt: convexOptionalDateTime(json['startedAt']),
    expiresAt: convexOptionalDateTime(json['expiresAt']),
    completedAt: convexOptionalDateTime(json['completedAt']),
    pausedAt: convexOptionalDateTime(json['pausedAt']),
  );
}

PurchaseOffer purchaseOfferFromConvex(Object? value) {
  final json = convexObject(value, label: 'offer');
  final amount = json['unitAmount'];
  if (amount is! num || amount < 0) {
    throw const GameException('Offre d achat invalide.');
  }
  final currency = json['currency']?.toString().trim() ?? '';
  if (currency.isEmpty) {
    throw const GameException('Offre d achat invalide.');
  }
  return PurchaseOffer(
    currency: currency.toLowerCase(),
    unitAmount: amount.round(),
  );
}

int? _avatarId(Object? value) {
  if (value is! num) {
    return null;
  }
  final id = value.toInt();
  if (id < 0 || id > 39) {
    return null;
  }
  return id;
}

List<InventoryItem> _inventory(Object? value) {
  if (value == null) {
    return const [];
  }
  if (value is! List) {
    throw const GameException('Inventory must be a JSON list');
  }
  return [
    for (final item in value)
      InventoryItem.fromJsonValue(
        item is Map ? Map<String, dynamic>.from(item) : item,
      ),
  ];
}
