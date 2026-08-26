import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';

abstract interface class AuthRepository {
  Future<User?> restoreSession();
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
  Future<User> signInAnonymously() async {
    final response = await _requiredClient.auth.signInAnonymously();
    final user = response.user;
    if (user == null) {
      throw const AppAuthException('Authentification anonyme impossible.');
    }
    return user;
  }

  @override
  Future<void> signOut() async {
    await _requiredClient.auth.signOut();
  }
}
