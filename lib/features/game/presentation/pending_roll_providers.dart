import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import 'pending_ability_roll.dart';

export '../../../core/backend/backend_composition.dart'
    show pendingRollRepositoryProvider;

final roomPendingRollsProvider = StreamProvider.autoDispose
    .family<List<PendingAbilityRoll>, String>((ref, roomId) {
  return ref.watch(pendingRollRepositoryProvider).watchRoomRolls(roomId);
});

PendingAbilityRoll? activePendingRoll(WidgetRef ref, String roomId) {
  if (ref.watch(useServerPendingRollsProvider)) {
    final rolls = ref.watch(roomPendingRollsProvider(roomId)).value ?? const [];
    for (final roll in rolls) {
      if (roll.isOpen) {
        return roll;
      }
    }
    return null;
  }
  if (ref.watch(serverAuthoritativeGameplayProvider)) {
    return null;
  }
  return ref.watch(pendingAbilityRollProvider);
}
