import 'package:dragons_lair/features/game/presentation/game_hud_button.dart';
import 'package:dragons_lair/features/game/presentation/game_session_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

Widget _session() {
  return GameSessionLayout(
    sheetLabel: 'Fiche',
    inventoryLabel: 'Inventaire',
    board: const ColoredBox(
      color: Colors.brown,
      child: Center(child: Text('BOARD')),
    ),
    journal: const Text('JOURNAL'),
    sheet: const Text('SHEET'),
    inventory: const Text('INV'),
    actions: const Text('ACTIONS'),
    hud: const Row(
      children: [
        GameHudButton(
          icon: Icons.badge_outlined,
          label: 'Fiche',
          onPressed: null,
        ),
        GameHudButton(
          icon: Icons.inventory_2_outlined,
          label: 'Sac',
          onPressed: null,
        ),
        GameHudButton(
          icon: Icons.menu_book,
          label: 'Livre',
          onPressed: null,
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('compact shows board hud actions, not journal', (tester) async {
    await pumpAtSize(tester, size: const Size(390, 844), child: _session());

    expect(find.text('BOARD'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('Livre'), findsOneWidget);
    expect(find.text('JOURNAL'), findsNothing);
    expect(find.text('SHEET'), findsNothing);
  });

  testWidgets('medium shows journal beside the board', (tester) async {
    await pumpAtSize(tester, size: const Size(768, 1024), child: _session());

    expect(find.text('BOARD'), findsOneWidget);
    expect(find.text('Livre'), findsOneWidget);
    expect(find.text('JOURNAL'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('SHEET'), findsNothing);
  });

  testWidgets('expanded shows journal sheet inventory without hud',
      (tester) async {
    await pumpAtSize(tester, size: const Size(1366, 768), child: _session());

    expect(find.text('BOARD'), findsOneWidget);
    expect(find.text('JOURNAL'), findsOneWidget);
    expect(find.text('ACTIONS'), findsOneWidget);
    expect(find.text('Fiche'), findsWidgets);
    expect(find.text('Inventaire'), findsOneWidget);
    expect(find.text('Livre'), findsNothing);
  });

  testWidgets('session layout does not overflow at target sizes',
      (tester) async {
    for (final size in responsiveTestSizes) {
      await pumpAtSize(tester, size: size, child: _session());
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });
}
