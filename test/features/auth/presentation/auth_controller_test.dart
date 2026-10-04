import 'dart:async';

import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/features/auth/domain/auth_repository.dart';
import 'package:dragons_lair/features/auth/domain/auth_user.dart';
import 'package:dragons_lair/features/auth/presentation/auth_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AuthController exposes AuthUser, never a Supabase User', () async {
    const user = AuthUser(id: 'user-1', isAnonymous: false);
    final repository = _FakeAuthRepository(user: user);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => repository),
      ],
    );
    addTearDown(container.dispose);

    final restored = await container.read(authControllerProvider.future);
    expect(restored, same(user));
    expect(restored, isA<AuthUser>());
    expect(container.read(authControllerProvider).value, same(user));
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
  Future<void> startSignIn({String? context}) async {}

  @override
  Future<AuthUser> signInAnonymously() async => user!;

  @override
  bool get supportsAnonymousSignIn => true;

  @override
  Future<void> signOut() async {
    user = null;
  }
}
