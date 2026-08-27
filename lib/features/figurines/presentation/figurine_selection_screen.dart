import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/domain/player_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../domain/figurine_definition.dart';
import 'figurine_sprite.dart';

class FigurineSelectionScreen extends ConsumerStatefulWidget {
  const FigurineSelectionScreen({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  ConsumerState<FigurineSelectionScreen> createState() =>
      _FigurineSelectionScreenState();
}

class _FigurineSelectionScreenState
    extends ConsumerState<FigurineSelectionScreen> {
  String? _classId;
  int? _figurineId;
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider(widget.roomId));
    final playersState = ref.watch(roomPlayersProvider(widget.roomId));
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(currentProfileProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Figurine et classe')),
      body: SafeArea(
        child: roomState.when(
          data: (room) {
            if (room == null) {
              return const Center(child: Text('Partie introuvable.'));
            }

            final scenario = ScenarioCatalog.byId(room.scenarioId);

            return playersState.when(
              data: (players) {
                final takenFigurines =
                    players.map((player) => player.figurineId).toSet();
                final takenClasses = players
                    .map((player) => player.classId)
                    .whereType<String>()
                    .toSet();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Une classe unique par joueur.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final classId in scenario.allowedClassIds)
                                ChoiceChip(
                                  label: Text(
                                    takenClasses.contains(classId)
                                        ? '${CharacterClassCatalog.byId(classId).label} (prise)'
                                        : CharacterClassCatalog.byId(classId)
                                            .label,
                                  ),
                                  selected: _classId == classId,
                                  onSelected: takenClasses.contains(classId)
                                      ? null
                                      : (_) {
                                          setState(() => _classId = classId);
                                        },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: FigurineCatalog.count,
                        itemBuilder: (context, index) {
                          final figurine = FigurineCatalog.byId(index);
                          final isTaken = takenFigurines.contains(figurine.id);

                          return _FigurineCard(
                            figurine: figurine,
                            isTaken: isTaken,
                            isSelected: _figurineId == figurine.id,
                            onTap: isTaken
                                ? null
                                : () {
                                    setState(() => _figurineId = figurine.id);
                                  },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: FilledButton(
                        onPressed: user == null ||
                                profile == null ||
                                _classId == null ||
                                _figurineId == null ||
                                _isSubmitting
                            ? null
                            : () => _join(
                                  user.id,
                                  profile,
                                  FigurineCatalog.byId(_figurineId!),
                                ),
                        child: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Rejoindre le lobby'),
                      ),
                    ),
                  ],
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

  Future<void> _join(
    String userId,
    PlayerProfile profile,
    FigurineDefinition figurine,
  ) async {
    final classId = _classId;
    if (classId == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(playerRepositoryProvider).joinRoom(
            roomId: widget.roomId,
            userId: userId,
            figurineId: figurine.id,
            figurineName: figurine.name,
            classId: classId,
            stats: profile.stats,
          );
      if (mounted) {
        context.pushNamed('lobby', pathParameters: {'roomId': widget.roomId});
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

class _FigurineCard extends StatelessWidget {
  const _FigurineCard({
    required this.figurine,
    required this.isTaken,
    required this.isSelected,
    required this.onTap,
  });

  final FigurineDefinition figurine;
  final bool isTaken;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: isTaken ? AppColors.surface.withValues(alpha: 0.5) : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? AppColors.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: isTaken ? 0.35 : 1,
                child: FigurineSprite(figurine: figurine, size: 64),
              ),
              const SizedBox(height: 8),
              Text(
                figurine.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (isTaken)
                const Text(
                  'Prise',
                  style: TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
