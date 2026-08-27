import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/profile_providers.dart';
import '../../auth/domain/profile_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(currentProfileProvider);
    final isAuthenticated = authState.value != null;
    final hasProfile = profileState.value != null;
    final canPlay = isAuthenticated && hasProfile;

    return Scaffold(
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.parchment, AppColors.background],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Image.asset(
                  'Assets/splash-icon.png',
                  height: 120,
                  semanticLabel: 'Embleme DragonsLair',
                ),
                const SizedBox(height: 24),
                Text(
                  'DragonsLair',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Jeu de role multijoueur avec maitre du jeu IA.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 32),
                _AuthStatus(authState: authState),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: AppConfig.isSupabaseConfigured
                      ? () => _enterTavern(context, ref)
                      : null,
                  child: const Text('Entrer dans la taverne'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: canPlay
                      ? () => context.pushNamed('create-room')
                      : isAuthenticated
                          ? () => context.pushNamed('display-name')
                          : null,
                  child: Text(
                    hasProfile || !isAuthenticated
                        ? 'Creer une partie'
                        : 'Choisir un pseudo',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: canPlay ? () => context.pushNamed('rooms') : null,
                  child: const Text('Rejoindre une partie'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: canPlay ? () => context.pushNamed('join-room') : null,
                  child: const Text('Rejoindre par code'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.pushNamed('game-master'),
                  child: const Text('Tester le MJ IA'),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _enterTavern(BuildContext context, WidgetRef ref) async {
  await ref.read(authControllerProvider.notifier).signInAnonymously();
  final profile = await ref.read(profileRepositoryProvider).fetchCurrent();
  ref.invalidate(currentProfileProvider);
  if (!context.mounted) {
    return;
  }
  if (profile == null) {
    context.pushNamed('display-name');
  }
}

class _AuthStatus extends StatelessWidget {
  const _AuthStatus({required this.authState});

  final AsyncValue<Object?> authState;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isSupabaseConfigured) {
      return const _StatusMessage(
        message: 'Configuration Supabase absente. L app compile en mode local.',
      );
    }

    return authState.when(
      data: (user) => _StatusMessage(
        message: user == null
            ? 'Session non ouverte.'
            : 'Session anonyme active.',
      ),
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
