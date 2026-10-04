import '../../../core/errors/app_exception.dart';
import '../../events/domain/game_event_repository.dart';
import '../../players/domain/inventory_item.dart';
import '../../players/domain/inventory_rules.dart';
import '../../players/domain/player.dart';
import '../../players/domain/player_repository.dart';
import '../../rooms/domain/room_repository.dart';
import '../domain/gameplay_commands.dart';

class LegacyGameplayCommands implements GameplayCommands {
  LegacyGameplayCommands({
    required RoomRepository rooms,
    required PlayerRepository players,
    required GameEventRepository events,
  })  : _rooms = rooms,
        _players = players,
        _events = events;

  final RoomRepository _rooms;
  final PlayerRepository _players;
  final GameEventRepository _events;

  @override
  Future<void> pauseRoom({
    required String roomId,
    required String pausedContent,
  }) async {
    await _rooms.pauseRoom(roomId);
    await _events.createSystem(roomId: roomId, content: pausedContent);
  }

  @override
  Future<void> setItemEquipped({
    required String roomId,
    required Player player,
    required String itemId,
    required bool equipped,
    required String systemContent,
  }) async {
    final next = setEquipped(
      inventory: player.inventory,
      itemId: itemId,
      equipped: equipped,
    );
    await _players.patchOwnPlayer(playerId: player.id, inventory: next);
    await _events.createSystem(roomId: roomId, content: systemContent);
  }

  @override
  Future<void> usePotion({
    required String roomId,
    required Player player,
    required InventoryItem item,
  }) async {
    final result = consumePotion(inventory: player.inventory, itemId: item.id);
    if (result.heal <= 0) {
      return;
    }
    final nextHp = (player.hp + result.heal).clamp(0, 100);
    await _players.patchOwnPlayer(
      playerId: player.id,
      hp: nextHp,
      inventory: result.inventory,
    );
    await _events.createSystem(
      roomId: roomId,
      content:
          '${player.figurineName} : ${item.name} (+${result.heal} PV, ${player.hp} -> $nextHp)',
    );
  }

  @override
  Future<void> useGrantedScroll({
    required String roomId,
    required Player player,
    required InventoryItem item,
  }) async {
    final result = consumeScroll(inventory: player.inventory, itemId: item.id);
    if (result.effect == null) {
      throw const GameException('Parchemin inutilisable.');
    }
    await _players.patchOwnPlayer(
      playerId: player.id,
      inventory: result.inventory,
      effects: upsertEffect(player.effects, result.effect!),
    );
    await _events.createSystem(
      roomId: roomId,
      content: '${player.figurineName} : ${item.name} (${result.effect!.name})',
    );
  }

  @override
  Future<void> submitAction({
    required String roomId,
    required Player player,
    required String content,
  }) {
    return _events.createAction(
      roomId: roomId,
      playerId: player.id,
      content: '${player.figurineName} : $content',
    );
  }

  @override
  Future<void> announceDice({
    required String roomId,
    required Player player,
    required int sides,
    required int raw,
  }) {
    final label = '1d$sides : $raw = $raw';
    return _events.createAction(
      roomId: roomId,
      playerId: player.id,
      content: '${player.figurineName} lance $label',
    );
  }

  @override
  Future<void> resolveServerRoll({
    required String pendingRollId,
    required int raw,
  }) {
    throw const GameException('Server roll resolve is not used in legacy.');
  }
}
