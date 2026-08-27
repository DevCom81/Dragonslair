import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../game_master/domain/game_master_repository.dart';
import '../../game_master/domain/game_master_response.dart';
import '../data/supabase_combat_repository.dart';
import '../domain/combat_repository.dart';
import '../domain/combat_session.dart';

final combatRepositoryProvider = Provider<CombatRepository>((ref) {
  return SupabaseCombatRepository(ref.watch(supabaseClientProvider));
});

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
  if (AppConfig.isGameMasterRemote) {
    return ref.watch(roomCombatProvider(roomId)).value ??
        CombatSession.inactive();
  }
  return ref.watch(localCombatProvider);
}

CombatSession readActiveCombat(WidgetRef ref, String roomId) {
  if (AppConfig.isGameMasterRemote) {
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
  if (AppConfig.isGameMasterRemote) {
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
