import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase l10n never names stripe or google in player-facing strings', () {
    final arbDir = Directory('lib/l10n');
    final purchaseKeys = <String>{
      'unlockDragonsLairTitle',
      'unlockTheGame',
      'unlockDragonsLair',
      'fullGameActivated',
      'accessAlreadyActive',
      'restorePurchase',
      'purchaseUnavailable',
      'purchaseRestored',
      'purchaseNotFound',
    };
  final forbidden = RegExp(r'stripe|google play|payer avec', caseSensitive: false);

    for (final file in arbDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final content = file.readAsStringSync();
      for (final line in content.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('"') || !trimmed.contains('":')) {
          continue;
        }
        final key = trimmed.split('":').first.replaceAll('"', '');
        if (!purchaseKeys.contains(key)) {
          continue;
        }
        expect(
          forbidden.hasMatch(line),
          isFalse,
          reason: '${file.path} key $key exposes a payment provider',
        );
      }
    }
  });

  test('billing provider routing stays platform-specific in access_providers', () {
    final src = File(
      'lib/features/access/presentation/access_providers.dart',
    ).readAsStringSync();
    expect(src.contains('if (kIsWeb)'), isTrue);
    expect(src.contains('TargetPlatform.android'), isTrue);
    expect(src.contains('StripeCheckoutPurchaseProvider'), isTrue);
    expect(src.contains('GooglePlayPurchaseProvider'), isTrue);
    final webBlock = src.split('if (kIsWeb)').last.split('if (defaultTargetPlatform').first;
    expect(webBlock.contains('GooglePlayPurchaseProvider'), isFalse);
  });

  test('presentation layer never launches stripe checkout directly', () {
    const presentationPaths = [
      'lib/features/access/presentation/access_offer_screen.dart',
      'lib/features/access/presentation/purchase_flow.dart',
      'lib/features/access/presentation/demo_timer_hud.dart',
      'lib/features/home/presentation/play_hub_screen.dart',
      'lib/features/rooms/presentation/game_summary_screen.dart',
      'lib/features/board/presentation/board_screen.dart',
    ];
    for (final path in presentationPaths) {
      final src = File(path).readAsStringSync();
      expect(src.contains('purchaseCheckoutUri'), isFalse, reason: path);
      expect(src.contains('StripeCheckoutPurchaseProvider'), isFalse, reason: path);
      expect(src.contains('in_app_purchase'), isFalse, reason: path);
    }
  });

  test('access offer exposes a single purchase cta label', () {
    final src = File(
      'lib/features/access/presentation/access_offer_screen.dart',
    ).readAsStringSync();
    expect(src.contains('unlockDragonsLair'), isTrue);
    expect(src.contains('unlockTheGame'), isFalse);
    expect(src.split('FilledButton').length, lessThan(6));
  });
}
