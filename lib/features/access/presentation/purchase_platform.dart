import 'package:flutter/foundation.dart';

/// Restore purchases is offered only on Android (Google Play).
bool billingRestoreOfferedOnPlatform() {
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
