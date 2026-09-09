class AppUser {
  const AppUser({required this.id, required this.username, required this.role});

  final String id;
  final String username;
  final String role;

  bool get isAdmin => role == 'admin';

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as String,
        username: map['username'] as String,
        role: map['role'] as String,
      );
}

class PredictionResult {
  const PredictionResult({required this.algorithm, required this.juiceMl});

  final String algorithm;
  final double juiceMl;

  factory PredictionResult.fromMap(Map<String, dynamic> map) => PredictionResult(
        algorithm: map['algorithm'] as String,
        juiceMl: (map['predicted_juice'] as num).toDouble(),
      );
}
