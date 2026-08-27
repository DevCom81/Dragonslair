import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('429 is a calm retry, not a visible rate-limit brand', () {
    expect(
      refusalMessageForStatus(429, 'fallback'),
      'Le maitre du jeu est occupe. Reessaie dans un instant.',
    );
    expect(refusalMessageForStatus(429, 'fallback'), isNot(contains('RATE')));
    expect(refusalMessageForStatus(403, 'refuse'), 'refuse');
  });
}
