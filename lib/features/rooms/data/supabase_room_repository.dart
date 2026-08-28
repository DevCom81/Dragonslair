import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../access/domain/game_access.dart';
import '../../music/domain/music_mood.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../../scenarios/domain/world_state.dart';
import '../domain/game_ending.dart';
import '../domain/join_code.dart';
import '../domain/room.dart';
import '../domain/room_locale.dart';
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

    return rows
        .map((row) => Room.fromJson(row))
        .where((room) => room.scenarioId != 'demo')
        .toList();
  }

  @override
  Stream<List<Room>> watchWaitingRooms() {
    return _requiredClient
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('status', RoomStatus.waiting.toJson())
        .order('created_at')
        .map((rows) => rows
            .map((row) => Room.fromJson(row))
            .where((room) => room.scenarioId != 'demo')
            .toList());
  }

  @override
  Future<Room> createRoom({
    required String name,
    required String hostId,
    required String scenarioId,
    required String scenarioName,
    required int minPlayers,
    required List<String> requiredClassIds,
    String scenarioPrompt = '',
    Map<String, dynamic> worldState = const {},
    String locale = fallbackRoomLocale,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final row = await _requiredClient
            .from('rooms')
            .insert({
              'name': name,
              'scenario': scenarioName,
              'scenario_id': scenarioId,
              'min_players': minPlayers,
              'required_class_ids': requiredClassIds,
              'scenario_prompt': scenarioPrompt,
              'world_state': sanitizePublicWorldState(worldState),
              'locale': normalizeRoomLocale(locale),
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
  Stream<List<Room>> watchMyContinuableRooms() {
    return _requiredClient
        .from('rooms')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final rooms = rows
              .map((row) => Room.fromJson(row))
              .where(
                (room) =>
                    room.status == RoomStatus.paused ||
                    room.status == RoomStatus.playing,
              )
              .toList();
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rooms;
        });
  }

  @override
  Future<void> startRoom(String roomId) async {
    try {
      await _requiredClient.from('rooms').update({
        'status': RoomStatus.playing.toJson(),
        'game_phase': 'exploration',
        'music_mood': MusicMood.exploration.jsonValue,
        'started_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', roomId);
    } on PostgrestException catch (error) {
      throw GameException(
        error.message.isEmpty
            ? 'Impossible de demarrer la partie.'
            : error.message,
        cause: error,
      );
    }
  }

  @override
  Future<void> pauseRoom(String roomId) async {
    await _setStatus(
      roomId: roomId,
      from: RoomStatus.playing,
      to: RoomStatus.paused,
      fallback: 'Impossible de mettre la partie en pause.',
    );
  }

  @override
  Future<void> resumeRoom(String roomId) async {
    await _setStatus(
      roomId: roomId,
      from: RoomStatus.paused,
      to: RoomStatus.playing,
      fallback: 'Impossible de reprendre la partie.',
    );
  }

  @override
  Future<void> finishRoom({
    required String roomId,
    String result = 'neutral',
    String summary = '',
    String epilogue = '',
  }) async {
    final current = await fetchRoom(roomId);
    if (current.status.isClosed) {
      return;
    }
    if (current.status != RoomStatus.playing &&
        current.status != RoomStatus.paused) {
      throw const GameException('Impossible de terminer la partie.');
    }
    var demoCut = current.scenarioId == ScenarioCatalog.demo.id;
    final hostId = current.hostId;
    if (demoCut && hostId != null && hostId.isNotEmpty) {
      try {
        final rows = await _requiredClient
            .from('user_entitlements')
            .select('user_id,access_level,source,expires_at')
            .eq('user_id', hostId)
            .limit(1);
        if (rows.isNotEmpty &&
            UserEntitlement.fromJson(
              Map<String, dynamic>.from(rows.first),
            ).level.isFull) {
          demoCut = false;
        }
      } on PostgrestException {
        demoCut = true;
      }
    }
    final ending = GameEnding(
      result: GameEndingResult.fromJson(result),
      summary: summary,
      epilogue: epilogue,
    );
    try {
      final row = await _requiredClient
          .from('rooms')
          .update({
            'status': demoCut
                ? RoomStatus.demoFinished.toJson()
                : RoomStatus.finished.toJson(),
            'finished_at': DateTime.now().toUtc().toIso8601String(),
            'ending': ending.toJson(),
          })
          .eq('id', roomId)
          .select()
          .maybeSingle();
      if (row == null) {
        throw const GameException('Impossible de terminer la partie.');
      }
    } on PostgrestException catch (error) {
      throw GameException(
        error.message.isEmpty
            ? 'Impossible de terminer la partie.'
            : error.message,
        cause: error,
      );
    }
  }

  Future<void> _setStatus({
    required String roomId,
    required RoomStatus from,
    required RoomStatus to,
    required String fallback,
  }) async {
    try {
      final row = await _requiredClient
          .from('rooms')
          .update({'status': to.toJson()})
          .eq('id', roomId)
          .eq('status', from.toJson())
          .select()
          .maybeSingle();
      if (row == null) {
        throw GameException(fallback);
      }
    } on PostgrestException catch (error) {
      throw GameException(
        error.message.isEmpty ? fallback : error.message,
        cause: error,
      );
    }
  }
}
