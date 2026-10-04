import '../config/app_config.dart';
import 'backend_mode.dart';

const convexUrlRequiredMessage =
    'BACKEND_MODE=convex requiert CONVEX_URL.';

void ensureSupportedBackendMode(BackendMode mode) {
  if (mode == BackendMode.convex && !AppConfig.isConvexConfigured) {
    throw StateError(convexUrlRequiredMessage);
  }
}

bool shouldInitializeSupabase(BackendMode mode) {
  return mode == BackendMode.legacy && AppConfig.isSupabaseConfigured;
}
