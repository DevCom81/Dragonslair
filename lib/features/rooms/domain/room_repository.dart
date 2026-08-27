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
    String scenarioPrompt = '',
    Map<String, dynamic> worldState = const {},
  });
  Future<Room> fetchRoom(String roomId);
  Future<Room?> fetchRoomByJoinCode(String joinCode);
  Stream<Room?> watchRoom(String roomId);
  Stream<List<Room>> watchMyContinuableRooms();
  Future<void> startRoom(String roomId);
  Future<void> pauseRoom(String roomId);
  Future<void> resumeRoom(String roomId);
}
