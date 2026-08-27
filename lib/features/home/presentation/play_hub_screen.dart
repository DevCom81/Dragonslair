import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/presentation/access_providers.dart';
import '../../access/presentation/demo_start.dart';
import '../../auth/domain/player_profile.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';
import '../../rooms/domain/room.dart';
import '../../rooms/presentation/room_navigation.dart';
import '../../rooms/presentation/room_providers.dart';

class PlayHubScreen extends ConsumerWidget {
  const PlayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final user = ref.watch(authControllerProvider).value;
    final classLabel = profile?.classId == null
        ? null
        : localizedClassLabel(l10n, profile!.classId!);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tavernTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: context.pagePadding,
                  child: ContentConstraint(
                    child: context.isExpanded
                        ? _ExpandedHub(
                            welcome: _welcomeText(l10n, profile, classLabel),
                            subtitle: l10n.hubSubtitle,
                            guestBanner: user is User && user.isAnonymous
                                ? l10n.guestBanner
                                : null,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _welcomeText(l10n, profile, classLabel),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.hubSubtitle,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (user is User && user.isAnonymous) ...[
                                const SizedBox(height: 12),
                                Text(
                                  l10n.guestBanner,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                              const SizedBox(height: 32),
                              const _ContinuableGames(),
                              const SizedBox(height: 24),
                              const _HubActions(),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _welcomeText(
  AppLocalizations l10n,
  PlayerProfile? profile,
  String? classLabel,
) {
  if (profile == null) {
    return l10n.welcome;
  }
  if (classLabel == null) {
    return l10n.welcomeNamed(profile.displayName);
  }
  return l10n.welcomeNamedClass(profile.displayName, classLabel);
}

class _HubActions extends ConsumerWidget {
  const _HubActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entitlement = ref.watch(currentEntitlementProvider).value;
    final isDemo = entitlement?.level.isDemo ?? false;
    final session = ref.watch(currentDemoSessionProvider).value;
    final demoLabel = session != null &&
            session.roomId != null &&
            session.roomId!.isNotEmpty
        ? (session.isConsumed ? l10n.demoSeeEnding : l10n.resumeDemo)
        : l10n.startDemo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isDemo) ...[
          FilledButton(
            onPressed: () => _runDemo(context, ref),
            child: Text(demoLabel),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.demoHubHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
        ] else ...[
          FilledButton(
            onPressed: () => context.pushNamed('create-room'),
            child: Text(l10n.createGame),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.pushNamed('rooms'),
            child: Text(l10n.joinGame),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => context.pushNamed('join-room'),
            child: Text(l10n.joinByCode),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: () => context.pushNamed('character-sheet'),
          child: Text(l10n.mySheet),
        ),
      ],
    );
  }

  Future<void> _runDemo(BuildContext context, WidgetRef ref) async {
    try {
      await startOrResumeDemo(context: context, ref: ref);
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

class _ExpandedHub extends StatelessWidget {
  const _ExpandedHub({
    required this.welcome,
    required this.subtitle,
    this.guestBanner,
  });

  final String welcome;
  final String subtitle;
  final String? guestBanner;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(welcome, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              if (guestBanner != null) ...[
                const SizedBox(height: 12),
                Text(
                  guestBanner!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
              const _ContinuableGames(),
            ],
          ),
        ),
        const SizedBox(width: 32),
        const SizedBox(
          width: 320,
          child: _HubActions(),
        ),
      ],
    );
  }
}

class _ContinuableGames extends ConsumerWidget {
  const _ContinuableGames();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final roomsState = ref.watch(myContinuableRoomsProvider);

    return roomsState.when(
      data: (rooms) {
        if (rooms.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.continueGames,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final room in rooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => _open(context, ref, room),
                  child: Text(
                    '${room.name} · ${room.status == RoomStatus.paused ? l10n.roomPausedBadge : l10n.roomPlayingBadge}',
                  ),
                ),
              ),
          ],
        );
      },
      error: (error, stackTrace) => Text(error.toString()),
      loading: () => const SizedBox.shrink(),
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Room room,
  ) async {
    try {
      await openRoomForCurrentUser(context: context, ref: ref, room: room);
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
