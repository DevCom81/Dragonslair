import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../domain/player_profile.dart';
import 'auth_controller.dart';

final currentProfileProvider = FutureProvider<PlayerProfile?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    return null;
  }
  return ref.read(profileRepositoryProvider).fetchCurrent();
});
