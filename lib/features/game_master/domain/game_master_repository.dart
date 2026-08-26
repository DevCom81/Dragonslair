import 'game_master_response.dart';

class GameMasterInput {
  const GameMasterInput({
    required this.action,
    this.roomId,
    this.playerId,
    this.playerName = 'Aventurier',
    this.players = const [],
    this.recentEvents = const [],
  });

  final String? roomId;
  final String? playerId;
  final String playerName;
  final String action;
  final List<GameMasterPlayerContext> players;
  final List<GameMasterRecentEvent> recentEvents;

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'player_id': playerId,
      'player_name': playerName,
      'action': action,
      'players': players.map((player) => player.toJson()).toList(),
      'recent_events': recentEvents.map((event) => event.toJson()).toList(),
    };
  }
}

class GameMasterPlayerContext {
  const GameMasterPlayerContext({
    required this.id,
    required this.name,
    required this.hp,
    required this.figurineId,
    this.position,
    this.inventory = const [],
  });

  final String id;
  final String name;
  final int hp;
  final int figurineId;
  final GameMasterPosition? position;
  final List<Map<String, dynamic>> inventory;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hp': hp,
      'figurine_id': figurineId,
      'position': position?.toJson(),
      'inventory': inventory,
    };
  }
}

class GameMasterPosition {
  const GameMasterPosition({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}

class GameMasterRecentEvent {
  const GameMasterRecentEvent({
    required this.type,
    required this.content,
  });

  final String type;
  final String content;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
    };
  }
}

abstract interface class GameMasterRepository {
  Future<GameMasterResponse> respond(GameMasterInput input);
}
