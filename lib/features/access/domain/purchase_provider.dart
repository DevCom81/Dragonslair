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

abstract interface class PurchaseProvider {
  Future<PurchaseOffer> loadOffer();
  Future<Uri> startCheckout();
}

class PurchaseUnavailableException implements Exception {
  const PurchaseUnavailableException([this.message = 'PURCHASE_UNAVAILABLE']);

  final String message;

  @override
  String toString() => message;
}
