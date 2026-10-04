import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../../../core/config/app_config.dart';
import '../domain/auth_email_verification.dart';
import '../domain/auth_user.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthUser?> {
  String? pendingVerificationEmail;

  @override
  FutureOr<AuthUser?> build() {
    final repository = ref.watch(authRepositoryProvider);
    if (!AppConfig.isIdentityConfigured) {
      return repository.currentUser;
    }

    final subscription = repository.authStateChanges().listen((user) {
      state = AsyncData(user);
    });
    ref.onDispose(subscription.cancel);

    final current = repository.currentUser;
    if (current != null || repository.supportsAnonymousSignIn) {
      return current;
    }
    return repository.restoreSession();
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => ref.read(authRepositoryProvider).signIn(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _authenticate(
      () => ref.read(authRepositoryProvider).signUp(
            email: email,
            password: password,
          ),
    );
  }

  Future<void> verifyEmailCode({required String code}) async {
    await _authenticate(
      () => ref.read(authRepositoryProvider).verifyEmailCode(code: code),
    );
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    pendingVerificationEmail = null;
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInAnonymously(),
    );
  }

  Future<void> requestPasswordReset({required String email}) {
    return ref.read(authRepositoryProvider).requestPasswordReset(email: email);
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    pendingVerificationEmail = null;
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }

  Future<void> _authenticate(Future<AuthUser> Function() call) async {
    state = const AsyncLoading();
    try {
      final user = await call();
      pendingVerificationEmail = null;
      state = AsyncData(user);
    } on AuthEmailVerificationRequired catch (error) {
      pendingVerificationEmail = error.email;
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      pendingVerificationEmail = null;
      state = AsyncError(error, stackTrace);
    }
  }
}
