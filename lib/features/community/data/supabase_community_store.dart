import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/community_store.dart';
import 'community_photo.dart';
import 'package:youwell/features/auth/data/fresh_session.dart';

/// Community through the phase 3/5 RPCs; tables are not exposed directly.
/// Photos sit in the private `community` bucket and are shown through
/// short-lived signed links.
class SupabaseCommunityStore implements CommunityStore {
  SupabaseCommunityStore({
    required this.client,
    required this.userId,
    required this.url,
    required this.publishableKey,
  });
  final SupabaseClient client;
  final String userId, url, publishableKey;

  static const bucket = 'community';

  @override
  bool get shared => true;

  @override
  bool get supportsPhotos => true;

  Future<Session> _session() async {
    try {
      return await freshSession(client, userId);
    } catch (_) {
      throw const CommunityException(
        'Sesi login perlu diperbarui. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  // As in progress sync: bind each request to this account's JWT, so an
  // account switch can never send A's action as B.
  Future<T> _call<T>(String function, [Map<String, dynamic>? params]) async {
    final session = await _session();
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
    '22023' when error.message.contains('Photo') =>
      'Foto belum terunggah. Coba kirim lagi.',
    // The app calls submit_youwell_post(text, text) from the phase 5
    // migration; an older server only has the one-argument version.
    'PGRST202' || '42883' when error.message.contains('admin_delete') =>
      'Server belum mendukung hapus post oleh admin. Jalankan migration '
          'Supabase tahap 7.',
    'PGRST202' || '42883' =>
      'Server Community belum mendukung foto. Admin perlu menjalankan '
          'migration Supabase terbaru.',
    '22023' => 'Tulis 3–$maxCommunityPostLength karakter, atau tambahkan foto.',
    _ => 'Community belum terhubung. Periksa koneksi lalu coba lagi.',
  };

  /// Names the server's reason, so a setup gap is not mistaken for a
  /// connection problem.
  static String storageMessage(StorageException error) {
    final text = '${error.message} ${error.error ?? ''}'.toLowerCase();
    return switch (error.statusCode) {
      _ when text.contains('bucket not found') =>
        'Penyimpanan foto belum disiapkan di server (bucket "community" '
            'belum ada). Admin perlu menjalankan migration Supabase tahap 5.',
      '413' => 'Foto terlalu besar untuk server. Coba foto lain.',
      '415' => 'Format foto ditolak server. Coba foto lain.',
      '401' => 'Sesi login berakhir. Keluar lalu masuk lagi.',
      '400' || '403'
          when text.contains('row-level security') ||
              text.contains('unauthorized') =>
        'Server belum mengizinkan unggah foto. Admin perlu menjalankan '
            'migration Supabase tahap 5.',
      _ =>
        'Foto belum bisa diunggah (${error.statusCode ?? 'tanpa kode'}: '
            '${error.message}).',
    };
  }

  /// Adds a signed link to every post with a photo. A failed link only
  /// hides that photo; the posts still load.
  Future<List<CommunityPost>> _withImages(List<CommunityPost> posts) async {
    final paths = [
      for (final post in posts)
        if (post.imagePath case final path?) path,
    ];
    if (paths.isEmpty) return posts;
    try {
      await _session();
      final links = await client.storage
          .from(bucket)
          .createSignedUrlsResult(paths, 3600);
      final byPath = {
        for (final link in links.whereType<SignedUrlSuccess>())
          link.path: link.signedUrl,
      };
      return [
        for (final post in posts) post.withImageUrl(byPath[post.imagePath]),
      ];
    } catch (_) {
      return posts;
    }
  }

  @override
  Future<List<CommunityPost>> feed() async {
    final rows = await _call<List>('youwell_community_feed');
    return _withImages([
      for (final row in rows.whereType<Map>()) CommunityPost.fromJson(row),
    ]);
  }

  @override
  Future<void> submit(String text, {Uint8List? photo}) async {
    String? path;
    if (photo != null) {
      await _session();
      path = '$userId/${randomUuid()}.png';
      try {
        await client.storage
            .from(bucket)
            .uploadBinary(
              path,
              photo,
              fileOptions: const FileOptions(contentType: 'image/png'),
            );
      } on StorageException catch (error) {
        throw CommunityException(storageMessage(error));
      } catch (_) {
        throw const CommunityException(
          'Foto belum bisa diunggah. Periksa koneksi lalu coba lagi.',
        );
      }
    }
    try {
      await _call<Object?>('submit_youwell_post', {
        'p_body': text.trim(),
        'p_image_path': path,
      });
    } catch (_) {
      // Do not leave an orphan photo behind a post that was never created.
      if (path != null) await _remove(path);
      rethrow;
    }
  }

  Future<void> _remove(String path) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Best effort; the file stays private to its author and admins.
    }
  }

  @override
  Future<void> react(String postId, String? reaction) => _call<Object?>(
    'react_youwell_post',
    {'p_post': postId, 'p_reaction': reaction},
  );

  @override
  Future<bool> report(String postId, String reason) async => await _call<bool>(
    'report_youwell_post',
    {'p_post': postId, 'p_reason': reason},
  );

  @override
  Future<ModerationQueue> moderationQueue() async {
    final value = await _call<Map>('youwell_moderation_queue');
    final pending = await _withImages([
      for (final row
          in ((value['pending'] ?? const []) as List).whereType<Map>())
        CommunityPost.fromJson(row),
    ]);
    final reportRows = ((value['reports'] ?? const []) as List)
        .whereType<Map>()
        .toList();
    final reported = await _withImages([
      for (final row in reportRows)
        CommunityPost.fromJson({...row, 'id': row['post_id']}),
    ]);
    final published = await _withImages([
      for (final row
          in ((value['published'] ?? const []) as List).whereType<Map>())
        CommunityPost.fromJson(row),
    ]);
    return ModerationQueue(
      pending: pending,
      published: published,
      reports: [
        for (final (index, row) in reportRows.indexed)
          CommunityReport(
            id: row['id'].toString(),
            reason: row['reason'].toString(),
            post: reported[index],
          ),
      ],
    );
  }

  @override
  Future<void> moderate(String postId, {required bool approve}) async {
    final photo = await _call<Object?>('moderate_youwell_post', {
      'p_post': postId,
      'p_status': approve ? 'approved' : 'rejected',
      'p_note': approve ? null : 'Tidak sesuai panduan komunitas.',
    });
    // A rejected post's photo is deleted, not just hidden.
    if (photo is String) await _remove(photo);
  }

  @override
  Future<void> resolveReport(String reportId) =>
      _call<Object?>('resolve_youwell_report', {'p_report': reportId});

  @override
  Future<void> deletePost(String postId) async {
    final photo = await _call<Object?>('delete_youwell_post', {
      'p_post': postId,
    });
    if (photo is String) await _remove(photo);
  }

  @override
  Future<void> adminDeletePost(String postId) async {
    final photo = await _call<Object?>('admin_delete_youwell_post', {
      'p_post': postId,
    });
    if (photo is String) await _remove(photo);
  }
}
