import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';

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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        profile == null
                            ? l10n.welcome
                            : classLabel == null
                                ? l10n.welcomeNamed(profile.displayName)
                                : l10n.welcomeNamedClass(
                                    profile.displayName,
                                    classLabel,
                                  ),
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
                    ],
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
