import 'package:flutter/material.dart';
import '../models.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.user, required this.service});
  final AppUser user;
  final HistoryService service;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<Map<String, dynamic>>> records;

  @override
  void initState() {
    super.initState();
    records = widget.service.forUser(widget.user.id);
  }

  void reload() => setState(() => records = widget.service.forUser(widget.user.id));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(future: records, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text('Could not load history.'));
      final rows = snapshot.data ?? [];
      if (rows.isEmpty) return const Center(child: Text('No predictions yet.'));
      return RefreshIndicator(onRefresh: () async => reload(), child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (context, index) {
        final row = rows[index];
        final juice = (row['predicted_juice'] as num).toDouble();
        return Card(child: ListTile(title: Text(row['algorithm'] as String), subtitle: Text('${row['weight_g']} g  •  ${row['created_at']}'), trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('${juice.toStringAsFixed(2)} ml', style: const TextStyle(fontWeight: FontWeight.bold)), Text('${(juice / 1000).toStringAsFixed(4)} L')]), onLongPress: () async { await widget.service.delete(row['id'] as String); reload(); }));
      }));
    });
  }
}
