import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/room.dart';
import 'room_providers.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(waitingRoomsProvider);
    final user = ref.watch(authControllerProvider).value;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.openGames),
        actions: [
          const LanguageButton(),
          IconButton(
            onPressed: user == null ? null : () => context.pushNamed('join-room'),
            icon: const Icon(Icons.vpn_key),
            tooltip: l10n.joinByCode,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: user == null ? null : () => context.pushNamed('create-room'),
        icon: const Icon(Icons.add),
        label: Text(l10n.create),
      ),
      body: SafeArea(
        child: roomsState.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return Center(child: Text(l10n.noWaitingGames));
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(waitingRoomsProvider.future),
              child: GridView.builder(
                padding: context.pagePadding,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: context.responsiveValue(
                    compact: 1,
                    medium: 2,
                    expanded: 3,
                  ),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 220,
                ),
                itemCount: rooms.length,
                itemBuilder: (context, index) => _RoomCard(room: rooms[index]),
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
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (room.joinCode != null && room.joinCode!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.codeLabel(room.joinCode!)),
            ],
            if (room.scenarioId != null ||
                (room.scenario != null && room.scenario!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Text(
                localizedScenarioName(
                  l10n,
                  room.scenarioId,
                  customTitle: room.scenario,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            FilledButton(
              onPressed: () => context.pushNamed(
                'figurines',
                pathParameters: {'roomId': room.id},
              ),
              child: Text(l10n.join),
            ),
          ],
        ),
      ),
    );
  }
}
