import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null || state == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber, size: 48),
            const SizedBox(height: 12),
            Text(error ?? 'No trained model yet. Add data to begin training.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                setState(() { loading = true; error = null; });
                _loadState();
              },
              icon: const Icon(Icons.refresh),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        Text('Model Results',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Last trained: $updatedAt', style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
        const SizedBox(height: 24),

        _sectionTitle(theme, 'Dataset Summary'),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard(colors, 'Total Samples', '$totalRows'),
            const SizedBox(width: 10),
            _statCard(colors, 'Training', '$trainSamples'),
            const SizedBox(width: 10),
            _statCard(colors, 'Test', '$testSamples'),
          ],
        ),
        const SizedBox(height: 28),

        _sectionTitle(theme, 'Algorithm Performance'),
        const SizedBox(height: 10),
        ...rawMetrics.entries.map((entry) {
          final isBest = entry.key == best;
          final m = entry.value as Map<String, dynamic>;
          final r2 = (m['r2'] as num).toDouble();
          final mae = (m['mae'] as num).toDouble();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            color: isBest ? colors.primaryContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.key,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isBest ? colors.primary : null)),
                      ),
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Best',
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _metricChip('R\u00b2', r2.toStringAsFixed(4), colors),
                      const SizedBox(width: 10),
                      _metricChip('MAE', '${mae.toStringAsFixed(4)} ml', colors),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: r2.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('R\u00b2 Score (higher = better)',
                      style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 28),

        _sectionTitle(theme, 'Size Distribution'),
        const SizedBox(height: 10),
        ...sizeDist.entries.map((entry) {
          final total = sizeDist.values.fold<int>(0, (a, b) => a + (b as int));
          final count = entry.value as int;
          final fraction = total > 0 ? count / total : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 70, child: Text(entry.key)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 18,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                    width: 50,
                    child: Text('$count',
                        style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          );
        }),
        const SizedBox(height: 28),

        _sectionTitle(theme, 'Learned Coefficients'),
        const SizedBox(height: 14),

        _coefCard(theme, colors, 'Simple Linear Regression',
            'Juice = Weight \u00d7 ${(coefs['simple'] as Map)['weight']} + ${(coefs['simple'] as Map)['intercept']}', [
          {'feature': 'Weight (g)', 'coef': '+${(coefs['simple'] as Map)['weight']}'},
          {'feature': 'Intercept', 'coef': '${(coefs['simple'] as Map)['intercept']}'},
        ]),
        const SizedBox(height: 14),

        _coefCard(theme, colors, 'Multiple Linear Regression',
            'Juice = Weight \u00d7 ${(coefs['multiple'] as Map)['weight']} + Size \u00d7 ${(coefs['multiple'] as Map)['size']} + ${(coefs['multiple'] as Map)['intercept']}', [
          {'feature': 'Weight (g)', 'coef': '+${(coefs['multiple'] as Map)['weight']}'},
          {'feature': 'Size (1\u20133)', 'coef': '+${(coefs['multiple'] as Map)['size']}'},
          {'feature': 'Intercept', 'coef': '${(coefs['multiple'] as Map)['intercept']}'},
        ]),
        const SizedBox(height: 14),

        _polyCoefCard(theme, colors, coefs['poly'] as Map<String, dynamic>),
        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.emoji_events, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Best Performing: $best',
                      style: TextStyle(fontWeight: FontWeight.bold, color: colors.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              Text(
                'R\u00b2 = ${(rawMetrics[best] as Map?)?['r2']} \u2014 this model explains '
                '${(((rawMetrics[best] as Map?)?['r2'] as num?)?.toDouble() ?? 0) * 100}.toStringAsFixed(1)}% of juice yield variation '
                'using only Weight and Size as inputs.',
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Model: Least-squares Linear Regression (trained in cloud)\n'
          'Dataset: $totalRows real calamansi samples\n'
          'Features: Weight (g), Size (1\u20133)',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _polyCoefCard(ThemeData theme, ColorScheme colors, Map<String, dynamic> poly) {
    final featNames = (poly['feat_names'] as List?)?.cast<String>() ?? ['Weight', 'Size', 'Weight^2', 'Weight Size', 'Size^2'];
    final polyCoefs = poly['coefs'] as List? ?? [];
    final intercept = poly['intercept'];
    final rows = <Map<String, String>>[];
    for (int i = 0; i < featNames.length; i++) {
      rows.add({'feature': featNames[i], 'coef': '${polyCoefs[i]}'});
    }
    rows.add({'feature': 'Intercept', 'coef': '$intercept'});
    return _coefCard(theme, colors, 'Polynomial Regression (d=2)',
        'Features: Weight, Size, Weight\u00b2, Weight\u00d7Size, Size\u00b2', rows);
  }

  Widget _sectionTitle(ThemeData theme, String text) {
    return Text(text,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
  }

  Widget _statCard(ColorScheme colors, String label, String value) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.primary)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _coefCard(ThemeData theme, ColorScheme colors, String title, String formula, List<Map<String, String>> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(formula, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
            const SizedBox(height: 12),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row['feature']!),
                      Text(row['coef']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
