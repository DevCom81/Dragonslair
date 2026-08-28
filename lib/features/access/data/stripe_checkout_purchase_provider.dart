import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/purchase_provider.dart';

class StripeCheckoutPurchaseProvider implements PurchaseProvider {
  const StripeCheckoutPurchaseProvider({
    this.accessToken,
    http.Client? client,
  }) : _client = client;

  final String? accessToken;
  final http.Client? _client;

  @override
  bool get canPurchase => AppConfig.isGameMasterBackendConfigured;

  @override
  Future<PurchaseOffer> loadOffer() async {
    final payload = await _request(
      (client) => client.get(
        AppConfig.purchaseOfferUri,
        headers: const {'Content-Type': 'application/json'},
      ),
    );
    return PurchaseOffer.fromJson(payload);
  }

  @override
  Future<void> purchase() async {
    final uri = await _createCheckoutUri();
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const PurchaseUnavailableException();
    }
  }

  @override
  Future<void> restore() async {}

  Future<Uri> _createCheckoutUri() async {
    final payload = await _request(
      (client) => client.post(
        AppConfig.purchaseCheckoutUri,
        headers: _authHeaders(),
        body: jsonEncode(const <String, dynamic>{}),
      ),
    );
    final url = payload['checkout_url']?.toString() ?? '';
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const PurchaseUnavailableException();
    }
    return uri;
  }

  Map<String, String> _authHeaders() {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const AppAuthException(
        'Session absente. Reconnecte-toi avant d acheter.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(http.Client client) send,
  ) async {
    if (!AppConfig.isGameMasterBackendConfigured) {
      throw const PurchaseUnavailableException();
    }
    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await send(client).timeout(const Duration(seconds: 25));
      if (response.statusCode == 503) {
        throw const PurchaseUnavailableException();
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

class UnavailablePurchaseProvider implements PurchaseProvider {
  const UnavailablePurchaseProvider();

  @override
  bool get canPurchase => false;

  @override
  Future<PurchaseOffer> loadOffer() async {
    throw const PurchaseUnavailableException();
  }

  @override
  Future<void> purchase() async {
    throw const PurchaseUnavailableException();
  }

  @override
  Future<void> restore() async {}
}
