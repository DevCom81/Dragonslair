import '../domain/play_account_id.dart';
import '../domain/purchase_provider.dart';

class GooglePlayPurchaseProvider implements PurchaseProvider {
  const GooglePlayPurchaseProvider({
    required PlayBillingStore store,
    required String productId,
    this.userId = '',
    this.billingIdentity,
    PlayPurchaseVerifier verifier = const UnconfiguredPlayPurchaseVerifier(),
  }) : _store = store,
       _productId = productId,
       _verifier = verifier;

  final PlayBillingStore _store;
  final String _productId;
  final String userId;
  final Future<String> Function()? billingIdentity;
  final PlayPurchaseVerifier _verifier;

  @override
  bool get canPurchase {
    if (!_store.isSupported || _productId.isEmpty || !_verifier.isConfigured) {
      return false;
    }
    if (billingIdentity != null) {
      return true;
    }
    return playObfuscatedAccountId(userId).isNotEmpty;
  }

  @override
  Future<PurchaseOffer> loadOffer() async {
    if (!_store.isSupported || _productId.isEmpty) {
      throw const PurchaseUnavailableException();
    }
    return _store.loadOffer(_productId);
  }

  @override
  Future<void> purchase() async {
    if (!canPurchase) {
      throw const PurchaseUnavailableException();
    }
    final result = await _store.buy(
      _productId,
      obfuscatedAccountId: await _obfuscatedAccountId(),
    );
    if (result.isPending || result.purchaseToken.isEmpty) {
      throw const PurchaseUnavailableException();
    }
    await _verifier.verify(
      productId: result.productId,
      purchaseToken: result.purchaseToken,
    );
    await _store.finish(result.purchaseToken);
  }

  @override
  Future<void> restore() async {
    if (!_store.isSupported || _productId.isEmpty || !_verifier.isConfigured) {
      return;
    }
    final accountId = await _obfuscatedAccountId();
    if (accountId.isEmpty) {
      return;
    }
    final results = await _store.restore(
      _productId,
      obfuscatedAccountId: accountId,
    );
    for (final result in results) {
      if (result.isPending || result.purchaseToken.isEmpty) {
        continue;
      }
      try {
        await _verifier.verify(
          productId: result.productId,
          purchaseToken: result.purchaseToken,
        );
        await _store.finish(result.purchaseToken);
        return;
      } catch (_) {
        continue;
      }
    }
  }

  Future<String> _obfuscatedAccountId() async {
    final resolve = billingIdentity;
    if (resolve != null) {
      return resolve();
    }
    return playObfuscatedAccountId(userId);
  }
}
