import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../game_master/domain/game_master_response.dart';

class GmChoiceBar extends StatelessWidget {
  const GmChoiceBar({
    required this.choices,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final List<GameMasterChoice> choices;
  final bool enabled;
  final ValueChanged<GameMasterChoice> onSelected;

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gmChoices,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final choice in choices)
              ActionChip(
                label: Text(choice.label),
                onPressed: enabled ? () => onSelected(choice) : null,
              ),
          ],
        ),
      ],
    );
  }
}
