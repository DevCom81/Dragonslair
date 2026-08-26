enum RoomStatus {
  waiting,
  playing,
  finished;

  static RoomStatus fromJson(Object? value) {
    return switch (value) {
      'waiting' => RoomStatus.waiting,
      'playing' => RoomStatus.playing,
      'finished' => RoomStatus.finished,
      _ => throw ArgumentError('Unknown room status: $value'),
    };
  }

  String toJson() => name;
}

class Room {
  const Room({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAt,
    required this.hostId,
    this.scenario,
  });

  final String id;
  final String name;
  final String? scenario;
  final RoomStatus status;
  final DateTime createdAt;
  final String? hostId;

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] as String,
      name: json['name'] as String,
      scenario: json['scenario'] as String?,
      status: RoomStatus.fromJson(json['status']),
      createdAt: DateTime.parse(json['created_at'] as String),
      hostId: json['host_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'scenario': scenario,
      'status': status.toJson(),
      'created_at': createdAt.toIso8601String(),
      'host_id': hostId,
    };
  }
}
