import 'package:dartvex/dartvex.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

final convexClientProvider = Provider<ConvexClient?>((ref) {
  if (!AppConfig.isConvexConfigured) {
    return null;
  }
  return ConvexClient(
    AppConfig.convexUrl,
    config: const ConvexClientConfig(
      logLevel: DartvexLogLevel.off,
    ),
  );
});
