import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/presentation/access_providers.dart';
import '../../access/presentation/demo_timer_hud.dart';
import '../../access/presentation/purchase_flow.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../combat/presentation/combat_providers.dart';
import '../../enemies/presentation/enemy_providers.dart';
import '../../events/domain/game_event.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../events/presentation/game_journal.dart';
import '../../game/presentation/action_panel.dart';
import '../../game/presentation/game_hud_button.dart';
import '../../game/presentation/game_session_layout.dart';
import '../../game/presentation/in_game_inventory_view.dart';
import '../../game/presentation/in_game_sheet_view.dart';
import '../../music/presentation/music_controller.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/scenario_definition.dart';
import 'game_board.dart';

class BoardScreen extends ConsumerStatefulWidget {
  const BoardScreen({required this.roomId, super.key});

  final String roomId;

  @override
  ConsumerState<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends ConsumerState<BoardScreen>
    with WidgetsBindingObserver {
  var _seededEvents = false;
  final _knownEventIds = <String>{};
  var _journalOpen = false;
  Timer? _openJournalDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _syncSceneMusic();
      if (!kIsWeb) {
        ref.read(musicControllerProvider.notifier).unlock();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openJournalDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(currentEntitlementProvider);
      ref.invalidate(currentDemoSessionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final playersState = ref.watch(roomPlayersProvider(widget.roomId));
    final currentUser = ref.watch(authControllerProvider).value;
    final room = ref.watch(roomProvider(widget.roomId)).value;
    final paused = room?.status == RoomStatus.paused;
    final finished = room?.status.isClosed ?? false;
    final isHost =
        currentUser != null && room != null && currentUser.id == room.hostId;
    final showDemoTimer =
        (room?.scenarioId == ScenarioCatalog.demo.id) &&
        (ref.watch(currentEntitlementProvider).value?.level.isDemo ?? false);

    ref.listen(roomProvider(widget.roomId), (previous, next) {
      if (previous?.value?.status != next.value?.status) {
        ref.invalidate(currentDemoSessionProvider);
      }
      final nextRoom = next.value;
      if (nextRoom?.status.isClosed == true &&
          context.mounted &&
          GoRouterState.of(context).name == 'board') {
        ref.read(musicControllerProvider.notifier).stop();
        context.pushReplacementNamed(
          'summary',
          pathParameters: {'roomId': widget.roomId},
        );
        return;
      }
      _syncSceneMusic();
    });

    if (AppConfig.isGameMasterRemote) {
      ref.listen(roomCombatProvider(widget.roomId), (previous, next) {
        _syncSceneMusic();
      });
    } else {
      ref.listen(localCombatProvider, (previous, next) {
        _syncSceneMusic();
      });
    }

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
      if (hasStory && context.mounted && context.isCompact) {
        _scheduleJournalOpen();
      }
    });

    return Listener(
      onPointerDown: (_) {
        ref.read(musicControllerProvider.notifier).primeFromUserGesture();
      },
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _unfocusIfIdle,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                finished
                    ? l10n.gameSummaryTitle
                    : (paused ? l10n.gamePaused : l10n.boardTitle),
              ),
              actions: [
                if (isHost && !paused && !finished)
                  IconButton(
                    onPressed: _pauseRoom,
                    icon: const Icon(Icons.pause_circle_outline),
                    tooltip: l10n.pauseGame,
                  ),
                if (isHost && paused && !finished)
                  IconButton(
                    onPressed: _resumeRoom,
                    icon: const Icon(Icons.play_circle_outline),
                    tooltip: l10n.resumeGame,
                  ),
                if (isHost && !finished)
                  IconButton(
                    onPressed: _finishRoom,
                    icon: const Icon(Icons.flag_outlined),
                    tooltip: l10n.finishGame,
                  ),
                const LanguageButton(),
              ],
            ),
            body: SafeArea(
              child: playersState.when(
                data: (players) {
                  final currentPlayer = _currentPlayer(
                    players,
                    currentUser?.id,
                  );
                  final enemies =
                      ref.watch(roomEnemiesProvider(widget.roomId)).value ??
                      const [];

                  return GameSessionLayout(
                    sheetLabel: l10n.hudSheet,
                    inventoryLabel: l10n.hudInventory,
                    board: GameBoard(
                      players: players,
                      enemies: enemies,
                      currentUserId: currentUser?.id,
                      onMovePlayer: (player, x, y) {
                        if (paused || finished) {
                          return Future.value();
                        }
                        if (player.userId != currentUser?.id) {
                          return Future.value();
                        }
                        return ref
                            .read(playerRepositoryProvider)
                            .updatePosition(playerId: player.id, x: x, y: y);
                      },
                    ),
                    journal: GameJournal(roomId: widget.roomId),
                    sheet: currentPlayer == null
                        ? Center(child: Text(l10n.inGameSheetTitle))
                        : InGameSheetView(
                            roomId: widget.roomId,
                            playerId: currentPlayer.id,
                          ),
                    inventory: currentPlayer == null
                        ? Center(child: Text(l10n.emptyInventory))
                        : InGameInventoryView(
                            roomId: widget.roomId,
                            playerId: currentPlayer.id,
                          ),
                    actions: ActionPanel(
                      roomId: widget.roomId,
                      currentPlayer: currentPlayer,
                      players: players,
                      paused: paused || finished,
                    ),
                    hud: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDemoTimer)
                          DemoTimerBanner(
                            roomPaused: paused,
                            onUnlock: () =>
                                startUnlockCheckout(context: context, ref: ref),
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
                                    : () => _openSheet(currentPlayer),
                              ),
                              GameHudButton(
                                icon: Icons.inventory_2_outlined,
                                label: l10n.hudInventory,
                                onPressed: currentPlayer == null
                                    ? null
                                    : () => _openInventory(currentPlayer),
                              ),
                              if (context.isCompact)
                                GameHudButton(
                                  icon: Icons.menu_book,
                                  label: l10n.hudJournal,
                                  onPressed: _openJournal,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                error: (error, stackTrace) =>
                    Center(child: Text(error.toString())),
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _syncSceneMusic() {
    final room = ref.read(roomProvider(widget.roomId)).value;
    if (room == null) {
      return;
    }
    unawaited(
      ref.read(musicControllerProvider.notifier).syncScene(
        narrativeMood: room.musicMood,
        combatActive: readActiveCombat(ref, widget.roomId).active,
      ),
    );
  }

  Player? _currentPlayer(List<Player>? players, String? userId) {
    if (players == null || userId == null) {
      return null;
    }
    for (final player in players) {
      if (player.userId == userId) {
        return player;
      }
    }
    return null;
  }

  bool _isEditingText() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) {
      return false;
    }
    return focusContext.widget is EditableText ||
        focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  void _unfocusIfIdle() {
    if (_isEditingText()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
    if (!mounted || _journalOpen || !context.isCompact) {
      return;
    }
    _journalOpen = true;
    await showGameBook(
      context: context,
      child: GameJournal(roomId: widget.roomId, closeOnChoice: true),
    );
    if (mounted) {
      _journalOpen = false;
    }
  }

  Future<void> _openSheet(Player player) {
    return showGameBook(
      context: context,
      child: InGameSheetView(roomId: widget.roomId, playerId: player.id),
    );
  }

  Future<void> _openInventory(Player player) {
    return showGameBook(
      context: context,
      child: InGameInventoryView(roomId: widget.roomId, playerId: player.id),
    );
  }

  Future<void> _pauseRoom() async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(roomRepositoryProvider).pauseRoom(widget.roomId);
      ref.invalidate(currentDemoSessionProvider);
      await ref
          .read(gameEventRepositoryProvider)
          .createSystem(roomId: widget.roomId, content: l10n.gamePaused);
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
      ref.invalidate(currentDemoSessionProvider);
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

  Future<void> _finishRoom() async {
    final l10n = AppLocalizations.of(context);
    var result = 'neutral';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(l10n.finishGameTitle),
              content: RadioGroup<String>(
                groupValue: result,
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => result = value);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.finishGameBody),
                    RadioListTile<String>(
                      value: 'victory',
                      title: Text(l10n.gameResultVictory),
                    ),
                    RadioListTile<String>(
                      value: 'defeat',
                      title: Text(l10n.gameResultDefeat),
                    ),
                    RadioListTile<String>(
                      value: 'neutral',
                      title: Text(l10n.gameResultNeutral),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.guestWarningCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.finishGame),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await ref
          .read(roomRepositoryProvider)
          .finishRoom(roomId: widget.roomId, result: result);
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
