import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PASS 20 client security guards', () {
    test('flutter never grants full locally', () {
      const paths = [
        'lib/features/access/domain/entitlement_repository.dart',
        'lib/features/access/data/google_play_backend_verifier.dart',
        'lib/features/access/data/google_play_purchase_provider.dart',
        'lib/features/access/data/stripe_checkout_purchase_provider.dart',
        'lib/features/access/presentation/access_providers.dart',
        'lib/features/access/presentation/purchase_flow.dart',
      ];
      for (final path in paths) {
        final src = File(path).readAsStringSync();
        expect(src.contains('.update('), isFalse, reason: path);
        expect(src.contains('.insert('), isFalse, reason: path);
        expect(src.contains('.upsert('), isFalse, reason: path);
        expect(src.contains("'access_level': 'full'"), isFalse, reason: path);
      }
    });

    test('play purchases always go through backend verifier', () {
      final provider = File(
        'lib/features/access/data/google_play_purchase_provider.dart',
      ).readAsStringSync();
      expect(provider.contains('await _verifier.verify'), isTrue);
      expect(provider.contains('user_entitlements'), isFalse);
      final store = File(
        'lib/features/access/data/play_billing_store_io.dart',
      ).readAsStringSync();
      expect(store.contains('access_level'), isFalse);
      expect(store.contains('GameAccessLevel.full'), isFalse);
    });

    test('no google play service account or stripe secrets in flutter', () {
      final config = File('lib/core/config/app_config.dart').readAsStringSync();
      expect(config.contains('SERVICE_ACCOUNT'), isFalse);
      expect(config.contains('STRIPE_SECRET'), isFalse);
      expect(config.contains('private_key'), isFalse);
      final verifier = File(
        'lib/features/access/data/google_play_backend_verifier.dart',
      ).readAsStringSync();
      expect(verifier.contains('SERVICE_ACCOUNT'), isFalse);
    });

    test('entitlement is not cached permanently in shared preferences', () {
      final lib = Directory('lib/features/access');
      for (final file in lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final src = file.readAsStringSync();
        expect(src.contains('SharedPreferences'), isFalse, reason: file.path);
      }
    });

    test('global full is resolved from backend not current platform', () {
      final providers = File(
        'lib/features/access/presentation/access_providers.dart',
      ).readAsStringSync();
      expect(providers.contains('BackendEntitlementClient'), isTrue);
      expect(providers.contains('fetchMe'), isTrue);
      final body = providers.split('final purchaseProvider').last;
      expect(body.contains('isFull'), isTrue);
      expect(body.contains('UnavailablePurchaseProvider'), isTrue);
    });

    test('rooms only read entitlements never write them', () {
      final src = File(
        'lib/features/rooms/data/supabase_room_repository.dart',
      ).readAsStringSync();
      expect(src.contains('.from(\'user_entitlements\')'), isTrue);
      expect(src.contains('.from(\'user_entitlements\').update'), isFalse);
      expect(src.contains('.from(\'user_entitlements\').insert'), isFalse);
      expect(src.contains('.from(\'user_entitlements\').upsert'), isFalse);
    });

    test('verifier trusts backend is_full not client-side grant', () {
      final src = File(
        'lib/features/access/data/google_play_backend_verifier.dart',
      ).readAsStringSync();
      expect(src.contains("'is_full'"), isTrue);
      expect(src.contains('user_entitlements'), isFalse);
    });
  });
}
