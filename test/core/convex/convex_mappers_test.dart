import 'package:dragons_lair/core/convex/convex_mappers.dart';
import 'package:dragons_lair/features/combat/domain/combat_session.dart';
import 'package:dragons_lair/features/events/domain/game_event.dart';
import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile mapping uses Convex document id and camelCase fields', () {
    final profile = profileFromConvex({
      '_id': 'profile_1',
      'userId': 'user_1',
      'displayName': 'Hero',
      'createdAt': 1_700_000_000_000,
      'sheetConfirmed': true,
      'classId': 'fighter',
      'avatarFigurineId': 3,
      'strength': 12,
      'dexterity': 10,
      'constitution': 11,
      'intelligence': 9,
      'wisdom': 8,
      'charisma': 13,
    });
    expect(profile.id, 'profile_1');
    expect(profile.displayName, 'Hero');
    expect(profile.classId, 'fighter');
    expect(profile.stats.strength, 12);
  });

  test('profile mapping treats unset classId as absent', () {
    final profile = profileFromConvex({
      '_id': 'profile_1',
      'displayName': 'Hero',
      'createdAt': 1_700_000_000_000,
      'sheetConfirmed': true,
      'classId': 'unset',
      'strength': 12,
      'dexterity': 10,
      'constitution': 11,
      'intelligence': 9,
      'wisdom': 8,
      'charisma': 13,
    });
    expect(profile.classId, isNull);
    expect(profile.isReadyToPlay, isFalse);
    expect(profile.stats.strength, 12);
  });

  test('profile mapping ignores non-numeric stats instead of throwing', () {
    final profile = profileFromConvex({
      '_id': 'profile_1',
      'displayName': 'Hero',
      'createdAt': 1_700_000_000_000,
      'sheetConfirmed': false,
      'strength': Object(),
      'dexterity': 10,
      'constitution': 11,
      'intelligence': 9,
      'wisdom': 8,
      'charisma': 13,
    });
    expect(profile.stats.strength, 10);
  });

  test('waiting and continuable rooms keep server order and ids', () {
    final rooms = roomsFromConvex([
      {
        '_id': 'room_a',
        'name': 'A',
        'status': 'waiting',
        'createdAt': 1,
        'hostUserId': 'user_host',
        'joinCode': 'ABC123',
        'minPlayers': 1,
        'requiredClassIds': <String>[],
        'scenarioPrompt': '',
        'worldState': <String, dynamic>{},
        'locale': 'fr',
        'musicMood': 'exploration',
        'scenarioId': 'demo',
      },
      {
        '_id': 'room_b',
        'name': 'B',
        'status': 'playing',
        'createdAt': 2,
        'hostUserId': 'user_host',
        'joinCode': 'DEF456',
        'minPlayers': 2,
        'requiredClassIds': ['fighter'],
        'scenarioPrompt': '',
        'worldState': <String, dynamic>{},
        'locale': 'en',
        'musicMood': 'tavern',
      },
    ]);
    expect(rooms.map((room) => room.id), ['room_a', 'room_b']);
    expect(rooms.first.hostId, 'user_host');
    expect(rooms.first.status, RoomStatus.waiting);
    expect(rooms.last.status, RoomStatus.playing);
  });

  test('room mapping uses Convex _id', () {
    final room = roomFromConvex({
      '_id': 'room_1',
      'name': 'Cave',
      'status': 'paused',
      'createdAt': 10,
      'hostUserId': 'host_1',
      'joinCode': 'XYZ789',
      'minPlayers': 1,
      'requiredClassIds': <String>[],
      'scenarioPrompt': '',
      'worldState': <String, dynamic>{},
      'locale': 'en',
      'musicMood': 'mystery',
    });
    expect(room.id, 'room_1');
    expect(room.status, RoomStatus.paused);
  });

  test('players mapping is room-scoped by document fields', () {
    final players = playersFromConvex([
      {
        '_id': 'player_1',
        'roomId': 'room_a',
        'userId': 'user_a',
        'figurineId': 1,
        'figurineName': 'A',
        'positionX': 0.2,
        'positionY': 0.3,
        'hp': 90,
        'inventory': <dynamic>[],
        'joinedAt': 1,
        'effects': <dynamic>[],
        'strength': 10,
        'dexterity': 10,
        'constitution': 10,
        'intelligence': 10,
        'wisdom': 10,
        'charisma': 10,
      },
    ]);
    expect(players.single.roomId, 'room_a');
    expect(players.single.userId, 'user_a');
  });

  test('events keep Convex list order', () {
    final events = gameEventsFromConvex([
      {
        '_id': 'e1',
        'roomId': 'room_a',
        'type': 'narration',
        'content': 'first',
        'createdAt': 1,
      },
      {
        '_id': 'e2',
        'roomId': 'room_a',
        'type': 'action',
        'content': 'second',
        'createdAt': 2,
        'playerId': 'player_1',
      },
    ]);
    expect(events.map((event) => event.content), ['first', 'second']);
    expect(events.last.type, GameEventType.action);
  });

  test('enemies mapping is room-scoped', () {
    final enemies = enemiesFromConvex([
      {
        '_id': 'en1',
        'roomId': 'room_a',
        'name': 'Goblin',
        'enemyType': 'goblin',
        'positionX': 0.4,
        'positionY': 0.5,
        'hp': 8,
        'maxHp': 10,
        'status': 'active',
        'metadata': <String, dynamic>{},
        'createdAt': 1,
        'updatedAt': 1,
      },
    ]);
    expect(enemies.single.roomId, 'room_a');
    expect(enemies.single.maxHp, 10);
  });

  test('combat null maps to inactive session', () {
    expect(combatSessionFromConvex(null).active, isFalse);
    expect(combatSessionFromConvex(null).round, 0);
  });

  test('combat document maps cardinality of one session', () {
    final combat = combatSessionFromConvex({
      '_id': 'c1',
      'roomId': 'room_a',
      'active': true,
      'round': 4,
    });
    expect(combat.id, 'c1');
    expect(combat.roomId, 'room_a');
    expect(combat.active, isTrue);
    expect(combat.round, 4);
    expect(combat, isA<CombatSession>());
  });

  test('pending rolls mapping is room player scoped', () {
    final rolls = pendingRollsFromConvex([
      {
        '_id': 'roll_1',
        'roomId': 'room_a',
        'playerId': 'player_1',
        'ability': 'strength',
        'dc': 12,
        'reason': 'door',
        'status': 'pending',
        'createdAt': 1,
      },
    ]);
    expect(rolls.single.playerId, 'player_1');
    expect(rolls.single.dc, 12);
    expect(rolls.single.isOpen, isTrue);
  });
}
