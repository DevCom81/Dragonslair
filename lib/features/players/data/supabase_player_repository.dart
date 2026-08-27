import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/domain/character_stats.dart';
import '../../rooms/domain/room.dart';
import '../domain/inventory_item.dart';
import '../domain/player.dart';
import '../domain/player_effect.dart';
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
    required String classId,
    required CharacterStats stats,
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

    final roomRows = await _requiredClient
        .from('rooms')
        .select('status')
        .eq('id', roomId)
        .limit(1);
    final roomStatus = roomRows.isEmpty ? null : roomRows.first['status'];
    if (roomStatus != RoomStatus.waiting.toJson()) {
      throw const GameException(
        'Impossible de rejoindre une partie deja lancee.',
      );
    }

    final figurineTaken = existingPlayers.any((player) {
      return player.figurineId == figurineId;
    });

    if (figurineTaken) {
      throw const GameException('Cette figurine est deja prise.');
    }

    final classTaken = existingPlayers.any((player) {
      return player.classId == classId;
    });
    if (classTaken) {
      throw const GameException('Cette classe est deja prise.');
    }

    try {
      final row = await _requiredClient
          .from('players')
          .insert({
            'room_id': roomId,
            'user_id': userId,
            'figurine_id': figurineId,
            'figurine_name': figurineName,
            'class_id': classId,
            'position_x': 0.5,
            'position_y': 0.5,
            'hp': 100,
            'inventory': <Map<String, dynamic>>[],
            ...stats.toJson(),
          })
          .select()
          .single();

      return Player.fromJson(row);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final text = '${error.message} ${error.details ?? ''}';
        if (text.contains('players_room_class_unique')) {
          throw const GameException('Cette classe est deja prise.');
        }
        if (text.contains('players_room_figurine_unique')) {
          throw const GameException('Cette figurine est deja prise.');
        }
        throw const GameException('Cette place est deja prise.');
      }
      throw GameException(error.message, cause: error);
    }
  }

  @override
  Future<void> updatePosition({
    required String playerId,
    required double x,
    required double y,
  }) async {
    final userId = _requiredClient.auth.currentUser?.id;
    if (userId == null) {
      throw const GameException('Session expiree.');
    }

    await _requiredClient.from('players').update({
      'position_x': x.clamp(0, 1),
      'position_y': y.clamp(0, 1),
    }).eq('id', playerId).eq('user_id', userId);
  }

  @override
  Future<void> patchOwnPlayer({
    required String playerId,
    int? hp,
    List<InventoryItem>? inventory,
    List<PlayerEffect>? effects,
  }) async {
    final userId = _requiredClient.auth.currentUser?.id;
    if (userId == null) {
      throw const GameException('Session expiree.');
    }

    final fields = <String, dynamic>{};
    if (hp != null) {
      fields['hp'] = hp.clamp(0, 100);
    }
    if (inventory != null) {
      fields['inventory'] = inventory.map((item) => item.toJson()).toList();
    }
    if (effects != null) {
      fields['effects'] = effects.map((effect) => effect.toJson()).toList();
    }
    if (fields.isEmpty) {
      return;
    }

    await _requiredClient
        .from('players')
        .update(fields)
        .eq('id', playerId)
        .eq('user_id', userId);
  }
}
