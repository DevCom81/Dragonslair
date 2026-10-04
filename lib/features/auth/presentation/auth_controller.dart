import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../../../core/config/app_config.dart';
import '../domain/auth_user.dart';

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AuthUser?> {
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

  Future<void> startSignIn({String? context}) {
    return ref.read(authRepositoryProvider).startSignIn(context: context);
  }

  Future<void> signInAnonymously() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signInAnonymously(),
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
  }
}
