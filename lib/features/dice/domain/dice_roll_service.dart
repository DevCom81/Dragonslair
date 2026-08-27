import 'dart:math';

import 'dice_roll.dart';

class DiceRollService {
  DiceRollService({Random? random}) : _random = random ?? Random();

  static const supportedSides = {4, 6, 8, 10, 12, 20, 100};

  final Random _random;

  DiceRoll roll({
    required int count,
    required int sides,
  }) {
    if (count < 1) {
      throw ArgumentError('Dice count must be positive.');
    }
    if (!supportedSides.contains(sides)) {
      throw ArgumentError('Unsupported dice: d$sides.');
    }

    return DiceRoll(
      count: count,
      sides: sides,
      values: List<int>.generate(count, (_) => _random.nextInt(sides) + 1),
    );
  }
}
