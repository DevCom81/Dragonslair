class AuthUser {
  const AuthUser({
    required this.id,
    required this.isAnonymous,
  });

  final String id;
  final bool isAnonymous;

  @override
  bool operator ==(Object other) {
    return other is AuthUser &&
        other.id == id &&
        other.isAnonymous == isAnonymous;
  }

  @override
  int get hashCode => Object.hash(id, isAnonymous);
}

bool showsAnonymousGuestUi(AuthUser? user) =>
    user != null && user.isAnonymous;
