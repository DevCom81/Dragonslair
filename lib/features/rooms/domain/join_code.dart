import 'dart:math';

class JoinCode {
  const JoinCode._();

  static const length = 6;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate([Random? random]) {
    final source = random ?? Random.secure();
    return List<String>.generate(length, (_) {
      return _alphabet[source.nextInt(_alphabet.length)];
    }).join();
  }

  static String normalize(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }
}
