import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../events/domain/game_event.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../events/presentation/game_journal.dart';
import '../../game/presentation/action_panel.dart';
import '../../game/presentation/game_hud_button.dart';
import '../../game/presentation/in_game_inventory_view.dart';
import '../../game/presentation/in_game_sheet_view.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_providers.dart';
import 'game_board.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen> {
  var _seededEvents = false;
  final _knownEventIds = <String>{};
  var _journalOpen = false;
  Timer? _openJournalDebounce;

  @override
  void dispose() {
    _openJournalDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playersState = ref.watch(roomPlayersProvider(widget.roomId));
    final currentUser = ref.watch(authControllerProvider).value;
    final room = ref.watch(roomProvider(widget.roomId)).value;
    final paused = room?.status == RoomStatus.paused;
    final isHost =
        currentUser != null && room != null && currentUser.id == room.hostId;

    ref.listen(roomEventsProvider(widget.roomId), (previous, next) {
      final events = next.value;
      if (events == null) {
        return;
      }
      if (!_seededEvents) {
        _knownEventIds
          ..clear()
          ..addAll(events.map((event) => event.id));
        _seededEvents = true;
        return;
      }

      final fresh = events.where((event) {
        return !_knownEventIds.contains(event.id);
      }).toList();
      _knownEventIds
        ..clear()
        ..addAll(events.map((event) => event.id));

      final hasStory = fresh.any((event) {
        return event.type == GameEventType.action ||
            event.type == GameEventType.narration;
      });
      if (hasStory) {
        _scheduleJournalOpen();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(paused ? l10n.gamePaused : l10n.boardTitle),
        actions: [
          if (isHost && !paused)
            IconButton(
              onPressed: _pauseRoom,
              icon: const Icon(Icons.pause_circle_outline),
              tooltip: l10n.pauseGame,
            ),
          if (isHost && paused)
            IconButton(
              onPressed: _resumeRoom,
              icon: const Icon(Icons.play_circle_outline),
              tooltip: l10n.resumeGame,
            ),
          const LanguageButton(),
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
                      if (paused) {
                        return Future.value();
                      }
                      return ref.read(playerRepositoryProvider).updatePosition(
                            playerId: player.id,
                            x: x,
                            y: y,
                          );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      GameHudButton(
                        icon: Icons.badge_outlined,
                        label: l10n.hudSheet,
                        onPressed: currentPlayer == null
                            ? null
                            : () => showGameBook(
                                  context: context,
                                  child: InGameSheetView(
                                    roomId: widget.roomId,
                                    playerId: currentPlayer.id,
                                  ),
                                ),
                      ),
                      GameHudButton(
                        icon: Icons.inventory_2_outlined,
                        label: l10n.hudInventory,
                        onPressed: currentPlayer == null
                            ? null
                            : () => showGameBook(
                                  context: context,
                                  child: InGameInventoryView(
                                    roomId: widget.roomId,
                                    playerId: currentPlayer.id,
                                  ),
                                ),
                      ),
                      GameHudButton(
                        icon: Icons.menu_book,
                        label: l10n.hudJournal,
                        onPressed: _openJournal,
                      ),
                    ],
                  ),
                ),
                ActionPanel(
                  roomId: widget.roomId,
                  currentPlayer: currentPlayer,
                  players: players,
                  paused: paused,
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

  void _scheduleJournalOpen() {
    _openJournalDebounce?.cancel();
    _openJournalDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) {
        _openJournal();
      }
    });
  }

  Future<void> _openJournal() async {
    if (!mounted || _journalOpen) {
      return;
    }
    _journalOpen = true;
    await showGameBook(
      context: context,
      child: GameJournal(roomId: widget.roomId),
    );
    if (mounted) {
      _journalOpen = false;
    }
  }

  Future<void> _pauseRoom() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(roomRepositoryProvider).pauseRoom(widget.roomId);
      await ref.read(gameEventRepositoryProvider).createSystem(
            roomId: widget.roomId,
            content: l10n.gamePaused,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _resumeRoom() async {
    try {
      await ref.read(roomRepositoryProvider).resumeRoom(widget.roomId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
