import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mutate.dart';
import '../../players/domain/inventory_item.dart';
import '../../players/domain/player.dart';
import '../domain/gameplay_commands.dart';

class ConvexGameplayCommands implements GameplayCommands {
  ConvexGameplayCommands({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  Future<void> _mutate(String name, Map<String, Object?> args) async {
    await convexMutate(
      gateway: _gateway,
      binder: _binder,
      name: name,
      args: args,
    );
  }

  @override
  Future<void> pauseRoom({
    required String roomId,
    required String pausedContent,
  }) {
    return _mutate('rooms:pause', {'roomId': roomId});
  }

  @override
  Future<void> setItemEquipped({
    required String roomId,
    required Player player,
    required String itemId,
    required bool equipped,
    required String systemContent,
  }) {
    return _mutate('players:setItemEquipped', {
      'roomId': roomId,
      'itemId': itemId,
      'equipped': equipped,
    });
  }

  @override
  Future<void> usePotion({
    required String roomId,
    required Player player,
    required InventoryItem item,
  }) {
    return _mutate('players:usePotion', {
      'roomId': roomId,
      'itemId': item.id,
    });
  }

  @override
  Future<void> useGrantedScroll({
    required String roomId,
    required Player player,
    required InventoryItem item,
  }) {
    return _mutate('players:useScroll', {
      'roomId': roomId,
      'itemId': item.id,
    });
  }

  @override
  Future<void> submitAction({
    required String roomId,
    required Player player,
    required String content,
  }) {
    return _mutate('players:submitAction', {
      'roomId': roomId,
      'content': content,
    });
  }

  @override
  Future<void> announceDice({
    required String roomId,
    required Player player,
    required int sides,
    required int raw,
  }) {
    return _mutate('players:announceDice', {
      'roomId': roomId,
      'sides': sides,
      'raw': raw,
    });
  }

  @override
  Future<void> resolveServerRoll({
    required String pendingRollId,
    required int raw,
  }) async {
    await convexAction(
      gateway: _gateway,
      binder: _binder,
      name: 'gameMaster:resolveRoll',
      args: {
        'pendingRollId': pendingRollId,
        'raw': raw,
      },
      timeout: convexGameMasterTimeout,
    );
  }
}
