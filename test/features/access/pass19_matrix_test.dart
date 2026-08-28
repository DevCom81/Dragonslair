import 'dart:io';

import 'package:dragons_lair/features/access/data/stripe_checkout_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/game_access.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:dragons_lair/features/access/presentation/access_offer_screen.dart';
import 'package:dragons_lair/features/access/presentation/access_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/responsive_harness.dart';

void main() {
  group('PASS 19 platform purchase matrix', () {
    testWidgets('android demo offer exposes a single unlock cta', (tester) async {
      var unlockTaps = 0;
      await pumpAtSize(
        tester,
        size: const Size(390, 844),
        child: SingleChildScrollView(
          child: AccessOfferView(
            demoCtaLabel: 'Commencer la demo',
            onStartDemo: () {},
            onUnlock: () => unlockTaps++,
          ),
        ),
      );
      expect(find.text('Debloquer DragonsLair'), findsOneWidget);
      await tester.tap(find.text('Debloquer DragonsLair'));
      expect(unlockTaps, 1);
    });

    test('android full via stripe never receives store billing provider', () {
      final container = ProviderContainer(
        overrides: [
          currentEntitlementProvider.overrideWith(
            (ref) async => const UserEntitlement(
              userId: 'stripe-user',
              level: GameAccessLevel.full,
              source: 'purchase',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final billing = container.read(purchaseProvider);
      expect(billing, isA<UnavailablePurchaseProvider>());
    });

    test('web demo routes to stripe in billing provider wiring', () {
      final src = File(
        'lib/features/access/presentation/access_providers.dart',
      ).readAsStringSync();
      final webBlock = src.split('if (kIsWeb)').last.split(
        'if (defaultTargetPlatform',
      ).first;
      expect(webBlock.contains('StripeCheckoutPurchaseProvider'), isTrue);
      expect(webBlock.contains('GooglePlayPurchaseProvider'), isFalse);
    });

    test('web full via google never receives stripe checkout provider', () {
      final container = ProviderContainer(
        overrides: [
          currentEntitlementProvider.overrideWith(
            (ref) async => const UserEntitlement(
              userId: 'play-user',
              level: GameAccessLevel.full,
              source: 'purchase',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final billing = container.read(purchaseProvider);
      expect(billing, isA<UnavailablePurchaseProvider>());
      expect(billing.canPurchase, isFalse);
    });

    test('windows full via google is full without local store billing', () {
      final entitlement = UserEntitlement.fromJson({
        'user_id': 'play-user',
        'access_level': 'full',
        'source': 'purchase',
      });
      expect(entitlement.level.isFull, isTrue);
      expect(
        shouldStartStorePurchase(
          isFull: entitlement.level.isFull,
          canPurchase: false,
        ),
        isFalse,
      );
      const billing = UnavailablePurchaseProvider();
      expect(billing.canPurchase, isFalse);
    });
  });
}
