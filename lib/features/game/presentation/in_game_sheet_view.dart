import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/character_stats.dart';
import '../../players/domain/player.dart';
import '../../players/domain/player_effect.dart';
import '../../players/presentation/player_providers.dart';

class InGameSheetView extends ConsumerWidget {
  const InGameSheetView({
    required this.roomId,
    required this.playerId,
    super.key,
  });

  final String roomId;
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final players = ref.watch(roomPlayersProvider(roomId)).value ?? const [];
    Player? player;
    for (final candidate in players) {
      if (candidate.id == playerId) {
        player = candidate;
        break;
      }
    }

    if (player == null) {
      return Center(child: Text(l10n.inGameSheetTitle));
    }

    final classLabel = player.classId == null
        ? null
        : localizedClassLabel(l10n, player.classId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n.inGameSheetTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.gold,
                ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Text(
                player.figurineName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (classLabel != null) ...[
                const SizedBox(height: 4),
                Text(l10n.yourClass(classLabel)),
              ],
              const SizedBox(height: 4),
              Text(l10n.hpLabel(player.hp)),
              const SizedBox(height: 16),
              for (final field in characterStatFields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _statLine(l10n, player, field.key),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                l10n.effectsTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                    ),
              ),
              const SizedBox(height: 8),
              if (player.effects.isEmpty)
                Text(l10n.emptyEffects)
              else
                for (final effect in player.effects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(_effectLine(l10n, effect)),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  String _statLine(AppLocalizations l10n, Player player, String key) {
    final label = localizedStatLabel(l10n, key);
    final base = player.stats.scoreFor(key);
    final effective = player.effectiveScoreFor(key);
    if (effective == base) {
      return l10n.statLine(label, base);
    }
    return l10n.statLineEffective(label, effective, base);
  }

  String _effectLine(AppLocalizations l10n, PlayerEffect effect) {
    final kind = localizedEffectKind(l10n, effect.kind);
    final duration = effect.isPermanent
        ? l10n.effectPermanent
        : l10n.effectRemaining(effect.remaining!);
    final stat = effect.stat == null
        ? ''
        : ' ${localizedStatLabel(l10n, effect.stat!)} ${effect.delta >= 0 ? '+' : ''}${effect.delta}';
    return '${effect.name} ($kind$stat) — $duration';
  }
}
