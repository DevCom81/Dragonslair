import 'dart:async';

import 'package:auth0_flutter/auth0_flutter_web.dart';
import 'package:auth0_flutter_platform_interface/auth0_flutter_platform_interface.dart'
    show CacheMode;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/auth_access_token_source.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';

Uri auth0AppOrigin([Uri? pageUri]) {
  final origin = pageUri ?? Uri.base;
  return Uri(
    scheme: origin.scheme,
    host: origin.host,
    port: _nonDefaultPort(origin),
    path: '/',
  );
}

int? _nonDefaultPort(Uri origin) {
  if (!origin.hasPort) {
    return null;
  }
  if (origin.scheme == 'https' && origin.port == 443) {
    return null;
  }
  if (origin.scheme == 'http' && origin.port == 80) {
    return null;
  }
  return origin.port;
}

class Auth0AuthRepository implements AuthRepository, AuthAccessTokenSource {
  Auth0AuthRepository({
    required Auth0Web auth0,
    String? audience,
    Uri? appOrigin,
  })  : _auth0 = auth0,
        _audience = audience,
        _appOrigin = appOrigin;

  final Auth0Web _auth0;
  final String? _audience;
  final Uri? _appOrigin;
  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  var _ready = false;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  bool get supportsAnonymousSignIn => false;

  @override
  Stream<AuthUser?> authStateChanges() => _changes.stream;

  @override
  Future<AuthUser?> restoreSession() async {
    final session = await _ensureInitialized();
    return _syncSession(session);
  }

  @override
  Future<String?> accessToken({bool forceRefresh = false}) async {
    await _ensureInitialized();
    final session = await _credentials(
      audience: _requireAudience(),
      forceRefresh: forceRefresh,
    );
    _syncSession(session);
    final token = session?.accessToken;
    if (token is! String || token.isEmpty) {
      return null;
    }
    return token;
  }

  @override
  Future<void> startSignIn({String? context}) async {
    await _ensureInitialized();
    await _auth0.loginWithRedirect(
      redirectUrl: _redirectUrl,
      audience: _requireAudience(),
    );
  }

  @override
  Future<AuthUser> signInAnonymously() {
    throw const AppAuthException(
      'Le mode invite n est pas disponible avec Auth0.',
    );
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    _currentUser = null;
    _changes.add(null);
    await _auth0.logout(returnToUrl: _redirectUrl);
  }

  Future<dynamic> _ensureInitialized() async {
    if (_ready) {
      return _credentials(
        audience: _requireAudience(),
        forceRefresh: false,
      );
    }
    final audience = _audience ?? AppConfig.auth0Audience;
    if (audience.isEmpty) {
      throw const AppAuthException('AUTH0_AUDIENCE est requis.');
    }
    await _auth0.onLoad(
      audience: audience,
    );
    _ready = true;
    return _credentials(audience: audience, forceRefresh: false);
  }

  String get _redirectUrl => (_appOrigin ?? auth0AppOrigin()).toString();

  String _requireAudience() {
    final audience = _audience ?? AppConfig.auth0Audience;
    if (audience.isEmpty) {
      throw const AppAuthException('AUTH0_AUDIENCE est requis.');
    }
    return audience;
  }

  Future<dynamic> _credentials({
    required String audience,
    required bool forceRefresh,
  }) async {
    if (!await _auth0.hasValidCredentials()) {
      return null;
    }
    if (forceRefresh) {
      return _auth0.credentials(
        audience: audience,
        cacheMode: CacheMode.off,
      );
    }
    return _auth0.credentials(audience: audience);
  }

  AuthUser? _syncSession(dynamic session) {
    final next = session == null
        ? null
        : AuthUser(id: _subjectFrom(session), isAnonymous: false);
    _currentUser = next;
    _changes.add(next);
    return next;
  }

  String _subjectFrom(dynamic credentials) {
    final subject = credentials.user.sub.trim();
    if (subject.isEmpty) {
      throw const AppAuthException('Auth0 user subject is missing.');
    }
    return subject;
  }
}
