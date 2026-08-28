import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/purchase_provider.dart';

class GooglePlayBackendVerifier implements PlayPurchaseVerifier {
  const GooglePlayBackendVerifier({
    this.accessToken,
    http.Client? client,
  }) : _client = client;

  final String? accessToken;
  final http.Client? _client;

  @override
  bool get isConfigured {
    final token = accessToken;
    return AppConfig.isGameMasterBackendConfigured &&
        token != null &&
        token.isNotEmpty;
  }

  @override
  Future<void> verify({
    required String productId,
    required String purchaseToken,
  }) async {
    if (!isConfigured) {
      throw const PurchaseUnavailableException();
    }
    final payload = await _request(
      productId: productId,
      purchaseToken: purchaseToken,
    );
    if (payload['is_full'] == true) {
      return;
    }
    final level = payload['entitlement'] ?? payload['access_level'];
    if (level?.toString() == 'full') {
      return;
    }
    throw const NetworkException('Achat Google Play refuse.');
  }

  Future<Map<String, dynamic>> _request({
    required String productId,
    required String purchaseToken,
  }) async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const AppAuthException(
        'Session absente. Reconnecte-toi avant d acheter.',
      );
    }
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .post(
            AppConfig.googlePlayPurchaseUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'product_id': productId,
              'purchase_token': purchaseToken,
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 409) {
        throw const PurchaseUnavailableException('PURCHASE_PENDING');
      }
      if (response.statusCode == 503) {
        throw const PurchaseUnavailableException();
      }
      if (response.statusCode == 401) {
        throw const AppAuthException(
          'Session absente. Reconnecte-toi avant d acheter.',
        );
      }
      if (response.statusCode >= 400) {
        throw NetworkException('Achat refuse (${response.statusCode}).');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('Reponse achat invalide.');
      }
      return decoded;
    } on TimeoutException catch (error) {
      throw NetworkException('Le backend achat ne repond pas.', cause: error);
    } on FormatException catch (error) {
      throw NetworkException('Reponse achat invalide.', cause: error);
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
