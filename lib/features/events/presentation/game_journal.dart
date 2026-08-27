import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/game_event.dart';
import 'game_event_providers.dart';

class GameJournal extends ConsumerWidget {
  const GameJournal({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsState = ref.watch(roomEventsProvider(roomId));

    return SafeArea(
      child: eventsState.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('Aucun evenement pour le moment.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _EventTile(event: events[index]),
          );
        },
        error: (error, stackTrace) => Center(child: Text(error.toString())),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.gold),
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final GameEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.type) {
      GameEventType.narration => AppColors.gold,
      GameEventType.action => AppColors.cream,
      GameEventType.system => AppColors.muted,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          event.content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ),
    );
  }
}
