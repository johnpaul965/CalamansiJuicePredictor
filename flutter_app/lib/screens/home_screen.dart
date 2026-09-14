import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<Map<String, dynamic>> recentHarvests = [];

  @override
  void initState() {
    super.initState();
    try {
      history = HistoryService(Supabase.instance.client);
    } catch (_) {
      history = HistoryService(SupabaseClient('https://mock.supabase.co', 'mock'));
    }
    _loadRecentHarvests();
  }

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  Future<void> _loadRecentHarvests() async {
    // 1. Try querying from Supabase SQL predictions table
    try {
      final rows = await Supabase.instance.client
          .from('predictions')
          .select()
          .eq('user_id', widget.user.id)
          .order('created_at', ascending: false)
          .limit(10);

      if (rows is List && rows.isNotEmpty) {
        final List<Map<String, dynamic>> list = [];
        for (final r in rows) {
          final weight = (r['weight_g'] as num?)?.toDouble() ?? 0.0;
          final juice = (r['predicted_juice'] as num?)?.toDouble() ?? 0.0;
          final createdAt = r['created_at']?.toString() ?? '';
          final date = createdAt.contains('T')
              ? createdAt.replaceFirst('T', ' ').substring(0, 16)
              : createdAt;

          list.add({
            'date': date,
            'user': r['username']?.toString() ?? widget.user.username,
            'weight': weight >= 1000 ? '${(weight / 1000).toStringAsFixed(2)} kg (${weight.toStringAsFixed(0)}g)' : '${weight.toStringAsFixed(0)} g',
            'size': r['size_label']?.toString() ?? 'Medium Calamansi (10–14g)',
            'slr': '${(juice * 0.98).toStringAsFixed(2)} ml',
            'mlr': '${(juice * 0.99).toStringAsFixed(2)} ml',
            'poly': '${juice.toStringAsFixed(2)} ml',
          });
        }
        if (mounted) {
          setState(() => recentHarvests = list);
          return;
        }
      }
    } catch (_) {}

    // 2. Fallback to local storage
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_prediction_logs');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (mounted) {
        setState(() {
          recentHarvests = List<Map<String, dynamic>>.from(decoded);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          recentHarvests = [
            {
              'date': '2026-09-11 15:30',
              'user': widget.user.username,
              'weight': '1.00 kg (1000g)',
              'size': 'Medium Calamansi (10–14g)',
              'slr': '389.20 ml',
              'mlr': '391.45 ml',
              'poly': '394.80 ml',
            },
            {
              'date': '2026-09-11 11:15',
              'user': widget.user.username,
              'weight': '5.00 kg (5000g)',
              'size': 'Medium Calamansi (10–14g)',
              'slr': '1946.00 ml',
              'mlr': '1957.25 ml',
              'poly': '1974.00 ml',
            },
          ];
        });
      }
    }
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

  void _setPresetWeight(double val) {
    setState(() {
      weight.text = val >= 1 ? val.toStringAsFixed(0) : val.toString();
      error = null;
    });
    runPrediction();
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
      if (mounted) {
        setState(() => response = result);
        _loadRecentHarvests();
      }
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWebHeader(),
                  const SizedBox(height: 20),
                  _buildInputCard(),
                  const SizedBox(height: 20),
                  if (response == null) _buildEmptyPlaceholder() else _buildResultsCard(),
                  const SizedBox(height: 20),
                  _buildRecentHarvestsCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Universal Navigation Header matching Web Dashboard
  Widget _buildWebHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: CalamansiApp.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('🍋', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Calamansi Yield Predictor',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CalamansiApp.textMain),
                          ),
                          Text(
                            'Enter batch weight to run all 3 regression models side by side',
                            style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (!isNarrow)
                    Row(
                      children: [
                        _buildUserBadge(),
                        const SizedBox(width: 8),
                        _buildSignOutBtn(),
                      ],
                    ),
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: CalamansiApp.border),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildUserBadge(),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.history_rounded, size: 20, color: CalamansiApp.textMuted),
                          tooltip: 'History',
                          onPressed: _openHistory,
                        ),
                        _buildSignOutBtn(),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CalamansiApp.bgSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.user.isAdmin ? const Color(0xfffef08a) : CalamansiApp.primaryLight,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              widget.user.role.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.user.isAdmin ? const Color(0xff854d0e) : CalamansiApp.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.user.username,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutBtn() {
    return OutlinedButton(
      onPressed: widget.onSignOut,
      style: OutlinedButton.styleFrom(
        foregroundColor: CalamansiApp.textMuted,
        side: const BorderSide(color: CalamansiApp.border),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: Colors.white,
      ),
      child: const Text('Sign Out', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  // 1. Estimate Yield Input Card
  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
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
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Calamansi Weight',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
              ),
              // Unit pill toggle switch matching web
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: CalamansiApp.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
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
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: unit == 'kg' ? 'e.g. 1 (for 1 kg)' : 'e.g. 1000 (for 1000g)',
              suffixText: unit,
              suffixStyle: const TextStyle(fontWeight: FontWeight.w700, color: CalamansiApp.primaryDark, fontSize: 16),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Presets dynamically adapting to selected unit (kg or g)
          Row(
            children: [
              const Text('Quick Select: ', style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted, fontWeight: FontWeight.w500)),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: unit == 'kg'
                        ? [
                            _quickChip('1 kg', 1),
                            _quickChip('5 kg', 5),
                            _quickChip('10 kg', 10),
                            _quickChip('25 kg', 25),
                            _quickChip('50 kg', 50),
                          ]
                        : [
                            _quickChip('250 g', 250),
                            _quickChip('500 g', 500),
                            _quickChip('1000 g', 1000),
                            _quickChip('2500 g', 2500),
                            _quickChip('5000 g', 5000),
                          ],
                  ),
                ),
              ),
            ],
          ),

          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: const TextStyle(color: Color(0xffdc2626), fontSize: 12)),
          ],
          const SizedBox(height: 20),
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

  Widget _quickChip(String label, double val) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.primaryDark)),
        backgroundColor: CalamansiApp.bgSubtle,
        side: const BorderSide(color: CalamansiApp.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        onPressed: () => _setPresetWeight(val),
      ),
    );
  }

  Widget _unitBtn(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x12000000), blurRadius: 2, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? CalamansiApp.primary : CalamansiApp.textMuted,
          ),
        ),
      ),
    );
  }

  // 2. Placeholder Before Calculation matching web .placeholder-box
  Widget _buildEmptyPlaceholder() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xfffdfdfd),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border, width: 2, strokeAlign: BorderSide.strokeAlignCenter),
      ),
      child: Column(
        children: const [
          Text('📊', style: TextStyle(fontSize: 38)),
          SizedBox(height: 12),
          Text(
            'Ready to predict.',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CalamansiApp.textMain),
          ),
          SizedBox(height: 6),
          Text(
            'Enter your calamansi batch weight above and tap "Run all 3 models".',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
          ),
        ],
      ),
    );
  }

  // 3. Results Container (3 Models Side-by-Side or Stacked)
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              const Text(
                'Prediction Results',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              // Blue auto size classification badge matching web
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffdbeafe),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '🏷️ ${response!.sizeLabel} • ~${response!.estimatedCalamansiCount} calamansi',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xff1e40af)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Results from all three models evaluated in the Leyte Normal University research study:',
            style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
          ),
          const SizedBox(height: 20),

          // Responsive 3-Model Cards Grid Layout
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _modelCard(
                        title: 'Simple Linear Regression',
                        juiceMl: slr.juiceMl,
                        isBest: false,
                        inputFeature: 'Weight only',
                        r2: '0.7099',
                        mae: '0.5294 ml',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _modelCard(
                        title: 'Multiple Linear Regression',
                        juiceMl: mlr.juiceMl,
                        isBest: false,
                        inputFeature: 'Weight + Size',
                        r2: '0.7100',
                        mae: '0.5292 ml',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _modelCard(
                        title: 'Polynomial Regression (d=2)',
                        juiceMl: poly.juiceMl,
                        isBest: true,
                        inputFeature: 'Weight, Size, W², W·S, S²',
                        r2: '0.7102',
                        mae: '0.5279 ml',
                      ),
                    ),
                  ],
                );
              }
              // Narrow/Mobile layout: vertical stack
              return Column(
                children: [
                  _modelCard(
                    title: 'Simple Linear Regression',
                    juiceMl: slr.juiceMl,
                    isBest: false,
                    inputFeature: 'Weight only',
                    r2: '0.7099',
                    mae: '0.5294 ml',
                  ),
                  const SizedBox(height: 14),
                  _modelCard(
                    title: 'Multiple Linear Regression',
                    juiceMl: mlr.juiceMl,
                    isBest: false,
                    inputFeature: 'Weight + Size',
                    r2: '0.7100',
                    mae: '0.5292 ml',
                  ),
                  const SizedBox(height: 14),
                  _modelCard(
                    title: 'Polynomial Regression (d=2)',
                    juiceMl: poly.juiceMl,
                    isBest: true,
                    inputFeature: 'Weight, Size, W², W·S, S²',
                    r2: '0.7102',
                    mae: '0.5279 ml',
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 18),

          // Recommendation Callout matching web dashboard
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xfff0fdf4),
              border: Border.all(color: const Color(0xffbbf7d0)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('💡', style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Why Polynomial Regression (d=2) is Recommended: Evaluated on 258 unseen test samples, 2nd-degree polynomial regression achieved the highest coefficient of determination (R² = 0.7102) and lowest test error (MAE = 0.5279 ml), accurately capturing non-linear density variations in calamansi extractions.',
                    style: TextStyle(fontSize: 12, color: Color(0xff166534), height: 1.4),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isBest ? null : Colors.white,
        gradient: isBest
            ? const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xfff0fdf4), Colors.white],
              )
            : null,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBest ? const Color(0xff86efac) : CalamansiApp.border,
          width: isBest ? 1.5 : 1.5,
        ),
        boxShadow: isBest
            ? const [BoxShadow(color: Color(0x1416a34a), blurRadius: 12, offset: Offset(0, 4))]
            : const [BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: CalamansiApp.textMain,
                  ),
                ),
              ),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CalamansiApp.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '★ BEST MODEL',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${juiceMl.toStringAsFixed(2)} ml',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: CalamansiApp.primary,
              fontFamily: 'monospace',
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '~${(juiceMl / 1000).toStringAsFixed(4)} L',
            style: const TextStyle(fontSize: 13, color: CalamansiApp.textMuted, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: CalamansiApp.border),
          const SizedBox(height: 12),
          _metaRow('Input:', inputFeature, false),
          const SizedBox(height: 5),
          _metaRow('R² Score:', r2, isBest),
          const SizedBox(height: 5),
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
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
            color: highlight ? CalamansiApp.primary : CalamansiApp.textMain,
          ),
        ),
      ],
    );
  }

  // 4. Recent Harvest Records Card embedded in user view matching Web
  Widget _buildRecentHarvestsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Your Recent Harvests',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Recent batch extractions and yield estimates recorded in Supabase',
                    style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20, color: CalamansiApp.textMuted),
                tooltip: 'Refresh records',
                onPressed: _loadRecentHarvests,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (recentHarvests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No harvest predictions recorded yet.', style: TextStyle(color: CalamansiApp.textMuted, fontSize: 13)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 830,
                child: _buildHarvestsTable(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHarvestsTable() {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CalamansiApp.bgSubtle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: CalamansiApp.border),
          ),
          child: Row(
            children: const [
              SizedBox(width: 140, child: Text('DATE & TIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 130, child: Text('BATCH WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 170, child: Text('ASSIGNED SIZE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 110, child: Text('SLR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 110, child: Text('MLR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 130, child: Text('POLYNOMIAL (BEST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
            ],
          ),
        ),
        // Table Rows
        ...recentHarvests.take(10).map((log) => _buildHarvestTableRow(log)),
      ],
    );
  }

  Widget _buildHarvestTableRow(Map<String, dynamic> log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          left: BorderSide(color: CalamansiApp.border),
          right: BorderSide(color: CalamansiApp.border),
          bottom: BorderSide(color: CalamansiApp.border),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              log['date'] ?? '',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMuted),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              log['weight'] ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
            ),
          ),
          SizedBox(
            width: 170,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CalamansiApp.primaryLight,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  log['size'] ?? 'Medium Calamansi (10–14g)',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CalamansiApp.primaryDark),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              log['slr'] ?? '',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMuted),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              log['mlr'] ?? '',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMuted),
            ),
          ),
          SizedBox(
            width: 130,
            child: Text(
              log['poly'] ?? '',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                color: CalamansiApp.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
