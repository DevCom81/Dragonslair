import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/presentation/access_offer_screen.dart';
import '../../access/presentation/access_providers.dart';
import '../../access/presentation/demo_start.dart';
import '../../access/presentation/purchase_flow.dart';
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

    final entitlement = ref.watch(currentEntitlementProvider);
    final isDemo = entitlement.maybeWhen(
      data: (value) => value?.level.isDemo ?? true,
      error: (error, stackTrace) => true,
      orElse: () => false,
    );
    final accessPending = entitlement.isLoading;

    return _EntitlementResumeListener(
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.tavernTitle),
          actions: [
            IconButton(
              onPressed: () => context.pushNamed('profile'),
              icon: const Icon(Icons.person_outline),
              tooltip: l10n.myProfile,
            ),
            const LanguageButton(),
          ],
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
                      child: accessPending
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            )
                          : isDemo
                          ? _DemoAccessHub(
                              welcome: _welcomeText(l10n, profile, classLabel),
                              subtitle: l10n.hubSubtitle,
                              guestBanner: user is User && user.isAnonymous
                                  ? l10n.guestBanner
                                  : null,
                            )
                          : context.isExpanded
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
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
      ),
    );
  }
}

class _EntitlementResumeListener extends ConsumerStatefulWidget {
  const _EntitlementResumeListener({required this.child});

  final Widget child;

  @override
  ConsumerState<_EntitlementResumeListener> createState() =>
      _EntitlementResumeListenerState();
}

class _EntitlementResumeListenerState
    extends ConsumerState<_EntitlementResumeListener>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  Widget build(BuildContext context) => widget.child;
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

class _HubActions extends ConsumerWidget {
  const _HubActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        OutlinedButton(
          onPressed: () => context.pushNamed('character-sheet'),
          child: Text(l10n.mySheet),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.pushNamed('profile'),
          child: Text(l10n.myProfile),
        ),
      ],
    );
  }
}

class _DemoAccessHub extends ConsumerWidget {
  const _DemoAccessHub({
    required this.welcome,
    required this.subtitle,
    this.guestBanner,
  });

  final String welcome;
  final String subtitle;
  final String? guestBanner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentDemoSessionProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(welcome, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        if (guestBanner != null) ...[
          const SizedBox(height: 12),
          Text(guestBanner!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        AccessOfferView(
          demoCtaLabel: demoOfferCtaLabel(l10n, session),
          onStartDemo: () => _runDemo(context, ref),
          onUnlock: () => startUnlockCheckout(context: context, ref: ref),
          onRestore: () => restorePurchases(context: context, ref: ref),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.pushNamed('character-sheet'),
          child: Text(l10n.mySheet),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => context.pushNamed('profile'),
          child: Text(l10n.myProfile),
        ),
      ],
    );
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
        const SizedBox(width: 320, child: _HubActions()),
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

  Future<void> _open(BuildContext context, WidgetRef ref, Room room) async {
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
