import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Web-only Windows installer download. Backend still enforces FULL.
Future<void> startWindowsDownload({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  try {
    final uri = await _requestWindowsDownloadUrl(ref);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telechargement impossible dans ce navigateur.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  } on AppException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Telechargement impossible.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }
}

Future<Uri> _requestWindowsDownloadUrl(WidgetRef ref) async {
  final token = ref
      .read(supabaseClientProvider)
      ?.auth
      .currentSession
      ?.accessToken;
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
