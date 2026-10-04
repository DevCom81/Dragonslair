import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/convex/convex_mutate.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/character_stats.dart';
import '../domain/player_profile.dart';
import '../domain/profile_repository.dart';

class ConvexProfileRepository implements ProfileRepository {
  ConvexProfileRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<PlayerProfile?> fetchCurrent() async {
    final ready = await _binder.ensureAuthenticated();
    if (!ready) {
      return null;
    }
    final raw = await _gateway.query('profiles:getMine');
    return profileFromConvexOrNull(raw);
  }

  @override
  Future<PlayerProfile> upsertDisplayName({
    required String userId,
    required String displayName,
  }) async {
    // userId is ignored: Convex derives the caller from ctx.auth.
    return profileFromConvex(
      await convexMutate(
        gateway: _gateway,
        binder: _binder,
        name: 'profiles:upsertDisplayName',
        args: {'displayName': displayName},
      ),
    );
  }

  @override
  Future<PlayerProfile> upsertSheet({
    required String userId,
    required String displayName,
    required CharacterStats stats,
    required String classId,
  }) async {
    return profileFromConvex(
      await convexMutate(
        gateway: _gateway,
        binder: _binder,
        name: 'profiles:upsertSheet',
        args: {
          'displayName': displayName,
          'classId': classId,
          ...stats.toJson(),
        },
      ),
    );
  }

  @override
  Future<PlayerProfile> upsertAvatar({
    required String userId,
    required int? figurineId,
  }) async {
    return profileFromConvex(
      await convexMutate(
        gateway: _gateway,
        binder: _binder,
        name: 'profiles:upsertAvatar',
        args: {'figurineId': figurineId},
      ),
    );
  }
}
