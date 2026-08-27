import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/custom_scenario_draft.dart';
import '../domain/world_state.dart';

class RemoteScenarioGenerator {
  const RemoteScenarioGenerator({this.accessToken, http.Client? client})
    : _client = client;

  final String? accessToken;
  final http.Client? _client;

  Future<Map<String, dynamic>> generate({
    required String roomId,
    required CustomScenarioDraft draft,
  }) async {
    if (!AppConfig.isGameMasterBackendConfigured) {
      throw const NetworkException(
        'Backend MJ IA non configure. Fournis GAME_MASTER_BACKEND_URL.',
      );
    }

    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const AppAuthException(
        'Session absente. Reconnecte-toi avant de generer une aventure.',
      );
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .post(
            AppConfig.scenarioGenerateUri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(draft.toGenerateJson(roomId)),
          )
          .timeout(const Duration(seconds: 40));

      if (response.statusCode >= 400) {
        throw NetworkException(
          refusalMessageForStatus(
            response.statusCode,
            'La generation du scenario a ete refusee (${response.statusCode}).',
          ),
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('Scenario genere invalide.');
      }
      if (decoded.containsKey('gm_secrets')) {
        throw const NetworkException('Le backend a renvoye des secrets MJ.');
      }
      final worldState = sanitizePublicWorldState(decoded['world_state']);
      if (worldState.containsKey('gm_secrets')) {
        throw const NetworkException('Le backend a renvoye des secrets MJ.');
      }
      return worldState;
    } on TimeoutException catch (error) {
      throw NetworkException(
        'La generation du scenario ne repond pas.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw NetworkException(
        'Le backend a renvoye un scenario invalide.',
        cause: error,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
