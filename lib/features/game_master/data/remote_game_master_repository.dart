import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/game_master_repository.dart';
import '../domain/game_master_response.dart';

class RemoteGameMasterRepository implements GameMasterRepository {
  const RemoteGameMasterRepository({http.Client? client}) : _client = client;

  final http.Client? _client;

  @override
  Future<GameMasterResponse> respond(GameMasterInput input) async {
    if (!AppConfig.isGameMasterBackendConfigured) {
      throw const NetworkException(
        'Backend MJ IA non configure. Fournis GAME_MASTER_BACKEND_URL.',
      );
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;

    try {
      final response = await client
          .post(
            AppConfig.gameMasterRespondUri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(input.toJson()),
          )
          .timeout(const Duration(seconds: 35));

      if (response.statusCode >= 400) {
        throw NetworkException(
          'Le backend MJ IA a refuse la requete (${response.statusCode}).',
        );
      }

      return GameMasterResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on TimeoutException catch (error) {
      throw NetworkException('Le backend MJ IA ne repond pas.', cause: error);
    } on FormatException catch (error) {
      throw NetworkException(
        'Le backend MJ IA a renvoye une reponse invalide.',
        cause: error,
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }
}
