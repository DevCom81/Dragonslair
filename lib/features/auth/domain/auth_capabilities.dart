class AuthCapabilities {
  const AuthCapabilities({
    required this.isConfigured,
    required this.supportsAnonymousSignIn,
  });

  final bool isConfigured;
  final bool supportsAnonymousSignIn;
}
