import 'dart:async';
import 'dart:io';

import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:dragons_lair/core/convex/convex_auth_binder.dart';
import 'package:dragons_lair/core/convex/convex_gateway.dart';
import 'package:dragons_lair/features/auth/domain/auth_access_token_source.dart';
import 'package:dragons_lair/features/auth/domain/auth_repository.dart';
import 'package:dragons_lair/features/auth/domain/auth_user.dart';
import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:dragons_lair/features/auth/domain/current_domain_user.dart';
import 'package:dragons_lair/features/auth/presentation/current_domain_user.dart';
import 'package:dragons_lair/features/players/domain/player.dart';
import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const authUser = AuthUser(id: 'user_workos_xxx', isAnonymous: false);
  const convexUserId = 'jd7convexuser';

  test('legacy currentDomainUserId equals AuthUser.id', () {
    expect(
      resolveCurrentDomainUserId(
        mode: BackendMode.legacy,
        authUser: authUser,
        convexDomainUserId: convexUserId,
      ),
      authUser.id,
    );
  });

  test('convex currentDomainUserId equals users._id from ensureUser', () {
    expect(
      resolveCurrentDomainUserId(
        mode: BackendMode.convex,
        authUser: authUser,
        convexDomainUserId: convexUserId,
      ),
      convexUserId,
    );
    expect(convexUserId, isNot(authUser.id));
  });

  test('host detection uses domain id, not WorkOS subject', () {
    final room = Room(
      id: 'room_1',
      name: 'Cave',
      status: RoomStatus.waiting,
      createdAt: DateTime.utc(2024),
      hostId: convexUserId,
      minPlayers: 1,
      requiredClassIds: const [],
    );
    final domainId = resolveCurrentDomainUserId(
      mode: BackendMode.convex,
      authUser: authUser,
      convexDomainUserId: convexUserId,
    );
    expect(isCurrentDomainUser(domainId, room.hostId), isTrue);
    expect(authUser.id == room.hostId, isFalse);
  });

  test('player ownership uses domain id, not WorkOS subject', () {
    final player = Player(
      id: 'player_1',
      roomId: 'room_1',
      userId: convexUserId,
      figurineId: 1,
      figurineName: 'Hero',
      positionX: 0.5,
      positionY: 0.5,
      hp: 100,
      inventory: const [],
      joinedAt: DateTime.utc(2024),
      stats: CharacterStats.defaults,
    );
    final domainId = resolveCurrentDomainUserId(
      mode: BackendMode.convex,
      authUser: authUser,
      convexDomainUserId: convexUserId,
    );
    expect(isCurrentDomainUser(domainId, player.userId), isTrue);
    expect(player.userId == authUser.id, isFalse);
  });

  test('logout clears the runtime Convex domain user id', () async {
    final tokens = _FakeTokens()..token = 'jwt';
    final gateway = _FakeGateway();
    final binder = ConvexAuthBinder(gateway: gateway, tokens: tokens);
    await binder.ensureAuthenticated(authSubject: authUser.id);
    expect(binder.domainUserId, convexUserId);
    tokens.token = null;
    await binder.ensureAuthenticated();
    expect(binder.domainUserId, isNull);
  });

  test('account change replaces the Convex domain user id', () async {
    final tokens = _FakeTokens()..token = 'jwt';
    final gateway = _FakeGateway()..nextUserId = 'user_a_doc';
    final binder = ConvexAuthBinder(gateway: gateway, tokens: tokens);
    await binder.ensureAuthenticated(authSubject: 'user_a');
    expect(binder.domainUserId, 'user_a_doc');
    gateway.nextUserId = 'user_b_doc';
    await binder.ensureAuthenticated(authSubject: 'user_b');
    expect(binder.domainUserId, 'user_b_doc');
  });

  test('legacy provider exposes AuthUser.id', () async {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.legacy),
        authRepositoryProvider.overrideWith(
          (ref) => _FakeAuthRepository(user: authUser),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(currentDomainUserIdProvider.future),
      authUser.id,
    );
  });

  test('convex provider exposes ensureUser _id', () async {
    final gateway = _FakeGateway();
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.convex),
        authRepositoryProvider.overrideWith(
          (ref) => _FakeAuthRepository(user: authUser),
        ),
        convexGatewayProvider.overrideWith((ref) => gateway),
        authAccessTokenSourceProvider.overrideWith((ref) => _FakeTokens()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(currentDomainUserIdProvider.future),
      convexUserId,
    );
    expect(gateway.mutates, ['users:ensureUser']);
  });

  test('JWT refresh with the same subject does not recreate domain identity',
      () async {
    final tokens = _FakeTokens()..token = 'jwt';
    final gateway = _FakeGateway();
    final binder = ConvexAuthBinder(gateway: gateway, tokens: tokens);
    await binder.ensureAuthenticated(authSubject: authUser.id);
    await binder.ensureAuthenticated(authSubject: authUser.id);
    expect(gateway.mutates, ['users:ensureUser']);
    expect(binder.domainUserId, convexUserId);
  });

  test('legacy host and player comparisons still match AuthUser.id', () {
    final room = Room(
      id: 'room_1',
      name: 'Cave',
      status: RoomStatus.waiting,
      createdAt: DateTime.utc(2024),
      hostId: authUser.id,
      minPlayers: 1,
      requiredClassIds: const [],
    );
    final player = Player(
      id: 'player_1',
      roomId: 'room_1',
      userId: authUser.id,
      figurineId: 1,
      figurineName: 'Hero',
      positionX: 0.5,
      positionY: 0.5,
      hp: 100,
      inventory: const [],
      joinedAt: DateTime.utc(2024),
      stats: CharacterStats.defaults,
    );
    final domainId = resolveCurrentDomainUserId(
      mode: BackendMode.legacy,
      authUser: authUser,
      convexDomainUserId: null,
    );
    expect(isCurrentDomainUser(domainId, room.hostId), isTrue);
    expect(isCurrentDomainUser(domainId, player.userId), isTrue);
  });

  test('corrected widgets do not branch on BACKEND_MODE', () {
    const files = [
      'lib/features/lobby/presentation/lobby_screen.dart',
      'lib/features/board/presentation/board_screen.dart',
      'lib/features/board/presentation/game_board.dart',
      'lib/features/rooms/presentation/room_navigation.dart',
      'lib/features/figurines/presentation/figurine_selection_screen.dart',
      'lib/features/events/presentation/game_journal.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('BACKEND_MODE'), isFalse, reason: path);
      expect(source.contains('BackendMode'), isFalse, reason: path);
      expect(source.contains('SharedPreferences'), isFalse, reason: path);
    }
  });

  test('join mutation still receives AuthUser.id, not Convex users._id', () {
    final source = File(
      'lib/features/figurines/presentation/figurine_selection_screen.dart',
    ).readAsStringSync();
    expect(source.contains('userId: domainUserId'), isFalse);
    expect(source.contains('userId: userId'), isTrue);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.user});

  AuthUser? user;
  final _changes = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<AuthUser?> restoreSession() async => user;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    return user!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    return user!;
  }

  @override
  Future<AuthUser> signInAnonymously() async => user!;

  @override
  Future<AuthUser> verifyEmailCode({required String code}) async => user!;

  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  bool get supportsAnonymousSignIn => true;

  @override
  bool get supportsPasswordReset => false;

  @override
  Future<void> signOut() async {
    user = null;
  }
}

class _FakeTokens implements AuthAccessTokenSource {
  String? token = 'jwt';

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => token;
}

class _FakeGateway implements ConvexGateway {
  String nextUserId = 'jd7convexuser';
  final mutates = <String>[];

  @override
  Future<void> setAuthWithRefresh({
    required ConvexTokenFetcher fetchToken,
  }) async {}

  @override
  Future<void> clearAuth() async {}

  @override
  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return null;
  }

  @override
  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    mutates.add(name);
    return {'_id': nextUserId, 'workosSubject': 'user_workos_xxx'};
  }

  @override
  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return null;
  }

  @override
  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    throw UnimplementedError();
  }
}
