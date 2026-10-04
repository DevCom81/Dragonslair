import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/backend/backend_composition.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';

/// Web-only Windows installer download. Backend still enforces FULL.
Future<void> startWindowsDownload({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  try {
    final uri = await ref.read(windowsDownloadClientProvider).requestDownloadUri();
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
