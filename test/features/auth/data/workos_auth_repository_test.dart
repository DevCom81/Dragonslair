import 'dart:convert';

import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:dragons_lair/features/auth/data/workos_auth_repository.dart';
import 'package:dragons_lair/features/auth/data/workos_session_store.dart';
import 'package:dragons_lair/features/auth/domain/auth_email_verification.dart';
import 'package:dragons_lair/features/auth/domain/workos_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGateway gateway;
  late _MemoryStore store;
  late WorkOsAuthRepository repository;
  final now = DateTime.fromMillisecondsSinceEpoch(1_700_000_000_000);

  setUp(() {
    gateway = _FakeGateway();
    store = _MemoryStore();
    repository = WorkOsAuthRepository(
      gateway: gateway,
      sessionStore: store,
      clock: () => now,
    );
  });

  test('login success maps WorkOS subject onto AuthUser', () async {
    gateway.signInResult = WorkOsAuthenticated(
      WorkOsTokenPair(
        accessToken: _jwt('user_workos_42', now, const Duration(hours: 1)),
        refreshToken: 'refresh-1',
      ),
    );
    final user = await repository.signIn(
      email: 'hero@example.com',
      password: 'secret',
    );
    expect(user.id, 'user_workos_42');
    expect(user.isAnonymous, isFalse);
    expect(repository.currentUser, user);
  });

  test('signup requiring verification does not create AuthUser', () async {
    gateway.signUpResult = const WorkOsEmailVerificationRequired(
      email: 'mage@example.com',
      pendingAuthenticationToken: 'pending-1',
    );
    await expectLater(
      repository.signUp(email: 'mage@example.com', password: 'secret'),
      throwsA(isA<AuthEmailVerificationRequired>()),
    );
    expect(repository.currentUser, isNull);
    expect(store.access, isNull);
  });

  test('email verification creates a session', () async {
    gateway.signUpResult = const WorkOsEmailVerificationRequired(
      email: 'mage@example.com',
      pendingAuthenticationToken: 'pending-1',
    );
    gateway.verifyTokens = WorkOsTokenPair(
      accessToken: _jwt('user_workos_7', now, const Duration(hours: 1)),
      refreshToken: 'refresh-2',
    );
    await expectLater(
      repository.signUp(email: 'mage@example.com', password: 'secret'),
      throwsA(isA<AuthEmailVerificationRequired>()),
    );
    final user = await repository.verifyEmailCode(code: '123456');
    expect(user.id, 'user_workos_7');
    expect(repository.currentUser?.isAnonymous, isFalse);
    expect(store.access, isNotNull);
  });

  test('persisted session can be restored', () async {
    store.access = _jwt('user_workos_9', now, const Duration(hours: 1));
    store.refresh = 'refresh-9';
    final user = await repository.restoreSession();
    expect(user?.id, 'user_workos_9');
    expect(gateway.refreshCalls, 0);
  });

  test('valid token does not refresh', () async {
    store.access = _jwt('user_workos_9', now, const Duration(hours: 1));
    store.refresh = 'refresh-9';
    await repository.restoreSession();
    final token = await repository.accessToken();
    expect(token, store.access);
    expect(gateway.refreshCalls, 0);
  });

  test('expired token refreshes', () async {
    store.access = _jwt('user_workos_9', now, Duration.zero);
    store.refresh = 'refresh-9';
    gateway.refreshTokens = WorkOsTokenPair(
      accessToken: _jwt('user_workos_9', now, const Duration(hours: 1)),
      refreshToken: 'refresh-10',
    );
    await repository.restoreSession();
    expect(gateway.refreshCalls, 1);
    expect(store.refresh, 'refresh-10');
  });

  test('failed refresh clears the local session', () async {
    store.access = _jwt('user_workos_9', now, Duration.zero);
    store.refresh = 'refresh-9';
    gateway.refreshError = true;
    final user = await repository.restoreSession();
    expect(user, isNull);
    expect(repository.currentUser, isNull);
    expect(store.access, isNull);
    expect(store.refresh, isNull);
  });

  test('logout clears the session', () async {
    gateway.signInResult = WorkOsAuthenticated(
      WorkOsTokenPair(
        accessToken: _jwt('user_workos_1', now, const Duration(hours: 1)),
        refreshToken: 'refresh-1',
      ),
    );
    await repository.signIn(email: 'a@b.c', password: 'x');
    await repository.signOut();
    expect(repository.currentUser, isNull);
    expect(store.access, isNull);
  });

  test('password reset request does not reveal account existence', () async {
    await repository.requestPasswordReset(email: 'known@example.com');
    await repository.requestPasswordReset(email: 'unknown@example.com');
    expect(gateway.resetEmails, ['known@example.com', 'unknown@example.com']);
  });

  test('password reset request stays enumeration-safe when WorkOS fails',
      () async {
    gateway.resetError = true;
    await repository.requestPasswordReset(email: 'anyone@example.com');
    expect(gateway.resetEmails, ['anyone@example.com']);
  });

  test('anonymous WorkOS sign-in is explicitly unsupported', () {
    expect(
      () => repository.signInAnonymously(),
      throwsA(isA<AppAuthException>()),
    );
  });

  test('legacy anonymous remains available on the interface', () {
    expect(repository.supportsAnonymousSignIn, isFalse);
  });
}

class _MemoryStore implements WorkOsSessionStore {
  String? access;
  String? refresh;

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}

class _FakeGateway implements WorkOsAuthGateway {
  WorkOsSignInResult? signInResult;
  WorkOsSignInResult? signUpResult;
  WorkOsTokenPair? verifyTokens;
  WorkOsTokenPair? refreshTokens;
  var refreshError = false;
  var refreshCalls = 0;
  var resetError = false;
  final resetEmails = <String>[];

  @override
  Future<WorkOsSignInResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return signInResult!;
  }

  @override
  Future<WorkOsSignInResult> signUpWithPassword({
    required String email,
    required String password,
  }) async {
    return signUpResult!;
  }

  @override
  Future<WorkOsTokenPair> verifyEmailCode({
    required String code,
    required String pendingAuthenticationToken,
  }) async {
    return verifyTokens!;
  }

  @override
  Future<WorkOsTokenPair> refreshSession({required String refreshToken}) async {
    refreshCalls += 1;
    if (refreshError) {
      throw Exception('refresh failed');
    }
    return refreshTokens!;
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    resetEmails.add(email);
    if (resetError) {
      throw Exception('reset failed');
    }
  }
}

String _jwt(String sub, DateTime now, Duration lifetime) {
  final exp = now.add(lifetime).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(
    utf8.encode(jsonEncode({'sub': sub, 'exp': exp})),
  );
  return 'eyJhbGciOiJub25lIn0.$payload.sig';
}
