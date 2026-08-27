import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/pending_roll_repository.dart';
import '../presentation/pending_ability_roll.dart';

class SupabasePendingRollRepository implements PendingRollRepository {
  const SupabasePendingRollRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<List<PendingAbilityRoll>> fetchRoomRolls(String roomId) async {
    final rows = await _requiredClient
        .from('pending_rolls')
        .select()
        .eq('room_id', roomId)
        .order('created_at');

    return [
      for (final row in rows)
        if (PendingAbilityRoll.tryParse(row) != null)
          PendingAbilityRoll.fromJson(row),
    ];
  }

  @override
  Stream<List<PendingAbilityRoll>> watchRoomRolls(String roomId) async* {
    yield await fetchRoomRolls(roomId);

    yield* _requiredClient
        .from('pending_rolls')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final rolls = [
            for (final row in rows)
              if (row['room_id']?.toString() == roomId &&
                  PendingAbilityRoll.tryParse(row) != null)
                PendingAbilityRoll.fromJson(row),
          ];
          rolls.sort((a, b) => (a.id ?? '').compareTo(b.id ?? ''));
          return rolls;
        });
  }
}
