import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../../../core/backend/backend_mode.dart';
import '../../../core/config/app_config.dart';
import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/backend_entitlement_client.dart';
import '../data/convex_google_play_verifier.dart';
import '../data/convex_stripe_checkout_purchase_provider.dart';
import '../data/google_play_backend_verifier.dart';
import '../data/google_play_purchase_provider.dart';
import '../data/play_billing_store.dart';
import '../data/stripe_checkout_purchase_provider.dart';
import '../domain/game_access.dart';
import '../domain/purchase_provider.dart';

export '../../../core/backend/backend_composition.dart'
    show entitlementRepositoryProvider;

final currentEntitlementProvider = FutureProvider.autoDispose<UserEntitlement?>(
  (ref) async {
    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      return null;
    }
    final repo = ref.watch(entitlementRepositoryProvider);
    final cached = await repo.fetchCurrent(user.id);
    if (ref.watch(backendModeProvider) == BackendMode.convex) {
      return cached;
    }
    final session = ref.watch(supabaseClientProvider)?.auth.currentSession;
    final token = session?.accessToken;
    if (AppConfig.isGameMasterBackendConfigured &&
        token != null &&
        token.isNotEmpty) {
      try {
        final me = await BackendEntitlementClient(accessToken: token).fetchMe();
        final isFull = me['is_full'] == true ||
            GameAccessLevel.fromJson(me['entitlement'] ?? me['access_level'])
                .isFull;
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
  final isFull = ref.watch(currentEntitlementProvider).maybeWhen(
    data: (value) => value?.level.isFull ?? false,
    orElse: () => false,
  );
  if (isFull) {
    return const UnavailablePurchaseProvider();
  }
  switch (ref.watch(backendModeProvider)) {
    case BackendMode.legacy:
      final session = ref.watch(supabaseClientProvider)?.auth.currentSession;
      return billingProviderForPlatform(
        accessToken: session?.accessToken,
        userId: session?.user.id,
      );
    case BackendMode.convex:
      return convexBillingProviderForPlatform(ref);
  }
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

PurchaseProvider convexBillingProviderForPlatform(Ref ref) {
  final convex = (
    gateway: ref.watch(convexGatewayProvider),
    binder: ref.watch(convexAuthBinderProvider),
  );
  final gateway = convex.gateway;
  final binder = convex.binder;
  if (gateway == null || binder == null) {
    return const UnavailablePurchaseProvider();
  }
  if (kIsWeb) {
    return ConvexStripeCheckoutPurchaseProvider(
      gateway: gateway,
      binder: binder,
    );
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    return GooglePlayPurchaseProvider(
      store: createPlayBillingStore(),
      productId: AppConfig.googlePlayProductId,
      billingIdentity: () async {
        final raw = await convexQuery(
          gateway: gateway,
          binder: binder,
          name: 'googlePlay:billingIdentity',
        );
        final json = convexObject(raw, label: 'billingIdentity');
        final id = json['obfuscatedAccountId']?.toString().trim() ?? '';
        if (id.isEmpty) {
          throw const PurchaseUnavailableException();
        }
        return id;
      },
      verifier: ConvexGooglePlayVerifier(
        gateway: gateway,
        binder: binder,
      ),
    );
  }
  return const UnavailablePurchaseProvider();
}
