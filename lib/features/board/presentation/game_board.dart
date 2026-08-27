import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../enemies/domain/enemy.dart';
import '../../enemies/presentation/enemy_token.dart';
import '../../figurines/domain/figurine_definition.dart';
import '../../figurines/presentation/figurine_sprite.dart';
import '../../players/domain/player.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({
    required this.players,
    required this.currentUserId,
    required this.onMovePlayer,
    this.enemies = const [],
    super.key,
  });

  final List<Player> players;
  final List<Enemy> enemies;
  final String? currentUserId;
  final Future<void> Function(Player player, double x, double y) onMovePlayer;

  static const aspectRatio = 544 / 786;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  final Map<String, Offset> _localPositions = {};
  final _transform = TransformationController();
  var _grabbing = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is! PointerScrollEvent) {
          return;
        }
        final delta = event.scrollDelta.dy;
        if (delta == 0) {
          return;
        }
        final scale = delta > 0 ? 0.92 : 1.08;
        final next = _transform.value.clone()
          ..scaleByDouble(scale, scale, scale, 1);
        final currentScale = next.getMaxScaleOnAxis();
        if (currentScale < 0.8 || currentScale > 3) {
          return;
        }
        _transform.value = next;
      },
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 0.8,
        maxScale: 3,
        trackpadScrollCausesScale: true,
        panEnabled: true,
        scaleEnabled: true,
        child: Center(
          child: AspectRatio(
            aspectRatio: GameBoard.aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final boardSize = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                final pieceSize = (boardSize.shortestSide * 0.09).clamp(40.0, 64.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    const Image(
                      image: AssetImage('Assets/Plateau.png'),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                    for (final player in widget.players)
                      _PlayerPiece(
                        player: player,
                        boardSize: boardSize,
                        pieceSize: pieceSize,
                        localPosition: _localPositions[player.id],
                        canMove: player.userId == widget.currentUserId,
                        grabbing: _grabbing,
                        onDragStart: () => setState(() => _grabbing = true),
                        onDrag: (delta) => _moveLocally(player, delta, boardSize),
                        onDragEnd: () {
                          setState(() => _grabbing = false);
                          _persistPosition(player, boardSize);
                        },
                      ),
                    for (final enemy in widget.enemies)
                      _EnemyPiece(
                        enemy: enemy,
                        boardSize: boardSize,
                        pieceSize: pieceSize,
                      ),
                  ],
                );
              },
            ),
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
    required this.pieceSize,
    required this.localPosition,
    required this.canMove,
    required this.grabbing,
    required this.onDragStart,
    required this.onDrag,
    required this.onDragEnd,
  });

  final Player player;
  final Size boardSize;
  final double pieceSize;
  final Offset? localPosition;
  final bool canMove;
  final bool grabbing;
  final VoidCallback onDragStart;
  final ValueChanged<Offset> onDrag;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final position = localPosition ??
        Offset(
          player.positionX * boardSize.width,
          player.positionY * boardSize.height,
        );

    final piece = DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: canMove ? Colors.amber : Colors.white54,
          width: 2,
        ),
      ),
      child: FigurineSprite(
        figurine: FigurineCatalog.byId(player.figurineId),
        size: pieceSize,
      ),
    );

    return Positioned(
      left: position.dx - pieceSize / 2,
      top: position.dy - pieceSize / 2,
      child: MouseRegion(
        cursor: canMove
            ? (grabbing ? SystemMouseCursors.grabbing : SystemMouseCursors.grab)
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onPanStart: canMove ? (_) => onDragStart() : null,
          onPanUpdate: canMove ? (details) => onDrag(details.delta) : null,
          onPanEnd: canMove ? (_) => onDragEnd() : null,
          child: piece,
        ),
      ),
    );
  }
}

class _EnemyPiece extends StatelessWidget {
  const _EnemyPiece({
    required this.enemy,
    required this.boardSize,
    required this.pieceSize,
  });

  final Enemy enemy;
  final Size boardSize;
  final double pieceSize;

  @override
  Widget build(BuildContext context) {
    final left = enemy.positionX * boardSize.width - pieceSize / 2;
    final top = enemy.positionY * boardSize.height - pieceSize / 2;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: EnemyToken(enemy: enemy, size: pieceSize),
      ),
    );
  }
}
