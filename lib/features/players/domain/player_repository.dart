import '../../auth/domain/character_stats.dart';
import 'inventory_item.dart';
import 'player.dart';
import 'player_effect.dart';

abstract interface class PlayerRepository {
  Future<List<Player>> fetchRoomPlayers(String roomId);
  Stream<List<Player>> watchRoomPlayers(String roomId);
  Future<Player> joinRoom({
    required String roomId,
    required String userId,
    required int figurineId,
    required String figurineName,
    required String classId,
    required CharacterStats stats,
  });
  Future<void> updatePosition({
    required String playerId,
    required double x,
    required double y,
  });
  Future<void> patchOwnPlayer({
    required String playerId,
    int? hp,
    List<InventoryItem>? inventory,
    List<PlayerEffect>? effects,
  });
}
