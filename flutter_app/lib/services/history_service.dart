import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryService {
  HistoryService(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> forUser(String userId) async {
    final rows = await client
        .from('predictions')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> all() async {
    final rows = await client
        .from('predictions')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> delete(String id) async {
    await client.from('predictions').delete().eq('id', id);
  }
}
