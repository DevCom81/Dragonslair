import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../domain/player.dart';

export '../../../core/backend/backend_composition.dart'
    show playerRepositoryProvider;

final roomPlayersProvider = StreamProvider.autoDispose.family<List<Player>, String>((
  ref,
  roomId,
) {
  return ref.watch(playerRepositoryProvider).watchRoomPlayers(roomId);
});
