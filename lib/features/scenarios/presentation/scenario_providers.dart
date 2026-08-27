import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_client_provider.dart';
import '../data/remote_scenario_generator.dart';

final scenarioGeneratorProvider = Provider<RemoteScenarioGenerator>((ref) {
  final accessToken =
      ref.watch(supabaseClientProvider)?.auth.currentSession?.accessToken;
  return RemoteScenarioGenerator(accessToken: accessToken);
});
