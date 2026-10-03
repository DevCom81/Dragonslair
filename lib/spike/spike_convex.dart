import 'package:dartvex/dartvex.dart';

import 'spike_config.dart';

class SpikeConvex {
  SpikeConvex._();

  static ConvexClient? _client;
  static AuthHandle? _authHandle;

  static ConvexClient get client {
    final existing = _client;
    if (existing != null) {
      return existing;
    }
    if (!SpikeConfig.isConfigured) {
      throw StateError('CONVEX_URL is missing.');
    }
    final created = ConvexClient(
      SpikeConfig.convexUrl,
      config: const ConvexClientConfig(
        logLevel: DartvexLogLevel.off,
      ),
    );
    _client = created;
    return created;
  }

  static Future<void> bindRefreshableAuth({
    required Future<String?> Function({required bool forceRefresh}) fetchToken,
  }) async {
    await _authHandle?.cancel();
    _authHandle = await client.setAuthWithRefresh(fetchToken: fetchToken);
  }
}
