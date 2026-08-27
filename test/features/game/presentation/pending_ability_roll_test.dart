import 'package:dragons_lair/features/game/presentation/pending_ability_roll.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _row({
  String status = 'pending',
  int? result,
  int? modifier,
  int? total,
  bool? success,
}) {
  return {
    'id': 'roll-1',
    'room_id': 'room-1',
    'player_id': 'player-b',
    'ability': 'dexterity',
    'dc': 14,
    'reason': 'esquiver le piege',
    'status': status,
    'result': result,
    'modifier': modifier,
    'total': total,
    'success': success,
  };
}

void main() {
  test('parses a realtime pending_rolls row', () {
    final roll = PendingAbilityRoll.fromJson(_row());

    expect(roll.id, 'roll-1');
    expect(roll.playerId, 'player-b');
    expect(roll.abilityKey, 'dexterity');
    expect(roll.dc, 14);
    expect(roll.reason, 'esquiver le piege');
    expect(roll.status, PendingRollStatus.pending);
    expect(roll.isOpen, isTrue);
  });

  test('resolved realtime row is no longer open', () {
    final roll = PendingAbilityRoll.fromJson(
      _row(
        status: 'resolved',
        result: 12,
        modifier: 2,
        total: 14,
        success: true,
      ),
    );

    expect(roll.status, PendingRollStatus.resolved);
    expect(roll.result, 12);
    expect(roll.modifier, 2);
    expect(roll.total, 14);
    expect(roll.success, isTrue);
    expect(roll.isOpen, isFalse);
  });

  test('tryParse accepts target_id alias used by the GM payload', () {
    final roll = PendingAbilityRoll.tryParse({
      'target_id': 'player-b',
      'stat': 'strength',
      'difficulty': 14,
    });

    expect(roll?.playerId, 'player-b');
    expect(roll?.abilityKey, 'strength');
    expect(roll?.dc, 14);
    expect(roll?.id, isNull);
  });
}
