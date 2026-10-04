import 'package:url_launcher/url_launcher.dart';

import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/purchase_provider.dart';

class ConvexStripeCheckoutPurchaseProvider implements PurchaseProvider {
  ConvexStripeCheckoutPurchaseProvider({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  bool get canPurchase => true;

  @override
  Future<PurchaseOffer> loadOffer() async {
    try {
      final raw = await convexAction(
        gateway: _gateway,
        binder: _binder,
        name: 'stripe:getOffer',
        timeout: convexBillingTimeout,
      );
      return purchaseOfferFromConvex(raw);
    } on AppException catch (error) {
      throw _asPurchaseError(error);
    }
  }

  @override
  Future<void> purchase() async {
    try {
      final raw = await convexAction(
        gateway: _gateway,
        binder: _binder,
        name: 'stripe:createCheckout',
        timeout: convexBillingTimeout,
      );
      final json = convexObject(raw, label: 'checkout');
      final url = json['checkout_url']?.toString() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || uri.scheme != 'https') {
        throw const PurchaseUnavailableException();
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw const PurchaseUnavailableException();
      }
    } on PurchaseUnavailableException {
      rethrow;
    } on AppException catch (error) {
      throw _asPurchaseError(error);
    }
  }

  @override
  Future<void> restore() async {}

  Exception _asPurchaseError(AppException error) {
    final lower = error.message.toLowerCase();
    if (lower.contains('indisponible') ||
        lower.contains('purchase') ||
        lower.contains('deja actif')) {
      return const PurchaseUnavailableException();
    }
    return error;
  }
}
