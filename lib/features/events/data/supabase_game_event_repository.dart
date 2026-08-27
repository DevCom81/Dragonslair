import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/game_event.dart';
import '../domain/game_event_repository.dart';

class SupabaseGameEventRepository implements GameEventRepository {
  const SupabaseGameEventRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Stream<List<GameEvent>> watchRoomEvents(String roomId) {
    return _requiredClient
        .from('game_events')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((rows) => rows.map((row) => GameEvent.fromJson(row)).toList());
  }

  @override
  Future<void> createAction({
    required String roomId,
    required String playerId,
    required String content,
  }) {
    return _insert(
      roomId: roomId,
      playerId: playerId,
      type: GameEventType.action,
      content: content,
    );
  }

  @override
  Future<void> createNarration({
    required String roomId,
    required String content,
  }) {
    return _insert(
      roomId: roomId,
      type: GameEventType.narration,
      content: content,
    );
  }

  @override
  Future<void> createSystem({
    required String roomId,
    required String content,
  }) {
    return _insert(
      roomId: roomId,
      type: GameEventType.system,
      content: content,
    );
  }

  Future<void> _insert({
    required String roomId,
    required GameEventType type,
    required String content,
    String? playerId,
  }) async {
    await _requiredClient.from('game_events').insert({
      'room_id': roomId,
      'player_id': playerId,
      'type': type.toJson(),
      'content': content,
    });
  }
}
