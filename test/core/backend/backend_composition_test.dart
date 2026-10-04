import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:dragons_lair/core/backend/backend_bootstrap.dart';
import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:dragons_lair/core/config/app_config.dart';
import 'package:dragons_lair/core/supabase/supabase_client_provider.dart';
import 'package:dragons_lair/features/auth/data/auth0_auth_repository.dart';
import 'package:dragons_lair/features/auth/data/supabase_auth_repository.dart';
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

  test('convex composition selects Auth0', () {
    final repository = createAuthRepository(
      mode: BackendMode.convex,
      client: null,
      auth0: Auth0Web('example.auth0.com', 'client_id'),
    );
    expect(repository, isA<Auth0AuthRepository>());
    expect(repository, isNot(isA<SupabaseAuthRepository>()));
  });

  test('convex provider selects Auth0', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.convex),
        auth0WebProvider.overrideWith(
          (ref) => Auth0Web('example.auth0.com', 'client_id'),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(authRepositoryProvider),
      isA<Auth0AuthRepository>(),
    );
    expect(
      container.read(authAccessTokenSourceProvider),
      isA<Auth0AuthRepository>(),
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
