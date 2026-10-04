import '../../../core/convex/convex_action.dart';
import '../../../core/convex/convex_auth_binder.dart';
import '../../../core/convex/convex_document.dart';
import '../../../core/convex/convex_gateway.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/game_master_repository.dart';
import '../domain/game_master_response.dart';

class ConvexGameMasterRepository implements GameMasterRepository {
  ConvexGameMasterRepository({
    required ConvexGateway gateway,
    required ConvexAuthBinder binder,
  })  : _gateway = gateway,
        _binder = binder;

  final ConvexGateway _gateway;
  final ConvexAuthBinder _binder;

  @override
  Future<GameMasterResponse> respond(GameMasterInput input) async {
    final roomId = input.roomId?.trim() ?? '';
    if (roomId.isEmpty) {
      throw const GameException('Partie introuvable.');
    }
    return _parse(
      await convexAction(
        gateway: _gateway,
        binder: _binder,
        name: 'gameMaster:respond',
        args: {
          'roomId': roomId,
          'action': input.action.trim(),
        },
        timeout: convexGameMasterTimeout,
      ),
    );
  }

  @override
  Future<GameMasterResponse> resolveRoll(ResolveRollInput input) async {
    return _parse(
      await convexAction(
        gateway: _gateway,
        binder: _binder,
        name: 'gameMaster:resolveRoll',
        args: {
          'pendingRollId': input.pendingRollId,
          'raw': input.raw,
        },
        timeout: convexGameMasterTimeout,
      ),
    );
  }

  GameMasterResponse _parse(Object? raw) {
    return GameMasterResponse.fromJson(convexObject(raw, label: 'gmResponse'));
  }
}
