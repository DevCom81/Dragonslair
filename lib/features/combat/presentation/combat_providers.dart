import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/domain/game_master_response.dart';
import '../domain/combat_session.dart';

export '../../../core/backend/backend_composition.dart'
    show combatRepositoryProvider;

final roomCombatProvider =
    StreamProvider.autoDispose.family<CombatSession, String>((ref, roomId) {
  return ref.watch(combatRepositoryProvider).watchRoomCombat(roomId);
});

class LocalCombatNotifier extends Notifier<CombatSession> {
  @override
  CombatSession build() => CombatSession.inactive();

  void setSession(CombatSession session) {
    state = session;
  }
}

final localCombatProvider =
    NotifierProvider<LocalCombatNotifier, CombatSession>(LocalCombatNotifier.new);

CombatSession watchActiveCombat(WidgetRef ref, String roomId) {
  if (ref.watch(serverAuthoritativeGameplayProvider)) {
    return ref.watch(roomCombatProvider(roomId)).value ??
        CombatSession.inactive();
  }
  return ref.watch(localCombatProvider);
}

CombatSession readActiveCombat(WidgetRef ref, String roomId) {
  if (ref.read(serverAuthoritativeGameplayProvider)) {
    return ref.read(roomCombatProvider(roomId)).value ??
        CombatSession.inactive();
  }
  return ref.read(localCombatProvider);
}

GameMasterCombatContext toGameMasterCombat(CombatSession session) {
  return GameMasterCombatContext(
    active: session.active,
    round: session.round,
  );
}

void applyLocalCombatFromResponse({
  required WidgetRef ref,
  required GameMasterResponse response,
}) {
  if (ref.read(serverAuthoritativeGameplayProvider)) {
    return;
  }
  var next = ref.read(localCombatProvider);
  for (final action in response.actions) {
    if (action.type == GameMasterActionType.startCombat) {
      final round = (action.payload['round'] as num?)?.toInt();
      next = next.applyStart(requestedRound: round);
    } else if (action.type == GameMasterActionType.endCombat) {
      next = next.applyEnd();
    }
  }
  ref.read(localCombatProvider.notifier).setSession(next);
}
