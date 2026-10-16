import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/community_store.dart';

/// Community through the phase 3 RPCs only; tables are not exposed directly.
class SupabaseCommunityStore implements CommunityStore {
  SupabaseCommunityStore({
    required this.client,
    required this.userId,
    required this.url,
    required this.publishableKey,
  });
  final SupabaseClient client;
  final String userId, url, publishableKey;

  @override
  bool get shared => true;

  // As in progress sync: bind each request to this account's JWT, so an
  // account switch can never send A's action as B.
  Future<T> _call<T>(String function, [Map<String, dynamic>? params]) async {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != userId) {
      throw const CommunityException('Sesi akun berubah. Buka ulang Community.');
    }
    final request = PostgrestClient(
      '$url/rest/v1',
      headers: {
        'apikey': publishableKey,
        'Authorization': 'Bearer ${session.accessToken}',
      },
      retryEnabled: false,
      requestTimeout: const Duration(seconds: 10),
    );
    try {
      return await request.rpc(function, params: params) as T;
    } on PostgrestException catch (error) {
      throw CommunityException(_message(error));
    } catch (_) {
      throw const CommunityException(
        'Community belum terhubung. Periksa koneksi lalu coba lagi.',
      );
    } finally {
      await request.dispose();
    }
  }

  static String _message(PostgrestException error) => switch (error.code) {
    'P0002' when error.message.contains('Profile') =>
      'Progres akunmu belum tersinkron. Tunggu sebentar lalu kirim lagi.',
    'P0002' => 'Post ini sudah tidak tersedia.',
    '54000' => 'Masih ada 3 post menunggu review. Tunggu moderator dulu ya.',
    '42501' => 'Akses ini butuh akun admin dengan verifikasi dua langkah.',
    '22023' => 'Tulis 3–$maxCommunityPostLength karakter.',
    _ => 'Community belum terhubung. Periksa koneksi lalu coba lagi.',
  };

  @override
  Future<List<CommunityPost>> feed() async {
    final rows = await _call<List>('youwell_community_feed');
    return [for (final row in rows.whereType<Map>()) CommunityPost.fromJson(row)];
  }

  @override
  Future<void> submit(String text) =>
      _call<Object?>('submit_youwell_post', {'p_body': text.trim()});

  @override
  Future<void> react(String postId, String? reaction) => _call<Object?>(
    'react_youwell_post',
    {'p_post': postId, 'p_reaction': reaction},
  );

  @override
  Future<bool> report(String postId, String reason) async =>
      await _call<bool>('report_youwell_post', {
        'p_post': postId,
        'p_reason': reason,
      });

  @override
  Future<ModerationQueue> moderationQueue() async {
    final value = await _call<Map>('youwell_moderation_queue');
    return ModerationQueue(
      pending: [
        for (final row in ((value['pending'] ?? const []) as List)
            .whereType<Map>())
          CommunityPost.fromJson(row),
      ],
      reports: [
        for (final row in ((value['reports'] ?? const []) as List)
            .whereType<Map>())
          CommunityReport(
            id: row['id'].toString(),
            reason: row['reason'].toString(),
            post: CommunityPost.fromJson({...row, 'id': row['post_id']}),
          ),
      ],
    );
  }

  @override
  Future<void> moderate(String postId, {required bool approve}) =>
      _call<Object?>('moderate_youwell_post', {
        'p_post': postId,
        'p_status': approve ? 'approved' : 'rejected',
        'p_note': approve ? null : 'Tidak sesuai panduan komunitas.',
      });

  @override
  Future<void> resolveReport(String reportId) =>
      _call<Object?>('resolve_youwell_report', {'p_report': reportId});
}
