enum EnemyStatus {
  active,
  defeated,
  escaped,
}

extension EnemyStatusJson on EnemyStatus {
  String toJson() {
    return switch (this) {
      EnemyStatus.active => 'active',
      EnemyStatus.defeated => 'defeated',
      EnemyStatus.escaped => 'escaped',
    };
  }

  static EnemyStatus fromJson(Object? value) {
    return switch (value) {
      'defeated' => EnemyStatus.defeated,
      'escaped' => EnemyStatus.escaped,
      _ => EnemyStatus.active,
    };
  }
}

class Enemy {
  const Enemy({
    required this.id,
    required this.roomId,
    required this.name,
    required this.enemyType,
    required this.positionX,
    required this.positionY,
    required this.hp,
    required this.maxHp,
    required this.status,
    this.metadata = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String roomId;
  final String name;
  final String enemyType;
  final double positionX;
  final double positionY;
  final int hp;
  final int maxHp;
  final EnemyStatus status;
  final Map<String, dynamic> metadata;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDefeated => status == EnemyStatus.defeated || hp <= 0;

  double get hpRatio {
    if (maxHp <= 0) {
      return 0;
    }
    return (hp / maxHp).clamp(0, 1);
  }

  factory Enemy.fromJson(Map<String, dynamic> json) {
    return Enemy(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      name: json['name'] as String,
      enemyType: json['enemy_type'] as String? ?? 'enemy',
      positionX: _normalized(json['position_x']),
      positionY: _normalized(json['position_y']),
      hp: (json['hp'] as num).toInt(),
      maxHp: (json['max_hp'] as num).toInt(),
      status: EnemyStatusJson.fromJson(json['status']),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
      createdAt: _optionalDate(json['created_at']),
      updatedAt: _optionalDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'name': name,
      'enemy_type': enemyType,
      'position_x': positionX,
      'position_y': positionY,
      'hp': hp,
      'max_hp': maxHp,
      'status': status.toJson(),
      'metadata': metadata,
    };
  }

  static double _normalized(Object? value) {
    final number = (value as num).toDouble();
    if (number < 0 || number > 1) {
      throw ArgumentError('Normalized position must be between 0 and 1');
    }
    return number;
  }

  static DateTime? _optionalDate(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
