import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/backend_entitlement_client.dart';
import '../data/google_play_backend_verifier.dart';
import '../data/google_play_purchase_provider.dart';
import '../data/play_billing_store.dart';
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
    final repo = ref.watch(entitlementRepositoryProvider);
    final cached = await repo.fetchCurrent(user.id);
    final session = ref.watch(supabaseClientProvider)?.auth.currentSession;
    final token = session?.accessToken;
    if (AppConfig.isGameMasterBackendConfigured &&
        token != null &&
        token.isNotEmpty) {
      try {
        final me = await BackendEntitlementClient(accessToken: token).fetchMe();
        final isFull = me['is_full'] == true ||
            GameAccessLevel.fromJson(me['entitlement'] ?? me['access_level']).isFull;
        if (isFull) {
          return UserEntitlement(
            userId: user.id,
            level: GameAccessLevel.full,
            source: me['source']?.toString() ?? cached.source,
          );
        }
      } catch (_) {
        // Fall back to Supabase row when backend is unreachable.
      }
    }
    return cached;
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
  final session = ref.watch(supabaseClientProvider)?.auth.currentSession;
  final isFull = ref.watch(currentEntitlementProvider).maybeWhen(
    data: (value) => value?.level.isFull ?? false,
    orElse: () => false,
  );
  if (isFull) {
    return const UnavailablePurchaseProvider();
  }
  return billingProviderForPlatform(
    accessToken: session?.accessToken,
    userId: session?.user.id,
  );
});

/// Web → Stripe. Android → Google Play (verify backend = PASS 6). Else none.
PurchaseProvider billingProviderForPlatform({
  String? accessToken,
  String? userId,
}) {
  if (!AppConfig.isGameMasterBackendConfigured) {
    return const UnavailablePurchaseProvider();
  }
  if (kIsWeb) {
    return StripeCheckoutPurchaseProvider(accessToken: accessToken);
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return GooglePlayPurchaseProvider(
      store: createPlayBillingStore(),
      productId: AppConfig.googlePlayProductId,
      userId: userId ?? '',
      verifier: GooglePlayBackendVerifier(accessToken: accessToken),
    );
  }
  return const UnavailablePurchaseProvider();
}
