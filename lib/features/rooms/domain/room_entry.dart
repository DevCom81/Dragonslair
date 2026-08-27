import 'room.dart';

enum RoomEntryAction {
  figurines,
  lobby,
  board,
  rejectNewPlayers,
  rejectFinished,
}

RoomEntryAction resolveRoomEntry({
  required RoomStatus status,
  required bool alreadyJoined,
  required bool isHost,
}) {
  final canContinue = alreadyJoined || isHost;
  return switch (status) {
    RoomStatus.waiting =>
      alreadyJoined ? RoomEntryAction.lobby : RoomEntryAction.figurines,
    RoomStatus.playing =>
      canContinue ? RoomEntryAction.board : RoomEntryAction.rejectNewPlayers,
    RoomStatus.paused =>
      canContinue ? RoomEntryAction.lobby : RoomEntryAction.rejectNewPlayers,
    RoomStatus.finished => RoomEntryAction.rejectFinished,
  };
}

String? routeNameFor(RoomEntryAction action) {
  return switch (action) {
    RoomEntryAction.figurines => 'figurines',
    RoomEntryAction.lobby => 'lobby',
    RoomEntryAction.board => 'board',
    RoomEntryAction.rejectNewPlayers => null,
    RoomEntryAction.rejectFinished => null,
  };
}
