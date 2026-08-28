import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/game_access.dart';
import '../domain/purchase_provider.dart';

/// Authoritative entitlement snapshot from FastAPI (`GET /v1/purchases/me`).
class BackendEntitlementClient {
  const BackendEntitlementClient({
    required this.accessToken,
    http.Client? client,
  }) : _client = client;

  final String accessToken;
  final http.Client? _client;

  Future<Map<String, dynamic>> fetchMe() async {
    if (!AppConfig.isGameMasterBackendConfigured) {
      throw const PurchaseUnavailableException();
    }
    final token = accessToken.trim();
    if (token.isEmpty) {
      throw const AppAuthException(
        'Session absente. Reconnecte-toi avant d acheter.',
      );
    }
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .get(
            AppConfig.purchaseMeUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 503) {
        throw const PurchaseUnavailableException();
      }
      if (response.statusCode >= 400) {
        throw NetworkException('Entitlement refuse (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('Reponse entitlement invalide.');
      }
      return decoded;
    } on TimeoutException catch (error) {
      throw NetworkException('Le backend entitlement ne repond pas.', cause: error);
    } on FormatException catch (error) {
      throw NetworkException('Reponse entitlement invalide.', cause: error);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  Future<GameAccessLevel> fetchAccessLevel() async {
    final payload = await fetchMe();
    final isFull = payload['is_full'];
    if (isFull is bool) {
      return isFull ? GameAccessLevel.full : GameAccessLevel.demo;
    }
    final entitlement = payload['entitlement'] ?? payload['access_level'];
    return GameAccessLevel.fromJson(entitlement);
  }
}
