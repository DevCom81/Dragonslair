import 'package:dragons_lair/features/access/data/google_play_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/play_account_id.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unconfigured google play never starts a buy', () async {
    final store = _FakePlayStore();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
    );
    expect(provider.canPurchase, isFalse);
    await expectLater(
      provider.purchase(),
      throwsA(isA<PurchaseUnavailableException>()),
    );
    expect(store.buyCount, 0);
  });

  test('pending play purchase is not verified and does not grant full', () async {
    final store = _FakePlayStore(
      purchase: const PlayPurchase(
        productId: 'dragonslair_full',
        purchaseToken: 'token',
        isPending: true,
      ),
    );
    final verifier = _RecordingVerifier();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
      verifier: verifier,
    );
    expect(provider.canPurchase, isTrue);
    await expectLater(
      provider.purchase(),
      throwsA(isA<PurchaseUnavailableException>()),
    );
    expect(verifier.verifyCount, 0);
    expect(store.finishCount, 0);
  });

  test('purchased token is sent to verifier only, never written as full', () async {
    final store = _FakePlayStore(
      purchase: const PlayPurchase(
        productId: 'dragonslair_full',
        purchaseToken: 'play-token',
      ),
    );
    final verifier = _RecordingVerifier();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
      verifier: verifier,
    );
    await provider.purchase();
    expect(verifier.productId, 'dragonslair_full');
    expect(verifier.purchaseToken, 'play-token');
    expect(store.obfuscatedAccountId, playObfuscatedAccountId('user-1'));
    expect(store.finishCount, 1);
    expect(store.finishedToken, 'play-token');
  });

  test('missing supabase user never starts a play buy', () async {
    final store = _FakePlayStore();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      verifier: _RecordingVerifier(),
    );
    expect(provider.canPurchase, isFalse);
    await expectLater(
      provider.purchase(),
      throwsA(isA<PurchaseUnavailableException>()),
    );
    expect(store.buyCount, 0);
  });

  test('restore sends play tokens to verifier only, never writes full', () async {
    final store = _FakePlayStore(
      restored: const [
        PlayPurchase(
          productId: 'dragonslair_full',
          purchaseToken: 'restored-token',
        ),
      ],
    );
    final verifier = _RecordingVerifier();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
      verifier: verifier,
    );
    await provider.restore();
    expect(store.restoreCount, 1);
    expect(store.restoredAccountId, playObfuscatedAccountId('user-1'));
    expect(verifier.purchaseToken, 'restored-token');
    expect(verifier.verifyCount, 1);
    expect(store.finishCount, 1);
    expect(store.finishedToken, 'restored-token');
  });

  test('restore ignores pending play purchases', () async {
    final store = _FakePlayStore(
      restored: const [
        PlayPurchase(
          productId: 'dragonslair_full',
          purchaseToken: 'token',
          isPending: true,
        ),
      ],
    );
    final verifier = _RecordingVerifier();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
      verifier: verifier,
    );
    await provider.restore();
    expect(store.restoreCount, 1);
    expect(verifier.verifyCount, 0);
    expect(store.finishCount, 0);
  });

  test('restore does not treat a rejected play token as full', () async {
    final store = _FakePlayStore(
      restored: const [
        PlayPurchase(
          productId: 'dragonslair_full',
          purchaseToken: 'other-account-token',
        ),
      ],
    );
    final verifier = _RecordingVerifier(throwOnVerify: true);
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
      verifier: verifier,
    );
    await provider.restore();
    expect(verifier.verifyCount, 1);
    expect(store.finishCount, 0);
  });

  test('unconfigured restore never queries play', () async {
    final store = _FakePlayStore();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragonslair_full',
      userId: 'user-1',
    );
    await provider.restore();
    expect(store.restoreCount, 0);
  });
}

class _FakePlayStore implements PlayBillingStore {
  _FakePlayStore({this.purchase, this.restored = const []});

  final PlayPurchase? purchase;
  final List<PlayPurchase> restored;
  int buyCount = 0;
  int restoreCount = 0;
  int finishCount = 0;
  String? obfuscatedAccountId;
  String? restoredAccountId;
  String? finishedToken;

  @override
  bool get isSupported => true;

  @override
  Future<PurchaseOffer> loadOffer(String productId) async {
    return const PurchaseOffer(currency: 'eur', unitAmount: 1999);
  }

  @override
  Future<PlayPurchase> buy(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    buyCount += 1;
    this.obfuscatedAccountId = obfuscatedAccountId;
    return purchase ??
        PlayPurchase(productId: productId, purchaseToken: 'token');
  }

  @override
  Future<List<PlayPurchase>> restore(
    String productId, {
    String obfuscatedAccountId = '',
  }) async {
    restoreCount += 1;
    restoredAccountId = obfuscatedAccountId;
    return restored;
  }

  @override
  Future<void> finish(String purchaseToken) async {
    finishCount += 1;
    finishedToken = purchaseToken;
  }
}

class _RecordingVerifier implements PlayPurchaseVerifier {
  _RecordingVerifier({this.throwOnVerify = false});

  final bool throwOnVerify;
  String? productId;
  String? purchaseToken;
  int verifyCount = 0;

  @override
  bool get isConfigured => true;

  @override
  Future<void> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    verifyCount += 1;
    this.productId = productId;
    this.purchaseToken = purchaseToken;
    if (throwOnVerify) {
      throw const PurchaseUnavailableException();
    }
  }
}
