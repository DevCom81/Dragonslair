import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../events/presentation/game_journal.dart';
import '../../game/presentation/action_panel.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import 'game_board.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersState = ref.watch(roomPlayersProvider(roomId));
    final currentUser = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plateau'),
        actions: [
          IconButton(
            onPressed: () => _showJournal(context),
            icon: const Icon(Icons.menu_book),
          ),
        ],
      ),
      body: SafeArea(
        child: playersState.when(
          data: (players) {
            final currentPlayer = _findCurrentPlayer(players, currentUser?.id);

            return Column(
              children: [
                Expanded(
                  child: GameBoard(
                    players: players,
                    currentUserId: currentUser?.id,
                    onMovePlayer: (player, x, y) {
                      return ref.read(playerRepositoryProvider).updatePosition(
                            playerId: player.id,
                            x: x,
                            y: y,
                          );
                    },
                  ),
                ),
                ActionPanel(
                  roomId: roomId,
                  currentPlayer: currentPlayer,
                  players: players,
                ),
              ],
            );
          },
          error: (error, stackTrace) => Center(child: Text(error.toString())),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        ),
      ),
    );
  }

  Player? _findCurrentPlayer(List<Player> players, String? userId) {
    if (userId == null) {
      return null;
    }

    for (final player in players) {
      if (player.userId == userId) {
        return player;
      }
    }

    return null;
  }

  void _showJournal(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => GameJournal(roomId: roomId),
    );
  }
}
