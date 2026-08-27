import 'package:dragons_lair/features/rooms/domain/game_ending.dart';
import 'package:dragons_lair/features/rooms/domain/game_recap.dart';
import 'package:dragons_lair/features/rooms/presentation/game_summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

void main() {
  testWidgets('game summary shows result and tavern button without overflow',
      (tester) async {
    const recap = GameRecap(
      title: 'La Route',
      result: GameEndingResult.victory,
      summary: 'Le prince est sauf.',
      epilogue: 'La porte se referme.',
      characters: [RecapCharacter(name: 'Aldric', classId: 'fighter')],
      notableEvents: ['La taverne s ouvre.'],
      defeatedEnemies: ['Gobelin'],
      items: ['Torche'],
      criticalRolls: ['strength 20'],
      duration: Duration(hours: 1, minutes: 5),
    );

    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: GameSummaryView(
        recap: recap,
        onBackToTavern: () {},
      ),
    );

    expect(find.text('La Route'), findsOneWidget);
    expect(find.text('Victoire'), findsOneWidget);
    expect(find.text('Retour a la taverne'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('demo summary shows unlock benefits', (tester) async {
    const recap = GameRecap(
      title: 'La porte du wyrm',
      result: GameEndingResult.neutral,
      summary: 'Le secret reste ferme.',
      epilogue: 'L aventure ne fait que commencer.',
      characters: [RecapCharacter(name: 'Aldric', classId: 'fighter')],
      notableEvents: [],
      defeatedEnemies: [],
      items: [],
      criticalRolls: [],
      isDemo: true,
    );

    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      child: GameSummaryView(
        recap: recap,
        onBackToTavern: () {},
      ),
    );

    expect(find.text('L aventure ne fait que commencer.'), findsWidgets);
    expect(find.text('Debloquer DragonsLair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
