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
    final parsed = GameAccessLevel.fromJson(json['access_level']);
    final expiresAt = DemoSession._dateTime(json['expires_at']);
    final expired =
        expiresAt != null && !expiresAt.toUtc().isAfter(DateTime.now().toUtc());
    return UserEntitlement(
      userId: json['user_id'] as String? ?? '',
      level: parsed.isFull && !expired
          ? GameAccessLevel.full
          : GameAccessLevel.demo,
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
    this.pausedAt,
  });

  static const Duration playBudget = Duration(minutes: 10);

  final String userId;
  final String? roomId;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? completedAt;
  final DateTime? pausedAt;

  bool get isConsumed => completedAt != null || isExpired;

  bool get isPaused => pausedAt != null;

  bool get isExpired {
    if (startedAt == null || expiresAt == null) {
      return false;
    }
    return remainingPlayTime() == Duration.zero;
  }

  bool get canResume =>
      roomId != null && roomId!.isNotEmpty && completedAt == null && !isExpired;

  Duration remainingPlayTime([DateTime? now]) {
    if (completedAt != null) {
      return Duration.zero;
    }
    if (startedAt == null || expiresAt == null) {
      return playBudget;
    }
    final clock = (pausedAt ?? now ?? DateTime.now()).toUtc();
    final left = expiresAt!.toUtc().difference(clock);
    if (left.isNegative) {
      return Duration.zero;
    }
    return left;
  }

  factory DemoSession.fromJson(Map<String, dynamic> json) {
    return DemoSession(
      userId: json['user_id'] as String? ?? '',
      roomId: json['room_id'] as String?,
      startedAt: _dateTime(json['started_at']),
      expiresAt: _dateTime(json['expires_at']),
      completedAt: _dateTime(json['completed_at']),
      pausedAt: _dateTime(json['paused_at']),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
