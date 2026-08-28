import 'package:dragons_lair/features/access/data/stripe_checkout_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/game_access.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:dragons_lair/features/access/presentation/access_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stripe full account never receives a store purchase provider', () {
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
    expect(billing.canPurchase, isFalse);
  });

  test('demo account is not offered store purchase when already full', () {
    final entitlement = UserEntitlement.demoFor('demo-user');
    expect(entitlement.level.isDemo, isTrue);
    expect(
      shouldStartStorePurchase(isFull: false, canPurchase: true),
      isTrue,
    );
    expect(
      shouldStartStorePurchase(isFull: true, canPurchase: true),
      isFalse,
    );
  });

  test('backend full response is treated as full regardless of payment platform', () {
    final entitlement = UserEntitlement.fromJson({
      'user_id': 'stripe-user',
      'access_level': 'full',
      'source': 'purchase',
    });
    expect(entitlement.level.isFull, isTrue);
    expect(
      shouldStartStorePurchase(isFull: entitlement.level.isFull, canPurchase: true),
      isFalse,
    );
  });
}
