import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryService {
  HistoryService(this.client);
  final SupabaseClient client;

  Future<List<Map<String, dynamic>>> forUser(String userId) async {
    try {
      final rows = await client
          .from('predictions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 2));
      if (rows.isNotEmpty) return List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    // Fallback to local logs
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_prediction_logs');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return List<Map<String, dynamic>>.from(decoded);
    }

    return [
      {
        'id': 'demo-1',
        'created_at': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
        'weight_g': 1000.0,
        'algorithm': 'Polynomial Regression (d=2)',
        'predicted_juice': 404.60,
      },
    ];
  }

  Future<List<Map<String, dynamic>>> all() async {
    try {
      final rows = await client
          .from('predictions')
          .select()
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 2));
      if (rows.isNotEmpty) return List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_prediction_logs');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [];
  }

  Future<void> delete(String id) async {
    try {
      await client.from('predictions').delete().eq('id', id);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_prediction_logs');
    if (raw != null) {
      List<dynamic> list = jsonDecode(raw);
      list.removeWhere((item) => item['id'] == id);
      await prefs.setString('local_prediction_logs', jsonEncode(list));
    }
  }
}
