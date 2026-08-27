import 'package:dragons_lair/app/app.dart';
import 'package:dragons_lair/features/auth/presentation/auth_screen.dart';
import 'package:dragons_lair/features/auth/presentation/character_sheet_screen.dart';
import 'package:dragons_lair/features/rooms/presentation/create_room_screen.dart';
import 'package:dragons_lair/features/rooms/presentation/join_room_by_code_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

void main() {
  testWidgets('home renders without overflow at target sizes', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    for (final size in responsiveTestSizes) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const ProviderScope(child: DragonsLairApp()));
      await tester.pump();

      expect(find.text('DragonsLair'), findsOneWidget, reason: '$size');
      expect(tester.takeException(), isNull, reason: 'overflow at $size');
    }
  });

  testWidgets('create room character auth join do not overflow', (tester) async {
    const screens = <String, Widget>{
      'create-room': CreateRoomScreen(),
      'character-sheet': CharacterSheetScreen(),
      'auth': AuthScreen(),
      'join-room': JoinRoomByCodeScreen(),
    };

    for (final entry in screens.entries) {
      for (final size in responsiveTestSizes) {
        await pumpAtSize(
          tester,
          size: size,
          child: ProviderScope(child: entry.value),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} overflow at $size',
        );
      }
    }
  });
}
