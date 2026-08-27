import 'package:dragons_lair/features/access/presentation/access_offer_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

void main() {
  testWidgets('access offer shows demo and full cards without f2p bait', (
    tester,
  ) async {
    var demoTaps = 0;
    var unlockTaps = 0;

    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: SingleChildScrollView(
        child: AccessOfferView(
          demoCtaLabel: 'Commencer la demo',
          onStartDemo: () => demoTaps++,
          onUnlock: () => unlockTaps++,
        ),
      ),
    );

    expect(find.text('Essayez DragonsLair gratuitement'), findsOneWidget);
    expect(find.text('Debloquez DragonsLair'), findsOneWidget);
    expect(find.text('• 10 minutes'), findsOneWidget);
    expect(find.text('• Solo'), findsOneWidget);
    expect(find.text('• MJ IA'), findsOneWidget);
    expect(find.text('• Creation personnage'), findsOneWidget);
    expect(find.text('• Des'), findsOneWidget);
    expect(find.text('• Combat'), findsOneWidget);
    expect(find.text('• Creer vos propres aventures'), findsOneWidget);
    expect(find.text('• Jouer sans limite'), findsOneWidget);
    expect(find.text('• Jouer avec vos amis'), findsOneWidget);
    expect(find.text('• Sauvegarder vos parties'), findsOneWidget);
    expect(find.text('Debloquer le jeu'), findsOneWidget);

    expect(find.textContaining('gemme', findRichText: true), findsNothing);
    expect(find.textContaining('energie', findRichText: true), findsNothing);
    expect(find.textContaining('credit', findRichText: true), findsNothing);
    expect(find.textContaining('lootbox', findRichText: true), findsNothing);

    await tester.ensureVisible(find.text('Commencer la demo'));
    await tester.tap(find.text('Commencer la demo'));
    await tester.ensureVisible(find.text('Debloquer le jeu'));
    await tester.tap(find.text('Debloquer le jeu'));
    expect(demoTaps, 1);
    expect(unlockTaps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access offer does not overflow at target sizes', (tester) async {
    for (final size in responsiveTestSizes) {
      await pumpAtSize(
        tester,
        size: size,
        child: SingleChildScrollView(
          child: AccessOfferView(
            demoCtaLabel: 'Commencer la demo',
            onStartDemo: () {},
            onUnlock: () {},
            onRestore: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });
}
