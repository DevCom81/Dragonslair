class RoomStartIssue {
  const RoomStartIssue.notEnoughPlayers({
    required this.current,
    required this.minimum,
  }) : missingClassId = null;

  const RoomStartIssue.missingClass(this.missingClassId)
      : current = 0,
        minimum = 0;

  final int current;
  final int minimum;
  final String? missingClassId;
}

class RoomStartRules {
  const RoomStartRules._();

  static List<RoomStartIssue> issues({
    required int playerCount,
    required int minPlayers,
    required List<String> requiredClassIds,
    required Iterable<String?> takenClassIds,
  }) {
    final issues = <RoomStartIssue>[];
    if (playerCount < minPlayers) {
      issues.add(
        RoomStartIssue.notEnoughPlayers(
          current: playerCount,
          minimum: minPlayers,
        ),
      );
    }

    final taken = takenClassIds.whereType<String>().toSet();
    for (final classId in requiredClassIds) {
      if (!taken.contains(classId)) {
        issues.add(RoomStartIssue.missingClass(classId));
      }
    }

    return issues;
  }
}
