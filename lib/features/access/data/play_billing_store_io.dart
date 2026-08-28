import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/purchase_provider.dart';
import 'play_billing_store_stub.dart';

PlayBillingStore createPlayBillingStore() {
  if (!Platform.isAndroid) {
    return const StubPlayBillingStore();
  }
  return AndroidPlayBillingStore();
}

class AndroidPlayBillingStore implements PlayBillingStore {
  AndroidPlayBillingStore({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;
  final Map<String, PurchaseDetails> _finishable = {};

  @override
  bool get isSupported => true;

  @override
  Future<PurchaseOffer> loadOffer(String productId) async {
    if (!await _iap.isAvailable()) {
      throw const PurchaseUnavailableException();
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw const PurchaseUnavailableException();
    }
    final product = response.productDetails.first;
    return PurchaseOffer(
      currency: product.currencyCode.toLowerCase(),
      unitAmount: (product.rawPrice * 100).round(),
    );
  }

  @override
  Future<PlayPurchase> buy(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    if (obfuscatedAccountId.isEmpty || obfuscatedAccountId.length > 64) {
      throw const PurchaseUnavailableException();
    }
    if (!await _iap.isAvailable()) {
      throw const PurchaseUnavailableException();
    }
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw const PurchaseUnavailableException();
    }
    final completer = Completer<PlayPurchase>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _iap.purchaseStream.listen(
      (purchases) {
        for (final purchase in purchases) {
          if (purchase.productID != productId || completer.isCompleted) {
            continue;
          }
          if (purchase.status == PurchaseStatus.pending) {
            completer.complete(
              PlayPurchase(
                productId: productId,
                purchaseToken: '',
                isPending: true,
              ),
            );
            return;
          }
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final token = purchase.verificationData.serverVerificationData;
            if (token.isNotEmpty) {
              _finishable[token] = purchase;
            }
            completer.complete(
              PlayPurchase(
                productId: productId,
                purchaseToken: token,
              ),
            );
            return;
          }
          if (purchase.status == PurchaseStatus.error ||
              purchase.status == PurchaseStatus.canceled) {
            completer.completeError(const PurchaseUnavailableException());
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(const PurchaseUnavailableException());
        }
      },
    );
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(
        productDetails: response.productDetails.first,
        applicationUserName: obfuscatedAccountId,
      ),
    );
    if (!started) {
      await subscription.cancel();
      throw const PurchaseUnavailableException();
    }
    try {
      return await completer.future.timeout(const Duration(minutes: 5));
    } on TimeoutException {
      throw const PurchaseUnavailableException();
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<List<PlayPurchase>> restore(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    if (!await _iap.isAvailable()) {
      throw const PurchaseUnavailableException();
    }
    final completer = Completer<List<PlayPurchase>>();
    late final StreamSubscription<List<PurchaseDetails>> subscription;
    subscription = _iap.purchaseStream.listen(
      (purchases) {
        if (completer.isCompleted) {
          return;
        }
        final matched = <PlayPurchase>[];
        for (final purchase in purchases) {
          if (purchase.productID != productId) {
            continue;
          }
          if (purchase.status == PurchaseStatus.pending) {
            matched.add(
              PlayPurchase(
                productId: productId,
                purchaseToken: '',
                isPending: true,
              ),
            );
            continue;
          }
          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            final token = purchase.verificationData.serverVerificationData;
            if (token.isEmpty) {
              continue;
            }
            _finishable[token] = purchase;
            matched.add(
              PlayPurchase(productId: productId, purchaseToken: token),
            );
          }
        }
        completer.complete(matched);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(const PurchaseUnavailableException());
        }
      },
    );
    try {
      await _iap.restorePurchases(
        applicationUserName:
            obfuscatedAccountId.isEmpty ? null : obfuscatedAccountId,
      );
      return await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return const [];
    } on PurchaseUnavailableException {
      rethrow;
    } catch (_) {
      throw const PurchaseUnavailableException();
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> finish(String purchaseToken) async {
    if (purchaseToken.isEmpty) {
      return;
    }
    final details = _finishable.remove(purchaseToken);
    if (details == null || details.status == PurchaseStatus.pending) {
      return;
    }
    if (!details.pendingCompletePurchase) {
      return;
    }
    await _iap.completePurchase(details);
  }
}
