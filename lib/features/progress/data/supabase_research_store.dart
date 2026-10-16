import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/types/json_map.dart';
import '../domain/research_store.dart';

class SupabaseResearchStore implements ResearchStore {
  SupabaseResearchStore(this.client);
  final SupabaseClient client;

  @override
  Future<List<JsonMap>> progressOverview() async {
    final rows = await client.rpc('youwell_admin_progress_overview') as List;
    return [
      for (final row in rows.whereType<Map>()) Map<String, dynamic>.from(row),
    ];
  }

  @override
  Future<void> setParticipantCode(String account, String? code) async {
    try {
      await client.rpc(
        'set_youwell_participant_code',
        params: {'p_account': account, 'p_code': code},
      );
    } on PostgrestException catch (error) {
      throw StateError(
        error.code == '23505'
            ? 'Kode $code sudah dipakai akun lain.'
            : 'Kode belum tersimpan. Periksa koneksi dan migration tahap 6.',
      );
    }
  }
}
