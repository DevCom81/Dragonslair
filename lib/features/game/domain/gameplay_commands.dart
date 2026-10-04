import '../../players/domain/inventory_item.dart';
import '../../players/domain/player.dart';

/// User-facing gameplay intents. Convex adapters call one mutation.
/// Legacy adapters keep historical multi-writes (patch + event).
abstract interface class GameplayCommands {
  Future<void> pauseRoom({
    required String roomId,
    required String pausedContent,
  });

  Future<void> setItemEquipped({
    required String roomId,
    required Player player,
    required String itemId,
    required bool equipped,
    required String systemContent,
  });

  Future<void> usePotion({
    required String roomId,
    required Player player,
    required InventoryItem item,
  });

  Future<void> useGrantedScroll({
    required String roomId,
    required Player player,
    required InventoryItem item,
  });

  Future<void> submitAction({
    required String roomId,
    required Player player,
    required String content,
  });

  Future<void> announceDice({
    required String roomId,
    required Player player,
    required int sides,
    required int raw,
  });

  Future<void> resolveServerRoll({
    required String pendingRollId,
    required int raw,
  });
}
