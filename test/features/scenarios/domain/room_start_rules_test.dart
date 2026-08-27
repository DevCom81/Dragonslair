import 'package:dragons_lair/features/scenarios/domain/room_start_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blocks start when player count is below minimum', () {
    final reasons = RoomStartRules.blockingReasons(
      playerCount: 1,
      minPlayers: 3,
      requiredClassIds: const ['healer'],
      takenClassIds: const ['healer'],
    );

    expect(reasons, ['Joueurs insuffisants (1 / 3).']);
  });

  test('blocks start when a required class is missing', () {
    final reasons = RoomStartRules.blockingReasons(
      playerCount: 3,
      minPlayers: 3,
      requiredClassIds: const ['warrior', 'healer'],
      takenClassIds: const ['warrior', 'mage', 'rogue'],
    );

    expect(reasons, ['Classe obligatoire manquante : Soigneur.']);
  });

  test('allows start when min players and required classes are present', () {
    final reasons = RoomStartRules.blockingReasons(
      playerCount: 3,
      minPlayers: 3,
      requiredClassIds: const ['healer'],
      takenClassIds: const ['warrior', 'healer', 'mage'],
    );

    expect(reasons, isEmpty);
  });
}
