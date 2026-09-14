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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: records,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: CalamansiApp.primary));
        }
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CalamansiApp.bgSubtle,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('🍋', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No predictions yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: CalamansiApp.textMain),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Run a prediction to see your yield logs here.',
                  style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: CalamansiApp.primary,
          onRefresh: () async => reload(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              final algo = row['algorithm']?.toString() ?? 'Polynomial Regression (d=2)';
              final isBest = algo.contains('Polynomial');

              double juice = 0.0;
              if (row['predicted_juice'] is num) {
                juice = (row['predicted_juice'] as num).toDouble();
              } else if (row['poly'] != null) {
                final match = RegExp(r'([\d\.]+)').firstMatch(row['poly'].toString());
                if (match != null) juice = double.tryParse(match.group(1)!) ?? 0.0;
              }

              final weightStr = row['weight']?.toString() ?? '${row['weight_g']} g';
              final sizeLabel = row['size_label']?.toString() ?? row['size']?.toString() ?? 'Medium Calamansi (10–14g)';
              final dateStr = (row['date'] ?? row['created_at']?.toString().split('T').first) ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: CalamansiApp.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBest ? CalamansiApp.primary : CalamansiApp.border,
                    width: isBest ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isBest ? CalamansiApp.primaryLight : CalamansiApp.bgSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text('🍋', style: TextStyle(fontSize: 20)),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          algo,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: isBest ? CalamansiApp.primary : CalamansiApp.textMain,
                          ),
                        ),
                      ),
                      if (isBest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: CalamansiApp.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '★ Best',
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '$weightStr • $sizeLabel • $dateStr',
                    style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${juice.toStringAsFixed(2)} ml',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: CalamansiApp.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '${(juice / 1000).toStringAsFixed(4)} L',
                        style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted, fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                  onLongPress: () async {
                    if (row['id'] != null) {
                      await widget.service.delete(row['id'].toString());
                      reload();
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
