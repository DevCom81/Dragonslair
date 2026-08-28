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

  test('stripe checkout client never sends access_level', () {
    final src = File(
      'lib/features/access/data/stripe_checkout_purchase_provider.dart',
    ).readAsStringSync();
    expect(src.contains('access_level'), isFalse);
    expect(src.contains("'full'"), isFalse);
  });
}
