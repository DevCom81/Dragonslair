import 'game_event.dart';

abstract interface class GameEventRepository {
  Stream<List<GameEvent>> watchRoomEvents(String roomId);
  Future<void> createAction({
    required String roomId,
    required String playerId,
    required String content,
  });
  Future<void> createNarration({
    required String roomId,
    required String content,
  });
  Future<void> createSystem({
    required String roomId,
    required String content,
  });
}
