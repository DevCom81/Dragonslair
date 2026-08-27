import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/combat_repository.dart';
import '../domain/combat_session.dart';

class SupabaseCombatRepository implements CombatRepository {
  const SupabaseCombatRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<CombatSession> fetchRoomCombat(String roomId) async {
    final rows = await _requiredClient
        .from('combat_sessions')
        .select()
        .eq('room_id', roomId)
        .limit(1);

    if (rows.isEmpty) {
      return CombatSession.inactive();
    }
    return CombatSession.tryParse(rows.first) ?? CombatSession.inactive();
  }

  @override
  Stream<CombatSession> watchRoomCombat(String roomId) async* {
    yield await fetchRoomCombat(roomId);

    yield* _requiredClient
        .from('combat_sessions')
        .stream(primaryKey: ['id'])
        .map((rows) {
          for (final row in rows) {
            if (row['room_id']?.toString() != roomId) {
              continue;
            }
            return CombatSession.tryParse(row) ?? CombatSession.inactive();
          }
          return CombatSession.inactive();
        });
  }
}
