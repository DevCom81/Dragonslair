import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

abstract interface class AuthRepository {
  Future<User?> restoreSession();
  Future<User> signIn({
    required String email,
    required String password,
  });
  Future<User> signUp({
    required String email,
    required String password,
  });
  Future<User> signInAnonymously();
  Future<void> signOut();
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

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
  Future<User?> restoreSession() async {
    return _client?.auth.currentUser;
  }

  @override
  Future<User> signIn({
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
      return user;
    } on AuthException catch (error) {
      throw AppAuthException(error.message, cause: error);
    }
  }

  @override
  Future<User> signUp({
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
      return sessionUser;
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
  Future<User> signInAnonymously() async {
    final existing = _client?.auth.currentUser;
    if (existing != null) {
      return existing;
    }

    try {
      final response = await _requiredClient.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw const AppAuthException('Anonymous sign-in is not available.');
      }
      return user;
    } on AuthException catch (error) {
      throw AppAuthException(error.message, cause: error);
    }
  }

  @override
  Future<void> signOut() async {
    await _requiredClient.auth.signOut();
  }
}
