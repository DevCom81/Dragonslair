import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/player_profile.dart';
import '../../auth/domain/profile_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';
import '../../players/domain/player.dart';
import '../../players/presentation/player_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/domain/room_entry.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../domain/figurine_definition.dart';
import 'figurine_picker.dart';

class FigurineSelectionScreen extends ConsumerStatefulWidget {
  const FigurineSelectionScreen({required this.roomId, super.key});

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
  var _didAutoJoin = false;

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(roomProvider(widget.roomId));
    final playersState = ref.watch(roomPlayersProvider(widget.roomId));
    final user = ref.watch(authControllerProvider).value;
    final profileState = ref.watch(currentProfileProvider);

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
                return profileState.when(
                  data: (profile) {
                    return _buildJoinBody(
                      context: context,
                      l10n: l10n,
                      room: room,
                      scenario: scenario,
                      players: players,
                      userId: user?.id,
                      profile: profile,
                    );
                  },
                  error: (error, stackTrace) =>
                      Center(child: Text(error.toString())),
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
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

  Widget _buildJoinBody({
    required BuildContext context,
    required AppLocalizations l10n,
    required Room room,
    required ScenarioDefinition scenario,
    required List<Player> players,
    required String? userId,
    required PlayerProfile? profile,
  }) {
    final alreadyJoined =
        userId != null && players.any((player) => player.userId == userId);
    if (room.status != RoomStatus.waiting) {
      if (alreadyJoined || userId == room.hostId) {
        _redirectMember(room, alreadyJoined, userId == room.hostId);
        return const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        );
      }
      return Center(child: Text(l10n.cannotJoinInProgress));
    }

    final takenFigurines = players.map((player) => player.figurineId).toSet();
    final takenClasses = players
        .map((player) => player.classId)
        .whereType<String>()
        .toSet();
    final classId = profile?.classId;
    final classTaken = classId != null && takenClasses.contains(classId);
    final classAllowed =
        classId != null && scenario.allowedClassIds.contains(classId);
    final preferred = profile?.avatarFigurineId;
    final canUsePreferred =
        userId != null &&
        profile != null &&
        classId != null &&
        classAllowed &&
        !classTaken &&
        preferred != null &&
        !takenFigurines.contains(preferred) &&
        !alreadyJoined;

    if (canUsePreferred && !_didAutoJoin) {
      _tryAutoJoin(userId, profile, FigurineCatalog.byId(preferred));
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }
    if (canUsePreferred && _isSubmitting) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            classId == null
                ? l10n.completeSheetFirst
                : classTaken
                ? l10n.classAlreadyTaken(localizedClassLabel(l10n, classId))
                : classAllowed
                ? l10n.yourClass(localizedClassLabel(l10n, classId))
                : l10n.classNotAllowed,
            style: TextStyle(
              color: classId != null && classAllowed && !classTaken
                  ? null
                  : AppColors.danger,
            ),
          ),
        ),
        Expanded(
          child: FigurinePickerGrid(
            selectedId: _figurineId,
            takenIds: takenFigurines,
            takenLabel: l10n.taken,
            onSelected: (id) {
              setState(() => _figurineId = id);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed:
                userId == null ||
                    profile == null ||
                    classId == null ||
                    !classAllowed ||
                    classTaken ||
                    _figurineId == null ||
                    _isSubmitting
                ? null
                : () => _join(
                    userId,
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
  }

  void _tryAutoJoin(
    String userId,
    PlayerProfile profile,
    FigurineDefinition figurine,
  ) {
    if (_didAutoJoin || _isSubmitting) {
      return;
    }
    _didAutoJoin = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _join(userId, profile, figurine);
    });
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
      await ref
          .read(playerRepositoryProvider)
          .joinRoom(
            roomId: widget.roomId,
            userId: userId,
            figurineId: figurine.id,
            figurineName: profile.displayName,
            classId: classId,
            stats: profile.stats,
          );
      try {
        await ref
            .read(profileRepositoryProvider)
            .upsertAvatar(userId: userId, figurineId: figurine.id);
        ref.invalidate(currentProfileProvider);
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
