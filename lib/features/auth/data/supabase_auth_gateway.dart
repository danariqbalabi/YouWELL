import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/config/app_environment.dart';
import '../domain/auth_gateway.dart';

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this.client);
  final SupabaseClient client;

  @override
  AuthIdentity? get identity => client.auth.currentUser == null
      ? null
      : AuthIdentity(client.auth.currentUser!.id);

  @override
  Stream<AuthIdentity?> get changes => client.auth.onAuthStateChange.map(
    (event) =>
        event.session == null ? null : AuthIdentity(event.session!.user.id),
  );

  @override
  Future<void> signInWithGoogle() async {
    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? '${Uri.base.origin}/'
          : AppEnvironment.authRedirectUrl,
      authScreenLaunchMode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      queryParams: const {'prompt': 'select_account'},
    );
    if (!launched) throw StateError('Browser login tidak dapat dibuka.');
  }

  @override
  Future<void> signOut() => client.auth.signOut(scope: SignOutScope.local);

  @override
  Future<AdminAccess> adminAccess() async {
    // The server checks the verified identity, private whitelist and JWT AAL.
    // No client-side email or route can grant moderator privileges.
    final value = await client.rpc('youwell_admin_access');
    return switch (value) {
      'allowed' => AdminAccess.allowed,
      'needs_mfa' => AdminAccess.needsMfa,
      _ => AdminAccess.denied,
    };
  }

  @override
  Future<MfaSetup> prepareMfa() async {
    final factors = await client.auth.mfa.listFactors();
    if (factors.totp.isNotEmpty) {
      return MfaSetup(factorId: factors.totp.first.id);
    }
    // Recover an unfinished setup instead of accumulating abandoned factors.
    for (final factor in factors.all) {
      if (factor.factorType == FactorType.totp &&
          factor.status == FactorStatus.unverified) {
        await client.auth.mfa.unenroll(factor.id);
      }
    }
    final enrolled = await client.auth.mfa.enroll(issuer: 'YouWELL Admin');
    return MfaSetup(factorId: enrolled.id, secret: enrolled.totp!.secret);
  }

  @override
  Future<void> verifyMfa(String factorId, String code) async {
    await client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  }

  @override
  Future<void> deleteAccount() async {
    await _deleteOwnPhotos();
    // The server derives the account from the JWT; no ID is sent.
    await client.rpc('delete_youwell_account');
  }

  /// Storage files are not removed by deleting the auth user, so this
  /// account's Community photos go first. A failure aborts the deletion.
  Future<void> _deleteOwnPhotos() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;
    final photos = client.storage.from('community');
    // list() returns up to 100 files per call; the round cap only stops a
    // loop if a removal were silently refused.
    for (var round = 0; round < 20; round++) {
      final List<FileObject> files;
      try {
        files = await photos.list(path: userId);
      } on StorageException catch (error) {
        // Before the phase 5 migration there is no bucket and no photo.
        if (error.statusCode == '404' ||
            error.message.toLowerCase().contains('not found')) {
          return;
        }
        rethrow;
      }
      if (files.isEmpty) return;
      await photos.remove([for (final file in files) '$userId/${file.name}']);
    }
    throw StateError('Community photos could not be removed');
  }
}
