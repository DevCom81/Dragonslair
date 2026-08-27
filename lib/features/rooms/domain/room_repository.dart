import 'room.dart';

abstract interface class RoomRepository {
  Future<List<Room>> fetchWaitingRooms();
  Stream<List<Room>> watchWaitingRooms();
  Future<Room> createRoom({
    required String name,
    required String hostId,
    required String scenarioId,
    required String scenarioName,
    required int minPlayers,
    required List<String> requiredClassIds,
  });
  Future<Room> fetchRoom(String roomId);
  Future<Room?> fetchRoomByJoinCode(String joinCode);
  Stream<Room?> watchRoom(String roomId);
  Future<void> startRoom(String roomId);
}
