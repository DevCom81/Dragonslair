import 'package:flutter_dotenv/flutter_dotenv.dart';

class SpikeConfig {
  const SpikeConfig._();

  static const _convexUrlDefine = String.fromEnvironment('CONVEX_URL');

  static String get convexUrl {
    final fromDefine = _convexUrlDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    try {
      return (dotenv.env['CONVEX_URL'] ?? '').trim();
    } catch (_) {
      return '';
    }
  }

  static bool get isConfigured => convexUrl.isNotEmpty;
}
