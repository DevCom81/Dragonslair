import 'custom_scenario_draft.dart';

abstract interface class ScenarioGenerator {
  Future<Map<String, dynamic>> generate({
    required String roomId,
    required CustomScenarioDraft draft,
  });
}
