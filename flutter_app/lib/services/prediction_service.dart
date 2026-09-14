import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class PredictionResponse {
  const PredictionResponse({
    required this.results,
    required this.sizeLabel,
    required this.estimatedCalamansiCount,
    required this.totalWeightG,
  });

  final List<PredictionResult> results;
  final String sizeLabel;
  final int estimatedCalamansiCount;
  final double totalWeightG;
}

class PredictionService {
  // Trained regression coefficients from the Tacloban City harvest research study
  static const double simpleWeight = 0.4569;
  static const double simpleIntercept = -0.6080;

  static const double multipleWeight = 0.4580;
  static const double multipleSize = -0.0053;
  static const double multipleIntercept = -0.6108;

  static const double polyIntercept = -0.5480;
  static const List<double> polyCoefs = [
    0.43568, // W
    0.086517, // S
    -0.003075, // W^2
    0.047385, // W*S
    -0.164087, // S^2
  ];

  static int getCalamansiSizeCode(double weightG) {
    if (weightG <= 10.0) return 1; // Small
    if (weightG <= 14.0) return 2; // Medium
    return 3; // Large
  }

  static double predictSimple(double w) {
    final val = simpleWeight * w + simpleIntercept;
    return val > 0 ? val : 0.0;
  }

  static double predictMultiple(double w, int s) {
    final val = multipleWeight * w + multipleSize * s + multipleIntercept;
    return val > 0 ? val : 0.0;
  }

  static double predictPoly(double w, int s) {
    final features = [w, s.toDouble(), w * w, w * s, s * s.toDouble()];
    double val = polyIntercept;
    for (int i = 0; i < features.length; i++) {
      val += polyCoefs[i] * features[i];
    }
    return val > 0 ? val : 0.0;
  }

  Future<PredictionResponse> predict({
    required double weightG,
    required String userId,
    required String username,
  }) async {
    // Exact research calculation engine identical to web/app.js
    // Calamansi fruits are evaluated on a per-unit basis using the representative
    // medium sample weight from the Leyte Normal University dataset (12.0g).
    const representativeUnitWeight = 12.0; // Average weight for medium calamansi
    final sizeCode = getCalamansiSizeCode(representativeUnitWeight); // 2: Medium
    final count = (weightG / representativeUnitWeight).round();
    final calamansiCountDouble = weightG / representativeUnitWeight;

    final slrJuice = predictSimple(representativeUnitWeight);
    final slrTotalMl = calamansiCountDouble * slrJuice;

    final mlrJuice = predictMultiple(representativeUnitWeight, sizeCode);
    final mlrTotalMl = calamansiCountDouble * mlrJuice;

    final polyJuice = predictPoly(representativeUnitWeight, sizeCode);
    final polyTotalMl = calamansiCountDouble * polyJuice;

    final results = [
      PredictionResult(algorithm: 'Simple Linear Regression', juiceMl: slrTotalMl),
      PredictionResult(algorithm: 'Multiple Linear Regression', juiceMl: mlrTotalMl),
      PredictionResult(algorithm: 'Polynomial Regression (d=2)', juiceMl: polyTotalMl),
    ];

    const sizeLabel = 'Medium Calamansi (10–14g)';
    await _saveLocalLog(username, weightG, sizeLabel, results);

    // Save directly to Supabase SQL predictions table
    try {
      final polyResult = results.firstWhere(
        (r) => r.algorithm.contains('Polynomial'),
        orElse: () => results.last,
      );
      await Supabase.instance.client.from('predictions').insert({
        'user_id': userId,
        'username': username,
        'weight_g': weightG,
        'algorithm': polyResult.algorithm,
        'predicted_juice': polyResult.juiceMl,
        'size_label': sizeLabel,
      });
    } catch (_) {}

    return PredictionResponse(
      results: results,
      sizeLabel: sizeLabel,
      estimatedCalamansiCount: count,
      totalWeightG: weightG,
    );
  }

  Future<void> _saveLocalLog(
    String username,
    double weightG,
    String sizeLabel,
    List<PredictionResult> results,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('local_prediction_logs');
      List<dynamic> list = [];
      if (raw != null) {
        list = jsonDecode(raw) as List<dynamic>;
      }

      String slr = '0.00 ml';
      String mlr = '0.00 ml';
      String poly = '0.00 ml';

      for (final r in results) {
        if (r.algorithm.contains('Simple Linear')) slr = '${r.juiceMl.toStringAsFixed(2)} ml';
        if (r.algorithm.contains('Multiple Linear')) mlr = '${r.juiceMl.toStringAsFixed(2)} ml';
        if (r.algorithm.contains('Polynomial')) poly = '${r.juiceMl.toStringAsFixed(2)} ml';
      }

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      list.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'date': dateStr,
        'user': username,
        'weight_g': weightG,
        'weight': weightG >= 1000 ? '${(weightG / 1000).toStringAsFixed(2)} kg (${weightG.toStringAsFixed(0)}g)' : '${weightG.toStringAsFixed(0)} g',
        'size': sizeLabel,
        'slr': slr,
        'mlr': mlr,
        'poly': poly,
        'created_at': now.toIso8601String(),
      });

      if (list.length > 50) list = list.sublist(0, 50);
      await prefs.setString('local_prediction_logs', jsonEncode(list));
    } catch (_) {}
  }
}
