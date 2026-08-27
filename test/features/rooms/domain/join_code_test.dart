import 'dart:math';

import 'package:dragons_lair/features/rooms/domain/join_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generates a 6 character join code', () {
    final code = JoinCode.generate(Random(1));

    expect(code.length, 6);
    expect(RegExp(r'^[A-Z0-9]+$').hasMatch(code), isTrue);
  });

  test('normalizes typed join codes', () {
    expect(JoinCode.normalize(' ab-c234 '), 'ABC234');
  });
}
