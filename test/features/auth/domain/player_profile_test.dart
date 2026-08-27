import 'package:dragons_lair/features/auth/domain/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses player profile from Supabase row', () {
    final profile = PlayerProfile.fromJson({
      'id': 'user-id',
      'display_name': 'Jérôme',
      'created_at': '2026-08-27T08:00:00Z',
    });

    expect(profile.id, 'user-id');
    expect(profile.displayName, 'Jérôme');
    expect(profile.stats.strength, 10);
    expect(profile.sheetConfirmed, isFalse);
    expect(profile.classId, isNull);
    expect(profile.isReadyToPlay, isFalse);
  });
}
