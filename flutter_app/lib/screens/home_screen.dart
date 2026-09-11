import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models.dart';
import '../services/history_service.dart';
import '../services/prediction_service.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.onSignOut});
  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final weight = TextEditingController(text: '1');
  String unit = 'kg'; // 'kg' | 'g'
  bool busy = false;
  String? error;
  PredictionResponse? response;
  late final HistoryService history;

  @override
  void initState() {
    super.initState();
    try {
      history = HistoryService(Supabase.instance.client);
    } catch (_) {
      history = HistoryService(SupabaseClient('https://mock.supabase.co', 'mock'));
    }
  }

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  void _switchUnit(String newUnit) {
    if (unit == newUnit) return;
    final val = double.tryParse(weight.text);
    setState(() {
      unit = newUnit;
      if (val != null && val > 0) {
        if (newUnit == 'g') {
          weight.text = (val * 1000).toStringAsFixed(0);
        } else {
          weight.text = (val / 1000).toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> runPrediction() async {
    final value = double.tryParse(weight.text);
    if (value == null || value <= 0) {
      setState(() => error = 'Please enter a valid weight greater than zero.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final weightG = unit == 'kg' ? value * 1000 : value;
      final result = await PredictionService().predict(
        weightG: weightG,
        userId: widget.user.id,
        username: widget.user.username,
      );
      if (mounted) setState(() => response = result);
    } catch (e) {
      if (mounted) setState(() => error = 'Prediction error: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Prediction History'),
          ),
          body: HistoryScreen(user: widget.user, service: history),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalamansiApp.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWebHeader(),
                const SizedBox(height: 16),
                _buildInputCard(),
                const SizedBox(height: 16),
                if (response == null) _buildEmptyPlaceholder() else _buildResultsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Universal Navigation Header matching Web
  Widget _buildWebHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x0a000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: CalamansiApp.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('🍋', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Calamansi Yield Predictor',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: CalamansiApp.textMain),
                  ),
                  Text(
                    'Enter weight to run all 3 regression models',
                    style: TextStyle(fontSize: 11, color: CalamansiApp.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.history_rounded, size: 20, color: CalamansiApp.textMuted),
                tooltip: 'History Logs',
                onPressed: _openHistory,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CalamansiApp.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.user.role.toUpperCase(),
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CalamansiApp.primaryDark),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xffdc2626)),
                tooltip: 'Sign out',
                onPressed: widget.onSignOut,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 1. Estimate Yield Input Card
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estimate Your Yield',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your total calamansi batch weight. All three regression models will run together.',
            style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Calamansi Weight',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
              ),
              // Unit toggle buttons
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: CalamansiApp.bgSubtle,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CalamansiApp.border),
                ),
                child: Row(
                  children: [
                    _unitBtn('kg', unit == 'kg', () => _switchUnit('kg')),
                    _unitBtn('g', unit == 'g', () => _switchUnit('g')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => runPrediction(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: unit == 'kg' ? 'e.g. 1 (for 1 kg)' : 'e.g. 1000 (for 1000g)',
              suffixText: unit,
              suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: CalamansiApp.primaryDark),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xffdc2626), fontSize: 12)),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: busy ? null : runPrediction,
              style: FilledButton.styleFrom(
                backgroundColor: CalamansiApp.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('⚡', style: TextStyle(fontSize: 16)),
              label: Text(
                busy ? 'Running models...' : 'Run all 3 models',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitBtn(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: active ? CalamansiApp.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : CalamansiApp.textMuted,
          ),
        ),
      ),
    );
  }

  // 2. Placeholder Before Calculation
  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Column(
        children: const [
          Text('📊', style: TextStyle(fontSize: 34)),
          SizedBox(height: 10),
          Text(
            'Ready to predict.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CalamansiApp.textMain),
          ),
          SizedBox(height: 4),
          Text(
            'Enter your calamansi batch weight above and tap "Run all 3 models".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
          ),
        ],
      ),
    );
  }

  // 3. Results Container (3 Models Side by Side / Stacked)
  Widget _buildResultsCard() {
    final slr = response!.results.firstWhere(
      (r) => r.algorithm.contains('Simple Linear'),
      orElse: () => response!.results.first,
    );
    final mlr = response!.results.firstWhere(
      (r) => r.algorithm.contains('Multiple Linear'),
      orElse: () => response!.results[1],
    );
    final poly = response!.results.firstWhere(
      (r) => r.algorithm.contains('Polynomial'),
      orElse: () => response!.results.last,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Prediction Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CalamansiApp.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🏷️ ${response!.sizeLabel} • ~${response!.estimatedCalamansiCount} calamansi',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.primaryDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Results from all three models evaluated in the Leyte Normal University research study:',
            style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
          ),
          const SizedBox(height: 18),

          // 1. Simple Linear Regression Card
          _modelCard(
            title: 'Simple Linear Regression',
            juiceMl: slr.juiceMl,
            isBest: false,
            inputFeature: 'Weight only',
            r2: '0.7099',
            mae: '0.5294 ml',
          ),
          const SizedBox(height: 12),

          // 2. Multiple Linear Regression Card
          _modelCard(
            title: 'Multiple Linear Regression',
            juiceMl: mlr.juiceMl,
            isBest: false,
            inputFeature: 'Weight + Size',
            r2: '0.7100',
            mae: '0.5292 ml',
          ),
          const SizedBox(height: 12),

          // 3. Polynomial Regression Card (★ Best)
          _modelCard(
            title: 'Polynomial Regression (d=2)',
            juiceMl: poly.juiceMl,
            isBest: true,
            inputFeature: 'Weight, Size, W², W·S, S²',
            r2: '0.7102',
            mae: '0.5279 ml',
          ),
        ],
      ),
    );
  }

  Widget _modelCard({
    required String title,
    required double juiceMl,
    required bool isBest,
    required String inputFeature,
    required String r2,
    required String mae,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isBest ? CalamansiApp.primarySoft : CalamansiApp.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBest ? CalamansiApp.primary : CalamansiApp.border,
          width: isBest ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isBest ? CalamansiApp.primary : CalamansiApp.textMain,
                  ),
                ),
              ),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: CalamansiApp.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '★ Best',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${juiceMl.toStringAsFixed(2)} ml',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: CalamansiApp.primary,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '${(juiceMl / 1000).toStringAsFixed(4)} L',
            style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: CalamansiApp.border),
          const SizedBox(height: 10),
          _metaRow('Input:', inputFeature, false),
          const SizedBox(height: 4),
          _metaRow('R² Score:', r2, isBest),
          const SizedBox(height: 4),
          _metaRow('Test MAE:', mae, isBest),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String val, bool highlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
        Text(
          val,
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            color: highlight ? CalamansiApp.primary : CalamansiApp.textMain,
          ),
        ),
      ],
    );
  }
}
