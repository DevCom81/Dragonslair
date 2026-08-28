import 'dart:io';

import 'package:dragons_lair/features/access/data/stripe_checkout_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/game_access.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:dragons_lair/features/access/presentation/access_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('google play full account never receives stripe checkout on web', () {
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

  test('google play full entitlement blocks any store purchase offer', () {
    final entitlement = UserEntitlement.fromJson({
      'user_id': 'play-user',
      'access_level': 'full',
      'source': 'purchase',
    });
    expect(entitlement.level.isFull, isTrue);
    expect(
      shouldStartStorePurchase(isFull: entitlement.level.isFull, canPurchase: true),
      isFalse,
    );
  });

  test('web hub shows windows download only when entitlement is full', () {
    final src = File(
      'lib/features/home/presentation/play_hub_screen.dart',
    ).readAsStringSync();
    expect(src.contains('kIsWeb && isFull'), isTrue);
    expect(src.contains('startWindowsDownload'), isTrue);
    expect(src.contains('Télécharger Windows'), isTrue);
  });
}
