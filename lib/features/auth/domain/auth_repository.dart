import 'auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> restoreSession();
  Future<AuthUser> signIn({
    required String email,
    required String password,
  });
  Future<AuthUser> signUp({
    required String email,
    required String password,
  });
  Future<AuthUser> verifyEmailCode({required String code});
  Future<AuthUser> signInAnonymously();
  Future<void> requestPasswordReset({required String email});
  Future<void> signOut();
  bool get supportsAnonymousSignIn;
  bool get supportsPasswordReset;
}
