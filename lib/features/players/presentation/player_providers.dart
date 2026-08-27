import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/supabase_player_repository.dart';
import '../domain/player.dart';
import '../domain/player_repository.dart';

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return SupabasePlayerRepository(ref.watch(supabaseClientProvider));
});

final roomPlayersProvider = StreamProvider.autoDispose.family<List<Player>, String>((
  ref,
  roomId,
) {
  return ref.watch(playerRepositoryProvider).watchRoomPlayers(roomId);
});
