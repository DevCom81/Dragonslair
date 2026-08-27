import 'package:flutter/material.dart';

import '../../figurines/domain/figurine_definition.dart';
import '../../figurines/presentation/figurine_sprite.dart';
import '../../players/domain/player.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({
    required this.players,
    required this.currentUserId,
    required this.onMovePlayer,
    super.key,
  });

  final List<Player> players;
  final String? currentUserId;
  final Future<void> Function(Player player, double x, double y) onMovePlayer;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  static const _boardAspectRatio = 544 / 786;
  static const _pieceSize = 56.0;

  final Map<String, Offset> _localPositions = {};

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 3,
      child: Center(
        child: AspectRatio(
          aspectRatio: _boardAspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boardSize = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );

              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('Assets/Plateau.png', fit: BoxFit.fill),
                  for (final player in widget.players)
                    _PlayerPiece(
                      player: player,
                      boardSize: boardSize,
                      localPosition: _localPositions[player.id],
                      canMove: player.userId == widget.currentUserId,
                      onDrag: (delta) => _moveLocally(player, delta, boardSize),
                      onDragEnd: () => _persistPosition(player, boardSize),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _moveLocally(Player player, Offset delta, Size boardSize) {
    final current = _localPositions[player.id] ??
        Offset(
          player.positionX * boardSize.width,
          player.positionY * boardSize.height,
        );
    final next = Offset(
      (current.dx + delta.dx).clamp(0, boardSize.width).toDouble(),
      (current.dy + delta.dy).clamp(0, boardSize.height).toDouble(),
    );

    setState(() {
      _localPositions[player.id] = next;
    });
  }

  Future<void> _persistPosition(Player player, Size boardSize) async {
    final position = _localPositions[player.id];
    if (position == null) {
      return;
    }

    final x = boardSize.width == 0 ? 0.5 : position.dx / boardSize.width;
    final y = boardSize.height == 0 ? 0.5 : position.dy / boardSize.height;

    await widget.onMovePlayer(
      player,
      x.clamp(0, 1).toDouble(),
      y.clamp(0, 1).toDouble(),
    );
  }
}

class _PlayerPiece extends StatelessWidget {
  const _PlayerPiece({
    required this.player,
    required this.boardSize,
    required this.localPosition,
    required this.canMove,
    required this.onDrag,
    required this.onDragEnd,
  });

  final Player player;
  final Size boardSize;
  final Offset? localPosition;
  final bool canMove;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final position = localPosition ??
        Offset(
          player.positionX * boardSize.width,
          player.positionY * boardSize.height,
        );

    return Positioned(
      left: position.dx - _GameBoardState._pieceSize / 2,
      top: position.dy - _GameBoardState._pieceSize / 2,
      child: GestureDetector(
        onPanUpdate: canMove ? (details) => onDrag(details.delta) : null,
        onPanEnd: canMove ? (_) => onDragEnd() : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: canMove ? Colors.amber : Colors.white54,
              width: 2,
            ),
          ),
          child: FigurineSprite(
            figurine: FigurineCatalog.byId(player.figurineId),
            size: _GameBoardState._pieceSize,
          ),
        ),
      ),
    );
  }
}
