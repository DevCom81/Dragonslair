const combatRoundMax = 999;

class CombatSession {
  const CombatSession({
    required this.active,
    required this.round,
    this.id,
    this.roomId,
  });

  factory CombatSession.inactive() =>
      const CombatSession(active: false, round: 0);

  final String? id;
  final String? roomId;
  final bool active;
  final int round;

  CombatSession applyStart({int? requestedRound}) {
    if (requestedRound != null) {
      final nextRound = requestedRound < 1
          ? 1
          : (requestedRound > combatRoundMax ? combatRoundMax : requestedRound);
      return CombatSession(
        id: id,
        roomId: roomId,
        active: true,
        round: nextRound,
      );
    }
    if (active) {
      final nextRound = round + 1 > combatRoundMax ? combatRoundMax : round + 1;
      return CombatSession(
        id: id,
        roomId: roomId,
        active: true,
        round: nextRound < 1 ? 1 : nextRound,
      );
    }
    return CombatSession(
      id: id,
      roomId: roomId,
      active: true,
      round: 1,
    );
  }

  CombatSession applyEnd() {
    return CombatSession(
      id: id,
      roomId: roomId,
      active: false,
      round: round,
    );
  }

  static CombatSession? tryParse(Map<String, dynamic> json) {
    final round = (json['round'] as num?)?.toInt();
    if (round == null || round < 0 || round > combatRoundMax) {
      return null;
    }
    final active = json['active'];
    if (active is! bool) {
      return null;
    }
    return CombatSession(
      id: json['id'] as String?,
      roomId: json['room_id'] as String?,
      active: active,
      round: round,
    );
  }

  factory CombatSession.fromJson(Map<String, dynamic> json) {
    final parsed = tryParse(json);
    if (parsed == null) {
      throw ArgumentError('Invalid combat session row.');
    }
    return parsed;
  }
}
