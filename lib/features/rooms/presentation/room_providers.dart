import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../domain/room.dart';

export '../../../core/backend/backend_composition.dart' show roomRepositoryProvider;

final waitingRoomsProvider = StreamProvider.autoDispose<List<Room>>((ref) {
  return ref.watch(roomRepositoryProvider).watchWaitingRooms();
});

final roomProvider = StreamProvider.autoDispose.family<Room?, String>((
  ref,
  roomId,
) {
  return ref.watch(roomRepositoryProvider).watchRoom(roomId);
});

final myContinuableRoomsProvider = StreamProvider.autoDispose<List<Room>>((ref) {
  return ref.watch(roomRepositoryProvider).watchMyContinuableRooms();
});
