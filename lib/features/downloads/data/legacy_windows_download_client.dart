import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/windows_download_client.dart';

class LegacyWindowsDownloadClient implements WindowsDownloadClient {
  const LegacyWindowsDownloadClient({this.accessToken});

  final String? accessToken;

  @override
  Future<Uri> requestDownloadUri() async {
    final token = accessToken;
    if (token == null || token.isEmpty) {
      throw const AppAuthException('Session absente. Reconnecte-toi.');
    }
    if (!AppConfig.isGameMasterBackendConfigured) {
      throw const NetworkException('API inaccessible.');
    }

    final client = http.Client();
    try {
      final response = await client
          .get(
            AppConfig.windowsDownloadUri,
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode == 401 || response.statusCode == 403) {
        if (_apiDetail(response) == 'FULL_GAME_REQUIRED') {
          throw const NetworkException(
            'Le jeu complet est requis pour telecharger Windows.',
          );
        }
        throw NetworkException('Acces refuse (${response.statusCode}).');
      }
      if (response.statusCode == 503) {
        throw const NetworkException(
          'Telechargement indisponible pour le moment.',
        );
      }
      if (response.statusCode != 200) {
        throw const NetworkException('API inaccessible.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const NetworkException('Lien de telechargement absent.');
      }
      final raw = decoded['download_url']?.toString().trim() ?? '';
      final uri = Uri.tryParse(raw);
      if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const NetworkException('Lien de telechargement absent.');
      }
      return uri;
    } on TimeoutException {
      throw const NetworkException('API inaccessible.');
    } on FormatException {
      throw const NetworkException('Lien de telechargement absent.');
    } finally {
      client.close();
    }
  }
}

String? _apiDetail(http.Response response) {
  try {
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}
