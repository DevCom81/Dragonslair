import 'room.dart';

enum RoomEntryAction {
  figurines,
  lobby,
  board,
  rejectNewPlayers,
  rejectFinished,
  summary,
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
    RoomStatus.finished =>
      canContinue ? RoomEntryAction.summary : RoomEntryAction.rejectFinished,
    RoomStatus.demoFinished =>
      canContinue ? RoomEntryAction.summary : RoomEntryAction.rejectFinished,
  };
}

String? routeNameFor(RoomEntryAction action) {
  return switch (action) {
    RoomEntryAction.figurines => 'figurines',
    RoomEntryAction.lobby => 'lobby',
    RoomEntryAction.board => 'board',
    RoomEntryAction.summary => 'summary',
    RoomEntryAction.rejectNewPlayers => null,
    RoomEntryAction.rejectFinished => null,
  };
}
