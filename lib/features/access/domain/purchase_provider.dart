class PurchaseOffer {
  const PurchaseOffer({
    required this.currency,
    required this.unitAmount,
  });

  final String currency;
  final int unitAmount;

  String get displayAmount {
    final major = unitAmount / 100;
    return '${major.toStringAsFixed(2)} ${currency.toUpperCase()}';
  }

  factory PurchaseOffer.fromJson(Map<String, dynamic> json) {
    final amount = json['unit_amount'];
    if (amount is! num || amount < 0) {
      throw const FormatException('Invalid purchase offer.');
    }
    final currency = json['currency']?.toString().trim() ?? '';
    if (currency.isEmpty) {
      throw const FormatException('Invalid purchase offer.');
    }
    return PurchaseOffer(
      currency: currency.toLowerCase(),
      unitAmount: amount.round(),
    );
  }
}

/// Store-agnostic billing. Screens must not import Stripe or Play Billing.
abstract interface class PurchaseProvider {
  bool get canPurchase;
  Future<PurchaseOffer> loadOffer();
  Future<void> purchase();
  Future<void> restore();
}

class PurchaseUnavailableException implements Exception {
  const PurchaseUnavailableException([this.message = 'PURCHASE_UNAVAILABLE']);

  final String message;

  @override
  String toString() => message;
}

/// Store purchase is offered only to DEMO users on a platform that can bill.
bool shouldStartStorePurchase({
  required bool isFull,
  required bool canPurchase,
}) {
  return !isFull && canPurchase;
}

class PlayPurchase {
  const PlayPurchase({
    required this.productId,
    required this.purchaseToken,
    this.isPending = false,
  });

  final String productId;
  final String purchaseToken;
  final bool isPending;
}

abstract interface class PlayBillingStore {
  bool get isSupported;
  Future<PurchaseOffer> loadOffer(String productId);
  Future<PlayPurchase> buy(
    String productId, {
    String obfuscatedAccountId = '',
  });
  Future<List<PlayPurchase>> restore(
    String productId, {
    String obfuscatedAccountId = '',
  });
  Future<void> finish(String purchaseToken);
}

abstract interface class PlayPurchaseVerifier {
  bool get isConfigured;
  Future<void> verify({
    required String productId,
    required String purchaseToken,
  });
}

class UnconfiguredPlayPurchaseVerifier implements PlayPurchaseVerifier {
  const UnconfiguredPlayPurchaseVerifier();

  @override
  bool get isConfigured => false;

  @override
  Future<void> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    throw const PurchaseUnavailableException();
  }
}
