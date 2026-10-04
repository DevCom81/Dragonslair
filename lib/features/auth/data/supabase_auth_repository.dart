import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/errors/app_exception.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import 'supabase_auth_mapper.dart';

class SupabaseAuthRepository implements AuthRepository {
  const SupabaseAuthRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const AppAuthException(
        'Supabase n est pas configure. Fournis SUPABASE_URL et SUPABASE_ANON_KEY.',
      );
    }
    return client;
  }

  @override
  AuthUser? get currentUser {
    final user = _client?.auth.currentUser;
    if (user == null) {
      return null;
    }
    return authUserFromSupabase(user);
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    final client = _client;
    if (client == null) {
      return const Stream<AuthUser?>.empty();
    }
    return client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) {
        return null;
      }
      return authUserFromSupabase(user);
    });
  }

  @override
  Future<AuthUser?> restoreSession() async {
    return currentUser;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _requiredClient.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AppAuthException('Connexion impossible.');
      }
      return authUserFromSupabase(user);
    } on AuthException catch (error) {
      throw AppAuthException(error.message, cause: error);
    }
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    try {
      final response = await _requiredClient.auth.signUp(
        email: trimmedEmail,
        password: password,
      );
      final sessionUser = response.session?.user ?? response.user;
      if (response.session == null) {
        try {
          return await signIn(email: trimmedEmail, password: password);
        } on AppAuthException {
          throw const AppAuthException(
            'Compte cree. Desactive Confirm email dans Supabase Auth.',
          );
        }
      }
      if (sessionUser == null) {
        throw const AppAuthException('Inscription impossible.');
      }
      return authUserFromSupabase(sessionUser);
    } on AppAuthException {
      rethrow;
    } on AuthException catch (error) {
      throw AppAuthException(
        '${error.message} Si le compte est cree, desactive Confirm email dans Supabase Auth.',
        cause: error,
      );
    }
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    final existing = _client?.auth.currentUser;
    if (existing != null) {
      return authUserFromSupabase(existing);
    }

    try {
      final response = await _requiredClient.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw const AppAuthException('Anonymous sign-in is not available.');
      }
      return authUserFromSupabase(user);
    } on AuthException catch (error) {
      throw AppAuthException(error.message, cause: error);
    }
  }

  @override
  Future<AuthUser> verifyEmailCode({required String code}) {
    throw const AppAuthException(
      'La verification email WorkOS n est pas utilisee en mode legacy.',
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) {
    throw const AppAuthException(
      'La reinitialisation du mot de passe n est pas disponible en mode legacy.',
    );
  }

  @override
  bool get supportsAnonymousSignIn => true;

  @override
  bool get supportsPasswordReset => false;

  @override
  Future<void> signOut() async {
    await _requiredClient.auth.signOut();
  }
}
