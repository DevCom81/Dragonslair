import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/supabase_room_repository.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return SupabaseRoomRepository(ref.watch(supabaseClientProvider));
});

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
