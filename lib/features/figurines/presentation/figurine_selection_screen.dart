import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../players/presentation/player_providers.dart';
import '../domain/figurine_definition.dart';
import 'figurine_sprite.dart';

class FigurineSelectionScreen extends ConsumerWidget {
  const FigurineSelectionScreen({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersState = ref.watch(roomPlayersProvider(roomId));
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Choisir une figurine')),
      body: SafeArea(
        child: playersState.when(
          data: (players) {
            final takenIds = players.map((player) => player.figurineId).toSet();

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: FigurineCatalog.count,
              itemBuilder: (context, index) {
                final figurine = FigurineCatalog.byId(index);
                final isTaken = takenIds.contains(figurine.id);

                return _FigurineCard(
                  figurine: figurine,
                  isTaken: isTaken,
                  onTap: user == null || isTaken
                      ? null
                      : () async {
                          await _joinRoom(context, ref, user.id, figurine);
                        },
                );
              },
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

  Future<void> _joinRoom(
    BuildContext context,
    WidgetRef ref,
    String userId,
    FigurineDefinition figurine,
  ) async {
    try {
      await ref.read(playerRepositoryProvider).joinRoom(
            roomId: roomId,
            userId: userId,
            figurineId: figurine.id,
            figurineName: figurine.name,
          );

      if (context.mounted) {
        context.pushNamed('lobby', pathParameters: {'roomId': roomId});
      }
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

class _FigurineCard extends StatelessWidget {
  const _FigurineCard({
    required this.figurine,
    required this.isTaken,
    required this.onTap,
  });

  final FigurineDefinition figurine;
  final bool isTaken;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: isTaken ? AppColors.surface.withValues(alpha: 0.5) : null,
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
