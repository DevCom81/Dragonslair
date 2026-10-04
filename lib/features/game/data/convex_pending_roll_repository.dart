import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/pending_roll_repository.dart';
import '../presentation/pending_ability_roll.dart';

class ConvexPendingRollRepository implements PendingRollRepository {
  ConvexPendingRollRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<List<PendingAbilityRoll>> fetchRoomRolls(String roomId) async {
    await _requireAuth();
    return pendingRollsFromConvex(
      await _gateway.query('pendingRolls:listByRoom', {'roomId': roomId}),
    );
  }

  @override
  Stream<List<PendingAbilityRoll>> watchRoomRolls(String roomId) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: 'pendingRolls:listByRoom',
      args: {'roomId': roomId},
      map: pendingRollsFromConvex,
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
