import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../domain/entitlement_repository.dart';
import '../domain/game_access.dart';

class ConvexEntitlementRepository implements EntitlementRepository {
  ConvexEntitlementRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<UserEntitlement> fetchCurrent(String userId) async {
    final raw = await convexQuery(
      gateway: _gateway,
      binder: _binder,
      name: 'entitlements:getMine',
    );
    return entitlementFromConvex(raw, userId: userId);
  }

  @override
  Future<DemoSession?> fetchDemoSession(String userId) async {
    final raw = await convexQuery(
      gateway: _gateway,
      binder: _binder,
      name: 'demoSessions:getMine',
    );
    return demoSessionFromConvex(raw, userId: userId);
  }

  @override
  Future<DemoPlayResult> ensureDemoPlay(String roomId) async {
    return DemoPlayResult.ok;
  }
}
