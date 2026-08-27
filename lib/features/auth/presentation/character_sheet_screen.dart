import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../dice/domain/dice_roll_service.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../domain/character_stats.dart';
import '../domain/profile_repository.dart';
import 'auth_controller.dart';
import 'onboarding.dart';
import 'profile_providers.dart';

class CharacterSheetScreen extends ConsumerStatefulWidget {
  const CharacterSheetScreen({super.key});

  @override
  ConsumerState<CharacterSheetScreen> createState() =>
      _CharacterSheetScreenState();
}

class _CharacterSheetScreenState extends ConsumerState<CharacterSheetScreen> {
  final _dice = DiceRollService();
  String? _classId;
  CharacterStats? _rawStats;
  var _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedClass = _classId == null
        ? null
        : CharacterClassCatalog.byId(_classId!);
    final finalStats = _rawStats == null || selectedClass == null
        ? null
        : _rawStats!.withPrimaryBonus(
            selectedClass.primaryStatKey,
            bonus: CharacterClassCatalog.classBonus,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.sheetTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: context.pagePadding,
          children: [
            ContentConstraint(
              child: context.isExpanded
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _classColumn(context, l10n)),
                        const SizedBox(width: 32),
                        Expanded(
                          child: _statsColumn(
                            context,
                            l10n,
                            selectedClass,
                            finalStats,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _classColumn(context, l10n),
                        const SizedBox(height: 16),
                        _statsColumn(
                          context,
                          l10n,
                          selectedClass,
                          finalStats,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _classColumn(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.sheetIntro,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(l10n.classLabel, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in CharacterClassCatalog.all)
              ChoiceChip(
                label: Text(
                  l10n.classBonusChip(
                    localizedClassLabel(l10n, item.id),
                    localizedStatLabel(l10n, item.primaryStatKey),
                  ),
                ),
                selected: _classId == item.id,
                onSelected: (_) {
                  setState(() => _classId = item.id);
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _statsColumn(
    BuildContext context,
    AppLocalizations l10n,
    CharacterClass? selectedClass,
    CharacterStats? finalStats,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonal(
          onPressed: _rollStats,
          child: Text(l10n.rollAbilities),
        ),
        const SizedBox(height: 16),
        if (_rawStats != null)
          for (final field in characterStatFields)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _statLine(
                  l10n: l10n,
                  field: field,
                  raw: _rawStats!,
                  finalStats: finalStats,
                  selectedClass: selectedClass,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
        FilledButton(
          onPressed: _isSubmitting || _classId == null || finalStats == null
              ? null
              : () => _submit(finalStats),
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveSheet),
        ),
      ],
    );
  }

  void _rollStats() {
    final roll = _dice.roll(count: 6, sides: 20);
    setState(() {
      _rawStats = CharacterStats.fromRolls(roll.values);
    });
  }

  String _statLine({
    required AppLocalizations l10n,
    required CharacterStatField field,
    required CharacterStats raw,
    required CharacterStats? finalStats,
    required CharacterClass? selectedClass,
  }) {
    final statName = localizedStatLabel(l10n, field.key);
    final rawValue = field.read(raw);
    if (finalStats == null || selectedClass == null) {
      return l10n.statLine(statName, rawValue);
    }
    final finalValue = field.read(finalStats);
    if (field.key == selectedClass.primaryStatKey && finalValue != rawValue) {
      return l10n.statLineBonus(
        statName,
        rawValue,
        finalValue,
        localizedClassLabel(l10n, selectedClass.id),
      );
    }
    return l10n.statLine(statName, finalValue);
  }

  Future<void> _submit(CharacterStats stats) async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authControllerProvider).value;
    final profile = ref.read(currentProfileProvider).value;
    final classId = _classId;
    if (user == null || profile == null || classId == null) {
      _showError(l10n.sheetRequiresAccount);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(profileRepositoryProvider).upsertSheet(
            userId: user.id,
            displayName: profile.displayName,
            stats: stats,
            classId: classId,
          );
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        await routeAfterSession(context, ref);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }
}
