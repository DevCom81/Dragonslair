const hiddenWorldStateKeys = {'gm_secrets', 'gm_state', 'secrets', 'secret'};

Map<String, dynamic> sanitizePublicWorldState(Object? value) {
  if (value is! Map) {
    return {};
  }
  final map = <String, dynamic>{};
  value.forEach((key, item) {
    final name = key.toString();
    if (hiddenWorldStateKeys.contains(name)) {
      return;
    }
    map[name] = item;
  });
  return map;
}

String? publicWorldStateTitle(Map<String, dynamic> worldState) {
  final title = worldState['title'];
  if (title is String && title.trim().isNotEmpty) {
    return title.trim();
  }
  return null;
}
