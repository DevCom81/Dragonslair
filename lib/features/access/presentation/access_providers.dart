import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/stripe_checkout_purchase_provider.dart';
import '../domain/entitlement_repository.dart';
import '../domain/game_access.dart';
import '../domain/purchase_provider.dart';

final currentEntitlementProvider = FutureProvider.autoDispose<UserEntitlement?>(
  (ref) async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      return null;
    }
    return ref.watch(entitlementRepositoryProvider).fetchCurrent(user.id);
  },
);

final currentDemoSessionProvider = FutureProvider.autoDispose<DemoSession?>((
  ref,
) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    return null;
  }
  return ref.watch(entitlementRepositoryProvider).fetchDemoSession(user.id);
});

final purchaseProvider = Provider<PurchaseProvider>((ref) {
  if (!_usesStripeCheckout) {
    return const UnavailablePurchaseProvider();
  }
  final accessToken = ref
      .watch(supabaseClientProvider)
      ?.auth
      .currentSession
      ?.accessToken;
  return StripeCheckoutPurchaseProvider(accessToken: accessToken);
});

/// Stripe Checkout is Web-only. Android IAP will use Play Billing later.
bool get _usesStripeCheckout {
  if (!AppConfig.isGameMasterBackendConfigured) {
    return false;
  }
  if (kIsWeb) {
    return true;
  }
  return defaultTargetPlatform != TargetPlatform.android;
}
