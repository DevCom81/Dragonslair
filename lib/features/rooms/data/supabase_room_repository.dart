import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/join_code.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';

class SupabaseRoomRepository implements RoomRepository {
  const SupabaseRoomRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<List<Room>> fetchWaitingRooms() async {
    final rows = await _requiredClient
        .from('rooms')
        .select()
        .eq('status', RoomStatus.waiting.toJson())
        .order('created_at');

    return rows.map((row) => Room.fromJson(row)).toList();
  }

  @override
  Stream<List<Room>> watchWaitingRooms() {
    return _requiredClient
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('status', RoomStatus.waiting.toJson())
        .order('created_at')
        .map((rows) => rows.map((row) => Room.fromJson(row)).toList());
  }

  @override
  Future<Room> createRoom({
    required String name,
    required String scenario,
    required String hostId,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final row = await _requiredClient
            .from('rooms')
            .insert({
              'name': name,
              'scenario': scenario,
              'host_id': hostId,
              'status': RoomStatus.waiting.toJson(),
              'join_code': JoinCode.generate(),
            })
            .select()
            .single();
        return Room.fromJson(row);
      } catch (error) {
        lastError = error;
      }
    }
    throw GameException(
      'Impossible de creer la partie.',
      cause: lastError,
    );
  }

  @override
  Future<Room> fetchRoom(String roomId) async {
    final row = await _requiredClient
        .from('rooms')
        .select()
        .eq('id', roomId)
        .single();

    return Room.fromJson(row);
  }

  @override
  Future<Room?> fetchRoomByJoinCode(String joinCode) async {
    final normalized = JoinCode.normalize(joinCode);
    if (normalized.length != JoinCode.length) {
      throw const GameException('Code de partie invalide.');
    }

    final rows = await _requiredClient
        .from('rooms')
        .select()
        .eq('join_code', normalized)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }
    return Room.fromJson(rows.first);
  }

  @override
  Stream<Room?> watchRoom(String roomId) {
    return _requiredClient
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.isEmpty ? null : Room.fromJson(rows.first));
  }

  @override
  Future<void> startRoom(String roomId) async {
    await _requiredClient.from('rooms').update({
      'status': RoomStatus.playing.toJson(),
      'game_phase': 'exploration',
      'started_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', roomId);
  }
}
