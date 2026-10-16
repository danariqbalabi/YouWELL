import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in [userId]'s session, refreshed first if it is about to
/// expire. Safari pauses timers while the iPhone web app is in the
/// background, so the SDK's own auto refresh can miss the expiry and the
/// first request after reopening would be rejected.
Future<Session> freshSession(SupabaseClient client, String userId) async {
  var session = client.auth.currentSession;
  if (session == null || session.user.id != userId) {
    throw StateError('The account is no longer signed in');
  }
  if (session.isExpired) {
    session = (await client.auth.refreshSession()).session;
    if (session == null || session.user.id != userId) {
      throw StateError('The account is no longer signed in');
    }
  }
  return session;
}
