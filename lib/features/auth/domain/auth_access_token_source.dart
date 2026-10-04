abstract interface class AuthAccessTokenSource {
  Future<String?> accessToken({bool forceRefresh = false});
}
