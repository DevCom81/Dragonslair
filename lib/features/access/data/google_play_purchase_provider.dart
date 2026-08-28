import '../domain/play_account_id.dart';
import '../domain/purchase_provider.dart';

class GooglePlayPurchaseProvider implements PurchaseProvider {
  const GooglePlayPurchaseProvider({
    required PlayBillingStore store,
    required String productId,
    this.userId = '',
    PlayPurchaseVerifier verifier = const UnconfiguredPlayPurchaseVerifier(),
  }) : _store = store,
       _productId = productId,
       _verifier = verifier;

  final PlayBillingStore _store;
  final String _productId;
  final String userId;
  final PlayPurchaseVerifier _verifier;

  @override
  bool get canPurchase =>
      _store.isSupported &&
      _productId.isNotEmpty &&
      playObfuscatedAccountId(userId).isNotEmpty &&
      _verifier.isConfigured;

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
      obfuscatedAccountId: playObfuscatedAccountId(userId),
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
    final accountId = playObfuscatedAccountId(userId);
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
}
