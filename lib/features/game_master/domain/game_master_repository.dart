import 'game_master_response.dart';

class GameMasterInput {
  const GameMasterInput({
    required this.action,
    this.roomId,
    this.playerId,
    this.playerName = 'Aventurier',
    this.players = const [],
    this.enemies = const [],
    this.recentEvents = const [],
    this.combat,
    this.rollResult,
    this.locale = 'en',
  });

  final String? roomId;
  final String? playerId;
  final String playerName;
  final String action;
  final List<GameMasterPlayerContext> players;
  final List<GameMasterEnemyContext> enemies;
  final List<GameMasterRecentEvent> recentEvents;
  final GameMasterCombatContext? combat;
  final GameMasterRollResult? rollResult;
  final String locale;

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'player_id': playerId,
      'player_name': playerName,
      'action': action,
      'players': players.map((player) => player.toJson()).toList(),
      'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
      'recent_events': recentEvents.map((event) => event.toJson()).toList(),
      if (combat != null) 'combat': combat!.toJson(),
      if (rollResult != null) 'roll_result': rollResult!.toJson(),
      'locale': locale,
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
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
    this.effects = const [],
  });

  final String id;
  final String name;
  final int hp;
  final int figurineId;
  final GameMasterPosition? position;
  final List<Map<String, dynamic>> inventory;
  final int strength;
  final int dexterity;
  final int constitution;
  final int intelligence;
  final int wisdom;
  final int charisma;
  final List<Map<String, dynamic>> effects;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hp': hp,
      'figurine_id': figurineId,
      'position': position?.toJson(),
      'inventory': inventory,
      'strength': strength,
      'dexterity': dexterity,
      'constitution': constitution,
      'intelligence': intelligence,
      'wisdom': wisdom,
      'charisma': charisma,
      'effects': effects,
    };
  }
}

class GameMasterEnemyContext {
  const GameMasterEnemyContext({
    required this.id,
    required this.name,
    required this.enemyType,
    required this.hp,
    required this.maxHp,
    required this.status,
    this.position,
  });

  final String id;
  final String name;
  final String enemyType;
  final int hp;
  final int maxHp;
  final String status;
  final GameMasterPosition? position;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enemy_type': enemyType,
      'hp': hp,
      'max_hp': maxHp,
      'status': status,
      'position': position?.toJson(),
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

class GameMasterCombatContext {
  const GameMasterCombatContext({
    this.active = false,
    this.round = 0,
  });

  final bool active;
  final int round;

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'round': round,
    };
  }
}

class GameMasterRollResult {
  const GameMasterRollResult({
    required this.pendingRollId,
    required this.playerId,
    required this.ability,
    required this.dc,
    required this.raw,
    required this.modifier,
    required this.total,
    required this.success,
    this.reason = '',
  });

  final String pendingRollId;
  final String playerId;
  final String ability;
  final int dc;
  final int raw;
  final int modifier;
  final int total;
  final bool success;
  final String reason;

  Map<String, dynamic> toJson() {
    return {
      'pending_roll_id': pendingRollId,
      'player_id': playerId,
      'ability': ability,
      'dc': dc,
      'raw': raw,
      'modifier': modifier,
      'total': total,
      'success': success,
      'reason': reason,
    };
  }
}

class ResolveRollInput {
  const ResolveRollInput({
    required this.pendingRollId,
    required this.raw,
    this.playerName = 'Aventurier',
    this.players = const [],
    this.enemies = const [],
    this.recentEvents = const [],
    this.combat,
  });

  final String pendingRollId;
  final int raw;
  final String playerName;
  final List<GameMasterPlayerContext> players;
  final List<GameMasterEnemyContext> enemies;
  final List<GameMasterRecentEvent> recentEvents;
  final GameMasterCombatContext? combat;

  Map<String, dynamic> toJson() {
    return {
      'pending_roll_id': pendingRollId,
      'raw': raw,
      'player_name': playerName,
      'players': players.map((player) => player.toJson()).toList(),
      'enemies': enemies.map((enemy) => enemy.toJson()).toList(),
      'recent_events': recentEvents.map((event) => event.toJson()).toList(),
      if (combat != null) 'combat': combat!.toJson(),
    };
  }
}

abstract interface class GameMasterRepository {
  Future<GameMasterResponse> respond(GameMasterInput input);
  Future<GameMasterResponse> resolveRoll(ResolveRollInput input);
}
