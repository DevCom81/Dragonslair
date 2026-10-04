import 'package:dragons_lair/features/auth/domain/character_stats.dart';
import 'package:dragons_lair/features/auth/domain/player_profile.dart';
import 'package:dragons_lair/features/auth/presentation/onboarding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PlayerProfile profile({
    required bool sheetConfirmed,
    String? classId,
  }) {
    return PlayerProfile(
      id: 'profile_1',
      displayName: 'Hero',
      createdAt: DateTime.utc(2026, 10, 4),
      stats: CharacterStats.defaults,
      sheetConfirmed: sheetConfirmed,
      classId: classId,
    );
  }

  test('ready profile must have a confirmed sheet and a catalog class', () {
    expect(
      isProfileReady(profile(sheetConfirmed: true, classId: 'druid')),
      isTrue,
    );
    expect(
      isProfileReady(profile(sheetConfirmed: true, classId: 'unset')),
      isFalse,
    );
    expect(
      isProfileReady(profile(sheetConfirmed: false, classId: 'druid')),
      isFalse,
    );
  });
}
