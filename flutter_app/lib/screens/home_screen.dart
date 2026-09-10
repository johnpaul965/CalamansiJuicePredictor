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
  int tab = 0;
  final weight = TextEditingController(text: '1');
  String unit = 'kg';
  bool busy = false;
  String? error;
  PredictionResponse? response;
  late final HistoryService history;

  @override
  void initState() {
    super.initState();
    history = HistoryService(Supabase.instance.client);
  }

  @override
  void dispose() {
    weight.dispose();
    super.dispose();
  }

  Future<void> runPrediction() async {
    final value = double.tryParse(weight.text);
    if (value == null || value <= 0) {
      setState(() => error = 'Enter a weight greater than zero.');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final result = await PredictionService().predict(
        weightG: unit == 'kg' ? value * 1000 : value,
        userId: widget.user.id,
        username: widget.user.username,
      );
      if (mounted) setState(() => response = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calamansi Yield'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: tab == 0 ? _predictionBody() : HistoryScreen(user: widget.user, service: history),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate_rounded),
            label: 'Predict',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _predictionBody() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
      children: [
        Text('Estimate Your Yield', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Enter your total calamansi batch weight. All three models will run together.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        _buildInputCard(colors),
        if (error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xffFDECEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xffD8483E), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(error!, style: const TextStyle(color: Color(0xffD8483E), fontSize: 13))),
              ],
            ),
          ),
        ],
        if (response != null) ...[
          const SizedBox(height: 28),
          _buildResultsHeader(colors),
          const SizedBox(height: 14),
          ...response!.results.map((result) => _resultCard(result, colors)),
        ],
      ],
    );
  }

  Widget _buildInputCard(ColorScheme colors) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weight,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Total weight'),
                  ),
                ),
                const SizedBox(width: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'kg', label: Text('kg')),
                    ButtonSegment(value: 'g', label: Text('g')),
                  ],
                  selected: {unit},
                  onSelectionChanged: (value) => setState(() => unit = value.first),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : runPrediction,
                icon: busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_graph_rounded, size: 20),
                label: Text(busy ? 'Running models...' : 'Run all 3 models'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader(ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Results', style: Theme.of(context).textTheme.titleLarge),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xffD6F0E3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            response!.sizeLabel,
            style: const TextStyle(color: CalamansiApp.primaryDark, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _resultCard(PredictionResult result, ColorScheme colors) {
    final isBest = result.algorithm.contains('Simple Linear');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isBest ? const Color(0xffD6F0E3) : const Color(0xffEDF3EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.local_drink_rounded,
                  color: isBest ? CalamansiApp.primary : CalamansiApp.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            result.algorithm,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: CalamansiApp.textDark),
                          ),
                        ),
                        if (isBest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: CalamansiApp.accent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Best', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${result.juiceMl.toStringAsFixed(2)} ml',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: CalamansiApp.primary),
                    ),
                    Text(
                      '${(result.juiceMl / 1000).toStringAsFixed(4)} L',
                      style: const TextStyle(color: CalamansiApp.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
