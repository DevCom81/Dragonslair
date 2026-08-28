import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/purchase_provider.dart';
import 'access_providers.dart';

Future<void> startUnlockCheckout({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);
  ref.invalidate(currentEntitlementProvider);
  final entitlement = await ref.read(currentEntitlementProvider.future);
  final isFull = entitlement?.level.isFull ?? false;
  final billing = ref.read(purchaseProvider);
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
    ref.invalidate(currentEntitlementProvider);
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
  ref.invalidate(currentEntitlementProvider);
  final entitlementBefore = await ref.read(currentEntitlementProvider.future);
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
  ref.invalidate(currentEntitlementProvider);
  try {
    final entitlement = await ref.read(currentEntitlementProvider.future);
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
