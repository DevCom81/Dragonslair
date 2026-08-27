import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/enemy.dart';
import '../domain/enemy_repository.dart';

class SupabaseEnemyRepository implements EnemyRepository {
  const SupabaseEnemyRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<List<Enemy>> fetchRoomEnemies(String roomId) async {
    final rows = await _requiredClient
        .from('enemies')
        .select()
        .eq('room_id', roomId)
        .order('created_at');

    return rows.map((row) => Enemy.fromJson(row)).toList();
  }

  @override
  Stream<List<Enemy>> watchRoomEnemies(String roomId) async* {
    yield await fetchRoomEnemies(roomId);

    yield* _requiredClient
        .from('enemies')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final enemies = rows
              .where((row) => row['room_id']?.toString() == roomId)
              .map(Enemy.fromJson)
              .toList();
          enemies.sort((a, b) {
            final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aDate.compareTo(bDate);
          });
          return enemies;
        });
  }
}
