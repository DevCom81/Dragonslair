import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/l10n/l10n_labels.dart';
import '../../../core/l10n/locale_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../rooms/domain/room_locale.dart';
import '../../rooms/presentation/room_navigation.dart';
import '../../rooms/presentation/room_providers.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../domain/demo_scenario.dart';
import 'access_providers.dart';

Future<void> startOrResumeDemo({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final l10n = AppLocalizations.of(context);
  final user = ref.read(authControllerProvider).value;
  if (user == null) {
    throw GameException(l10n.authRequired);
  }

  final session = await ref.read(currentDemoSessionProvider.future);
  if (session != null && session.roomId != null && session.roomId!.isNotEmpty) {
    try {
      final room =
          await ref.read(roomRepositoryProvider).fetchRoom(session.roomId!);
      if (context.mounted) {
        await openRoomForCurrentUser(context: context, ref: ref, room: room);
        return;
      }
    } catch (_) {
      if (session.isConsumed) {
        throw GameException(l10n.demoAlreadyUsed);
      }
    }
  }

  if (session != null && session.isConsumed) {
    throw GameException(l10n.demoAlreadyUsed);
  }

  final locale = normalizeRoomLocale(
    ref.read(localeControllerProvider).languageCode,
  );
  final room = await ref.read(roomRepositoryProvider).createRoom(
        name: l10n.scenarioDemoName,
        hostId: user.id,
        scenarioId: ScenarioCatalog.demo.id,
        scenarioName: localizedScenarioName(l10n, ScenarioCatalog.demo.id),
        minPlayers: ScenarioCatalog.demo.minPlayers,
        requiredClassIds: const [],
        worldState: demoWorldState(locale),
        locale: locale,
      );
  ref.invalidate(currentDemoSessionProvider);
  if (context.mounted) {
    context.pushNamed('figurines', pathParameters: {'roomId': room.id});
  }
}
