import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../domain/game_event.dart';

export '../../../core/backend/backend_composition.dart'
    show gameEventRepositoryProvider;

final roomEventsProvider =
    StreamProvider.autoDispose.family<List<GameEvent>, String>((ref, roomId) {
  return ref.watch(gameEventRepositoryProvider).watchRoomEvents(roomId);
});
