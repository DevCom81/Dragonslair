import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/game_event.dart';
import '../domain/game_event_repository.dart';

class ConvexGameEventRepository implements GameEventRepository {
  ConvexGameEventRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Stream<List<GameEvent>> watchRoomEvents(String roomId) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: 'gameEvents:listByRoom',
      args: {'roomId': roomId},
      map: gameEventsFromConvex,
    );
  }

  @override
  Future<void> createAction({
    required String roomId,
    required String playerId,
    required String content,
  }) {
    throw const UnsupportedConvexWriteException(
      'Player actions use players:submitAction.',
    );
  }

  @override
  Future<void> createNarration({
    required String roomId,
    required String content,
  }) {
    throw const UnsupportedConvexWriteException(
      'Narration is written by the game master (LOT13E).',
    );
  }

  @override
  Future<void> createSystem({
    required String roomId,
    required String content,
  }) {
    throw const UnsupportedConvexWriteException(
      'System events are produced by gameplay mutations.',
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
