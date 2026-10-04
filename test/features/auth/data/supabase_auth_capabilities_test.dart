import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:dragons_lair/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy anonymous remains supported', () {
    const repository = SupabaseAuthRepository(null);
    expect(repository.supportsAnonymousSignIn, isTrue);
    expect(repository.supportsPasswordReset, isFalse);
  });

  test('legacy password reset remains unavailable', () {
    expect(
      () => const SupabaseAuthRepository(null).requestPasswordReset(
        email: 'a@b.c',
      ),
      throwsA(isA<AppAuthException>()),
    );
  });
}
