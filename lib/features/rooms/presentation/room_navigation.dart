import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../players/presentation/player_providers.dart';
import '../domain/room.dart';
import '../domain/room_entry.dart';

Future<void> openRoomForCurrentUser({
  required BuildContext context,
  required WidgetRef ref,
  required Room room,
}) async {
  final l10n = AppLocalizations.of(context);
  final user = ref.read(authControllerProvider).value;
  if (user == null) {
    throw GameException(l10n.authRequired);
  }

  final players =
      await ref.read(playerRepositoryProvider).fetchRoomPlayers(room.id);
  final alreadyJoined = players.any((player) => player.userId == user.id);
  final action = resolveRoomEntry(
    status: room.status,
    alreadyJoined: alreadyJoined,
    isHost: user.id == room.hostId,
  );
  final routeName = routeNameFor(action);
  if (routeName == null) {
    throw GameException(
      action == RoomEntryAction.rejectFinished
          ? l10n.cannotJoinFinished
          : l10n.cannotJoinInProgress,
    );
  }
  if (context.mounted) {
    context.pushNamed(
      routeName,
      pathParameters: {'roomId': room.id},
    );
  }
}
