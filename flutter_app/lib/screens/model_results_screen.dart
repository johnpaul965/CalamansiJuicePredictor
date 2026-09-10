import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';

class ModelResultsScreen extends StatefulWidget {
  const ModelResultsScreen({super.key});

  @override
  State<ModelResultsScreen> createState() => _ModelResultsScreenState();
}

class _ModelResultsScreenState extends State<ModelResultsScreen> {
  Map<String, dynamic>? state;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final row = await Supabase.instance.client
          .from('model_state')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (mounted) setState(() { state = row; loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = 'Could not load model data.'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (loading) {
      return const Center(child: CircularProgressIndicator(color: CalamansiApp.primary));
    }

    if (error != null || state == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xffFFF3D6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.warning_amber_rounded, size: 32, color: CalamansiApp.accent),
            ),
            const SizedBox(height: 16),
            Text(error ?? 'No trained model yet.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() { loading = true; error = null; });
                _loadState();
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final rawMetrics = state!['metrics'] as Map<String, dynamic>;
    final best = state!['best_model'] as String;
    final coefs = state!['coefficients'] as Map<String, dynamic>;
    final totalRows = state!['dataset_rows'] as int;
    final trainSamples = state!['training_samples'] as int;
    final testSamples = state!['test_samples'] as int;
    final sizeDist = state!['size_dist'] as Map<String, dynamic>;
    final updatedAt = (state!['updated_at'] as String).split('T').first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      children: [
        Text('Model Results', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.schedule_rounded, size: 14, color: CalamansiApp.textMuted),
            const SizedBox(width: 4),
            Text('Last trained: $updatedAt', style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
          ],
        ),
        const SizedBox(height: 24),

        _sectionTitle('Dataset Summary'),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard('Total Samples', '$totalRows'),
            const SizedBox(width: 10),
            _statCard('Training', '$trainSamples'),
            const SizedBox(width: 10),
            _statCard('Test', '$testSamples'),
          ],
        ),
        const SizedBox(height: 28),

        _sectionTitle('Algorithm Performance'),
        const SizedBox(height: 12),
        ...rawMetrics.entries.map((entry) {
          final isBest = entry.key == best;
          final m = entry.value as Map<String, dynamic>;
          final r2 = (m['r2'] as num).toDouble();
          final mae = (m['mae'] as num).toDouble();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              color: isBest ? const Color(0xffD6F0E3) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: isBest ? CalamansiApp.primaryDark : CalamansiApp.textDark,
                            ),
                          ),
                        ),
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: CalamansiApp.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Best', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _metricChip('R\u00b2', r2.toStringAsFixed(4)),
                        const SizedBox(width: 10),
                        _metricChip('MAE', '${mae.toStringAsFixed(4)} ml'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: r2.clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: const Color(0xffEDF3EE),
                        color: CalamansiApp.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('R\u00b2 Score (higher = better)', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 28),

        _sectionTitle('Size Distribution'),
        const SizedBox(height: 12),
        ...sizeDist.entries.map((entry) {
          final total = sizeDist.values.fold<int>(0, (a, b) => a + (b as int));
          final count = entry.value as int;
          final fraction = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 18,
                      backgroundColor: const Color(0xffEDF3EE),
                      color: CalamansiApp.primaryLight,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 50,
                  child: Text('$count', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CalamansiApp.primary)),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),

        _sectionTitle('Learned Coefficients'),
        const SizedBox(height: 14),

        _coefCard('Simple Linear Regression',
            'Juice = Weight \u00d7 ${(coefs['simple'] as Map)['weight']} + ${(coefs['simple'] as Map)['intercept']}', [
          {'feature': 'Weight (g)', 'coef': '+${(coefs['simple'] as Map)['weight']}'},
          {'feature': 'Intercept', 'coef': '${(coefs['simple'] as Map)['intercept']}'},
        ]),
        const SizedBox(height: 14),

        _coefCard('Multiple Linear Regression',
            'Juice = Weight \u00d7 ${(coefs['multiple'] as Map)['weight']} + Size \u00d7 ${(coefs['multiple'] as Map)['size']} + ${(coefs['multiple'] as Map)['intercept']}', [
          {'feature': 'Weight (g)', 'coef': '+${(coefs['multiple'] as Map)['weight']}'},
          {'feature': 'Size (1\u20133)', 'coef': '+${(coefs['multiple'] as Map)['size']}'},
          {'feature': 'Intercept', 'coef': '${(coefs['multiple'] as Map)['intercept']}'},
        ]),
        const SizedBox(height: 14),

        _polyCoefCard(coefs['poly'] as Map<String, dynamic>),
        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [CalamansiApp.primary, CalamansiApp.primaryDark],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: CalamansiApp.accent, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Best Performing: $best',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'R\u00b2 = ${(rawMetrics[best] as Map?)?['r2']} \u2014 this model explains '
                '${(((rawMetrics[best] as Map?)?['r2'] as num?)?.toDouble() ?? 0) * 100}.toStringAsFixed(1)}% of juice yield variation '
                'using only Weight and Size as inputs.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Model: Least-squares Linear Regression (trained in cloud)\n'
          'Dataset: $totalRows real calamansi samples\n'
          'Features: Weight (g), Size (1\u20133)',
          style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted, height: 1.6),
        ),
      ],
    );
  }

  Widget _polyCoefCard(Map<String, dynamic> poly) {
    final featNames = (poly['feat_names'] as List?)?.cast<String>() ?? ['Weight', 'Size', 'Weight^2', 'Weight Size', 'Size^2'];
    final polyCoefs = poly['coefs'] as List? ?? [];
    final intercept = poly['intercept'];
    final rows = <Map<String, String>>[];
    for (int i = 0; i < featNames.length; i++) {
      rows.add({'feature': featNames[i], 'coef': '${polyCoefs[i]}'});
    }
    rows.add({'feature': 'Intercept', 'coef': '$intercept'});
    return _coefCard('Polynomial Regression (d=2)',
        'Features: Weight, Size, Weight\u00b2, Weight\u00d7Size, Size\u00b2', rows);
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CalamansiApp.textDark));
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CalamansiApp.primary)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xffEDF3EE),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CalamansiApp.textDark)),
        ],
      ),
    );
  }

  Widget _coefCard(String title, String formula, List<Map<String, String>> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CalamansiApp.textDark)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xffEDF3EE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: CalamansiApp.textDark, height: 1.5)),
            ),
            const SizedBox(height: 14),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row['feature']!, style: const TextStyle(fontSize: 13, color: CalamansiApp.textMuted)),
                      Text(row['coef']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: CalamansiApp.primary)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
