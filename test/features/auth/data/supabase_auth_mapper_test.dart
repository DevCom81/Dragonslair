import 'package:dragons_lair/features/auth/data/supabase_auth_mapper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

void main() {
  test('maps a Supabase user id onto AuthUser', () {
    final user = _supabaseUser(
      id: 'user-1',
      isAnonymous: false,
      email: 'hero@example.com',
    );
    final mapped = authUserFromSupabase(user);
    expect(mapped.id, 'user-1');
    expect(mapped.isAnonymous, isFalse);
  });

  test('anonymous Supabase user becomes AuthUser.isAnonymous=true', () {
    final mapped = authUserFromSupabase(
      _supabaseUser(id: 'anon-1', isAnonymous: true),
    );
    expect(mapped.isAnonymous, isTrue);
  });

  test('email Supabase user becomes AuthUser.isAnonymous=false', () {
    final mapped = authUserFromSupabase(
      _supabaseUser(
        id: 'user-2',
        isAnonymous: false,
        email: 'mage@example.com',
      ),
    );
    expect(mapped.isAnonymous, isFalse);
  });
}

User _supabaseUser({
  required String id,
  required bool isAnonymous,
  String? email,
}) {
  return User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2024-01-01T00:00:00.000Z',
    isAnonymous: isAnonymous,
    email: email,
  );
}
