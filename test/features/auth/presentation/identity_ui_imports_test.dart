import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity widgets do not import supabase_flutter', () {
    const files = [
      'lib/features/home/presentation/home_screen.dart',
      'lib/features/home/presentation/play_hub_screen.dart',
      'lib/features/auth/presentation/auth_controller.dart',
      'lib/features/auth/presentation/auth_screen.dart',
      'lib/features/auth/presentation/display_name_screen.dart',
      'lib/features/auth/presentation/password_reset_screen.dart',
    ];

    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains("package:supabase_flutter/supabase_flutter.dart"),
        isFalse,
        reason: '$path still imports supabase_flutter',
      );
      expect(
        source.contains('package:dartvex'),
        isFalse,
        reason: '$path imports dartvex',
      );
      expect(
        source.contains('WORKOS_API_KEY'),
        isFalse,
        reason: '$path mentions WORKOS_API_KEY',
      );
      expect(
        source.contains('auth.workos.access'),
        isFalse,
        reason: '$path reads WorkOS tokens directly',
      );
    }

    final resetSource =
        File('lib/features/auth/presentation/password_reset_screen.dart')
            .readAsStringSync();
    expect(resetSource.contains('confirmPasswordReset'), isFalse);
    expect(resetSource.contains('resetToken'), isFalse);
    expect(resetSource.contains('newPassword'), isFalse);
  });

  test('Flutter auth client does not embed a WorkOS server API key', () {
    const roots = [
      'lib/features/auth',
      'lib/core/backend',
      'lib/core/convex',
    ];
    for (final root in roots) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) {
          continue;
        }
        final source = entity.readAsStringSync();
        expect(
          source.contains('WORKOS_API_KEY'),
          isFalse,
          reason: '${entity.path} contains WORKOS_API_KEY',
        );
      }
    }
  });

  test('Convex adapters do not read SharedPreferences or import Supabase', () {
    const files = [
      'lib/features/auth/data/convex_profile_repository.dart',
      'lib/features/rooms/data/convex_room_repository.dart',
      'lib/features/players/data/convex_player_repository.dart',
      'lib/features/events/data/convex_game_event_repository.dart',
      'lib/features/enemies/data/convex_enemy_repository.dart',
      'lib/features/combat/data/convex_combat_repository.dart',
      'lib/features/game/data/convex_pending_roll_repository.dart',
      'lib/features/game/data/convex_gameplay_commands.dart',
      'lib/features/game_master/data/convex_game_master_repository.dart',
      'lib/features/access/data/convex_entitlement_repository.dart',
      'lib/core/convex/convex_auth_binder.dart',
      'lib/core/convex/convex_mappers.dart',
      'lib/features/auth/domain/current_domain_user.dart',
      'lib/features/auth/presentation/current_domain_user.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source.contains('SharedPreferences'), isFalse, reason: path);
      expect(source.contains('supabase_flutter'), isFalse, reason: path);
      expect(source.contains('.scenarioId != \'demo\''), isFalse, reason: path);
      expect(source.contains('scenarioId != "demo"'), isFalse, reason: path);
    }
  });
}
