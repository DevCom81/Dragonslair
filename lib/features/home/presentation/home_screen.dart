import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/onboarding.dart';
import '../../auth/presentation/profile_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(currentProfileProvider);
    final canPlay = isProfileReady(profileState.value);
    final user = authState.value;
    final configured = AppConfig.isSupabaseConfigured;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.parchment, AppColors.background],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: context.pagePadding,
                    child: ContentConstraint(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Image.asset(
                            'Assets/splash-icon.png',
                            height: context.responsiveValue(
                              compact: 120,
                              medium: 140,
                              expanded: 160,
                            ),
                            semanticLabel: l10n.emblemSemantic,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            l10n.appTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.appTagline,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 32),
                          if (authState.isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            )
                          else if (user != null) ...[
                            Text(
                              _signedInWelcome(
                                l10n,
                                profileState.value?.displayName,
                              ),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: configured
                                  ? () => canPlay
                                        ? context.pushNamed('play-hub')
                                        : routeAfterSession(context, ref)
                                  : null,
                              child: Text(l10n.continuePlay),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: configured
                                  ? () => context.pushNamed('profile')
                                  : null,
                              child: Text(l10n.myProfile),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .signOut();
                                ref.invalidate(currentProfileProvider);
                              },
                              child: Text(l10n.signOut),
                            ),
                          ] else ...[
                            _AuthStatus(authState: authState),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: configured
                                  ? () => _playAsGuest(context, ref)
                                  : null,
                              child: Text(l10n.playAsGuest),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: configured
                                  ? () => context.pushNamed(
                                      'auth',
                                      queryParameters: {'mode': 'login'},
                                    )
                                  : null,
                              child: Text(l10n.logIn),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.tonal(
                              onPressed: configured
                                  ? () => context.pushNamed('auth')
                                  : null,
                              child: Text(l10n.signUp),
                            ),
                          ],
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

Future<void> _playAsGuest(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authControllerProvider).value;
  if (user != null) {
    await routeAfterSession(context, ref);
    return;
  }

  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(l10n.guestWarningTitle),
        content: Text(l10n.guestWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.guestWarningCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.guestWarningConfirm),
          ),
        ],
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  await ref.read(authControllerProvider.notifier).signInAnonymously();
  final authState = ref.read(authControllerProvider);
  if (authState.hasError) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authState.error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return;
  }
  if (authState.value == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.authRequired),
          backgroundColor: AppColors.danger,
        ),
      );
    }
    return;
  }
  if (context.mounted) {
    await routeAfterSession(context, ref);
  }
}

String _signedInWelcome(AppLocalizations l10n, String? displayName) {
  final name = displayName?.trim();
  if (name != null && name.isNotEmpty) {
    return l10n.welcomeNamed(name);
  }
  return l10n.welcome;
}

class _AuthStatus extends StatelessWidget {
  const _AuthStatus({required this.authState});

  final AsyncValue<User?> authState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!AppConfig.isSupabaseConfigured) {
      return _StatusMessage(message: l10n.supabaseMissing);
    }

    return authState.when(
      data: (user) {
        if (user == null) {
          return _StatusMessage(message: l10n.sessionClosed);
        }
        return _StatusMessage(
          message: user.isAnonymous ? l10n.sessionGuest : l10n.sessionConnected,
        );
      },
      error: (error, stackTrace) => _StatusMessage(message: error.toString()),
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.gold)),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
