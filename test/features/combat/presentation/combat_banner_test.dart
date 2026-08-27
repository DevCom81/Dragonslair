import 'package:dragons_lair/features/combat/domain/combat_session.dart';
import 'package:dragons_lair/features/combat/presentation/combat_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

void main() {
  testWidgets('hides when combat is inactive', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: CombatBanner(combat: CombatSession.inactive()),
    );

    expect(find.textContaining('Combat'), findsNothing);
  });

  testWidgets('shows the current round when combat is active', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: const CombatBanner(
        combat: CombatSession(active: true, round: 2),
      ),
    );

    expect(find.text('Combat — round 2'), findsOneWidget);
  });
}
