class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class AppAuthException extends AppException {
  const AppAuthException(super.message, {super.cause});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

class RealtimeException extends AppException {
  const RealtimeException(super.message, {super.cause});
}

class GameException extends AppException {
  const GameException(super.message, {super.cause});
}
