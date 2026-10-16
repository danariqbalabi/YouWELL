import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/types/json_map.dart';
import '../domain/cloud_progress.dart';
import 'package:youwell/features/auth/data/fresh_session.dart';

class SupabaseProgressStore implements ProgressCloudStore {
  SupabaseProgressStore({
    required this.client,
    required this.userId,
    required this.url,
    required this.publishableKey,
  });
  final SupabaseClient client;
  final String userId, url, publishableKey;
  CloudProgressSnapshot? _lastSnapshot;

  // Capture this account's JWT per request. A logout/account switch must not
  // turn an in-flight A snapshot into an authenticated write for account B.
  Future<PostgrestClient> _request() async {
    final session = await freshSession(client, userId);
    return PostgrestClient(
      '$url/rest/v1',
      headers: {
        'apikey': publishableKey,
        'Authorization': 'Bearer ${session.accessToken}',
      },
      retryEnabled: false,
      requestTimeout: const Duration(seconds: 10),
    );
  }

  @override
  Future<CloudProgressSnapshot?> read() async {
    final request = await _request();
    try {
      // Poll only a small revision header. Do not download the entire 28-day
      // history every 30 seconds when nothing changed on another device.
      final header = await request
          .from('youwell_progress')
          .select('revision,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
      if (header == null) {
        _lastSnapshot = null;
        return null;
      }
      if (header['revision'] == _lastSnapshot?.revision) return _lastSnapshot;
      final row = await request
          .from('youwell_progress')
          .select('revision,payload,updated_at')
          .eq('user_id', userId)
          .maybeSingle();
      _lastSnapshot = row == null ? null : CloudProgressSnapshot.fromJson(row);
      return _lastSnapshot;
    } finally {
      await request.dispose();
    }
  }

  @override
  Future<ProgressSaveResult> save(
    JsonMap payload, {
    required int expectedRevision,
  }) async {
    final request = await _request();
    try {
      final row =
          await request.rpc(
                'save_youwell_progress',
                params: {
                  'p_payload': payload,
                  'p_expected_revision': expectedRevision,
                },
              )
              as Map;
      final snapshot = row['snapshot'];
      _lastSnapshot = snapshot is Map && snapshot['revision'] is num
          ? CloudProgressSnapshot.fromJson(snapshot)
          : null;
      return ProgressSaveResult(
        saved: row['saved'] == true,
        snapshot: _lastSnapshot,
      );
    } finally {
      await request.dispose();
    }
  }
}
