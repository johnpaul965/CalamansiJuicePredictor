import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
          IconButton(onPressed: widget.onSignOut, icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Predictions'),
          NavigationDestination(icon: Icon(Icons.science_outlined), selectedIcon: Icon(Icons.science), label: 'Models'),
        ],
      ),
      body: [() => _usersBody(), () => _predictionsBody(), () => const ModelResultsScreen()][tab](),
    );
  }

  Widget _usersBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: users,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load users.'));
        }
        final rows = snapshot.data ?? [];
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final isCurrentUser = row['id'] == widget.user.id;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: row['role'] == 'admin'
                      ? Colors.amber.shade100
                      : Colors.green.shade100,
                  child: Icon(
                    row['role'] == 'admin' ? Icons.shield : Icons.person,
                    color: row['role'] == 'admin' ? Colors.amber.shade800 : Colors.green.shade800,
                  ),
                ),
                title: Text(row['username'] as String),
                subtitle: Text(row['role'] as String),
                trailing: isCurrentUser
                    ? const Text('You', style: TextStyle(color: Colors.grey))
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.swap_horiz),
                            tooltip: 'Toggle role',
                            onPressed: () {
                              final newRole = row['role'] == 'admin' ? 'user' : 'admin';
                              _updateRole(row['id'] as String, newRole);
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Delete user',
                            onPressed: () => _deleteUser(row['id'] as String, row['username'] as String),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _predictionsBody() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: records,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Could not load predictions.'));
        }
        final rows = snapshot.data ?? [];
        return ListView(padding: const EdgeInsets.all(18), children: [
          Text('All Predictions',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('${rows.length} model results recorded'),
          const SizedBox(height: 18),
          ...rows.map((row) {
            final juice = (row['predicted_juice'] as num).toDouble();
            return Card(
              child: ListTile(
                title: Text(row['algorithm'] as String),
                subtitle: Text('${row['username']}  -  ${row['weight_g']} g'),
                trailing: Text('${juice.toStringAsFixed(2)} ml'),
              ),
            );
          }),
        ]);
      },
    );
  }
}
