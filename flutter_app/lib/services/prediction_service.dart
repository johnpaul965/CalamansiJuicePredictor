import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models.dart';

class PredictionResponse {
  const PredictionResponse({required this.results, required this.sizeLabel});
  final List<PredictionResult> results;
  final String sizeLabel;
}

class PredictionService {
  Future<PredictionResponse> predict({
    required double weightG,
    required String userId,
    required String username,
  }) async {
    final response = await http.post(
      Uri.parse(predictFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'weight_g': weightG,
        'user_id': userId,
        'username': username,
        'save': true,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['error'] ?? 'Prediction failed.');
    }
    return PredictionResponse(
      results: (body['results'] as List)
          .map((item) => PredictionResult.fromMap(item as Map<String, dynamic>))
          .toList(),
      sizeLabel: body['size_label'] as String,
    );
  }
}
