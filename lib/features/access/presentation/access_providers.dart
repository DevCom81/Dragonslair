import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_controller.dart';
import '../domain/entitlement_repository.dart';
import '../domain/game_access.dart';

final currentEntitlementProvider =
    FutureProvider.autoDispose<UserEntitlement?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    return null;
  }
  return ref.watch(entitlementRepositoryProvider).fetchCurrent(user.id);
});

final currentDemoSessionProvider =
    FutureProvider.autoDispose<DemoSession?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) {
    return null;
  }
  return ref.watch(entitlementRepositoryProvider).fetchDemoSession(user.id);
});
