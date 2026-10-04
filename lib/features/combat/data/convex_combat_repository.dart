import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/combat_repository.dart';
import '../domain/combat_session.dart';

class ConvexCombatRepository implements CombatRepository {
  ConvexCombatRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<CombatSession> fetchRoomCombat(String roomId) async {
    await _requireAuth();
    return combatSessionFromConvex(
      await _gateway.query('combatSessions:getForRoom', {'roomId': roomId}),
    );
  }

  @override
  Stream<CombatSession> watchRoomCombat(String roomId) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: 'combatSessions:getForRoom',
      args: {'roomId': roomId},
      map: combatSessionFromConvex,
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
