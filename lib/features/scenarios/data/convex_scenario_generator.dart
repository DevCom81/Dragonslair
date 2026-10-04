import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/convex/convex_mappers.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/custom_scenario_draft.dart';
import '../domain/scenario_generator.dart';
import '../domain/world_state.dart';

class ConvexScenarioGenerator implements ScenarioGenerator {
  ConvexScenarioGenerator({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<Map<String, dynamic>> generate({
    required String roomId,
    required CustomScenarioDraft draft,
  }) async {
    final raw = await convexAction(
      gateway: _gateway,
      binder: _binder,
      name: 'gameMaster:generate',
      args: {
        'roomId': roomId,
        'prompt': draft.prompt.trim(),
        if (draft.title.trim().isNotEmpty) 'title': draft.title.trim(),
        if (draft.tone.trim().isNotEmpty) 'tone': draft.tone.trim(),
        'difficulty': draft.difficulty.name,
        'duration': draft.duration.name,
        'orientations':
            draft.orientations.map((item) => item.name).toList(growable: false),
        'improvise': draft.improvise,
        'permadeath': draft.permadeath,
        'pvp': draft.pvp,
        'betrayals': draft.betrayals,
      },
      timeout: convexScenarioTimeout,
    );
    final json = convexObject(raw, label: 'scenario');
    if (json.containsKey('gm_secrets') || json.containsKey('gmSecrets')) {
      throw const NetworkException('Le backend a renvoye des secrets MJ.');
    }
    final worldState = sanitizePublicWorldState(json['world_state']);
    if (worldState.containsKey('gm_secrets')) {
      throw const NetworkException('Le backend a renvoye des secrets MJ.');
    }
    return worldState;
  }
}
