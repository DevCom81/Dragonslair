import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../game/presentation/pending_ability_roll.dart';
import '../../game/presentation/pending_roll_providers.dart';
import '../../game_master/presentation/game_master_controller.dart';
import '../../players/presentation/player_providers.dart';
import '../domain/game_event.dart';
import 'game_event_providers.dart';

class GameJournal extends ConsumerStatefulWidget {
  const GameJournal({
    required this.roomId,
    super.key,
  });

  final String roomId;

  @override
  ConsumerState<GameJournal> createState() => _GameJournalState();
}

class _GameJournalState extends ConsumerState<GameJournal> {
  final _scroll = ScrollController();
  var _lastEventCount = -1;
  var _followJournal = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final position = _scroll.position;
    _followJournal = position.maxScrollExtent - position.pixels < 96;
  }

  void _scrollToEndIfFollowing() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients || !_followJournal) {
        return;
      }
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventsState = ref.watch(roomEventsProvider(widget.roomId));
    final gmResponse = ref.watch(gameMasterControllerProvider).value;
    final choices = gmResponse?.choices ?? const [];
    final players =
        ref.watch(roomPlayersProvider(widget.roomId)).value ?? const [];
    final currentUserId = ref.watch(authControllerProvider).value?.id;
    final currentPlayer = currentUserId == null
        ? null
        : players.where((player) => player.userId == currentUserId).firstOrNull;
    final pending = activePendingRoll(ref, widget.roomId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.journalTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                ),
          ),
        ),
        Expanded(
          child: eventsState.when(
            data: (events) {
              if (events.isEmpty) {
                return Center(child: Text(l10n.journalEmpty));
              }
              if (events.length != _lastEventCount) {
                final previousCount = _lastEventCount;
                _lastEventCount = events.length;
                if (previousCount == -1 || events.length > previousCount) {
                  _scrollToEndIfFollowing();
                }
              }
              return ListView.separated(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        ),
        if (pending != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PendingAbilityRollBar(
              roomId: widget.roomId,
              currentPlayer: currentPlayer,
              players: players,
              pending: pending,
            ),
          ),
        if (choices.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.gmChoices,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
                const SizedBox(height: 8),
                for (final choice in choices)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${choice.label}'),
                  ),
              ],
            ),
          ),
      ],
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
