import 'package:dragons_lair/features/access/domain/play_account_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('play obfuscated account id is sha256 of uuid never email', () {
    const userId = '11111111-1111-1111-1111-111111111111';
    final accountId = playObfuscatedAccountId(userId);
    expect(accountId.length, 64);
    expect(
      accountId,
      'fb6a91d8f279ffe254ec44fbd79f829197d217f4d56e588b96d4bf816d6f88a0',
    );
    expect(accountId.contains(userId), isFalse);
    expect(playObfuscatedAccountId('player@example.com'), isNot('player@example.com'));
    expect(playObfuscatedAccountId(''), isEmpty);
  });
}
