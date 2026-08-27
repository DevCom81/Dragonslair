import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/supabase_enemy_repository.dart';
import '../domain/enemy.dart';
import '../domain/enemy_repository.dart';

final enemyRepositoryProvider = Provider<EnemyRepository>((ref) {
  return SupabaseEnemyRepository(ref.watch(supabaseClientProvider));
});

final roomEnemiesProvider =
    StreamProvider.autoDispose.family<List<Enemy>, String>((ref, roomId) {
  return ref.watch(enemyRepositoryProvider).watchRoomEnemies(roomId);
});
