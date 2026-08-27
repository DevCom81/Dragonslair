import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/supabase_game_event_repository.dart';
import '../domain/game_event.dart';
import '../domain/game_event_repository.dart';

final gameEventRepositoryProvider = Provider<GameEventRepository>((ref) {
  return SupabaseGameEventRepository(ref.watch(supabaseClientProvider));
});

final roomEventsProvider =
    StreamProvider.autoDispose.family<List<GameEvent>, String>((ref, roomId) {
  return ref.watch(gameEventRepositoryProvider).watchRoomEvents(roomId);
});
