import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import 'character_stats.dart';
import 'player_profile.dart';

abstract interface class ProfileRepository {
  Future<PlayerProfile?> fetchCurrent();
  Future<PlayerProfile> upsertDisplayName({
    required String userId,
    required String displayName,
  });
  Future<PlayerProfile> upsertSheet({
    required String userId,
    required String displayName,
    required CharacterStats stats,
    required String classId,
  });
  Future<PlayerProfile> upsertAvatar({
    required String userId,
    required int? figurineId,
  });
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return SupabaseProfileRepository(ref.watch(supabaseClientProvider));
});

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const AppAuthException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<PlayerProfile?> fetchCurrent() async {
    final userId = _client?.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final rows = await _requiredClient
        .from('profiles')
        .select()
        .eq('id', userId)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return PlayerProfile.fromJson(rows.first);
  }

  @override
  Future<PlayerProfile> upsertDisplayName({
    required String userId,
    required String displayName,
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.length < 2 || trimmed.length > 32) {
      throw const GameException(
        'Le pseudo doit contenir entre 2 et 32 caracteres.',
      );
    }

    try {
      final row = await _requiredClient
          .from('profiles')
          .upsert({'id': userId, 'display_name': trimmed})
          .select()
          .single();

      return PlayerProfile.fromJson(row);
    } on PostgrestException catch (error) {
      throw GameException(error.message, cause: error);
    }
  }

  @override
  Future<PlayerProfile> upsertSheet({
    required String userId,
    required String displayName,
    required CharacterStats stats,
    required String classId,
  }) async {
    try {
      final row = await _requiredClient
          .from('profiles')
          .upsert({
            'id': userId,
            'display_name': displayName,
            'sheet_confirmed': true,
            'class_id': classId,
            ...stats.toJson(),
          })
          .select()
          .single();

      return PlayerProfile.fromJson(row);
    } on PostgrestException catch (error) {
      throw GameException(error.message, cause: error);
    }
  }

  @override
  Future<PlayerProfile> upsertAvatar({
    required String userId,
    required int? figurineId,
  }) async {
    if (figurineId != null && (figurineId < 0 || figurineId > 39)) {
      throw const GameException('Figurine invalide.');
    }

    try {
      final row = await _requiredClient
          .from('profiles')
          .update({'avatar_figurine_id': figurineId})
          .eq('id', userId)
          .select()
          .single();

      return PlayerProfile.fromJson(row);
    } on PostgrestException catch (error) {
      throw GameException(error.message, cause: error);
    }
  }
}
