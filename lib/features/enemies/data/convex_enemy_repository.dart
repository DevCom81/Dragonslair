import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/enemy.dart';
import '../domain/enemy_repository.dart';

class ConvexEnemyRepository implements EnemyRepository {
  ConvexEnemyRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<List<Enemy>> fetchRoomEnemies(String roomId) async {
    await _requireAuth();
    return enemiesFromConvex(
      await _gateway.query('enemies:listByRoom', {'roomId': roomId}),
    );
  }

  @override
  Stream<List<Enemy>> watchRoomEnemies(String roomId) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: 'enemies:listByRoom',
      args: {'roomId': roomId},
      map: enemiesFromConvex,
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
