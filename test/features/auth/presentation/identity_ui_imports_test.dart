import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('identity widgets do not import supabase_flutter', () {
    const files = [
      'lib/features/home/presentation/home_screen.dart',
      'lib/features/home/presentation/play_hub_screen.dart',
      'lib/features/auth/presentation/auth_controller.dart',
      'lib/features/auth/presentation/auth0_screens.dart',
      'lib/features/auth/presentation/display_name_screen.dart',
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
        source.contains('WORKOS_API_KEY') || source.contains('AUTH0_CLIENT_SECRET'),
        isFalse,
        reason: '$path mentions a server auth secret',
      );
      expect(
        source.contains('auth.workos.access'),
        isFalse,
        reason: '$path reads legacy WorkOS tokens directly',
      );
    }
  });

  test('Flutter auth client does not embed auth server secrets', () {
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
          source.contains('WORKOS_API_KEY') ||
              source.contains('AUTH0_CLIENT_SECRET'),
          isFalse,
          reason: '${entity.path} contains a server auth secret',
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
