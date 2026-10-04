import 'dart:convert';

import 'package:dragons_lair/features/auth/data/workos_jwt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads WorkOS subject from access token', () {
    final token = _jwt(sub: 'user_workos_1', exp: 2000000000);
    expect(workosSubjectFromAccessToken(token), 'user_workos_1');
  });

  test('valid token is still usable', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
    final token = _jwt(
      sub: 'user_1',
      exp: now.millisecondsSinceEpoch ~/ 1000 + 120,
    );
    expect(accessTokenStillValid(token, now: now), isTrue);
  });

  test('expired token is not usable', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);
    final token = _jwt(
      sub: 'user_1',
      exp: now.millisecondsSinceEpoch ~/ 1000,
    );
    expect(accessTokenStillValid(token, now: now), isFalse);
  });
}

String _jwt({required String sub, required int exp}) {
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'sub': sub, 'exp': exp})),
  );
  return 'eyJhbGciOiJub25lIn0.$payload.sig';
}
