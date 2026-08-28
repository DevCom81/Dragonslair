import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../l10n/app_localizations.dart';
import '../../access/presentation/purchase_flow.dart';
import '../../enemies/presentation/enemy_providers.dart';
import '../../events/presentation/game_event_providers.dart';
import '../../game/presentation/pending_roll_providers.dart';
import '../../players/presentation/player_providers.dart';
import '../domain/game_ending.dart';
import '../domain/game_recap.dart';
import 'room_providers.dart';

class GameSummaryScreen extends ConsumerWidget {
  const GameSummaryScreen({required this.roomId, super.key});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final room = ref.watch(roomProvider(roomId)).value;
    final players = ref.watch(roomPlayersProvider(roomId)).value ?? const [];
    final enemies = ref.watch(roomEnemiesProvider(roomId)).value ?? const [];
    final events = ref.watch(roomEventsProvider(roomId)).value ?? const [];
    final rolls = ref.watch(roomPendingRollsProvider(roomId)).value ?? const [];

    if (room == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.gameSummaryTitle)),
        body: Center(child: Text(l10n.roomNotFound)),
      );
    }

    final recap = buildGameRecap(
      room: room,
      players: players,
      enemies: enemies,
      events: events,
      rolls: rolls,
    );

    return GameSummaryView(
      recap: recap,
      onBackToTavern: () => context.goNamed('play-hub'),
      onUnlock: () => startUnlockCheckout(context: context, ref: ref),
      onRestore: () => restorePurchases(context: context, ref: ref),
    );
  }
}

class GameSummaryView extends StatelessWidget {
  const GameSummaryView({
    required this.recap,
    required this.onBackToTavern,
    this.onUnlock,
    this.onRestore,
    super.key,
  });

  final GameRecap recap;
  final VoidCallback onBackToTavern;
  final VoidCallback? onUnlock;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.gameSummaryTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: [
            ContentConstraint(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    recap.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultLabel(l10n, recap.result),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (recap.duration != null) ...[
                    const SizedBox(height: 8),
                    Text(_durationLabel(l10n, recap.duration!)),
                  ],
                  _section(context, l10n.gameSummaryCharacters, [
                    for (final character in recap.characters)
                      character.classId == null || character.classId!.isEmpty
                          ? character.name
                          : '${character.name} (${localizedClassLabel(l10n, character.classId!)})',
                  ]),
                  if (recap.summary.isNotEmpty)
                    _section(context, l10n.gameSummaryNarrative, [
                      recap.summary,
                    ]),
                  if (recap.epilogue.isNotEmpty)
                    _section(context, l10n.gameSummaryEpilogue, [
                      recap.epilogue,
                    ]),
                  _section(
                    context,
                    l10n.gameSummaryEvents,
                    recap.notableEvents,
                  ),
                  _section(
                    context,
                    l10n.gameSummaryEnemies,
                    recap.defeatedEnemies,
                  ),
                  _section(context, l10n.gameSummaryItems, recap.items),
                  _section(
                    context,
                    l10n.gameSummaryCriticals,
                    recap.criticalRolls,
                  ),
                  const SizedBox(height: 24),
                  if (recap.isDemo) ...[
                    Text(
                      l10n.demoAdventureBegins,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Text('✓ ${l10n.unlockBenefitCustom}'),
                    Text('✓ ${l10n.unlockBenefitSolo}'),
                    Text('✓ ${l10n.unlockBenefitMultiplayer}'),
                    Text('✓ ${l10n.unlockBenefitSave}'),
                    Text('✓ ${l10n.unlockBenefitUnlimited}'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed:
                          onUnlock ??
                          () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.purchaseUnavailable)),
                            );
                          },
                      child: Text(l10n.unlockDragonsLair),
                    ),
                    if (onRestore != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onRestore,
                        child: Text(l10n.restorePurchase),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: onBackToTavern,
                    child: Text(l10n.backToTavern),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<String> lines) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (lines.isEmpty)
            Text(l10n.gameSummaryEmpty)
          else
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $line'),
              ),
        ],
      ),
    );
  }

  String _resultLabel(AppLocalizations l10n, GameEndingResult result) {
    return switch (result) {
      GameEndingResult.victory => l10n.gameResultVictory,
      GameEndingResult.defeat => l10n.gameResultDefeat,
      GameEndingResult.neutral => l10n.gameResultNeutral,
    };
  }

  String _durationLabel(AppLocalizations l10n, Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours <= 0) {
      return l10n.gameDurationMinutes(minutes);
    }
    return l10n.gameDurationHoursMinutes(hours, minutes);
  }
}
