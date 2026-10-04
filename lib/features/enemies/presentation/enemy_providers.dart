import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../domain/enemy.dart';

export '../../../core/backend/backend_composition.dart' show enemyRepositoryProvider;

final roomEnemiesProvider =
    StreamProvider.autoDispose.family<List<Enemy>, String>((ref, roomId) {
  return ref.watch(enemyRepositoryProvider).watchRoomEnemies(roomId);
});
