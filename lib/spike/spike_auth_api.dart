import 'spike_convex.dart';
import 'spike_session_store.dart';

sealed class SpikeSignInResult {
  const SpikeSignInResult();
}

class SpikeSignedIn extends SpikeSignInResult {
  const SpikeSignedIn({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class SpikeEmailVerificationRequired extends SpikeSignInResult {
  const SpikeEmailVerificationRequired({
    required this.email,
    required this.pendingAuthenticationToken,
  });

  final String email;
  final String pendingAuthenticationToken;
}

class SpikeTokenPair {
  const SpikeTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

class SpikeAuthApi {
  const SpikeAuthApi();

  Future<SpikeSignInResult> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final raw = await SpikeConvex.client.action(
      'spikeAuth:signInWithPassword',
      {
        'email': email.trim(),
        'password': password,
      },
    );
    if (raw is! Map) {
      throw StateError('Unexpected sign-in response.');
    }
    final status = raw['status']?.toString();
    if (status == 'email_verification_required') {
      final pending = raw['pendingAuthenticationToken'];
      if (pending is! String || pending.isEmpty) {
        throw StateError('Email verification is required but the token is missing.');
      }
      return SpikeEmailVerificationRequired(
        email: raw['email']?.toString() ?? email.trim(),
        pendingAuthenticationToken: pending,
      );
    }
    if (status == 'authenticated') {
      return SpikeSignedIn(
        accessToken: _requireToken(raw, 'accessToken'),
        refreshToken: _requireToken(raw, 'refreshToken'),
      );
    }
    throw StateError('Unexpected sign-in status.');
  }

  Future<SpikeSignedIn> verifyEmailCode({
    required String code,
    required String pendingAuthenticationToken,
  }) async {
    final raw = await SpikeConvex.client.action(
      'spikeAuth:verifyEmailCode',
      {
        'code': code.trim(),
        'pendingAuthenticationToken': pendingAuthenticationToken,
      },
    );
    if (raw is! Map) {
      throw StateError('Unexpected verification response.');
    }
    return SpikeSignedIn(
      accessToken: _requireToken(raw, 'accessToken'),
      refreshToken: _requireToken(raw, 'refreshToken'),
    );
  }

  Future<SpikeTokenPair> refreshSession(String refreshToken) async {
    final raw = await SpikeConvex.client.action(
      'spikeAuth:refreshSession',
      {
        'refreshToken': refreshToken,
      },
    );
    if (raw is! Map) {
      throw StateError('Unexpected refresh response.');
    }
    return SpikeTokenPair(
      accessToken: _requireToken(raw, 'accessToken'),
      refreshToken: _requireToken(raw, 'refreshToken'),
    );
  }

  Future<String?> fetchStoredWorkosToken({required bool forceRefresh}) async {
    if (!forceRefresh) {
      final access = await SpikeSessionStore.readAccessToken();
      if (access != null && SpikeSessionStore.accessTokenStillValid(access)) {
        return access;
      }
    }
    final refresh = await SpikeSessionStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return null;
    }
    try {
      final pair = await refreshSession(refresh);
      await SpikeSessionStore.save(
        accessToken: pair.accessToken,
        refreshToken: pair.refreshToken,
      );
      return pair.accessToken;
    } catch (_) {
      await SpikeSessionStore.clear();
      return null;
    }
  }

  String _requireToken(Map<dynamic, dynamic> raw, String key) {
    final token = raw[key];
    if (token is! String || token.isEmpty) {
      throw StateError('WorkOS did not return $key.');
    }
    return token;
  }
}
