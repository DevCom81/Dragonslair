import 'dart:ui';

import 'package:dragons_lair/features/board/domain/board_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts normalized position to board offset', () {
    const position = BoardPosition(x: 0.25, y: 0.75);

    expect(position.toOffset(const Size(400, 800)), const Offset(100, 600));
  });

  test('converts board offset to clamped normalized position', () {
    final position = BoardPosition.fromOffset(
      const Offset(500, -20),
      const Size(400, 800),
    );

    expect(position.x, 1);
    expect(position.y, 0);
  });
}
