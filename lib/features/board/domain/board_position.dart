import 'dart:ui';

class BoardPosition {
  const BoardPosition({
    required this.x,
    required this.y,
  });

  final double x;
  final double y;

  Offset toOffset(Size boardSize) {
    return Offset(x * boardSize.width, y * boardSize.height);
  }

  static BoardPosition fromOffset(Offset offset, Size boardSize) {
    final x = boardSize.width == 0 ? 0.5 : offset.dx / boardSize.width;
    final y = boardSize.height == 0 ? 0.5 : offset.dy / boardSize.height;
    return BoardPosition(x: _clamp(x), y: _clamp(y));
  }

  static double _clamp(double value) {
    if (value < 0) {
      return 0;
    }
    if (value > 1) {
      return 1;
    }
    return value;
  }
}
