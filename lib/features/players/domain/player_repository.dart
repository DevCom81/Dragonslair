import 'player.dart';

abstract interface class PlayerRepository {
  Future<List<Player>> fetchRoomPlayers(String roomId);
  Stream<List<Player>> watchRoomPlayers(String roomId);
  Future<Player> joinRoom({
    required String roomId,
    required String userId,
    required int figurineId,
    required String figurineName,
  });
  Future<void> updatePosition({
    required String playerId,
    required double x,
    required double y,
  });
}
