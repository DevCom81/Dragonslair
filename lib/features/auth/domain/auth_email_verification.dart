class AuthEmailVerificationRequired implements Exception {
  const AuthEmailVerificationRequired({required this.email});

  final String email;

  @override
  String toString() => 'Email verification required.';
}
