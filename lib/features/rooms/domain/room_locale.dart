const supportedRoomLocales = ['fr', 'en', 'de', 'es'];
const fallbackRoomLocale = 'en';

String normalizeRoomLocale(Object? value) {
  final raw = (value ?? '').toString().trim().toLowerCase();
  if (raw.isEmpty) {
    return fallbackRoomLocale;
  }
  final code = raw.split(RegExp('[-_]')).first;
  if (supportedRoomLocales.contains(code)) {
    return code;
  }
  return fallbackRoomLocale;
}
