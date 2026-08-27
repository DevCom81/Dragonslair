import 'package:dragons_lair/features/combat/domain/combat_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses a realtime combat_sessions row', () {
    final combat = CombatSession.fromJson({
      'id': 'c1',
      'room_id': 'r1',
      'active': true,
      'round': 2,
    });

    expect(combat.id, 'c1');
    expect(combat.roomId, 'r1');
    expect(combat.active, isTrue);
    expect(combat.round, 2);
  });

  test('start from inactive is round 1', () {
    final next = CombatSession.inactive().applyStart();
    expect(next.active, isTrue);
    expect(next.round, 1);
  });

  test('start while active increments round', () {
    final next = const CombatSession(active: true, round: 1).applyStart();
    expect(next.round, 2);
  });

  test('explicit round overrides increment', () {
    final next = const CombatSession(
      active: true,
      round: 2,
    ).applyStart(requestedRound: 4);
    expect(next.round, 4);
  });

  test('end keeps round and deactivates', () {
    final next = const CombatSession(active: true, round: 3).applyEnd();
    expect(next.active, isFalse);
    expect(next.round, 3);
  });

  test('tryParse rejects invalid round', () {
    expect(
      CombatSession.tryParse({'active': true, 'round': 1000}),
      isNull,
    );
  });
}
