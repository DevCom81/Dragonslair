import 'package:dragons_lair/features/rooms/domain/room.dart';
import 'package:dragons_lair/features/rooms/domain/room_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends existing members of a paused room to the lobby', () {
    expect(
      resolveRoomEntry(
        status: RoomStatus.paused,
        alreadyJoined: true,
        isHost: false,
      ),
      RoomEntryAction.lobby,
    );
  });

  test('blocks new players once the game has started', () {
    expect(
      resolveRoomEntry(
        status: RoomStatus.playing,
        alreadyJoined: false,
        isHost: false,
      ),
      RoomEntryAction.rejectNewPlayers,
    );
    expect(
      resolveRoomEntry(
        status: RoomStatus.paused,
        alreadyJoined: false,
        isHost: false,
      ),
      RoomEntryAction.rejectNewPlayers,
    );
  });

  test('lets the host resume even without a player row', () {
    expect(
      resolveRoomEntry(
        status: RoomStatus.paused,
        alreadyJoined: false,
        isHost: true,
      ),
      RoomEntryAction.lobby,
    );
  });
}
