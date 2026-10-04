import '../errors/app_exception.dart';

AppException mapConvexError(Object error) {
  if (error is AppException) {
    return error;
  }
  final cleaned = _cleanConvexMessage(error.toString());
  final lower = cleaned.toLowerCase();
  if (lower.contains('unauthenticated') ||
      lower.contains('n est pas authentifie')) {
    return AppAuthException(cleaned, cause: error);
  }
  if (lower.contains('demo_expired')) {
    return const GameException('La demo est terminee.');
  }
  if (lower.contains('full_game_required') ||
      lower.contains('not_entitled')) {
    return const GameException(
      'Le jeu complet est requis pour cette action.',
    );
  }
  if (lower.contains('purchase_already_full')) {
    return const GameException('Cet achat est deja actif.');
  }
  if (lower.contains('purchase_pending')) {
    return const GameException('Achat en attente.');
  }
  if (lower.contains('purchase_unavailable') ||
      lower.contains('google_play_unavailable') ||
      lower.contains('windows_download_unavailable')) {
    return const NetworkException('Service d achat ou de telechargement indisponible.');
  }
  if (lower.contains('google_play')) {
    return const NetworkException('Achat Google Play refuse.');
  }
  if (lower.contains('rate_limited') || lower.contains('rate limited')) {
    return const NetworkException(
      'Le maitre du jeu est occupe. Reessaie dans un instant.',
    );
  }
  if (lower.contains('openrouter') ||
      lower.contains('invalid json') ||
      lower.contains('malformed')) {
    return const NetworkException('Le maitre du jeu n a pas pu repondre.');
  }
  if (lower.contains('forbidden') ||
      lower.contains('host only') ||
      lower.contains('player only')) {
    return GameException('Action non autorisee.', cause: error);
  }
  if (lower.contains('room not found') ||
      lower.contains('partie introuvable')) {
    return const GameException('Partie introuvable.');
  }
  if (lower.contains('pending roll') ||
      lower.contains('not pending') ||
      lower.contains('raw must be')) {
    return GameException('Ce jet ne peut pas etre resolu.', cause: error);
  }
  if (cleaned.isEmpty || _looksInternal(cleaned)) {
    return GameException('Impossible de terminer cette action.', cause: error);
  }
  return GameException(cleaned, cause: error);
}

Never throwMappedConvexError(Object error) {
  throw mapConvexError(error);
}

String _cleanConvexMessage(String raw) {
  var text = raw.trim();
  const prefixes = [
    'Exception: ',
    'Error: ',
    'ConvexError: ',
    'GameRuleError: ',
    'ForbiddenError: ',
    'NotFoundError: ',
    'UnauthenticatedError: ',
    'InvalidProfileError: ',
    'UserNotFoundError: ',
    'GameMasterBackendError: ',
    'PurchaseUnavailableError: ',
    'DownloadConfigError: ',
    'GooglePlayPurchaseError: ',
    'GooglePlayPendingError: ',
    'GooglePlayConfigError: ',
    'InvalidOpenRouterJsonError: ',
    'Uncaught Error: ',
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        text = text.substring(prefix.length).trim();
        changed = true;
      }
    }
  }
  return text;
}

bool _looksInternal(String text) {
  return text.contains('\n') ||
      text.contains(' at ') ||
      text.contains('ConvexError') ||
      text.startsWith('[CONVEX');
}
