import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:dragons_lair/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy anonymous remains supported', () {
    const repository = SupabaseAuthRepository(null);
    expect(repository.supportsAnonymousSignIn, isTrue);
  });

  test('legacy external sign-in remains unavailable', () {
    expect(
      () => const SupabaseAuthRepository(null).startSignIn(),
      throwsA(isA<AppAuthException>()),
    );
  });
}
