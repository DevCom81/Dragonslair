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
  Future<void> startSignIn({String? context}) {
    throw const AppAuthException(
      'La connexion externe n est pas disponible en mode legacy.',
    );
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
  bool get supportsAnonymousSignIn => true;

  @override
  Future<void> signOut() async {
    await _requiredClient.auth.signOut();
  }
}
