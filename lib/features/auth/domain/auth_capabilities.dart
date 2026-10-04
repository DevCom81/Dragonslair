class AuthCapabilities {
  const AuthCapabilities({
    required this.isConfigured,
    required this.supportsAnonymousSignIn,
    required this.supportsPasswordReset,
  });

  final bool isConfigured;
  final bool supportsAnonymousSignIn;
  final bool supportsPasswordReset;
}
