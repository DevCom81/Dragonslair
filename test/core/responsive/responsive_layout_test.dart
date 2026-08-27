import 'package:dragons_lair/core/responsive/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_harness.dart';

void main() {
  testWidgets('ResponsiveLayout picks the slot for each size', (tester) async {
    Future<void> expectSlot(Size size, String label) async {
      await pumpAtSize(
        tester,
        size: size,
        child: const ResponsiveLayout(
          compact: Text('compact-slot'),
          medium: Text('medium-slot'),
          expanded: Text('expanded-slot'),
        ),
      );
      expect(find.text(label), findsOneWidget);
    }

    await expectSlot(const Size(390, 844), 'compact-slot');
    await expectSlot(const Size(768, 1024), 'medium-slot');
    await expectSlot(const Size(1366, 768), 'expanded-slot');
  });
}
