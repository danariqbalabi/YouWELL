enum AdminAccess { denied, needsMfa, allowed }

class AuthIdentity {
  const AuthIdentity(this.id);
  final String id;
}

class MfaSetup {
  const MfaSetup({required this.factorId, this.secret});
  final String factorId;
  final String? secret;
}

/// SDK-independent boundary: auth state and errors can be tested offline.
abstract interface class AuthGateway {
  AuthIdentity? get identity;
  Stream<AuthIdentity?> get changes;
  Future<void> signInWithGoogle();
  Future<void> signOut();
  Future<AdminAccess> adminAccess();
  Future<MfaSetup> prepareMfa();
  Future<void> verifyMfa(String factorId, String code);
}
