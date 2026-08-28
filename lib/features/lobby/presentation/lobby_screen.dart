import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../music/presentation/music_controller.dart';
import '../../figurines/domain/figurine_definition.dart';
import '../../figurines/presentation/figurine_sprite.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/room_start_rules.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomState = ref.watch(roomProvider(roomId));
    final playersState = ref.watch(roomPlayersProvider(roomId));
    final user = ref.watch(authControllerProvider).value;

    ref.listen(roomProvider(roomId), (_, next) {
      final room = next.value;
      final isOnLobby = GoRouterState.of(context).name == 'lobby';
      if (room?.status == RoomStatus.playing && isOnLobby && context.mounted) {
        context.pushReplacementNamed(
          'board',
          pathParameters: {'roomId': roomId},
        );
      }
      if (room?.status.isClosed == true && isOnLobby && context.mounted) {
        context.pushReplacementNamed(
          'summary',
          pathParameters: {'roomId': roomId},
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).lobbyTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: roomState.when(
          data: (room) {
            if (room == null) {
              return Center(
                child: Text(AppLocalizations.of(context).roomNotFound),
              );
            }

            final isHost = user != null && user.id == room.hostId;

            return playersState.when(
              data: (players) {
                final l10n = AppLocalizations.of(context);
                final startIssues = RoomStartRules.issues(
                  playerCount: players.length,
                  minPlayers: room.minPlayers,
                  requiredClassIds: room.requiredClassIds,
                  takenClassIds: players.map((player) => player.classId),
                );
                final isPaused = room.status == RoomStatus.paused;
                final canStart =
                    isHost &&
                    startIssues.isEmpty &&
                    room.status == RoomStatus.waiting;
                final canResume = isHost && isPaused;
                final scenarioLabel = localizedScenarioName(
                  l10n,
                  room.scenarioId,
                  customTitle: room.scenario,
                );

                final info = _LobbyInfo(
                  name: room.name,
                  joinCode: room.joinCode,
                  scenarioLine:
                      room.scenarioId != null ||
                          (room.scenario != null && room.scenario!.isNotEmpty)
                      ? l10n.scenarioMinPlayersLine(
                          scenarioLabel,
                          room.minPlayers,
                        )
                      : null,
                  paused: isPaused,
                  pausedLabel: l10n.gamePaused,
                );
                final playerTiles = _LobbyPlayers(
                  playersTitle: l10n.players,
                  emptyLabel: l10n.waitingForPlayers,
                  players: players,
                );
                final issues = _LobbyIssues(
                  issues: room.status == RoomStatus.waiting
                      ? startIssues
                      : const [],
                );
                final startButton = FilledButton(
                  onPressed: isPaused
                      ? (canResume ? () => _resumeRoom(context, ref) : null)
                      : (canStart ? () => _startRoom(context, ref) : null),
                  child: Text(
                    isPaused
                        ? (isHost ? l10n.resumeGame : l10n.waitingForHostResume)
                        : (isHost ? l10n.startGame : l10n.waitingForHost),
                  ),
                );

                return Padding(
                  padding: context.pagePadding,
                  child: ResponsiveLayout(
                    compact: _CompactLobby(
                      info: info,
                      players: playerTiles,
                      footer: issues,
                      startButton: startButton,
                    ),
                    medium: _MediumLobby(
                      info: info,
                      players: playerTiles,
                      footer: issues,
                      startButton: startButton,
                    ),
                    expanded: _ExpandedLobby(
                      info: info,
                      players: playerTiles,
                      footer: issues,
                      startButton: startButton,
                    ),
                  ),
                );
              },
              error: (error, stackTrace) =>
                  Center(child: Text(error.toString())),
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
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

  Future<void> _startRoom(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(musicControllerProvider.notifier).unlock();
      await ref.read(roomRepositoryProvider).startRoom(roomId);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _resumeRoom(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(musicControllerProvider.notifier).unlock();
      await ref.read(roomRepositoryProvider).resumeRoom(roomId);
    } catch (error) {
      if (context.mounted) {
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

class _LobbyInfo extends StatelessWidget {
  const _LobbyInfo({
    required this.name,
    required this.joinCode,
    required this.scenarioLine,
    required this.paused,
    required this.pausedLabel,
  });

  final String name;
  final String? joinCode;
  final String? scenarioLine;
  final bool paused;
  final String pausedLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(name, style: Theme.of(context).textTheme.titleLarge),
        if (joinCode != null && joinCode!.isNotEmpty) ...[
          const SizedBox(height: 8),
          SelectableText(
            l10n.codeLabel(joinCode!),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        if (scenarioLine != null) ...[
          const SizedBox(height: 8),
          Text(scenarioLine!),
        ],
        if (paused) ...[
          const SizedBox(height: 8),
          Text(pausedLabel, style: const TextStyle(color: AppColors.gold)),
        ],
      ],
    );
  }
}

class _LobbyPlayers extends StatelessWidget {
  const _LobbyPlayers({
    required this.playersTitle,
    required this.emptyLabel,
    required this.players,
  });

  final String playersTitle;
  final String emptyLabel;
  final List<Player> players;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(playersTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (players.isEmpty) Text(emptyLabel),
        for (final player in players) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FigurineSprite(
              figurine: FigurineCatalog.byId(player.figurineId),
              size: 40,
            ),
            title: Text(player.figurineName),
            subtitle: Text(
              [
                if (player.classId != null)
                  localizedClassLabel(l10n, player.classId!),
                l10n.hpLabel(player.hp),
              ].join(' · '),
            ),
          ),
          const Divider(),
        ],
      ],
    );
  }
}

class _LobbyIssues extends StatelessWidget {
  const _LobbyIssues({required this.issues});

  final List<RoomStartIssue> issues;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (issues.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final issue in issues)
          Text(
            issue.missingClassId != null
                ? l10n.missingRequiredClass(
                    localizedClassLabel(l10n, issue.missingClassId!),
                  )
                : l10n.notEnoughPlayers(issue.current, issue.minimum),
            style: const TextStyle(color: AppColors.danger),
          ),
      ],
    );
  }
}

class _CompactLobby extends StatelessWidget {
  const _CompactLobby({
    required this.info,
    required this.players,
    required this.footer,
    required this.startButton,
  });

  final Widget info;
  final Widget players;
  final Widget footer;
  final Widget startButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            children: [info, const SizedBox(height: 16), players, footer],
          ),
        ),
        startButton,
      ],
    );
  }
}

class _MediumLobby extends StatelessWidget {
  const _MediumLobby({
    required this.info,
    required this.players,
    required this.footer,
    required this.startButton,
  });

  final Widget info;
  final Widget players;
  final Widget footer;
  final Widget startButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: ListView(children: [players])),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: 16),
              footer,
              const Spacer(),
              startButton,
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpandedLobby extends StatelessWidget {
  const _ExpandedLobby({
    required this.info,
    required this.players,
    required this.footer,
    required this.startButton,
  });

  final Widget info;
  final Widget players;
  final Widget footer;
  final Widget startButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(children: [info, const SizedBox(height: 16), footer]),
        ),
        const SizedBox(width: 24),
        Expanded(flex: 2, child: ListView(children: [players])),
        const SizedBox(width: 24),
        SizedBox(
          width: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const Spacer(), startButton],
          ),
        ),
      ],
    );
  }
}
