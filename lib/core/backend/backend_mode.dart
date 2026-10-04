enum BackendMode { legacy, convex }

class BackendConfigException implements Exception {
  const BackendConfigException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses BACKEND_MODE. Empty/absent means legacy. Unknown values fail closed.
BackendMode parseBackendMode(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value.isEmpty || value == 'legacy') {
    return BackendMode.legacy;
  }
  if (value == 'convex') {
    return BackendMode.convex;
  }
  throw BackendConfigException(
    'BACKEND_MODE invalide: "$raw". Valeurs autorisees: legacy, convex.',
  );
}
