import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseBackendMode', () {
    test('absent or empty means legacy', () {
      expect(parseBackendMode(null), BackendMode.legacy);
      expect(parseBackendMode(''), BackendMode.legacy);
      expect(parseBackendMode('   '), BackendMode.legacy);
    });

    test('legacy means legacy', () {
      expect(parseBackendMode('legacy'), BackendMode.legacy);
      expect(parseBackendMode('LEGACY'), BackendMode.legacy);
    });

    test('convex means convex', () {
      expect(parseBackendMode('convex'), BackendMode.convex);
      expect(parseBackendMode(' Convex '), BackendMode.convex);
    });

    test('unknown value is an explicit error', () {
      expect(
        () => parseBackendMode('supabase'),
        throwsA(
          isA<BackendConfigException>().having(
            (error) => error.message,
            'message',
            contains('BACKEND_MODE invalide'),
          ),
        ),
      );
    });
  });
}
