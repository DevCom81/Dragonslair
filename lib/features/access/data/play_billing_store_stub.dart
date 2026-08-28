import '../domain/purchase_provider.dart';

class StubPlayBillingStore implements PlayBillingStore {
  const StubPlayBillingStore();

  @override
  bool get isSupported => false;

  @override
  Future<PurchaseOffer> loadOffer(String productId) async {
    throw const PurchaseUnavailableException();
  }

  @override
  Future<PlayPurchase> buy(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    throw const PurchaseUnavailableException();
  }

  @override
  Future<List<PlayPurchase>> restore(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    return const [];
  }

  @override
  Future<void> finish(String purchaseToken) async {}
}

PlayBillingStore createPlayBillingStore() => const StubPlayBillingStore();
