import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../domain/game_master_response.dart';
import 'game_master_controller.dart';

class GameMasterScreen extends ConsumerStatefulWidget {
  const GameMasterScreen({super.key});

  @override
  ConsumerState<GameMasterScreen> createState() => _GameMasterScreenState();
}

class _GameMasterScreenState extends ConsumerState<GameMasterScreen> {
  final _actionController = TextEditingController();

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameMasterState = ref.watch(gameMasterControllerProvider);
    final canSubmit = !AppConfig.isGameMasterRemote ||
        AppConfig.isGameMasterBackendConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Maitre du jeu IA')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModeBanner(canSubmit: canSubmit),
              const SizedBox(height: 16),
              TextField(
                controller: _actionController,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Action du joueur',
                  hintText: 'Exemple: examiner la porte scellee',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: canSubmit && !gameMasterState.isLoading
                    ? () => ref
                          .read(gameMasterControllerProvider.notifier)
                          .submitAction(_actionController.text)
                    : null,
                child: gameMasterState.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Interroger le MJ'),
              ),
              const SizedBox(height: 16),
              Expanded(child: _GameMasterResult(state: gameMasterState)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.canSubmit});

  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final mode = AppConfig.isGameMasterRemote ? 'remote Railway' : 'mock local';
    final message = canSubmit
        ? 'Mode MJ: $mode'
        : 'Mode remote actif, mais GAME_MASTER_BACKEND_URL est absent.';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _GameMasterResult extends StatelessWidget {
  const _GameMasterResult({required this.state});

  final AsyncValue<GameMasterResponse?> state;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: (response) {
        if (response == null) {
          return const Center(
            child: Text('Envoie une action pour recevoir une narration.'),
          );
        }

        return ListView(
          children: [
            Text(
              response.narration,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (response.actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Actions structurees',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final action in response.actions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(action.type.value),
                  subtitle: Text(action.payload.toString()),
                ),
            ],
            if (response.choices.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Choix', style: Theme.of(context).textTheme.titleMedium),
              for (final choice in response.choices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(choice.label),
                  subtitle: choice.action == null ? null : Text(choice.action!),
                ),
            ],
          ],
        );
      },
      error: (error, stackTrace) => Center(child: Text(error.toString())),
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      ),
    );
  }
}
