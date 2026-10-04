import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_mutate.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/room.dart';
import '../domain/room_repository.dart';

class ConvexRoomRepository implements RoomRepository {
  ConvexRoomRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<List<Room>> fetchWaitingRooms() async {
    await _requireAuth();
    return roomsFromConvex(await _gateway.query('rooms:listWaiting'));
  }

  @override
  Stream<List<Room>> watchWaitingRooms() {
    return _watch(
      name: 'rooms:listWaiting',
      map: roomsFromConvex,
    );
  }

  @override
  Future<Room> fetchRoom(String roomId) async {
    await _requireAuth();
    return roomFromConvex(
      await _gateway.query('rooms:get', {'roomId': roomId}),
    );
  }

  @override
  Future<Room?> fetchRoomByJoinCode(String joinCode) async {
    await _requireAuth();
    return roomFromConvexOrNull(
      await _gateway.query('rooms:getByJoinCode', {'joinCode': joinCode}),
    );
  }

  @override
  Stream<Room?> watchRoom(String roomId) {
    return _watch(
      name: 'rooms:get',
      args: {'roomId': roomId},
      map: roomFromConvexOrNull,
    );
  }

  @override
  Stream<List<Room>> watchMyContinuableRooms() {
    return _watch(
      name: 'rooms:listMineContinuable',
      map: roomsFromConvex,
    );
  }

  @override
  Future<Room> createRoom({
    required String name,
    required String hostId,
    required String scenarioId,
    required String scenarioName,
    required int minPlayers,
    required List<String> requiredClassIds,
    String scenarioPrompt = '',
    Map<String, dynamic> worldState = const {},
    String locale = 'en',
  }) async {
    // hostId is ignored: rooms.hostUserId is taken from ctx.auth.
    return roomFromConvex(
      await convexMutate(
        gateway: _gateway,
        binder: _binder,
        name: 'rooms:create',
        args: {
          'name': name,
          'scenarioId': scenarioId,
          'scenarioName': scenarioName,
          'minPlayers': minPlayers,
          'requiredClassIds': requiredClassIds,
          'scenarioPrompt': scenarioPrompt,
          'worldState': worldState,
          'locale': locale,
        },
      ),
    );
  }

  @override
  Future<void> startRoom(String roomId) {
    return _mutate('rooms:start', {'roomId': roomId});
  }

  @override
  Future<void> pauseRoom(String roomId) {
    return _mutate('rooms:pause', {'roomId': roomId});
  }

  @override
  Future<void> resumeRoom(String roomId) {
    return _mutate('rooms:resume', {'roomId': roomId});
  }

  @override
  Future<void> finishRoom({
    required String roomId,
    String result = 'neutral',
    String summary = '',
    String epilogue = '',
  }) {
    return _mutate('rooms:finish', {
      'roomId': roomId,
      'result': _finishResult(result),
    });
  }

  String _finishResult(String result) {
    switch (result.trim().toLowerCase()) {
      case 'victory':
      case 'defeat':
      case 'neutral':
        return result.trim().toLowerCase();
      default:
        return 'neutral';
    }
  }

  Future<void> _mutate(String name, Map<String, Object?> args) async {
    await convexMutate(
      gateway: _gateway,
      binder: _binder,
      name: name,
      args: args,
    );
  }

  Stream<T> _watch<T>({
    required String name,
    Map<String, Object?> args = const {},
    required T Function(Object? value) map,
  }) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: name,
      args: args,
      map: map,
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
