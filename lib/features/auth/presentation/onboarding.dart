import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/backend_composition.dart';
import '../../scenarios/domain/scenario_definition.dart';
import '../domain/player_profile.dart';
import 'profile_providers.dart';

Future<void> routeAfterSession(BuildContext context, WidgetRef ref) async {
  final profile = await ref.read(profileRepositoryProvider).fetchCurrent();
  ref.invalidate(currentProfileProvider);
  if (!context.mounted) {
    return;
  }

  if (profile == null) {
    context.goNamed('display-name');
    return;
  }
  if (!isProfileReady(profile)) {
    context.goNamed('character-sheet');
    return;
  }
  context.goNamed('play-hub');
}

bool isProfileReady(PlayerProfile? profile) {
  return (profile?.sheetConfirmed ?? false) &&
      CharacterClassCatalog.isPlayableId(profile?.classId);
}
