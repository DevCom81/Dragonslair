import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/player_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/domain/room_entry.dart';
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
  int? _figurineId;
  var _isSubmitting = false;
  var _didRedirect = false;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider(widget.roomId));
    final playersState = ref.watch(roomPlayersProvider(widget.roomId));
    final user = ref.watch(authControllerProvider).value;
    final profile = ref.watch(currentProfileProvider).value;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chooseFigurine)),
      body: SafeArea(
        child: roomState.when(
          data: (room) {
            if (room == null) {
              return Center(child: Text(l10n.roomNotFound));
            }

            final scenario = ScenarioCatalog.byId(room.scenarioId);

            return playersState.when(
              data: (players) {
                final alreadyJoined = user != null &&
                    players.any((player) => player.userId == user.id);
                if (room.status != RoomStatus.waiting) {
                  if (alreadyJoined || user?.id == room.hostId) {
                    _redirectMember(room, alreadyJoined, user?.id == room.hostId);
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    );
                  }
                  return Center(child: Text(l10n.cannotJoinInProgress));
                }
                final takenFigurines =
                    players.map((player) => player.figurineId).toSet();
                final takenClasses = players
                    .map((player) => player.classId)
                    .whereType<String>()
                    .toSet();
                final classId = profile?.classId;
                final classTaken =
                    classId != null && takenClasses.contains(classId);
                final classAllowed = classId != null &&
                    scenario.allowedClassIds.contains(classId);

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        classId == null
                            ? l10n.completeSheetFirst
                            : classTaken
                                ? l10n.classAlreadyTaken(
                                    localizedClassLabel(l10n, classId),
                                  )
                                : classAllowed
                                    ? l10n.yourClass(
                                        localizedClassLabel(l10n, classId),
                                      )
                                    : l10n.classNotAllowed,
                        style: TextStyle(
                          color: classId != null && classAllowed && !classTaken
                              ? null
                              : AppColors.danger,
                        ),
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: context.responsiveValue(
                            compact: 3,
                            medium: 4,
                            expanded: 6,
                          ),
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
                            takenLabel: l10n.taken,
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
                                classId == null ||
                                !classAllowed ||
                                classTaken ||
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
                            : Text(l10n.joinLobby),
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

  void _redirectMember(Room room, bool alreadyJoined, bool isHost) {
    if (_didRedirect) {
      return;
    }
    _didRedirect = true;
    final action = resolveRoomEntry(
      status: room.status,
      alreadyJoined: alreadyJoined,
      isHost: isHost,
    );
    final routeName = routeNameFor(action);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || routeName == null) {
        return;
      }
      context.pushReplacementNamed(
        routeName,
        pathParameters: {'roomId': widget.roomId},
      );
    });
  }

  Future<void> _join(
    String userId,
    PlayerProfile profile,
    FigurineDefinition figurine,
  ) async {
    final classId = profile.classId;
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
    required this.takenLabel,
    required this.onTap,
  });

  final FigurineDefinition figurine;
  final bool isTaken;
  final bool isSelected;
  final String takenLabel;
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
                Text(
                  takenLabel,
                  style: const TextStyle(color: AppColors.danger),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
