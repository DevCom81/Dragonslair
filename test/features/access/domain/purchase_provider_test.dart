import 'package:dragons_lair/features/access/data/stripe_checkout_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase offer uses Stripe amount and currency', () {
    final offer = PurchaseOffer.fromJson({
      'unit_amount': 2450,
      'currency': 'eur',
    });
    expect(offer.unitAmount, 2450);
    expect(offer.currency, 'eur');
    expect(offer.displayAmount, isNot(contains('19.99')));
  });

  test('invalid offer json is rejected', () {
    expect(
      () => PurchaseOffer.fromJson({'currency': 'eur'}),
      throwsFormatException,
    );
    expect(
      () => PurchaseOffer.fromJson({'unit_amount': 100}),
      throwsFormatException,
    );
  });

  test('unavailable provider does not invent a checkout', () async {
    const provider = UnavailablePurchaseProvider();
    await expectLater(
      provider.loadOffer(),
      throwsA(isA<PurchaseUnavailableException>()),
    );
    await expectLater(
      provider.startCheckout(),
      throwsA(isA<PurchaseUnavailableException>()),
    );
  });
}
