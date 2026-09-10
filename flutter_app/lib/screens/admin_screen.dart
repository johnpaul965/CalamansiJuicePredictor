import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../models.dart';
import '../services/history_service.dart';
import 'model_results_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.user, required this.onSignOut});
  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int tab = 0;
  late final HistoryService service;
  late Future<List<Map<String, dynamic>>> records;
  late Future<List<Map<String, dynamic>>> users;

  @override
  void initState() {
    super.initState();
    service = HistoryService(Supabase.instance.client);
    records = service.all();
    users = _loadUsers();
  }

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final rows = await Supabase.instance.client
        .from('app_users')
        .select('id, username, role, created_at')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(rows);
  }

  void reload() {
    setState(() {
      records = service.all();
      users = _loadUsers();
    });
  }

  Future<void> _deleteUser(String userId, String username) async {
    await Supabase.instance.client.from('app_users').delete().eq('id', userId);
    reload();
  }

  Future<void> _updateRole(String userId, String newRole) async {
    await Supabase.instance.client
        .from('app_users')
        .update({'role': newRole}).eq('id', userId);
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_rounded),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Predictions',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_outlined),
            selectedIcon: Icon(Icons.science_rounded),
            label: 'Models',
          ),
        ],
      ),
      body: [() => _usersBody(), () => _predictionsBody(), () => const ModelResultsScreen()][tab](),
    );
  }

  Widget _usersBody() {
    final theme = Theme.of(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: users,
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
                Text('Could not load users.', style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final isCurrentUser = row['id'] == widget.user.id;
            final isAdmin = row['role'] == 'admin';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isAdmin ? const Color(0xffFFF3D6) : const Color(0xffD6F0E3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isAdmin ? Icons.shield_rounded : Icons.person_rounded,
                      color: isAdmin ? const Color(0xffB8860B) : CalamansiApp.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(row['username'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isAdmin ? const Color(0xffFFF3D6) : const Color(0xffEDF3EE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      row['role'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isAdmin ? const Color(0xff7A5800) : CalamansiApp.textMuted,
                      ),
                    ),
                  ),
                  trailing: isCurrentUser
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xffEDF3EE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('You', style: TextStyle(color: CalamansiApp.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded, color: CalamansiApp.primary),
                              tooltip: 'Toggle role',
                              onPressed: () {
                                final newRole = row['role'] == 'admin' ? 'user' : 'admin';
                                _updateRole(row['id'] as String, newRole);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xffD8483E)),
                              tooltip: 'Delete user',
                              onPressed: () => _deleteUser(row['id'] as String, row['username'] as String),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _predictionsBody() {
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
                Text('Could not load predictions.', style: theme.textTheme.bodyMedium),
              ],
            ),
          );
        }
        final rows = snapshot.data ?? [];
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          children: [
            Row(
              children: [
                Text('All Predictions', style: theme.textTheme.headlineSmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xffD6F0E3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${rows.length}',
                    style: const TextStyle(color: CalamansiApp.primaryDark, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('${rows.length} model results recorded', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 18),
            ...rows.map((row) {
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
                    subtitle: Text('${row['username']}  -  ${row['weight_g']} g', style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
                    trailing: Text(
                      '${juice.toStringAsFixed(2)} ml',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: CalamansiApp.primary),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
