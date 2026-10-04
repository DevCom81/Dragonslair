import 'package:dartvex/dartvex.dart';

import '../../../core/errors/app_exception.dart';
import '../domain/workos_auth_gateway.dart';

class ConvexWorkOsAuthGateway implements WorkOsAuthGateway {
  ConvexWorkOsAuthGateway(this._client);

  final ConvexClient _client;

  @override
  Future<WorkOsSignInResult> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _signInAction(
      'spikeAuth:signInWithPassword',
      {'email': email.trim(), 'password': password},
    );
  }

  @override
  Future<WorkOsSignInResult> signUpWithPassword({
    required String email,
    required String password,
  }) {
    return _signInAction(
      'spikeAuth:signUpWithPassword',
      {'email': email.trim(), 'password': password},
    );
  }

  @override
  Future<WorkOsTokenPair> verifyEmailCode({
    required String code,
    required String pendingAuthenticationToken,
  }) async {
    final raw = await _action('spikeAuth:verifyEmailCode', {
      'code': code.trim(),
      'pendingAuthenticationToken': pendingAuthenticationToken,
    });
    return _requireTokens(raw);
  }

  @override
  Future<WorkOsTokenPair> refreshSession({required String refreshToken}) async {
    final raw = await _action('spikeAuth:refreshSession', {
      'refreshToken': refreshToken,
    });
    return _requireTokens(raw);
  }

  @override
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _client.action(
        'spikeAuth:requestPasswordReset',
        <String, dynamic>{'email': email.trim()},
      );
    } catch (_) {
      // Existence of the account must not leak to the client.
    }
  }

  Future<WorkOsSignInResult> _signInAction(
    String name,
    Map<String, Object> args,
  ) async {
    final raw = await _action(name, args);
    final status = raw['status']?.toString();
    if (status == 'email_verification_required') {
      final pending = raw['pendingAuthenticationToken'];
      if (pending is! String || pending.isEmpty) {
        throw const AppAuthException('Verification email is required.');
      }
      return WorkOsEmailVerificationRequired(
        email: raw['email']?.toString() ?? args['email']?.toString() ?? '',
        pendingAuthenticationToken: pending,
      );
    }
    if (status == 'authenticated') {
      return WorkOsAuthenticated(_requireTokens(raw));
    }
    throw const AppAuthException('Connexion impossible.');
  }

  Future<Map<dynamic, dynamic>> _action(
    String name,
    Map<String, Object> args,
  ) async {
    try {
      final raw = await _client.action(name, Map<String, dynamic>.from(args));
      if (raw is! Map) {
        throw const AppAuthException('Connexion impossible.');
      }
      return raw;
    } on AppAuthException {
      rethrow;
    } catch (error) {
      throw AppAuthException('Connexion impossible.', cause: error);
    }
  }

  WorkOsTokenPair _requireTokens(Map<dynamic, dynamic> raw) {
    final accessToken = raw['accessToken'];
    final refreshToken = raw['refreshToken'];
    if (accessToken is! String ||
        accessToken.isEmpty ||
        refreshToken is! String ||
        refreshToken.isEmpty) {
      throw const AppAuthException('Connexion impossible.');
    }
    return WorkOsTokenPair(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
  }
}
