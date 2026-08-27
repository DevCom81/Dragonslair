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

String refusalMessageForStatus(int statusCode, String fallback) {
  if (statusCode == 429) {
    return 'Le maitre du jeu est occupe. Reessaie dans un instant.';
  }
  return fallback;
}

class RealtimeException extends AppException {
  const RealtimeException(super.message, {super.cause});
}

class GameException extends AppException {
  const GameException(super.message, {super.cause});
}
