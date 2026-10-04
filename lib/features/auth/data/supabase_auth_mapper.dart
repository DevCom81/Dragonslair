import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../domain/auth_user.dart';

AuthUser authUserFromSupabase(User user) {
  return AuthUser(
    id: user.id,
    isAnonymous: user.isAnonymous,
  );
}
