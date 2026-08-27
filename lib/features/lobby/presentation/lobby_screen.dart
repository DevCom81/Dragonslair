import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../figurines/domain/figurine_definition.dart';
import '../../figurines/presentation/figurine_sprite.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/room_start_rules.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({
    required this.roomId,
    super.key,
  });

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
                final canStart = isHost && startIssues.isEmpty;
                final scenarioLabel = localizedScenarioName(
                  l10n,
                  room.scenarioId,
                );

                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ListView(
                          children: [
                            Text(
                              room.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (room.joinCode != null &&
                                room.joinCode!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              SelectableText(
                                l10n.codeLabel(room.joinCode!),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                            if (room.scenarioId != null ||
                                (room.scenario != null &&
                                    room.scenario!.isNotEmpty)) ...[
                              const SizedBox(height: 8),
                              Text(
                                l10n.scenarioMinPlayersLine(
                                  scenarioLabel,
                                  room.minPlayers,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              l10n.players,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (players.isEmpty)
                              Text(l10n.waitingForPlayers),
                            for (final player in players) ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: FigurineSprite(
                                  figurine:
                                      FigurineCatalog.byId(player.figurineId),
                                  size: 40,
                                ),
                                title: Text(player.figurineName),
                                subtitle: Text(
                                  [
                                    if (player.classId != null)
                                      localizedClassLabel(
                                        l10n,
                                        player.classId!,
                                      ),
                                    l10n.hpLabel(player.hp),
                                  ].join(' · '),
                                ),
                              ),
                              const Divider(),
                            ],
                            if (startIssues.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final issue in startIssues)
                                Text(
                                  issue.missingClassId != null
                                      ? l10n.missingRequiredClass(
                                          localizedClassLabel(
                                            l10n,
                                            issue.missingClassId!,
                                          ),
                                        )
                                      : l10n.notEnoughPlayers(
                                          issue.current,
                                          issue.minimum,
                                        ),
                                  style: const TextStyle(color: AppColors.danger),
                                ),
                            ],
                          ],
                        ),
                      ),
                      FilledButton(
                        onPressed: canStart
                            ? () => _startRoom(context, ref)
                            : null,
                        child: Text(
                          isHost ? l10n.startGame : l10n.waitingForHost,
                        ),
                      ),
                    ],
                  ),
                );
              },
              error: (error, stackTrace) => Center(child: Text(error.toString())),
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
}
