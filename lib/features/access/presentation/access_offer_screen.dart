import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/language_button.dart';
import '../../../core/responsive/responsive.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/game_access.dart';
import 'access_providers.dart';
import 'demo_start.dart';
import 'purchase_flow.dart';

class AccessOfferScreen extends ConsumerWidget {
  const AccessOfferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(currentDemoSessionProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: const [LanguageButton()],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: context.pagePadding,
                  child: ContentConstraint(
                    child: AccessOfferView(
                      demoCtaLabel: demoOfferCtaLabel(l10n, session),
                      onStartDemo: () => _runDemo(context, ref),
                      onUnlock: () =>
                          startUnlockCheckout(context: context, ref: ref),
                      onRestore: () =>
                          restorePurchases(context: context, ref: ref),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String demoOfferCtaLabel(AppLocalizations l10n, DemoSession? session) {
  if (session != null && session.roomId != null && session.roomId!.isNotEmpty) {
    return session.isConsumed ? l10n.demoSeeEnding : l10n.resumeDemo;
  }
  return l10n.startDemo;
}

Future<void> _runDemo(BuildContext context, WidgetRef ref) async {
  try {
    await startOrResumeDemo(context: context, ref: ref);
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

class AccessOfferView extends StatelessWidget {
  const AccessOfferView({
    required this.demoCtaLabel,
    required this.onStartDemo,
    required this.onUnlock,
    this.onRestore,
    super.key,
  });

  final String demoCtaLabel;
  final VoidCallback onStartDemo;
  final VoidCallback onUnlock;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final demoCard = _OfferCard(
      title: l10n.tryDragonsLairFree,
      benefits: [
        l10n.demoBenefitMinutes,
        l10n.demoBenefitSoloPlay,
        l10n.demoBenefitAiGm,
        l10n.demoBenefitCharacter,
        l10n.demoBenefitDice,
        l10n.demoBenefitCombat,
      ],
      ctaLabel: demoCtaLabel,
      onCta: onStartDemo,
      filled: true,
    );
    final fullCard = _OfferCard(
      title: l10n.unlockDragonsLairTitle,
      benefits: [
        l10n.unlockBenefitCustom,
        l10n.unlockBenefitUnlimited,
        l10n.unlockBenefitMultiplayer,
        l10n.unlockBenefitSave,
      ],
      ctaLabel: l10n.unlockTheGame,
      onCta: onUnlock,
      filled: false,
    );
    final restore = onRestore == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: onRestore,
              child: Text(l10n.restorePurchase),
            ),
          );

    return ResponsiveLayout(
      compact: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [demoCard, const SizedBox(height: 16), fullCard, restore],
      ),
      expanded: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: demoCard),
              const SizedBox(width: 24),
              Expanded(child: fullCard),
            ],
          ),
          restore,
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.title,
    required this.benefits,
    required this.ctaLabel,
    required this.onCta,
    required this.filled,
  });

  final String title;
  final List<String> benefits;
  final String ctaLabel;
  final VoidCallback onCta;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final cta = filled
        ? FilledButton(onPressed: onCta, child: Text(ctaLabel))
        : FilledButton.tonal(onPressed: onCta, child: Text(ctaLabel));

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final benefit in benefits)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $benefit'),
              ),
            const SizedBox(height: 12),
            cta,
          ],
        ),
      ),
    );
  }
}
