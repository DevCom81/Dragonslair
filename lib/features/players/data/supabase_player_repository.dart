import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/player.dart';
import '../domain/player_repository.dart';

class SupabasePlayerRepository implements PlayerRepository {
  const SupabasePlayerRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requiredClient {
    final client = _client;
    if (client == null) {
      throw const NetworkException('Supabase n est pas configure.');
    }
    return client;
  }

  @override
  Future<List<Player>> fetchRoomPlayers(String roomId) async {
    final rows = await _requiredClient
        .from('players')
        .select()
        .eq('room_id', roomId)
        .order('joined_at');

    return rows.map((row) => Player.fromJson(row)).toList();
  }

  @override
  Stream<List<Player>> watchRoomPlayers(String roomId) async* {
    yield await fetchRoomPlayers(roomId);

    yield* _requiredClient
        .from('players')
        .stream(primaryKey: ['id'])
        .map((rows) {
          final players = rows
              .where((row) => row['room_id']?.toString() == roomId)
              .map(Player.fromJson)
              .toList();
          players.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
          return players;
        });
  }

  @override
  Future<Player> joinRoom({
    required String roomId,
    required String userId,
    required int figurineId,
    required String figurineName,
  }) async {
    final existingPlayers = await fetchRoomPlayers(roomId);
    Player? existingUser;
    for (final player in existingPlayers) {
      if (player.userId == userId) {
        existingUser = player;
        break;
      }
    }

    if (existingUser != null) {
      return existingUser;
    }

    final figurineTaken = existingPlayers.any((player) {
      return player.figurineId == figurineId;
    });

    if (figurineTaken) {
      throw const GameException('Cette figurine est deja prise.');
    }

    final row = await _requiredClient
        .from('players')
        .insert({
          'room_id': roomId,
          'user_id': userId,
          'figurine_id': figurineId,
          'figurine_name': figurineName,
          'position_x': 0.5,
          'position_y': 0.5,
          'hp': 100,
          'inventory': <Map<String, dynamic>>[],
        })
        .select()
        .single();

    return Player.fromJson(row);
  }

  @override
  Future<void> updatePosition({
    required String playerId,
    required double x,
    required double y,
  }) async {
    await _requiredClient.from('players').update({
      'position_x': x.clamp(0, 1),
      'position_y': y.clamp(0, 1),
    }).eq('id', playerId);
  }
}
