import 'package:dragons_lair/core/backend/backend_composition.dart';
import 'package:dragons_lair/core/backend/backend_mode.dart';
import 'package:dragons_lair/core/convex/convex_auth_binder.dart';
import 'package:dragons_lair/core/convex/convex_gateway.dart';
import 'package:dragons_lair/core/errors/app_exception.dart';
import 'package:dragons_lair/features/access/data/convex_entitlement_repository.dart';
import 'package:dragons_lair/features/access/data/convex_google_play_verifier.dart';
import 'package:dragons_lair/features/access/data/convex_stripe_checkout_purchase_provider.dart';
import 'package:dragons_lair/features/access/data/google_play_purchase_provider.dart';
import 'package:dragons_lair/features/access/domain/entitlement_repository.dart';
import 'package:dragons_lair/features/access/domain/play_account_id.dart';
import 'package:dragons_lair/features/access/domain/purchase_provider.dart';
import 'package:dragons_lair/features/auth/domain/auth_access_token_source.dart';
import 'package:dragons_lair/features/downloads/data/convex_windows_download_client.dart';
import 'package:dragons_lair/features/downloads/data/legacy_windows_download_client.dart';
import 'package:dragons_lair/features/game/data/convex_gameplay_commands.dart';
import 'package:dragons_lair/features/game_master/data/convex_game_master_repository.dart';
import 'package:dragons_lair/features/game_master/data/mock_game_master_repository.dart';
import 'package:dragons_lair/features/game_master/data/remote_game_master_repository.dart';
import 'package:dragons_lair/features/game_master/domain/game_master_repository.dart';
import 'package:dragons_lair/features/scenarios/data/convex_scenario_generator.dart';
import 'package:dragons_lair/features/scenarios/data/remote_scenario_generator.dart';
import 'package:dragons_lair/features/scenarios/domain/custom_scenario_draft.dart';
import 'package:dragons_lair/core/supabase/supabase_client_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGateway gateway;
  late ConvexAuthBinder binder;

  setUp(() {
    gateway = _FakeGateway();
    binder = ConvexAuthBinder(gateway: gateway, tokens: _FakeTokens());
  });

  test('gateway action reuses the auth binder', () async {
    gateway.actionResults['stripe:getOffer'] = {
      'currency': 'eur',
      'unitAmount': 1999,
    };
    final offer = await ConvexStripeCheckoutPurchaseProvider(
      gateway: gateway,
      binder: binder,
    ).loadOffer();
    expect(gateway.setAuthCalls, 1);
    expect(gateway.actions, ['stripe:getOffer']);
    expect(gateway.actionArgs.single, isEmpty);
    expect(offer.currency, 'eur');
    expect(offer.unitAmount, 1999);
  });

  test('GM respond sends only roomId and action', () async {
    gateway.actionResults['gameMaster:respond'] = {
      'narration': 'La porte s ouvre.',
      'actions': <Object?>[],
      'choices': <Object?>[],
    };
    await ConvexGameMasterRepository(gateway: gateway, binder: binder).respond(
      const GameMasterInput(
        roomId: 'room_a',
        playerId: 'player_a',
        action: 'ouvre la porte',
        playerName: 'Aldric',
      ),
    );
    expect(gateway.actions, ['gameMaster:respond']);
    expect(gateway.actionArgs.single, {
      'roomId': 'room_a',
      'action': 'ouvre la porte',
    });
    expect(gateway.mutates, isNot(contains('gameEvents:create')));
  });

  test('pending roll GM continuation is a single resolveRoll action', () async {
    await binder.ensureAuthenticated();
    gateway.mutates.clear();
    await ConvexGameplayCommands(gateway: gateway, binder: binder)
        .resolveServerRoll(pendingRollId: 'roll_1', raw: 18);
    expect(gateway.actions, ['gameMaster:resolveRoll']);
    expect(gateway.mutates, isEmpty);
    expect(gateway.mutates, isNot(contains('rolls:resolve')));
    expect(gateway.actionArgs.single, {
      'pendingRollId': 'roll_1',
      'raw': 18,
    });
  });

  test('scenario generate maps Convex world_state', () async {
    gateway.actionResults['gameMaster:generate'] = {
      'world_state': {'title': 'Cave', 'setting': 'dark'},
      'opening_narration': 'You enter.',
    };
    const draft = CustomScenarioDraft(
      prompt: 'Une aventure dans les cavernes oubliees',
      title: 'Cave',
    );
    final world = await ConvexScenarioGenerator(
      gateway: gateway,
      binder: binder,
    ).generate(roomId: 'room_a', draft: draft);
    expect(world['title'], 'Cave');
    expect(gateway.actions, ['gameMaster:generate']);
    expect(gateway.actionArgs.single['roomId'], 'room_a');
    expect(gateway.actionArgs.single.containsKey('userId'), isFalse);
  });

  test('entitlement getMine keeps server accessLevel', () async {
    gateway.queries['entitlements:getMine'] = {
      'accessLevel': 'demo',
      'source': 'purchase',
      'expiresAt': 1,
    };
    final row = await ConvexEntitlementRepository(
      gateway: gateway,
      binder: binder,
    ).fetchCurrent('ignored-auth-id');
    expect(row.level.isDemo, isTrue);
    expect(row.source, 'purchase');
    expect(gateway.queryNames, ['entitlements:getMine']);
    expect(gateway.queryArgs.single, isEmpty);
  });

  test('demo getMine is read-only', () async {
    gateway.queries['demoSessions:getMine'] = {
      'startedAt': 1_700_000_000_000,
      'expiresAt': 1_700_000_600_000,
    };
    await binder.ensureAuthenticated();
    gateway.mutates.clear();
    final session = await ConvexEntitlementRepository(
      gateway: gateway,
      binder: binder,
    ).fetchDemoSession('ignored');
    expect(session?.startedAt, isNotNull);
    expect(gateway.mutates, isEmpty);
    expect(gateway.actions, isEmpty);
    await ConvexEntitlementRepository(gateway: gateway, binder: binder)
        .ensureDemoPlay('room_a');
    expect(gateway.mutates, isEmpty);
    expect(gateway.actions, isEmpty);
  });

  test('stripe checkout sends empty args', () async {
    gateway.actionResults['stripe:createCheckout'] = {
      'checkout_url': 'https://checkout.stripe.com/c/pay/cs_test',
    };
    await expectLater(
      ConvexStripeCheckoutPurchaseProvider(gateway: gateway, binder: binder)
          .purchase(),
      throwsA(anything),
    );
    expect(gateway.actions, ['stripe:createCheckout']);
    expect(gateway.actionArgs.single, isEmpty);
  });

  test('play buy uses billingIdentity and redeem token only', () async {
    gateway.queries['googlePlay:billingIdentity'] = {
      'obfuscatedAccountId': 'abc123hash',
    };
    gateway.actionResults['googlePlay:redeem'] = {
      'accessLevel': 'full',
      'source': 'purchase',
      'metadata': {'active_sources': <Object?>['google_play']},
    };
    final store = _FakePlayStore();
    final provider = GooglePlayPurchaseProvider(
      store: store,
      productId: 'dragons_lair_unlock',
      billingIdentity: () async {
        final raw = await gateway.query('googlePlay:billingIdentity');
        return (raw as Map)['obfuscatedAccountId'] as String;
      },
      verifier: ConvexGooglePlayVerifier(gateway: gateway, binder: binder),
    );
    await provider.purchase();
    expect(store.obfuscatedAccountId, 'abc123hash');
    expect(store.obfuscatedAccountId, isNot(playObfuscatedAccountId('user-1')));
    expect(gateway.actions, ['googlePlay:redeem']);
    expect(gateway.actionArgs.single, {'purchaseToken': 'tok'});
  });

  test('windows download asks for URL only', () async {
    gateway.actionResults['downloads:createWindowsDownload'] = {
      'download_url': 'https://signed.example/file',
    };
    final uri = await ConvexWindowsDownloadClient(
      gateway: gateway,
      binder: binder,
    ).requestDownloadUri();
    expect(uri.toString(), 'https://signed.example/file');
    expect(gateway.actionArgs.single, isEmpty);
  });

  test('legacy composition keeps railway GM and HTTP download', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.legacy),
        supabaseClientProvider.overrideWith((ref) => null),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(gameMasterRepositoryProvider),
      isA<MockGameMasterRepository>(),
    );
    expect(
      container.read(scenarioGeneratorProvider),
      isA<RemoteScenarioGenerator>(),
    );
    expect(
      container.read(windowsDownloadClientProvider),
      isA<LegacyWindowsDownloadClient>(),
    );
    expect(
      container.read(entitlementRepositoryProvider),
      isA<SupabaseEntitlementRepository>(),
    );
  });

  test('convex composition selects Convex remote adapters', () {
    final container = ProviderContainer(
      overrides: [
        backendModeProvider.overrideWith((ref) => BackendMode.convex),
        convexGatewayProvider.overrideWith((ref) => gateway),
        authAccessTokenSourceProvider.overrideWith((ref) => _FakeTokens()),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(gameMasterRepositoryProvider),
      isA<ConvexGameMasterRepository>(),
    );
    expect(
      container.read(scenarioGeneratorProvider),
      isA<ConvexScenarioGenerator>(),
    );
    expect(
      container.read(entitlementRepositoryProvider),
      isA<ConvexEntitlementRepository>(),
    );
    expect(
      container.read(windowsDownloadClientProvider),
      isA<ConvexWindowsDownloadClient>(),
    );
    expect(container.read(gameMasterRepositoryProvider), isNot(isA<RemoteGameMasterRepository>()));
  });

  test('GM timeout is mapped without OpenRouter details', () async {
    gateway.failActionWith = Exception('OpenRouter timeout stack');
    await expectLater(
      ConvexGameMasterRepository(gateway: gateway, binder: binder).respond(
        const GameMasterInput(roomId: 'room_a', action: 'look'),
      ),
      throwsA(
        isA<NetworkException>().having(
          (error) => error.message.toLowerCase().contains('openrouter'),
          'openrouter leak',
          isFalse,
        ),
      ),
    );
  });
}

class _FakeTokens implements AuthAccessTokenSource {
  @override
  Future<String?> accessToken({bool forceRefresh = false}) async => 'jwt';
}

class _FakePlayStore implements PlayBillingStore {
  String? obfuscatedAccountId;

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
    this.obfuscatedAccountId = obfuscatedAccountId;
    return const PlayPurchase(
      productId: 'dragons_lair_unlock',
      purchaseToken: 'tok',
    );
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

class _FakeGateway implements ConvexGateway {
  var setAuthCalls = 0;
  final mutates = <String>[];
  final actions = <String>[];
  final actionArgs = <Map<String, Object?>>[];
  final actionResults = <String, Object?>{};
  Object? failActionWith;
  final queryNames = <String>[];
  final queryArgs = <Map<String, Object?>>[];
  final queries = <String, Object?>{};

  @override
  Future<void> setAuthWithRefresh({
    required ConvexTokenFetcher fetchToken,
  }) async {
    setAuthCalls += 1;
  }

  @override
  Future<void> clearAuth() async {}

  @override
  Future<Object?> query(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    queryNames.add(name);
    queryArgs.add(args);
    return queries[name];
  }

  @override
  Future<Object?> mutate(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    mutates.add(name);
    if (name == 'users:ensureUser') {
      return {'_id': 'user_1'};
    }
    return null;
  }

  @override
  Future<Object?> action(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    actions.add(name);
    actionArgs.add(Map<String, Object?>.from(args));
    final failure = failActionWith;
    if (failure != null) {
      throw failure;
    }
    return actionResults[name] ??
        {
          'narration': 'ok',
          'actions': <Object?>[],
          'choices': <Object?>[],
        };
  }

  @override
  ConvexWatch subscribe(
    String name, [
    Map<String, Object?> args = const {},
  ]) {
    throw UnimplementedError();
  }
}
