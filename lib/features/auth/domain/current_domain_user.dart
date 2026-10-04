import '../../../core/backend/backend_mode.dart';
import 'auth_user.dart';

String? resolveCurrentDomainUserId({
  required BackendMode mode,
  required AuthUser? authUser,
  required String? convexDomainUserId,
}) {
  if (authUser == null) {
    return null;
  }
  switch (mode) {
    case BackendMode.legacy:
      return authUser.id;
    case BackendMode.convex:
      return convexDomainUserId;
  }
}

bool isCurrentDomainUser(String? domainUserId, String? recordUserId) {
  return domainUserId != null &&
      recordUserId != null &&
      domainUserId == recordUserId;
}
