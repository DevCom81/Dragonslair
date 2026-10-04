import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_composition.dart';
import '../../../core/backend/backend_mode.dart';
import '../domain/current_domain_user.dart';
import 'auth_controller.dart';

final currentDomainUserIdProvider = FutureProvider<String?>((ref) async {
  final authUser = await ref.watch(authControllerProvider.future);
  final mode = ref.watch(backendModeProvider);
  if (authUser == null) {
    if (mode == BackendMode.convex) {
      await ref.read(convexAuthBinderProvider)?.sync(null);
    }
    return resolveCurrentDomainUserId(
      mode: mode,
      authUser: null,
      convexDomainUserId: null,
    );
  }
  if (mode == BackendMode.legacy) {
    return resolveCurrentDomainUserId(
      mode: mode,
      authUser: authUser,
      convexDomainUserId: null,
    );
  }
  final binder = ref.watch(convexAuthBinderProvider);
  if (binder == null) {
    return null;
  }
  final ready = await binder.ensureAuthenticated(authSubject: authUser.id);
  if (!ready) {
    return null;
  }
  return resolveCurrentDomainUserId(
    mode: mode,
    authUser: authUser,
    convexDomainUserId: binder.domainUserId,
  );
});
