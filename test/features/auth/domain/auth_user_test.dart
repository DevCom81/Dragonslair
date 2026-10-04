import 'package:dragons_lair/features/auth/domain/auth_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('anonymous guest UI follows AuthUser.isAnonymous', () {
    expect(
      showsAnonymousGuestUi(const AuthUser(id: 'a', isAnonymous: true)),
      isTrue,
    );
    expect(
      showsAnonymousGuestUi(const AuthUser(id: 'b', isAnonymous: false)),
      isFalse,
    );
    expect(showsAnonymousGuestUi(null), isFalse);
  });
}
