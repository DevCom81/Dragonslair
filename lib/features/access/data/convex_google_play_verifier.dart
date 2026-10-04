import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/purchase_provider.dart';

class ConvexGooglePlayVerifier implements PlayPurchaseVerifier {
  ConvexGooglePlayVerifier({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  bool get isConfigured => true;

  @override
  Future<void> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    final raw = await convexAction(
      gateway: _gateway,
      binder: _binder,
      name: 'googlePlay:redeem',
      args: {'purchaseToken': purchaseToken},
      timeout: convexBillingTimeout,
    );
    final json = convexObject(raw, label: 'playRedeem');
    if (json['accessLevel']?.toString() == 'full') {
      return;
    }
    throw const NetworkException('Achat Google Play refuse.');
  }
}
