enum GameAccessLevel {
  demo,
  full;

  static GameAccessLevel fromJson(Object? value) {
    return switch (value) {
      'full' => GameAccessLevel.full,
      _ => GameAccessLevel.demo,
    };
  }

  String toJson() => name;

  bool get isFull => this == GameAccessLevel.full;
  bool get isDemo => this == GameAccessLevel.demo;
}

class UserEntitlement {
  const UserEntitlement({
    required this.userId,
    this.level = GameAccessLevel.demo,
    this.source = 'default',
  });

  final String userId;
  final GameAccessLevel level;
  final String source;

  factory UserEntitlement.fromJson(Map<String, dynamic> json) {
    return UserEntitlement(
      userId: json['user_id'] as String? ?? '',
      level: GameAccessLevel.fromJson(json['access_level']),
      source: json['source'] as String? ?? 'default',
    );
  }

  static UserEntitlement demoFor(String userId) {
    return UserEntitlement(userId: userId);
  }
}

enum DemoPlayResult {
  ok,
  expired,
  forbidden,
  closed;

  static DemoPlayResult fromJson(Object? value) {
    return switch (value) {
      'expired' => DemoPlayResult.expired,
      'forbidden' => DemoPlayResult.forbidden,
      'closed' => DemoPlayResult.closed,
      _ => DemoPlayResult.ok,
    };
  }
}

class DemoSession {
  const DemoSession({
    required this.userId,
    this.roomId,
    this.startedAt,
    this.expiresAt,
    this.completedAt,
  });

  final String userId;
  final String? roomId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;

  bool get isConsumed => completedAt != null || isExpired;

  bool get isExpired {
    final end = expiresAt;
    if (end == null) {
      return false;
    }
    return !DateTime.now().toUtc().isBefore(end.toUtc());
  }

  bool get canResume =>
      roomId != null && roomId!.isNotEmpty && completedAt == null && !isExpired;

  factory DemoSession.fromJson(Map<String, dynamic> json) {
    return DemoSession(
      userId: json['user_id'] as String? ?? '',
      roomId: json['room_id'] as String?,
      startedAt: _dateTime(json['started_at']),
      expiresAt: _dateTime(json['expires_at']),
      completedAt: _dateTime(json['completed_at']),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
