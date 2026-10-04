import 'package:dragons_lair/core/backend/backend_bootstrap.dart';
import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:dragons_lair/core/config/app_config.dart';
import 'package:dragons_lair/core/supabase/supabase_client_provider.dart';
import 'package:dragons_lair/features/auth/data/supabase_auth_repository.dart';
import 'package:dragons_lair/features/auth/data/workos_auth_repository.dart';
import 'package:dragons_lair/features/auth/data/workos_session_store.dart';
import 'package:dragons_lair/features/auth/domain/workos_auth_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy composition selects Supabase auth', () {
    final repository = createAuthRepository(
      mode: BackendMode.legacy,
      client: null,
    );
    expect(repository, isA<SupabaseAuthRepository>());
  });

  test('legacy provider keeps the Supabase auth path', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.legacy),
        supabaseClientProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(authRepositoryProvider),
      isA<SupabaseAuthRepository>(),
    );
    expect(container.read(authAccessTokenSourceProvider), isNull);
  });

  test('convex composition selects WorkOS auth', () {
    final repository = createAuthRepository(
      mode: BackendMode.convex,
      client: null,
      workOsGateway: _FakeGateway(),
      workOsSessionStore: _MemoryStore(),
    );
    expect(repository, isA<WorkOsAuthRepository>());
    expect(repository, isNot(isA<SupabaseAuthRepository>()));
  });

  test('convex provider selects WorkOS auth', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.convex),
        workOsAuthGatewayProvider.overrideWith((ref) => _FakeGateway()),
        workOsSessionStoreProvider.overrideWith((ref) => _MemoryStore()),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(authRepositoryProvider),
      isA<WorkOsAuthRepository>(),
    );
    expect(
      container.read(authAccessTokenSourceProvider),
      isA<WorkOsAuthRepository>(),
    );
  });

  test('convex mode does not initialize Supabase', () {
    expect(shouldInitializeSupabase(BackendMode.convex), isFalse);
  });

  test('convex without CONVEX_URL fails closed at bootstrap', () {
    if (AppConfig.isConvexConfigured) {
      return;
    }
    expect(
      () => ensureSupportedBackendMode(BackendMode.convex),
      throwsA(isA<StateError>()),
    );
  });

  test('legacy initializes Supabase only when keys exist', () {
    expect(
      shouldInitializeSupabase(BackendMode.legacy),
      AppConfig.isSupabaseConfigured,
    );
  });
}

class _MemoryStore implements WorkOsSessionStore {
  String? access;
  String? refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _FakeGateway implements WorkOsAuthGateway {
  @override
  Future<void> requestPasswordReset({required String email}) async {}

  @override
  Future<WorkOsTokenPair> refreshSession({required String refreshToken}) {
    throw UnimplementedError();
  }

  @override
  Future<WorkOsSignInResult> signInWithPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkOsSignInResult> signUpWithPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WorkOsTokenPair> verifyEmailCode({
    required String code,
    required String pendingAuthenticationToken,
  }) {
    throw UnimplementedError();
  }
}
