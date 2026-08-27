import 'package:dragons_lair/features/dice/domain/dice_roll_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rolls supported dice inside bounds', () {
    final service = DiceRollService();

    final roll = service.roll(count: 2, sides: 6);

    expect(roll.values, hasLength(2));
    expect(roll.values.every((value) => value >= 1 && value <= 6), isTrue);
    expect(roll.total, greaterThanOrEqualTo(2));
    expect(roll.notation, '2d6');
  });

  test('rejects unsupported dice', () {
    final service = DiceRollService();

    expect(
      () => service.roll(count: 1, sides: 13),
      throwsA(isA<ArgumentError>()),
    );
  });
}
