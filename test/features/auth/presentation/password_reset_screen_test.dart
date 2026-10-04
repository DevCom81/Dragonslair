import 'dart:async';

import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/features/auth/domain/auth_repository.dart';
import 'package:dragons_lair/features/auth/domain/auth_user.dart';
import 'package:dragons_lair/features/auth/presentation/password_reset_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/responsive_harness.dart';

void main() {
  testWidgets('password reset asks only for email then shows a send message',
      (tester) async {
    final repository = _FakeAuthRepository();
    await _pumpReset(tester, repository);

    expect(find.text('Jeton recu par email'), findsNothing);
    expect(find.text('Nouveau mot de passe'), findsNothing);
    expect(find.text('Definir le mot de passe'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'hero@example.com');
    await tester.tap(find.text('Envoyer l email'));
    await tester.pumpAndSettle();

    expect(repository.resetEmails, ['hero@example.com']);
    expect(
      find.text(
        'Si un compte existe pour cette adresse, un email de reinitialisation a ete envoye.',
      ),
      findsOneWidget,
    );
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Jeton recu par email'), findsNothing);
    expect(find.text('Nouveau mot de passe'), findsNothing);
  });

  testWidgets('password reset stays enumeration-safe if the request fails',
      (tester) async {
    final repository = _FakeAuthRepository(resetError: true);
    await _pumpReset(tester, repository);

    await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
    await tester.tap(find.text('Envoyer l email'));
    await tester.pumpAndSettle();

    expect(repository.resetEmails, ['unknown@example.com']);
    expect(
      find.text(
        'Si un compte existe pour cette adresse, un email de reinitialisation a ete envoye.',
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpReset(
  WidgetTester tester,
  _FakeAuthRepository repository,
) {
  return pumpAtSize(
    tester,
    size: const Size(390, 844),
    child: ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWith((ref) => repository),
      ],
      child: const PasswordResetScreen(),
    ),
  );
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.resetError = false});

  final bool resetError;
  final resetEmails = <String>[];
  final _changes = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<AuthUser?> restoreSession() async => null;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signInAnonymously() async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> verifyEmailCode({required String code}) async {
    throw UnimplementedError();
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    resetEmails.add(email);
    if (resetError) {
      throw Exception('reset failed');
    }
  }

  @override
  bool get supportsAnonymousSignIn => true;

  @override
  bool get supportsPasswordReset => true;

  @override
  Future<void> signOut() async {}
}
