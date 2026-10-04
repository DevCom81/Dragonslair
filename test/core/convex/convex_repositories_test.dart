import 'dart:async';

import 'package:dragons_lair/core/convex/convex_auth_binder.dart';
import 'package:dragons_lair/core/convex/convex_gateway.dart';
import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:dragons_lair/features/auth/data/convex_profile_repository.dart';
import 'package:dragons_lair/features/auth/domain/auth_access_token_source.dart';
import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:dragons_lair/features/combat/data/convex_combat_repository.dart';
import 'package:dragons_lair/features/enemies/data/convex_enemy_repository.dart';
import 'package:dragons_lair/features/events/data/convex_game_event_repository.dart';
import 'package:dragons_lair/features/game/data/convex_gameplay_commands.dart';
import 'package:dragons_lair/features/game/data/convex_pending_roll_repository.dart';
import 'package:dragons_lair/features/players/data/convex_player_repository.dart';
import 'package:dragons_lair/features/players/domain/player.dart';
import 'package:dragons_lair/features/rooms/data/convex_room_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGateway gateway;
  late _FakeTokens tokens;
  late ConvexAuthBinder binder;

  setUp(() {
    gateway = _FakeGateway();
    tokens = _FakeTokens();
    binder = ConvexAuthBinder(gateway: gateway, tokens: tokens);
  });

  test('JWT is read from AuthAccessTokenSource then ensureUser is reused',
      () async {
    tokens.token = 'jwt-workos';
    await binder.ensureAuthenticated();
    expect(gateway.mutates, ['users:ensureUser']);
    expect(binder.domainUserId, 'user_1');
    expect(gateway.fetchTokenCalls, isNotEmpty);
    final refreshed = await gateway.fetcher!(forceRefresh: true);
    expect(refreshed, 'jwt-workos');
    expect(tokens.forceRefreshCalls, 1);
  });

  test('logout without a token clears Convex auth', () async {
    tokens.token = 'jwt-workos';
    await binder.ensureAuthenticated();
    tokens.token = null;
    final ready = await binder.ensureAuthenticated();
    expect(ready, isFalse);
    expect(binder.domainUserId, isNull);
    expect(gateway.clearAuthCalls, greaterThanOrEqualTo(1));
    expect(binder.isBound, isFalse);
  });

  test('session change rebinds Convex auth', () async {
    tokens.token = 'jwt-1';
    await binder.ensureAuthenticated();
    await binder.sync(null);
    expect(binder.isBound, isFalse);
    tokens.token = 'jwt-2';
    await binder.ensureAuthenticated();
    expect(gateway.setAuthCalls, 2);
    expect(gateway.mutates, ['users:ensureUser', 'users:ensureUser']);
  });

  test('profile mapping goes through profiles:getMine', () async {
    tokens.token = 'jwt';
    gateway.queries['profiles:getMine'] = {
      '_id': 'profile_1',
      'displayName': 'Hero',
      'createdAt': 1,
      'sheetConfirmed': false,
      'strength': 10,
      'dexterity': 10,
      'constitution': 10,
      'intelligence': 10,
      'wisdom': 10,
      'charisma': 10,
    };
    final profile = await ConvexProfileRepository(
      gateway: gateway,
      binder: binder,
    ).fetchCurrent();
    expect(profile?.id, 'profile_1');
    expect(gateway.queryNames, ['profiles:getMine']);
  });

  test('waiting rooms use the server query without extra client filters',
      () async {
    tokens.token = 'jwt';
    gateway.queries['rooms:listWaiting'] = [
      _room('room_demo', scenarioId: 'demo'),
      _room('room_full', scenarioId: 'full'),
    ];
    final rooms = await ConvexRoomRepository(
      gateway: gateway,
      binder: binder,
    ).fetchWaitingRooms();
    expect(rooms.map((room) => room.id), ['room_demo', 'room_full']);
  });

  test('continuable rooms use the server query as-is', () async {
    tokens.token = 'jwt';
    gateway.queries['rooms:listMineContinuable'] = [
      _room('room_play', status: 'playing'),
    ];
    final rooms = await ConvexRoomRepository(
      gateway: gateway,
      binder: binder,
    ).watchMyContinuableRooms().first;
    expect(rooms.single.id, 'room_play');
    expect(gateway.subscribeNames, ['rooms:listMineContinuable']);
  });

  test('players of room A never receive room B', () async {
    tokens.token = 'jwt';
    final repository = ConvexPlayerRepository(
      gateway: gateway,
      binder: binder,
    );
    final received = <String>[];
    final sub = repository.watchRoomPlayers('room_a').listen((players) {
      received.addAll(players.map((player) => player.roomId));
    });
    await pumpEventQueue();
    final watch = gateway.watchFor('players:listByRoom', 'room_a');
    watch.controller.add([
      _player('p1', 'room_a'),
    ]);
    await pumpEventQueue();
    expect(received, ['room_a']);
    expect(gateway.subscribedRoomIds, ['room_a']);
    await sub.cancel();
  });

  test('events stay room-scoped and ordered', () async {
    tokens.token = 'jwt';
    final repository = ConvexGameEventRepository(
      gateway: gateway,
      binder: binder,
    );
    final contents = <String>[];
    final sub = repository.watchRoomEvents('room_a').listen((events) {
      contents
        ..clear()
        ..addAll(events.map((event) => event.content));
    });
    await pumpEventQueue();
    gateway.watchFor('gameEvents:listByRoom', 'room_a').controller.add([
      _event('e1', 'room_a', 'first', 1),
      _event('e2', 'room_a', 'second', 2),
    ]);
    await pumpEventQueue();
    expect(contents, ['first', 'second']);
    await sub.cancel();
  });

  test('enemies stay room-scoped', () async {
    tokens.token = 'jwt';
    gateway.queries['enemies:listByRoom'] = [_enemy('room_a')];
    final enemies = await ConvexEnemyRepository(
      gateway: gateway,
      binder: binder,
    ).fetchRoomEnemies('room_a');
    expect(enemies.single.roomId, 'room_a');
    expect(gateway.queryArgs.last['roomId'], 'room_a');
  });

  test('pending rolls stay room-scoped', () async {
    tokens.token = 'jwt';
    gateway.queries['pendingRolls:listByRoom'] = [_roll('room_a')];
    final rolls = await ConvexPendingRollRepository(
      gateway: gateway,
      binder: binder,
    ).fetchRoomRolls('room_a');
    expect(rolls.single.playerId, 'player_1');
    expect(gateway.queryArgs.last['roomId'], 'room_a');
  });

  test('combat fetch maps null to inactive', () async {
    tokens.token = 'jwt';
    gateway.queries['combatSessions:getForRoom'] = null;
    final combat = await ConvexCombatRepository(
      gateway: gateway,
      binder: binder,
    ).fetchRoomCombat('room_a');
    expect(combat.active, isFalse);
  });

  test('dispose cancels the Convex subscription', () async {
    tokens.token = 'jwt';
    final repository = ConvexPlayerRepository(
      gateway: gateway,
      binder: binder,
    );
    final sub = repository.watchRoomPlayers('room_a').listen((_) {});
    await pumpEventQueue();
    final watch = gateway.watchFor('players:listByRoom', 'room_a');
    expect(watch.cancelled, isFalse);
    await sub.cancel();
    await pumpEventQueue();
    expect(watch.cancelled, isTrue);
  });

  test('changing roomId cancels the previous subscription', () async {
    tokens.token = 'jwt';
    final repository = ConvexPlayerRepository(
      gateway: gateway,
      binder: binder,
    );
    final first = repository.watchRoomPlayers('room_a').listen((_) {});
    await pumpEventQueue();
    final watchA = gateway.watchFor('players:listByRoom', 'room_a');
    await first.cancel();
    final second = repository.watchRoomPlayers('room_b').listen((_) {});
    await pumpEventQueue();
    expect(watchA.cancelled, isTrue);
    expect(gateway.subscribedRoomIds, ['room_a', 'room_b']);
    await second.cancel();
  });

  test('convex mutations omit identity authority and map contracts', () async {
    tokens.token = 'jwt';
    gateway.mutateResults['rooms:create'] = _room('room_new');
    gateway.mutateResults['players:join'] = _player('p1', 'room_new');
    gateway.mutateResults['profiles:upsertDisplayName'] = {
      '_id': 'profile_1',
      'displayName': 'Hero',
      'createdAt': 1,
      'sheetConfirmed': false,
      'strength': 10,
      'dexterity': 10,
      'constitution': 10,
      'intelligence': 10,
      'wisdom': 10,
      'charisma': 10,
    };
    gateway.mutateResults['profiles:upsertSheet'] =
        gateway.mutateResults['profiles:upsertDisplayName'];
    gateway.mutateResults['profiles:upsertAvatar'] =
        gateway.mutateResults['profiles:upsertDisplayName'];
    final rooms = ConvexRoomRepository(gateway: gateway, binder: binder);
    final players = ConvexPlayerRepository(gateway: gateway, binder: binder);
    final profiles = ConvexProfileRepository(gateway: gateway, binder: binder);

    await profiles.upsertDisplayName(
      userId: 'workos-or-domain',
      displayName: 'Hero',
    );
    expect(gateway.mutates.last, 'profiles:upsertDisplayName');
    expect(gateway.mutateArgs.last.containsKey('userId'), isFalse);
    expect(gateway.mutateArgs.last['displayName'], 'Hero');
    await profiles.upsertSheet(
      userId: 'ignored',
      displayName: 'Hero',
      stats: CharacterStats.defaults,
      classId: 'fighter',
    );
    expect(gateway.mutates.last, 'profiles:upsertSheet');
    expect(gateway.mutateArgs.last.containsKey('userId'), isFalse);
    await profiles.upsertAvatar(userId: 'ignored', figurineId: 2);
    expect(gateway.mutates.last, 'profiles:upsertAvatar');
    expect(gateway.mutateArgs.last, {'figurineId': 2});

    final created = await rooms.createRoom(
      name: 'Tavern',
      hostId: 'should-not-be-sent',
      scenarioId: 'custom',
      scenarioName: 'Aventure',
      minPlayers: 1,
      requiredClassIds: const [],
    );
    expect(created.id, 'room_new');
    expect(gateway.mutates.last, 'rooms:create');
    expect(gateway.mutateArgs.last.containsKey('hostId'), isFalse);
    expect(gateway.mutateArgs.last.containsKey('userId'), isFalse);

    await players.joinRoom(
      roomId: 'room_new',
      userId: 'should-not-be-sent',
      figurineId: 3,
      figurineName: 'ignored',
      classId: 'fighter',
      stats: CharacterStats.defaults,
    );
    expect(gateway.mutates.last, 'players:join');
    expect(gateway.mutateArgs.last, {
      'roomId': 'room_new',
      'figurineId': 3,
    });

    await rooms.startRoom('room_new');
    await rooms.pauseRoom('room_new');
    await rooms.resumeRoom('room_new');
    await rooms.finishRoom(roomId: 'room_new', result: 'VICTORY', summary: 'nope');
    expect(gateway.mutates.sublist(gateway.mutates.length - 4), [
      'rooms:start',
      'rooms:pause',
      'rooms:resume',
      'rooms:finish',
    ]);
    expect(gateway.mutateArgs.last, {
      'roomId': 'room_new',
      'result': 'victory',
    });

    await players.updatePosition(
      playerId: 'other-player',
      roomId: 'room_new',
      x: 0.2,
      y: 0.8,
    );
    expect(gateway.mutates.last, 'players:updatePosition');
    expect(gateway.mutateArgs.last, {
      'roomId': 'room_new',
      'x': 0.2,
      'y': 0.8,
    });
    expect(gateway.mutateArgs.last.containsKey('playerId'), isFalse);
  });

  test('gameplay commands use one Convex mutation and no generic events', () async {
    tokens.token = 'jwt';
    await binder.ensureAuthenticated();
    gateway.mutates.clear();
    gateway.mutateArgs.clear();
    final commands = ConvexGameplayCommands(gateway: gateway, binder: binder);
    final player = Player.fromJson({
      'id': 'p1',
      'room_id': 'room_a',
      'user_id': 'user',
      'figurine_id': 1,
      'figurine_name': 'Aldric',
      'position_x': 0.5,
      'position_y': 0.5,
      'hp': 80,
      'inventory': [
        {
          'id': 'potion',
          'name': 'Potion',
          'description': '',
          'quantity': 1,
          'type': 'potion',
          'heal': 20,
        },
        {
          'id': 'scroll',
          'name': 'Parchemin',
          'description': '',
          'quantity': 1,
          'type': 'scroll',
          'effect': {'id': 'bless', 'name': 'Bless', 'kind': 'buff'},
        },
      ],
      'joined_at': DateTime.utc(2026, 1, 1).toIso8601String(),
      'effects': <dynamic>[],
      'strength': 10,
      'dexterity': 10,
      'constitution': 10,
      'intelligence': 10,
      'wisdom': 10,
      'charisma': 10,
    });

    await commands.pauseRoom(roomId: 'room_a', pausedContent: 'ignored');
    await commands.setItemEquipped(
      roomId: 'room_a',
      player: player,
      itemId: 'sword',
      equipped: true,
      systemContent: 'ignored event',
    );
    await commands.usePotion(roomId: 'room_a', player: player, item: player.inventory.first);
    await commands.useGrantedScroll(
      roomId: 'room_a',
      player: player,
      item: player.inventory.last,
    );
    await commands.submitAction(
      roomId: 'room_a',
      player: player,
      content: 'ouvre la porte',
    );
    await commands.announceDice(
      roomId: 'room_a',
      player: player,
      sides: 20,
      raw: 17,
    );
    await commands.resolveServerRoll(pendingRollId: 'roll_1', raw: 12);

    expect(gateway.mutates, [
      'rooms:pause',
      'players:setItemEquipped',
      'players:usePotion',
      'players:useScroll',
      'players:submitAction',
      'players:announceDice',
    ]);
    expect(gateway.actions, ['gameMaster:resolveRoll']);
    expect(gateway.actionArgs.single, {
      'pendingRollId': 'roll_1',
      'raw': 12,
    });
    expect(gateway.mutates, isNot(contains('rolls:resolve')));
    expect(gateway.mutateArgs[0], {'roomId': 'room_a'});
    expect(gateway.mutateArgs[1], {
      'roomId': 'room_a',
      'itemId': 'sword',
      'equipped': true,
    });
    expect(gateway.mutateArgs[2], {'roomId': 'room_a', 'itemId': 'potion'});
    expect(gateway.mutateArgs[3], {'roomId': 'room_a', 'itemId': 'scroll'});
    expect(gateway.mutateArgs[4], {
      'roomId': 'room_a',
      'content': 'ouvre la porte',
    });
    expect(gateway.mutateArgs[5], {
      'roomId': 'room_a',
      'sides': 20,
      'raw': 17,
    });
    for (final args in [...gateway.mutateArgs, ...gateway.actionArgs]) {
      expect(args.containsKey('userId'), isFalse);
      expect(args.containsKey('hostId'), isFalse);
      expect(args.containsKey('currentDomainUserId'), isFalse);
    }

    final events = ConvexGameEventRepository(gateway: gateway, binder: binder);
    await expectLater(
      () => events.createAction(roomId: 'r', playerId: 'p', content: 'go'),
      throwsA(isA<UnsupportedConvexWriteException>()),
    );
    await expectLater(
      () => events.createNarration(roomId: 'r', content: 'story'),
      throwsA(isA<UnsupportedConvexWriteException>()),
    );
    await expectLater(
      () => events.createSystem(roomId: 'r', content: 'sys'),
      throwsA(isA<UnsupportedConvexWriteException>()),
    );
    await expectLater(
      () => ConvexPlayerRepository(gateway: gateway, binder: binder).patchOwnPlayer(
        playerId: 'p1',
        hp: 1,
      ),
      throwsA(isA<UnsupportedConvexWriteException>()),
    );
    expect(gateway.mutates, isNot(contains('gameEvents:create')));
  });

  test('convex errors map to domain exceptions', () async {
    tokens.token = 'jwt';
    await binder.ensureAuthenticated();
    gateway.failMutateWith = Exception('ForbiddenError: Host only');
    final rooms = ConvexRoomRepository(gateway: gateway, binder: binder);
    await expectLater(
      () => rooms.finishRoom(roomId: 'room_a'),
      throwsA(
        isA<GameException>().having(
          (error) => error.message,
          'message',
          'Action non autorisee.',
        ),
      ),
    );
  });
}

Map<String, Object?> _room(
  String id, {
  String status = 'waiting',
  String? scenarioId,
}) {
  return {
    '_id': id,
    'name': id,
    'status': status,
    'createdAt': 1,
    'hostUserId': 'host',
    'joinCode': 'ABC123',
    'minPlayers': 1,
    'requiredClassIds': <String>[],
    'scenarioPrompt': '',
    'worldState': <String, dynamic>{},
    'locale': 'en',
    'musicMood': 'exploration',
    if (scenarioId != null) 'scenarioId': scenarioId,
  };
}

Map<String, Object?> _player(String id, String roomId) {
  return {
    '_id': id,
    'roomId': roomId,
    'userId': 'user',
    'figurineId': 1,
    'figurineName': 'N',
    'positionX': 0.5,
    'positionY': 0.5,
    'hp': 100,
    'inventory': <dynamic>[],
    'joinedAt': 1,
    'effects': <dynamic>[],
    'strength': 10,
    'dexterity': 10,
    'constitution': 10,
    'intelligence': 10,
    'wisdom': 10,
    'charisma': 10,
  };
}

Map<String, Object?> _event(
  String id,
  String roomId,
  String content,
  int createdAt,
) {
  return {
    '_id': id,
    'roomId': roomId,
    'type': 'system',
    'content': content,
    'createdAt': createdAt,
  };
}

Map<String, Object?> _enemy(String roomId) {
  return {
    '_id': 'en1',
    'roomId': roomId,
    'name': 'Goblin',
    'enemyType': 'goblin',
    'positionX': 0.1,
    'positionY': 0.2,
    'hp': 5,
    'maxHp': 5,
    'status': 'active',
    'metadata': <String, dynamic>{},
    'createdAt': 1,
    'updatedAt': 1,
  };
}

Map<String, Object?> _roll(String roomId) {
  return {
    '_id': 'roll_1',
    'roomId': roomId,
    'playerId': 'player_1',
    'ability': 'strength',
    'dc': 10,
    'reason': 'lock',
    'status': 'pending',
    'createdAt': 1,
  };
}

class _FakeTokens implements AuthAccessTokenSource {
  String? token = 'jwt';
  var forceRefreshCalls = 0;

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    if (forceRefresh) {
      forceRefreshCalls += 1;
    }
    return token;
  }
}

class _FakeWatch implements ConvexWatch {
  final controller = StreamController<Object?>.broadcast();
  var cancelled = false;

  @override
  Stream<Object?> get snapshots => controller.stream;

  @override
  void cancel() {
    cancelled = true;
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

class _FakeGateway implements ConvexGateway {
  ConvexTokenFetcher? fetcher;
  var setAuthCalls = 0;
  var clearAuthCalls = 0;
  final mutates = <String>[];
  final mutateArgs = <Map<String, Object?>>[];
  final mutateResults = <String, Object?>{};
  Object? failMutateWith;
  final actions = <String>[];
  final actionArgs = <Map<String, Object?>>[];
  final actionResults = <String, Object?>{};
  Object? failActionWith;
  final queryNames = <String>[];
  final queryArgs = <Map<String, Object?>>[];
  final queries = <String, Object?>{};
  final subscribeNames = <String>[];
  final subscribedRoomIds = <String>[];
  final watches = <_FakeWatch>[];
  final watchByKey = <String, _FakeWatch>{};

  @override
  Future<void> setAuthWithRefresh({
    required ConvexTokenFetcher fetchToken,
  }) async {
    setAuthCalls += 1;
    fetcher = fetchToken;
    fetchTokenCalls.add(true);
  }

  final fetchTokenCalls = <bool>[];

  @override
  Future<void> clearAuth() async {
    clearAuthCalls += 1;
    fetcher = null;
  }

  @override
  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    queryNames.add(name);
    queryArgs.add(args);
    return queries[name];
  }

  @override
  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    mutates.add(name);
    mutateArgs.add(Map<String, Object?>.from(args));
    final failure = failMutateWith;
    if (failure != null) {
      throw failure;
    }
    return mutateResults[name] ?? {'_id': 'user_1'};
  }

  @override
  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    actions.add(name);
    actionArgs.add(Map<String, Object?>.from(args));
    final failure = failActionWith;
    if (failure != null) {
      throw failure;
    }
    return actionResults[name] ??
        {
          'narration': 'ok',
          'actions': <Object?>[],
          'choices': <Object?>[],
        };
  }

  @override
  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    subscribeNames.add(name);
    final roomId = args['roomId']?.toString();
    if (roomId != null) {
      subscribedRoomIds.add(roomId);
    }
    final watch = _FakeWatch();
    watches.add(watch);
    watchByKey['$name:${roomId ?? ''}'] = watch;
    final initial = queries[name];
    if (initial != null) {
      scheduleMicrotask(() {
        if (!watch.cancelled) {
          watch.controller.add(initial);
        }
      });
    }
    return watch;
  }

  _FakeWatch watchFor(String name, String roomId) {
    return watchByKey['$name:$roomId']!;
  }
}

Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);
