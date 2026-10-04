import 'dart:async';

import 'package:dartvex/dartvex.dart';

import 'convex_gateway.dart';

class DartvexConvexGateway implements ConvexGateway {
  DartvexConvexGateway(this._client);

  final ConvexClient _client;
  AuthHandle? _authHandle;

  @override
  Future<void> setAuthWithRefresh({
    required ConvexTokenFetcher fetchToken,
  }) async {
    await _authHandle?.cancel();
    _authHandle = await _client.setAuthWithRefresh(
      fetchToken: fetchToken,
    );
  }

  @override
  Future<void> clearAuth() async {
    await _authHandle?.cancel();
    _authHandle = null;
    await _client.clearAuth();
  }

  @override
  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    return _client.query(name, Map<String, dynamic>.from(args));
  }

  @override
  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    return _client.mutate(name, Map<String, dynamic>.from(args));
  }

  @override
  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    return _client.action(name, Map<String, dynamic>.from(args));
  }

  @override
  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    return _DartvexWatch(
      _client.subscribe(name, Map<String, dynamic>.from(args)),
    );
  }
}

class _DartvexWatch implements ConvexWatch {
  _DartvexWatch(this._subscription) {
    _controller = StreamController<Object?>.broadcast();
    _listen = _subscription.stream.listen(
      _onResult,
      onError: _controller.addError,
    );
  }

  final ConvexSubscription _subscription;
  late final StreamController<Object?> _controller;
  late final StreamSubscription<QueryResult> _listen;
  var _cancelled = false;

  @override
  Stream<Object?> get snapshots => _controller.stream;

  void _onResult(QueryResult result) {
    if (_cancelled || _controller.isClosed) {
      return;
    }
    switch (result) {
      case QueryLoading():
        return;
      case QueryError(:final message):
        _controller.addError(Exception(message));
      case QuerySuccess(:final value):
        _controller.add(value);
    }
  }

  @override
  void cancel() {
    if (_cancelled) {
      return;
    }
    _cancelled = true;
    unawaited(_listen.cancel());
    _subscription.cancel();
    unawaited(_controller.close());
  }
}
