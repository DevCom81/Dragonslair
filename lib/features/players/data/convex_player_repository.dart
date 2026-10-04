import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_mutate.dart';
import '../../../core/convex/convex_watch.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/domain/character_stats.dart';
import '../domain/inventory_item.dart';
import '../domain/player.dart';
import '../domain/player_effect.dart';
import '../domain/player_repository.dart';

class ConvexPlayerRepository implements PlayerRepository {
  ConvexPlayerRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<List<Player>> fetchRoomPlayers(String roomId) async {
    await _requireAuth();
    return playersFromConvex(
      await _gateway.query('players:listByRoom', {'roomId': roomId}),
    );
  }

  @override
  Stream<List<Player>> watchRoomPlayers(String roomId) async* {
    await _requireAuth();
    yield* watchConvexQuery(
      gateway: _gateway,
      name: 'players:listByRoom',
      args: {'roomId': roomId},
      map: playersFromConvex,
    );
  }

  @override
  Future<Player> joinRoom({
    required String roomId,
    required String userId,
    required int figurineId,
    required String figurineName,
    required String classId,
    required CharacterStats stats,
  }) async {
    // userId, figurineName, classId and stats are ignored: the server
    // binds the authenticated user and their confirmed sheet.
    return playerFromConvex(
      await convexMutate(
        gateway: _gateway,
        binder: _binder,
        name: 'players:join',
        args: {
          'roomId': roomId,
          'figurineId': figurineId,
        },
      ),
    );
  }

  @override
  Future<void> updatePosition({
    required String playerId,
    required double x,
    required double y,
    String? roomId,
  }) async {
    // playerId is ignored: requirePlayer uses ctx.auth.
    final targetRoomId = roomId;
    if (targetRoomId == null || targetRoomId.isEmpty) {
      throw const GameException('Room id required.');
    }
    await convexMutate(
      gateway: _gateway,
      binder: _binder,
      name: 'players:updatePosition',
      args: {
        'roomId': targetRoomId,
        'x': x,
        'y': y,
      },
    );
  }

  @override
  Future<void> patchOwnPlayer({
    required String playerId,
    int? hp,
    List<InventoryItem>? inventory,
    List<PlayerEffect>? effects,
  }) {
    throw const UnsupportedConvexWriteException(
      'Use setItemEquipped, usePotion or useScroll.',
    );
  }

  Future<void> _requireAuth() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      throw const AppAuthException('Convex n est pas authentifie.');
    }
  }
}
