import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/combat_session.dart';

class CombatBanner extends StatelessWidget {
  const CombatBanner({
    required this.combat,
    super.key,
  });

  final CombatSession combat;

  @override
  Widget build(BuildContext context) {
    if (!combat.active) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        l10n.combatRoundBanner(combat.round),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.gold,
            ),
      ),
    );
  }
}
