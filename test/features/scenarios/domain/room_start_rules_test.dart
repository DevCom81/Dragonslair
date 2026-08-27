import 'package:dragons_lair/features/scenarios/domain/room_start_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks start when player count is below minimum', () {
    final issues = RoomStartRules.issues(
      playerCount: 1,
      minPlayers: 3,
      requiredClassIds: const ['cleric'],
      takenClassIds: const ['cleric'],
    );

    expect(issues, hasLength(1));
    expect(issues.single.current, 1);
    expect(issues.single.minimum, 3);
    expect(issues.single.missingClassId, isNull);
  });

  test('blocks start when a required class is missing', () {
    final issues = RoomStartRules.issues(
      playerCount: 3,
      minPlayers: 3,
      requiredClassIds: const ['fighter', 'cleric'],
      takenClassIds: const ['fighter', 'wizard', 'rogue'],
    );

    expect(issues.single.missingClassId, 'cleric');
  });

  test('allows start when min players and required classes are present', () {
    final issues = RoomStartRules.issues(
      playerCount: 3,
      minPlayers: 3,
      requiredClassIds: const ['cleric'],
      takenClassIds: const ['fighter', 'cleric', 'wizard'],
    );

    expect(issues, isEmpty);
  });
}
