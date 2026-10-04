class WorkOsTokenPair {
  const WorkOsTokenPair({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;
}

sealed class WorkOsSignInResult {
  const WorkOsSignInResult();
}

class WorkOsAuthenticated extends WorkOsSignInResult {
  const WorkOsAuthenticated(this.tokens);

  final WorkOsTokenPair tokens;
}

class WorkOsEmailVerificationRequired extends WorkOsSignInResult {
  const WorkOsEmailVerificationRequired({
    required this.email,
    required this.pendingAuthenticationToken,
  });

  final String email;
  final String pendingAuthenticationToken;
}

abstract interface class WorkOsAuthGateway {
  Future<WorkOsSignInResult> signInWithPassword({
    required String email,
    required String password,
  });

  Future<WorkOsSignInResult> signUpWithPassword({
    required String email,
    required String password,
  });

  Future<WorkOsTokenPair> verifyEmailCode({
    required String code,
    required String pendingAuthenticationToken,
  });

  Future<WorkOsTokenPair> refreshSession({required String refreshToken});

  Future<void> requestPasswordReset({required String email});
}
