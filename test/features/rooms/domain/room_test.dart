import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses room from Supabase row', () {
    final room = Room.fromJson({
      'id': 'room-id',
      'name': 'La Crypte',
      'scenario': 'Exploration souterraine',
      'status': 'waiting',
      'created_at': '2026-08-26T12:00:00Z',
      'host_id': 'user-id',
      'join_code': 'ABC234',
    });

    expect(room.id, 'room-id');
    expect(room.status, RoomStatus.waiting);
    expect(room.joinCode, 'ABC234');
    expect(room.createdAt.toUtc().year, 2026);
  });

  test('rejects unknown room status', () {
    expect(
      () => RoomStatus.fromJson('archived'),
      throwsA(isA<ArgumentError>()),
    );
  });
}
