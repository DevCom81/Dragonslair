enum GameEventType {
  action,
  narration,
  system;

  static GameEventType fromJson(Object? value) {
    return switch (value) {
      'action' => GameEventType.action,
      'narration' => GameEventType.narration,
      'system' => GameEventType.system,
      _ => throw ArgumentError('Unknown game event type: $value'),
    };
  }

  String toJson() => name;
}

class GameEvent {
  const GameEvent({
    required this.id,
    required this.roomId,
    required this.playerId,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String? playerId;
  final GameEventType type;
  final String content;
  final DateTime createdAt;

  factory GameEvent.fromJson(Map<String, dynamic> json) {
    return GameEvent(
      id: json['id'] as String,
      roomId: json['room_id'] as String,
      playerId: json['player_id'] as String?,
      type: GameEventType.fromJson(json['type']),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'room_id': roomId,
      'player_id': playerId,
      'type': type.toJson(),
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
