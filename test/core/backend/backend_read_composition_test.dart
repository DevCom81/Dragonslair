import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:dragons_lair/core/convex/convex_gateway.dart';
import 'package:dragons_lair/core/supabase/supabase_client_provider.dart';
import 'package:dragons_lair/features/access/data/convex_entitlement_repository.dart';
import 'package:dragons_lair/features/access/domain/entitlement_repository.dart';
import 'package:dragons_lair/features/auth/data/convex_profile_repository.dart';
import 'package:dragons_lair/features/auth/domain/auth_access_token_source.dart';
import 'package:dragons_lair/features/auth/domain/profile_repository.dart';
import 'package:dragons_lair/features/combat/data/convex_combat_repository.dart';
import 'package:dragons_lair/features/combat/data/supabase_combat_repository.dart';
import 'package:dragons_lair/features/enemies/data/convex_enemy_repository.dart';
import 'package:dragons_lair/features/enemies/data/supabase_enemy_repository.dart';
import 'package:dragons_lair/features/events/data/convex_game_event_repository.dart';
import 'package:dragons_lair/features/events/data/supabase_game_event_repository.dart';
import 'package:dragons_lair/features/game/data/convex_gameplay_commands.dart';
import 'package:dragons_lair/features/game/data/convex_pending_roll_repository.dart';
import 'package:dragons_lair/features/game/data/legacy_gameplay_commands.dart';
import 'package:dragons_lair/features/game_master/data/convex_game_master_repository.dart';
import 'package:dragons_lair/features/game_master/data/mock_game_master_repository.dart';
import 'package:dragons_lair/features/game/data/supabase_pending_roll_repository.dart';
import 'package:dragons_lair/features/players/data/convex_player_repository.dart';
import 'package:dragons_lair/features/players/data/supabase_player_repository.dart';
import 'package:dragons_lair/features/rooms/data/convex_room_repository.dart';
import 'package:dragons_lair/features/rooms/data/supabase_room_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy composition selects Supabase game repositories', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.legacy),
        supabaseClientProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileRepositoryProvider),
      isA<SupabaseProfileRepository>(),
    );
    expect(container.read(roomRepositoryProvider), isA<SupabaseRoomRepository>());
    expect(
      container.read(playerRepositoryProvider),
      isA<SupabasePlayerRepository>(),
    );
    expect(
      container.read(gameEventRepositoryProvider),
      isA<SupabaseGameEventRepository>(),
    );
    expect(
      container.read(enemyRepositoryProvider),
      isA<SupabaseEnemyRepository>(),
    );
    expect(
      container.read(combatRepositoryProvider),
      isA<SupabaseCombatRepository>(),
    );
    expect(
      container.read(pendingRollRepositoryProvider),
      isA<SupabasePendingRollRepository>(),
    );
    expect(
      container.read(gameplayCommandsProvider),
      isA<LegacyGameplayCommands>(),
    );
    expect(
      container.read(entitlementRepositoryProvider),
      isA<SupabaseEntitlementRepository>(),
    );
    expect(
      container.read(gameMasterRepositoryProvider),
      isA<MockGameMasterRepository>(),
    );
  });

  test('convex composition selects Convex game repositories', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.convex),
        convexGatewayProvider.overrideWith((ref) => _FakeConvexGateway()),
        authAccessTokenSourceProvider.overrideWith((ref) => _FakeTokens()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(profileRepositoryProvider),
      isA<ConvexProfileRepository>(),
    );
    expect(container.read(roomRepositoryProvider), isA<ConvexRoomRepository>());
    expect(
      container.read(playerRepositoryProvider),
      isA<ConvexPlayerRepository>(),
    );
    expect(
      container.read(gameEventRepositoryProvider),
      isA<ConvexGameEventRepository>(),
    );
    expect(
      container.read(enemyRepositoryProvider),
      isA<ConvexEnemyRepository>(),
    );
    expect(
      container.read(combatRepositoryProvider),
      isA<ConvexCombatRepository>(),
    );
    expect(
      container.read(pendingRollRepositoryProvider),
      isA<ConvexPendingRollRepository>(),
    );
    expect(
      container.read(gameplayCommandsProvider),
      isA<ConvexGameplayCommands>(),
    );
    expect(
      container.read(entitlementRepositoryProvider),
      isA<ConvexEntitlementRepository>(),
    );
    expect(
      container.read(gameMasterRepositoryProvider),
      isA<ConvexGameMasterRepository>(),
    );
  });
}

class _FakeTokens implements AuthAccessTokenSource {
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'jwt';
}

class _FakeConvexGateway implements ConvexGateway {
  @override
  Future<void> clearAuth() async {}

  @override
  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return null;
  }

  @override
  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return null;
  }

  @override
  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return null;
  }

  @override
  Future<void> setAuthWithRefresh({
    required ConvexTokenFetcher fetchToken,
  }) async {}

  @override
  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    throw UnimplementedError();
  }
}
