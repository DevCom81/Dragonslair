import 'dart:async';

import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../features/access/data/convex_entitlement_repository.dart';
import '../../features/access/domain/entitlement_repository.dart';
import '../../features/auth/data/auth0_auth_repository.dart';
import '../../features/auth/data/convex_profile_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/auth_access_token_source.dart';
import '../../features/auth/domain/auth_capabilities.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/auth/domain/profile_repository.dart';
import '../../features/combat/data/convex_combat_repository.dart';
import '../../features/downloads/data/convex_windows_download_client.dart';
import '../../features/downloads/data/legacy_windows_download_client.dart';
import '../../features/downloads/domain/windows_download_client.dart';
import '../../features/combat/data/supabase_combat_repository.dart';
import '../../features/combat/domain/combat_repository.dart';
import '../../features/enemies/data/convex_enemy_repository.dart';
import '../../features/enemies/data/supabase_enemy_repository.dart';
import '../../features/enemies/domain/enemy_repository.dart';
import '../../features/events/data/convex_game_event_repository.dart';
import '../../features/events/data/supabase_game_event_repository.dart';
import '../../features/events/domain/game_event_repository.dart';
import '../../features/game/data/convex_gameplay_commands.dart';
import '../../features/game_master/data/convex_game_master_repository.dart';
import '../../features/game_master/data/mock_game_master_repository.dart';
import '../../features/game_master/data/remote_game_master_repository.dart';
import '../../features/game_master/domain/game_master_repository.dart';
import '../../features/game/data/convex_pending_roll_repository.dart';
import '../../features/game/data/legacy_gameplay_commands.dart';
import '../../features/game/data/supabase_pending_roll_repository.dart';
import '../../features/game/domain/gameplay_commands.dart';
import '../../features/game/domain/pending_roll_repository.dart';
import '../../features/players/data/convex_player_repository.dart';
import '../../features/players/data/supabase_player_repository.dart';
import '../../features/players/domain/player_repository.dart';
import '../../features/rooms/data/convex_room_repository.dart';
import '../../features/scenarios/data/convex_scenario_generator.dart';
import '../../features/scenarios/data/remote_scenario_generator.dart';
import '../../features/scenarios/domain/scenario_generator.dart';
import '../../features/rooms/data/supabase_room_repository.dart';
import '../../features/rooms/domain/room_repository.dart';
import '../config/app_config.dart';
import '../convex/convex_auth_binder.dart';
import '../convex/convex_client_provider.dart';
import '../convex/convex_gateway.dart';
import '../convex/dartvex_convex_gateway.dart';
import '../errors/app_exception.dart';
import '../supabase/supabase_client_provider.dart';
import 'backend_mode.dart';

final backendModeProvider = Provider<BackendMode>((ref) {
  return AppConfig.backendMode;
});

final auth0WebProvider = Provider<Auth0Web>((ref) {
  return Auth0Web(
    AppConfig.auth0Domain,
    AppConfig.auth0ClientId,
    cacheLocation: CacheLocation.localStorage,
  );
});

AuthRepository createAuthRepository({
  required BackendMode mode,
  required SupabaseClient? client,
  Auth0Web? auth0,
}) {
  switch (mode) {
    case BackendMode.legacy:
      return SupabaseAuthRepository(client);
    case BackendMode.convex:
      return Auth0AuthRepository(
        auth0: auth0 ??
            Auth0Web(
              AppConfig.auth0Domain,
              AppConfig.auth0ClientId,
              cacheLocation: CacheLocation.localStorage,
            ),
      );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      return Auth0AuthRepository(auth0: ref.watch(auth0WebProvider));
  }
});

final authAccessTokenSourceProvider = Provider<AuthAccessTokenSource?>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return null;
    case BackendMode.convex:
      final repository = ref.watch(authRepositoryProvider);
      if (repository is Auth0AuthRepository) {
        return repository;
      }
      return null;
  }
});

final authCapabilitiesProvider = Provider<AuthCapabilities>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return AuthCapabilities(
        isConfigured: AppConfig.isSupabaseConfigured,
        supportsAnonymousSignIn: true,
      );
    case BackendMode.convex:
      return AuthCapabilities(
        isConfigured: AppConfig.isIdentityConfigured,
        supportsAnonymousSignIn: false,
      );
  }
});

final convexGatewayProvider = Provider<ConvexGateway?>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return null;
    case BackendMode.convex:
      final client = ref.watch(convexClientProvider);
      if (client == null) {
        throw const AppAuthException(
          'CONVEX_URL est requis pour BACKEND_MODE=convex.',
        );
      }
      return DartvexConvexGateway(client);
  }
});

final convexAuthBinderProvider = Provider<ConvexAuthBinder?>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return null;
    case BackendMode.convex:
      final gateway = ref.watch(convexGatewayProvider);
      final source = ref.watch(authAccessTokenSourceProvider);
      if (gateway == null || source == null) {
        throw const AppAuthException(
          'Auth Convex incomplete.',
        );
      }
      final binder = ConvexAuthBinder(gateway: gateway, tokens: source);
      ref.onDispose(() {
        unawaited(binder.dispose());
      });
      return binder;
  }
});

({ConvexGateway gateway, ConvexAuthBinder binder}) _requireConvex(
  Ref ref,
) {
  final gateway = ref.watch(convexGatewayProvider);
  final binder = ref.watch(convexAuthBinderProvider);
  if (gateway == null || binder == null) {
    throw const AppAuthException(
      'CONVEX_URL est requis pour BACKEND_MODE=convex.',
    );
  }
  return (gateway: gateway, binder: binder);
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexProfileRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseRoomRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexRoomRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabasePlayerRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexPlayerRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final gameEventRepositoryProvider = Provider<GameEventRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseGameEventRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexGameEventRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final enemyRepositoryProvider = Provider<EnemyRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseEnemyRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexEnemyRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final combatRepositoryProvider = Provider<CombatRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseCombatRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexCombatRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final pendingRollRepositoryProvider = Provider<PendingRollRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabasePendingRollRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexPendingRollRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final gameplayCommandsProvider = Provider<GameplayCommands>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return LegacyGameplayCommands(
        rooms: ref.watch(roomRepositoryProvider),
        players: ref.watch(playerRepositoryProvider),
        events: ref.watch(gameEventRepositoryProvider),
      );
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexGameplayCommands(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final useServerPendingRollsProvider = Provider<bool>((ref) {
  return ref.watch(backendModeProvider) == BackendMode.convex;
});

final serverAuthoritativeGameplayProvider = Provider<bool>((ref) {
  return ref.watch(backendModeProvider) == BackendMode.convex ||
      AppConfig.isGameMasterRemote;
});

final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return SupabaseEntitlementRepository(ref.watch(supabaseClientProvider));
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexEntitlementRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final gameMasterRepositoryProvider = Provider<GameMasterRepository>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      if (AppConfig.isGameMasterRemote) {
        final accessToken = ref
            .watch(supabaseClientProvider)
            ?.auth
            .currentSession
            ?.accessToken;
        return RemoteGameMasterRepository(accessToken: accessToken);
      }
      return const MockGameMasterRepository();
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexGameMasterRepository(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final scenarioGeneratorProvider = Provider<ScenarioGenerator>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      final accessToken = ref
          .watch(supabaseClientProvider)
          ?.auth
          .currentSession
          ?.accessToken;
      return RemoteScenarioGenerator(accessToken: accessToken);
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexScenarioGenerator(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});

final windowsDownloadClientProvider = Provider<WindowsDownloadClient>((ref) {
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      return LegacyWindowsDownloadClient(
        accessToken: ref
            .watch(supabaseClientProvider)
            ?.auth
            .currentSession
            ?.accessToken,
      );
    case BackendMode.convex:
      final convex = _requireConvex(ref);
      return ConvexWindowsDownloadClient(
        gateway: convex.gateway,
        binder: convex.binder,
      );
  }
});
