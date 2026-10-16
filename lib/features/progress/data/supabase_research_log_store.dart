import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:youwell/core/types/json_map.dart';
import '../domain/research_log_store.dart';

class SupabaseResearchLogStore implements ResearchLogStore {
  SupabaseResearchLogStore(this.client);
  final SupabaseClient client;

  @override
  Future<void> submit({
    required String participantCode,
    required bool weekComplete,
    required JsonMap summary,
  }) async {
    await client.rpc(
      'submit_youwell_research_log',
      params: {
        'p_code': participantCode,
        'p_week_complete': weekComplete,
        'p_summary': summary,
      },
    );
  }

  @override
  Future<List<JsonMap>> exportLatest() async {
    final rows = await client.rpc('youwell_research_export') as List;
    return [
      for (final row in rows.whereType<Map>()) Map<String, dynamic>.from(row),
    ];
  }
}
