import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../figurines/domain/figurine_definition.dart';
import '../../figurines/presentation/figurine_sprite.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/room_start_rules.dart';
import '../../scenarios/domain/scenario_definition.dart';

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
      appBar: AppBar(title: const Text('Lobby')),
      body: SafeArea(
        child: roomState.when(
          data: (room) {
            if (room == null) {
              return const Center(child: Text('Partie introuvable.'));
            }

            final isHost = user != null && user.id == room.hostId;

            return playersState.when(
              data: (players) {
                final reasons = RoomStartRules.blockingReasons(
                  playerCount: players.length,
                  minPlayers: room.minPlayers,
                  requiredClassIds: room.requiredClassIds,
                  takenClassIds: players.map((player) => player.classId),
                );
                final canStart = isHost && reasons.isEmpty;

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
                                'Code: ${room.joinCode}',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                            if (room.scenario != null &&
                                room.scenario!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${room.scenario} · min ${room.minPlayers} joueurs',
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              'Joueurs',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            if (players.isEmpty)
                              const Text('En attente de joueurs.'),
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
                                      CharacterClassCatalog.byId(
                                        player.classId!,
                                      ).label,
                                    'PV ${player.hp}',
                                  ].join(' · '),
                                ),
                              ),
                              const Divider(),
                            ],
                            if (reasons.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              for (final reason in reasons)
                                Text(
                                  reason,
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
                          isHost
                              ? 'Demarrer la partie'
                              : 'En attente du host',
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
