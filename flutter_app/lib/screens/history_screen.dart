import 'package:flutter/material.dart';
import '../main.dart';
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
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: records,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CalamansiApp.primary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44, color: CalamansiApp.textMuted),
                const SizedBox(height: 12),
                Text('Could not load history.', style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xffEDF3EE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.history_rounded, size: 36, color: CalamansiApp.textMuted),
                ),
                const SizedBox(height: 16),
                Text('No predictions yet', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Run a prediction to see results here.', style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: CalamansiApp.primary,
          onRefresh: () async => reload(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final juice = (row['predicted_juice'] as num).toDouble();
              final algo = row['algorithm'] as String;
              final isBest = algo.contains('Simple Linear');
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isBest ? const Color(0xffD6F0E3) : const Color(0xffEDF3EE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_drink_rounded,
                        color: isBest ? CalamansiApp.primary : CalamansiApp.textMuted,
                        size: 22,
                      ),
                    ),
                    title: Text(algo, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('${row['weight_g']} g  -  ${_formatDate(row['created_at'])}', style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${juice.toStringAsFixed(2)} ml', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CalamansiApp.primary)),
                        Text('${(juice / 1000).toStringAsFixed(4)} L', style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
                      ],
                    ),
                    onLongPress: () async {
                      await widget.service.delete(row['id'] as String);
                      reload();
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    final parts = raw.split('T');
    return parts.first;
  }
}
