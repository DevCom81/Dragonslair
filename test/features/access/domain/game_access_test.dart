import 'package:dragons_lair/features/access/domain/game_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing access level is demo', () {
    expect(GameAccessLevel.fromJson(null), GameAccessLevel.demo);
    expect(GameAccessLevel.fromJson('full').isFull, isTrue);
  });

  test('demo session is consumed after completion or expiry', () {
    final completed = DemoSession(
      userId: 'u1',
      roomId: 'r1',
      completedAt: DateTime.utc(2026, 8, 27),
    );
    expect(completed.isConsumed, isTrue);
    expect(completed.canResume, isFalse);

    final expired = DemoSession(
      userId: 'u1',
      roomId: 'r1',
      startedAt: DateTime.utc(2020, 1, 1, 10),
      expiresAt: DateTime.utc(2020, 1, 1, 10, 10),
    );
    expect(expired.isExpired, isTrue);
    expect(expired.canResume, isFalse);
  });

  test('open demo session can be resumed', () {
    final session = DemoSession(
      userId: 'u1',
      roomId: 'r1',
      startedAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 8)),
    );
    expect(session.canResume, isTrue);
    expect(session.isConsumed, isFalse);
  });

  test('paused demo clock ignores wall time after freeze', () {
    final started = DateTime.utc(2026, 8, 27, 10);
    final session = DemoSession(
      userId: 'u1',
      roomId: 'r1',
      startedAt: started,
      expiresAt: started.add(const Duration(minutes: 10)),
      pausedAt: started.add(const Duration(minutes: 4)),
    );
    expect(
      session.remainingPlayTime(DateTime.utc(2026, 8, 27, 12)),
      const Duration(minutes: 6),
    );
    expect(session.isExpired, isFalse);
    expect(session.canResume, isTrue);
  });
}
