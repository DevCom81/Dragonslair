import '../../auth/domain/character_stats.dart';
import 'inventory_item.dart';
import 'inventory_rules.dart';
import 'player_effect.dart';

class Player {
  const Player({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.figurineId,
    required this.figurineName,
    required this.positionX,
    required this.positionY,
    required this.hp,
    required this.inventory,
    required this.joinedAt,
    required this.stats,
    this.classId,
    this.effects = const [],
  });

  final String id;
  final String roomId;
  final String? userId;
  final int figurineId;
  final String figurineName;
  final double positionX;
  final double positionY;
  final int hp;
  final List<InventoryItem> inventory;
  final DateTime joinedAt;
  final String? classId;
  final CharacterStats stats;
  final List<PlayerEffect> effects;

  int effectiveScoreFor(String key) {
    return effectiveScore(
      stats: stats,
      inventory: inventory,
      effects: effects,
      key: key,
    );
  }

  int effectiveModifierFor(String key) {
    return effectiveModifier(
      stats: stats,
      inventory: inventory,
      effects: effects,
      key: key,
    );
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      userId: json['user_id'] as String?,
      figurineId: (json['figurine_id'] as num).toInt(),
      figurineName: json['figurine_name'] as String,
      positionX: _normalized(json['position_x']),
      positionY: _normalized(json['position_y']),
      hp: (json['hp'] as num).toInt(),
      inventory: InventoryItem.listFromJson(json['inventory']),
      joinedAt: DateTime.parse(json['joined_at'] as String),
      classId: json['class_id'] as String?,
      stats: CharacterStats.fromJson(json),
      effects: PlayerEffect.listFromJson(json['effects']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'user_id': userId,
      'figurine_id': figurineId,
      'figurine_name': figurineName,
      'position_x': positionX,
      'position_y': positionY,
      'hp': hp,
      'inventory': inventory.map((item) => item.toJson()).toList(),
      'joined_at': joinedAt.toIso8601String(),
      'class_id': classId,
      'effects': effects.map((effect) => effect.toJson()).toList(),
      ...stats.toJson(),
    };
  }

  static double _normalized(Object? value) {
    final number = (value as num).toDouble();
    if (number < 0 || number > 1) {
      throw ArgumentError('Normalized position must be between 0 and 1');
    }
    return number;
  }
}
