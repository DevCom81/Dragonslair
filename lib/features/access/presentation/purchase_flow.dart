import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/purchase_provider.dart';
import 'access_providers.dart';

void _invalidateEntitlement(BuildContext context) {
  ProviderScope.containerOf(context).invalidate(currentEntitlementProvider);
}

Future<void> startUnlockCheckout({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);

  // Capture sync reads before any await. Do not invalidate entitlement here:
  // PlayHubScreen shows a loading spinner while entitlement reloads, which
  // unmounts _DemoAccessHub and makes this WidgetRef unsafe after await.
  final entitlement = ref.read(currentEntitlementProvider).value;
  final billing = ref.read(purchaseProvider);
  final isFull = entitlement?.level.isFull ?? false;

  if (isFull) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accessAlreadyActive)),
      );
    }
    return;
  }
  if (!shouldStartStorePurchase(isFull: isFull, canPurchase: billing.canPurchase)) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.purchaseUnavailable)));
    }
    return;
  }
  try {
    await billing.purchase();
    if (context.mounted) {
      _invalidateEntitlement(context);
    }
  } on PurchaseUnavailableException {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.purchaseUnavailable)));
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

Future<void> restorePurchases({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);
  final entitlementBefore = ref.read(currentEntitlementProvider).value;
  if (entitlementBefore?.level.isFull == true) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accessAlreadyActive)),
      );
    }
    return;
  }
  final billing = ref.read(purchaseProvider);
  var restoreFailed = false;
  try {
    await billing.restore();
  } catch (_) {
    restoreFailed = true;
  }
  if (!context.mounted) {
    return;
  }
  final container = ProviderScope.containerOf(context);
  container.invalidate(currentEntitlementProvider);
  try {
    final entitlement = await container.read(currentEntitlementProvider.future);
    if (!context.mounted) {
      return;
    }
    final isFull = entitlement?.level.isFull == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFull
              ? l10n.purchaseRestored
              : restoreFailed
                  ? l10n.purchaseUnavailable
                  : l10n.purchaseNotFound,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}
