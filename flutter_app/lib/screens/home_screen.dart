import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      appBar: AppBar(title: const Text('Calamansi Yield'), actions: [IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout))]),
      body: tab == 0 ? _predictionBody() : HistoryScreen(user: widget.user, service: history),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate), label: 'Predict'), NavigationDestination(icon: Icon(Icons.history), label: 'History')]),
    );
  }

  Widget _predictionBody() {
    final colors = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 30), children: [
      Text('Estimate your yield', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      const Text('Enter your total calamansi batch weight. All three models will run together.'),
      const SizedBox(height: 24),
      Row(children: [
        Expanded(child: TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Total weight'))),
        const SizedBox(width: 12),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'kg', label: Text('kg')), ButtonSegment(value: 'g', label: Text('g'))], selected: {unit}, onSelectionChanged: (value) => setState(() => unit = value.first)),
      ]),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: busy ? null : runPrediction, icon: const Icon(Icons.auto_graph), label: Padding(padding: const EdgeInsets.all(13), child: Text(busy ? 'Running models...' : 'Run all 3 models'))),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: TextStyle(color: colors.error))),
      if (response != null) ...[
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Results', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)), Text(response!.sizeLabel, style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        ...response!.results.map((result) => _resultCard(result)),
      ],
    ]);
  }

  Widget _resultCard(PredictionResult result) {
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
      CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(Icons.local_drink, color: Theme.of(context).colorScheme.primary)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(result.algorithm, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text('${result.juiceMl.toStringAsFixed(2)} ml', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), Text('${(result.juiceMl / 1000).toStringAsFixed(4)} L', style: const TextStyle(color: Colors.black54))])),
    ])));
  }
}
