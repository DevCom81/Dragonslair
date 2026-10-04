import 'dart:async';

import '../../../core/errors/app_exception.dart';
import '../domain/auth_access_token_source.dart';
import '../domain/auth_email_verification.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../domain/workos_auth_gateway.dart';
import 'workos_jwt.dart';
import 'workos_session_store.dart';

class WorkOsAuthRepository
    implements AuthRepository, AuthAccessTokenSource {
  WorkOsAuthRepository({
    required WorkOsAuthGateway gateway,
    required WorkOsSessionStore sessionStore,
    DateTime Function()? clock,
  })  : _gateway = gateway,
        _sessionStore = sessionStore,
        _clock = clock ?? DateTime.now;

  final WorkOsAuthGateway _gateway;
  final WorkOsSessionStore _sessionStore;
  final DateTime Function() _clock;
  final _changes = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  String? _pendingAuthenticationToken;
  String? _pendingVerificationEmail;
  var _refreshInFlight = false;

  @override
  AuthUser? get currentUser => _currentUser;

  String? get pendingVerificationEmail => _pendingVerificationEmail;

  @override
  bool get supportsAnonymousSignIn => false;

  @override
  bool get supportsPasswordReset => true;

  @override
  Stream<AuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<AuthUser?> restoreSession() async {
    final access = await _sessionStore.readAccessToken();
    final refresh = await _sessionStore.readRefreshToken();
    _accessToken = access;
    _refreshToken = refresh;
    if (access != null &&
        accessTokenStillValid(access, now: _clock())) {
      return _setSession(accessToken: access, refreshToken: refresh ?? '');
    }
    if (refresh == null || refresh.isEmpty) {
      await _clearSession();
      return null;
    }
    return _refresh(refresh);
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    final access = _accessToken ?? await _sessionStore.readAccessToken();
    if (!forceRefresh &&
        access != null &&
        accessTokenStillValid(access, now: _clock())) {
      _accessToken = access;
      return access;
    }
    final refresh = _refreshToken ?? await _sessionStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      await _clearSession();
      return null;
    }
    final user = await _refresh(refresh);
    return user == null ? null : _accessToken;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) {
    return _authenticate(
      () => _gateway.signInWithPassword(email: email, password: password),
    );
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) {
    return _authenticate(
      () => _gateway.signUpWithPassword(email: email, password: password),
    );
  }

  @override
  Future<AuthUser> verifyEmailCode({required String code}) async {
    final pending = _pendingAuthenticationToken;
    if (pending == null || pending.isEmpty) {
      throw const AppAuthException('Verification email is required.');
    }
    try {
      final tokens = await _gateway.verifyEmailCode(
        code: code,
        pendingAuthenticationToken: pending,
      );
      _pendingAuthenticationToken = null;
      _pendingVerificationEmail = null;
      final user = await _setSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      if (user == null) {
        throw const AppAuthException('Connexion impossible.');
      }
      return user;
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AppAuthException('Code de verification invalide.', cause: error);
    }
  }

  @override
  Future<AuthUser> signInAnonymously() {
    throw const AppAuthException(
      'Le mode invite n est pas disponible avec WorkOS.',
    );
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _gateway.requestPasswordReset(email: email);
    } catch (_) {
      // Same visible outcome whether or not the address exists.
    }
  }

  @override
  Future<void> signOut() async {
    await _clearSession();
  }

  Future<AuthUser> _authenticate(
    Future<WorkOsSignInResult> Function() call,
  ) async {
    try {
      final result = await call();
      switch (result) {
        case WorkOsEmailVerificationRequired(
            :final email,
            :final pendingAuthenticationToken,
          ):
          _pendingAuthenticationToken = pendingAuthenticationToken;
          _pendingVerificationEmail = email;
          throw AuthEmailVerificationRequired(email: email);
        case WorkOsAuthenticated(:final tokens):
          _pendingAuthenticationToken = null;
          _pendingVerificationEmail = null;
          final user = await _setSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
          );
          if (user == null) {
            throw const AppAuthException('Connexion impossible.');
          }
          return user;
      }
    } on AuthEmailVerificationRequired {
      rethrow;
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AppAuthException('Connexion impossible.', cause: error);
    }
  }

  Future<AuthUser?> _refresh(String refreshToken) async {
    if (_refreshInFlight) {
      return _currentUser;
    }
    _refreshInFlight = true;
    try {
      final tokens = await _gateway.refreshSession(refreshToken: refreshToken);
      return _setSession(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
    } catch (_) {
      await _clearSession();
      return null;
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<AuthUser?> _setSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    final subject = workosSubjectFromAccessToken(accessToken);
    if (subject == null) {
      await _clearSession();
      return null;
    }
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _sessionStore.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    final user = AuthUser(id: subject, isAnonymous: false);
    _currentUser = user;
    _changes.add(user);
    return user;
  }

  Future<void> _clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    _pendingAuthenticationToken = null;
    _pendingVerificationEmail = null;
    await _sessionStore.clear();
    _changes.add(null);
  }
}
