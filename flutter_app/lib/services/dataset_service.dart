import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class DatasetRow {
  const DatasetRow({required this.id, required this.weight, required this.size, required this.juice, required this.createdAt});
  final String id;
  final double weight;
  final int size;
  final double juice;
  final String createdAt;

  String get sizeLabel => size == 1 ? 'Small' : size == 2 ? 'Medium' : 'Large';

  factory DatasetRow.fromMap(Map<String, dynamic> map) => DatasetRow(
        id: map['id'] as String,
        weight: (map['weight'] as num).toDouble(),
        size: (map['size'] as num).toInt(),
        juice: (map['juice'] as num).toDouble(),
        createdAt: (map['created_at'] as String?) ?? '',
      );
}

class RetrainResult {
  const RetrainResult({required this.success, required this.message, required this.metrics, required this.datasetRows, required this.bestModel});
  final bool success;
  final String message;
  final Map<String, dynamic> metrics;
  final int datasetRows;
  final String bestModel;
}

class DatasetService {
  DatasetService(this.client);
  final SupabaseClient client;

  Future<List<DatasetRow>> fetchAll() async {
    final rows = await client
        .from('dataset_rows')
        .select('id, weight, size, juice, created_at')
        .order('created_at', ascending: false);
    return (rows as List).map((row) => DatasetRow.fromMap(row as Map<String, dynamic>)).toList();
  }

  Future<void> add(double weight, int size, double juice) async {
    await client.from('dataset_rows').insert({
      'weight': weight,
      'size': size,
      'juice': juice,
    });
    await retrain();
  }

  Future<void> deleteRow(String id) async {
    await client.from('dataset_rows').delete().eq('id', id);
  }

  Future<RetrainResult> retrain() async {
    final response = await http.post(
      Uri.parse(retrainFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Retrain failed.');
    }
    return RetrainResult(
      success: body['success'] as bool? ?? false,
      message: body['message'] as String? ?? '',
      metrics: body['metrics'] as Map<String, dynamic>? ?? {},
      datasetRows: (body['dataset_rows'] as num?)?.toInt() ?? 0,
      bestModel: body['best_model'] as String? ?? '',
    );
  }
}
