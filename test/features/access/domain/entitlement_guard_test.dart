import 'dart:io';

import 'package:dragons_lair/features/access/domain/game_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server full entitlement survives a login parse', () {
    final entitlement = UserEntitlement.fromJson({
      'user_id': 'user-1',
      'access_level': 'full',
      'source': 'purchase',
    });
    expect(entitlement.level.isFull, isTrue);
    expect(entitlement.source, 'purchase');
  });

  test('expired full cache is treated as demo', () {
    final entitlement = UserEntitlement.fromJson({
      'user_id': 'user-1',
      'access_level': 'full',
      'source': 'purchase',
      'expires_at': '2020-01-01T00:00:00Z',
    });
    expect(entitlement.level.isDemo, isTrue);
  });

  test('forged source cannot self-grant full', () {
    expect(
      UserEntitlement.fromJson({
        'user_id': 'user-1',
        'access_level': 'demo',
        'source': 'full',
      }).level.isFull,
      isFalse,
    );
    expect(GameAccessLevel.fromJson('admin'), GameAccessLevel.demo);
    expect(GameAccessLevel.fromJson('purchase'), GameAccessLevel.demo);
  });

  test('client entitlement repository never writes the table', () {
    final src = File(
      'lib/features/access/domain/entitlement_repository.dart',
    ).readAsStringSync();
    expect(src.contains(".from('user_entitlements')"), isTrue);
    expect(src.contains('.update('), isFalse);
    expect(src.contains('.insert('), isFalse);
    expect(src.contains('.upsert('), isFalse);
  });

  test('google play verifier sends token without a client-side full grant', () {
    final src = File(
      'lib/features/access/data/google_play_backend_verifier.dart',
    ).readAsStringSync();
    expect(src.contains("'purchase_token': purchaseToken"), isTrue);
    expect(src.contains("'access_level':"), isFalse);
    expect(src.contains('user_entitlements'), isFalse);
  });

  test('stripe checkout client never sends access_level', () {
    final src = File(
      'lib/features/access/data/stripe_checkout_purchase_provider.dart',
    ).readAsStringSync();
    expect(src.contains('access_level'), isFalse);
    expect(src.contains("'full'"), isFalse);
  });

  test('hub and offer screens do not import play billing or stripe', () {
    const paths = [
      'lib/features/access/presentation/access_offer_screen.dart',
      'lib/features/access/presentation/purchase_flow.dart',
      'lib/features/access/presentation/purchase_platform.dart',
      'lib/features/home/presentation/play_hub_screen.dart',
    ];
    for (final path in paths) {
      final src = File(path).readAsStringSync();
      expect(src.contains('in_app_purchase'), isFalse, reason: path);
      expect(src.contains('StripeCheckout'), isFalse, reason: path);
      expect(src.contains('GooglePlayPurchase'), isFalse, reason: path);
    }
  });

  test('purchase provider is disabled when entitlement is full', () {
    final src = File(
      'lib/features/access/presentation/access_providers.dart',
    ).readAsStringSync();
    expect(src.contains('UnavailablePurchaseProvider'), isTrue);
    expect(src.contains('BackendEntitlementClient'), isTrue);
    expect(src.contains('fetchMe'), isTrue);
  });

  test('stripe full on web does not force google play on android install path', () {
    final src = File(
      'test/features/access/cross_platform_stripe_full_test.dart',
    ).readAsStringSync();
    expect(src.contains('stripe-user'), isTrue);
    expect(src.contains('UnavailablePurchaseProvider'), isTrue);
  });

  test('google play full on android does not force stripe on web login path', () {
    final src = File(
      'test/features/access/cross_platform_google_play_full_test.dart',
    ).readAsStringSync();
    expect(src.contains('play-user'), isTrue);
    expect(src.contains('UnavailablePurchaseProvider'), isTrue);
    expect(src.contains('startWindowsDownload'), isTrue);
  });

  test('play account id is derived from uuid never from email', () {
    final src = File(
      'lib/features/access/domain/play_account_id.dart',
    ).readAsStringSync();
    expect(src.contains('email'), isFalse);
    expect(src.contains('sha256'), isTrue);
    final store = File(
      'lib/features/access/data/play_billing_store_io.dart',
    ).readAsStringSync();
    expect(store.contains('applicationUserName: obfuscatedAccountId'), isTrue);
    expect(store.contains('restorePurchases('), isTrue);
    expect(store.contains('completePurchase'), isTrue);
  });

  test('flutter never embeds google play service account', () {
    final src = File('lib/core/config/app_config.dart').readAsStringSync();
    expect(src.contains('SERVICE_ACCOUNT'), isFalse);
    expect(src.contains('private_key'), isFalse);
  });
}
