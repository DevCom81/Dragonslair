import 'auth_user.dart';

abstract interface class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> restoreSession();
  Future<void> startSignIn({String? context});
  Future<AuthUser> signInAnonymously();
  Future<void> signOut();
  bool get supportsAnonymousSignIn;
}
