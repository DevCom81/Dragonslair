typedef ConvexTokenFetcher = Future<String?> Function({
  required bool forceRefresh,
});

abstract interface class ConvexWatch {
  Stream<Object?> get snapshots;
  void cancel();
}

abstract interface class ConvexGateway {
  Future<void> setAuthWithRefresh({required ConvexTokenFetcher fetchToken});

  Future<void> clearAuth();

  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]);

  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]);

  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]);

  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]);
}
