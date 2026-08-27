import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/room.dart';
import 'room_providers.dart';

class RoomListScreen extends ConsumerWidget {
  const RoomListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomsState = ref.watch(waitingRoomsProvider);
    final user = ref.watch(authControllerProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties ouvertes'),
        actions: [
          IconButton(
            onPressed: user == null ? null : () => context.pushNamed('join-room'),
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Rejoindre par code',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: user == null ? null : () => context.pushNamed('create-room'),
        icon: const Icon(Icons.add),
        label: const Text('Creer'),
      ),
      body: SafeArea(
        child: roomsState.when(
          data: (rooms) {
            if (rooms.isEmpty) {
              return const Center(child: Text('Aucune partie en attente.'));
            }

            return RefreshIndicator(
              onRefresh: () => ref.refresh(waitingRoomsProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rooms.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(room.name, style: Theme.of(context).textTheme.titleMedium),
            if (room.joinCode != null && room.joinCode!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Code ${room.joinCode}'),
            ],
            if (room.scenario != null && room.scenario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(room.scenario!),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.pushNamed(
                'figurines',
                pathParameters: {'roomId': room.id},
              ),
              child: const Text('Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }
}
