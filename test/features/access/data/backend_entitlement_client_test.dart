import 'dart:convert';

import 'package:dragons_lair/core/config/app_config.dart';
import 'package:dragons_lair/features/access/data/backend_entitlement_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(
      isOptional: true,
      mergeWith: {'GAME_MASTER_BACKEND_URL': 'https://api.example.com'},
    );
  });

  test('fetchMe parses backend full entitlement', () async {
    final client = BackendEntitlementClient(
      accessToken: 'jwt-token',
      client: MockClient((request) async {
        expect(request.url, AppConfig.purchaseMeUri);
        expect(request.headers['Authorization'], 'Bearer jwt-token');
        return http.Response(
          jsonEncode({
            'entitlement': 'full',
            'is_full': true,
            'access_level': 'full',
            'source': 'purchase',
            'active_sources': ['stripe'],
          }),
          200,
        );
      }),
    );
    final level = await client.fetchAccessLevel();
    expect(level.isFull, isTrue);
  });

  test('fetchMe prefers is_full from backend over forged access_level', () async {
    final client = BackendEntitlementClient(
      accessToken: 'jwt-token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'entitlement': 'demo',
            'is_full': true,
            'access_level': 'demo',
            'source': 'purchase',
          }),
          200,
        );
      }),
    );
    final level = await client.fetchAccessLevel();
    expect(level.isFull, isTrue);
  });

  test('fetchMe treats unknown access_level as demo when is_full is false', () async {
    final client = BackendEntitlementClient(
      accessToken: 'jwt-token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'entitlement': 'admin',
            'is_full': false,
            'access_level': 'admin',
            'source': 'purchase',
          }),
          200,
        );
      }),
    );
    final level = await client.fetchAccessLevel();
    expect(level.isDemo, isTrue);
  });
}
