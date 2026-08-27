import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../data/supabase_pending_roll_repository.dart';
import '../domain/pending_roll_repository.dart';
import 'pending_ability_roll.dart';

final pendingRollRepositoryProvider = Provider<PendingRollRepository>((ref) {
  return SupabasePendingRollRepository(ref.watch(supabaseClientProvider));
});

final roomPendingRollsProvider = StreamProvider.autoDispose
    .family<List<PendingAbilityRoll>, String>((ref, roomId) {
  return ref.watch(pendingRollRepositoryProvider).watchRoomRolls(roomId);
});

PendingAbilityRoll? activePendingRoll(WidgetRef ref, String roomId) {
  if (AppConfig.isGameMasterRemote) {
    final rolls = ref.watch(roomPendingRollsProvider(roomId)).value ?? const [];
    for (final roll in rolls) {
      if (roll.isOpen) {
        return roll;
      }
    }
    return null;
  }
  return ref.watch(pendingAbilityRollProvider);
}
