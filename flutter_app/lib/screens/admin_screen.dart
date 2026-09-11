import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../models.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.user, required this.onSignOut});
  final AppUser user;
  final Future<void> Function() onSignOut;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int activeTab = 0; // 0: Paper & Models, 1: Users, 2: Logs

  // User Management state
  bool showAddUser = false;
  final newUsername = TextEditingController();
  final newPassword = TextEditingController();
  String newRole = 'user';
  List<Map<String, dynamic>> usersList = [];

  // Prediction Logs state
  List<Map<String, dynamic>> logsList = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadLogs();
  }

  @override
  void dispose() {
    newUsername.dispose();
    newPassword.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    List<Map<String, dynamic>> list = [
      {'username': 'admin', 'role': 'admin', 'status': 'Active', 'predictionsCount': 0, 'joined': '2026-09-01'},
      {'username': 'farmer_juan', 'role': 'user', 'status': 'Active', 'predictionsCount': 8, 'joined': '2026-09-02'},
      {'username': 'tacloban_vendor', 'role': 'user', 'status': 'Active', 'predictionsCount': 14, 'joined': '2026-09-03'},
    ];
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        if (!list.any((u) => u['username'] == item['username'])) {
          list.add({
            'username': item['username'],
            'role': item['role'] ?? 'user',
            'status': 'Active',
            'predictionsCount': 1,
            'joined': (item['created_at']?.toString() ?? '2026-09-10').split('T').first,
          });
        }
      }
    }
    if (mounted) setState(() => usersList = list);
  }

  Future<void> _addUser() async {
    final u = newUsername.text.trim().toLowerCase();
    final p = newPassword.text.trim();
    if (u.isEmpty || p.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    List<dynamic> list = [];
    if (raw != null) list = jsonDecode(raw);

    list.add({
      'username': u,
      'password': p,
      'role': newRole,
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('local_registered_users', jsonEncode(list));

    setState(() {
      showAddUser = false;
      newUsername.clear();
      newPassword.clear();
    });
    _loadUsers();
  }

  Future<void> _deleteUser(String username) async {
    if (username == 'admin') return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    if (raw != null) {
      List<dynamic> list = jsonDecode(raw);
      list.removeWhere((item) => item['username'] == username);
      await prefs.setString('local_registered_users', jsonEncode(list));
    }
    setState(() {
      usersList.removeWhere((u) => u['username'] == username);
    });
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_prediction_logs');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      if (mounted) {
        setState(() {
          logsList = List<Map<String, dynamic>>.from(decoded);
        });
      }
    } else {
      if (mounted) {
        setState(() {
          logsList = [
            {
              'date': '2026-09-10 14:20',
              'user': 'farmer_juan',
              'weight': '1.00 kg (1000g)',
              'size': 'Medium (Size 2)',
              'slr': '402.30 ml',
              'mlr': '403.10 ml',
              'poly': '404.60 ml',
            },
            {
              'date': '2026-09-10 12:15',
              'user': 'tacloban_vendor',
              'weight': '2.50 kg (2500g)',
              'size': 'Medium (Size 2)',
              'slr': '1005.75 ml',
              'mlr': '1007.80 ml',
              'poly': '1011.50 ml',
            },
          ];
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('local_prediction_logs');
    setState(() => logsList = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalamansiApp.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildAdminTabs(),
                const SizedBox(height: 16),
                if (activeTab == 0) _buildPaperTab(),
                if (activeTab == 1) _buildUsersTab(),
                if (activeTab == 2) _buildLogsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
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
                    'Admin Portal • Tacloban City Harvest Study',
                    style: TextStyle(fontSize: 11, color: CalamansiApp.textMuted),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xffede9fe),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xff7c3aed)),
                ),
              ),
              const SizedBox(width: 8),
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

  Widget _buildAdminTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: CalamansiApp.bgSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Row(
        children: [
          Expanded(child: _tabBtn('📑 Paper Results', activeTab == 0, () => setState(() => activeTab = 0))),
          Expanded(child: _tabBtn('👥 User Management', activeTab == 1, () => setState(() => activeTab = 1))),
          Expanded(child: _tabBtn('📋 Logs', activeTab == 2, () => setState(() => activeTab = 2))),
        ],
      ),
    );
  }

  Widget _tabBtn(String title, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x10000000), blurRadius: 4, offset: Offset(0, 1))]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? CalamansiApp.primary : CalamansiApp.textMuted,
          ),
        ),
      ),
    );
  }

  // ──────────────── TAB 1: Paper & Model Results ────────────────
  Widget _buildPaperTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dataset Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CalamansiApp.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CalamansiApp.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dataset Summary (Tacloban City Harvest Study)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                '1,292 physical calamansi fruit extractions measured for weight, size, and juice yield.',
                style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _statBox('1,292', 'Total Fruits'),
                  const SizedBox(width: 8),
                  _statBox('1,034', 'Training (80%)'),
                  const SizedBox(width: 8),
                  _statBox('258', 'Testing (20%)'),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Fruit Size Classification', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalamansiApp.textMain)),
              const SizedBox(height: 8),
              _tableRow('Small (Size 1)', '≤ 10.0 g', '412', '31.9%'),
              _tableRow('Medium (Size 2)', '10.1–14.0 g', '568', '44.0%'),
              _tableRow('Large (Size 3)', '> 14.0 g', '312', '24.1%'),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Algorithm Comparison Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: CalamansiApp.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CalamansiApp.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Algorithm Performance Comparison',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                'Evaluated on unseen test set (N=258) from the research findings:',
                style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
              ),
              const SizedBox(height: 14),
              _modelPerfRow('Simple Linear', 'Weight', '0.7099', '0.5294 ml', false),
              const SizedBox(height: 8),
              _modelPerfRow('Multiple Linear', 'Weight, Size', '0.7100', '0.5292 ml', false),
              const SizedBox(height: 8),
              _modelPerfRow('Polynomial (d=2)', 'Weight, Size, W², W·S, S²', '0.7102', '0.5279 ml', true),
              const SizedBox(height: 16),
              const Text('Mathematical Formulas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalamansiApp.textMain)),
              const SizedBox(height: 8),
              _formulaBox('1. Simple Linear', 'Juice (ml) = 0.4569 × Weight - 0.6080', false),
              const SizedBox(height: 6),
              _formulaBox('2. Multiple Linear', 'Juice (ml) = 0.4580 × Weight - 0.0053 × Size - 0.6108', false),
              const SizedBox(height: 6),
              _formulaBox('3. Polynomial (Optimal)', 'Juice = -0.5480 + 0.4357(W) + 0.0865(S) - 0.0031(W²) + 0.0474(W·S) - 0.1641(S²)', true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String num, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: CalamansiApp.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CalamansiApp.border),
        ),
        child: Column(
          children: [
            Text(num, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.primaryDark, fontFamily: 'monospace')),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: CalamansiApp.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _tableRow(String name, String weight, String count, String share) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(flex: 2, child: Text(weight, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text(count, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Text(share, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CalamansiApp.primary)),
        ],
      ),
    );
  }

  Widget _modelPerfRow(String name, String features, String r2, String mae, bool isWinner) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWinner ? CalamansiApp.primarySoft : CalamansiApp.bgSubtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isWinner ? CalamansiApp.primary : CalamansiApp.border, width: isWinner ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain)),
                    if (isWinner) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: CalamansiApp.accent, borderRadius: BorderRadius.circular(4)),
                        child: const Text('★ Best', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
                Text(features, style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('R²: $r2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain, fontFamily: 'monospace')),
              Text('MAE: $mae', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formulaBox(String title, String formula, bool highlight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xfff0fdf4) : CalamansiApp.bgSubtle,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? const Color(0xff86efac) : CalamansiApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? CalamansiApp.primary : CalamansiApp.textMain)),
          const SizedBox(height: 2),
          Text(formula, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: CalamansiApp.textMain)),
        ],
      ),
    );
  }

  // ──────────────── TAB 2: User Management ────────────────
  Widget _buildUsersTab() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Text('System Users', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CalamansiApp.textMain)),
              FilledButton.icon(
                onPressed: () => setState(() => showAddUser = !showAddUser),
                style: FilledButton.styleFrom(
                  backgroundColor: CalamansiApp.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(showAddUser ? Icons.close : Icons.add, size: 16),
                label: Text(showAddUser ? 'Cancel' : 'Add User', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          if (showAddUser) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CalamansiApp.bgSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CalamansiApp.border),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: newUsername,
                    decoration: const InputDecoration(hintText: 'Username (e.g. farmer_pedro)'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: newPassword,
                    decoration: const InputDecoration(hintText: 'Password (min 4 chars)'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _addUser,
                      child: const Text('Save User Account'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          ...usersList.map(
            (u) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CalamansiApp.bgSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CalamansiApp.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(u['username'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text('Joined: ${u['joined']}', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: u['role'] == 'admin' ? const Color(0xffede9fe) : CalamansiApp.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (u['role'] as String).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: u['role'] == 'admin' ? const Color(0xff7c3aed) : CalamansiApp.primaryDark,
                      ),
                    ),
                  ),
                  if (u['username'] != 'admin') ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xffdc2626)),
                      onPressed: () => _deleteUser(u['username'] as String),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── TAB 3: Prediction Logs ────────────────
  Widget _buildLogsTab() {
    return Container(
      padding: const EdgeInsets.all(18),
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
              const Text('Prediction History Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: CalamansiApp.textMain)),
              TextButton.icon(
                onPressed: _clearLogs,
                icon: const Icon(Icons.delete_sweep, size: 16, color: Color(0xffdc2626)),
                label: const Text('Clear', style: TextStyle(color: Color(0xffdc2626), fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No prediction logs recorded yet.', style: TextStyle(color: CalamansiApp.textMuted, fontSize: 13))),
            )
          else
            ...logsList.map(
              (l) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CalamansiApp.bgSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CalamansiApp.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(l['user'] ?? 'user', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        Text(l['date'] ?? '', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Batch Weight: ${l['weight']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.primaryDark)),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('SLR: ${l['slr']}', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted, fontFamily: 'monospace')),
                        Text('MLR: ${l['mlr']}', style: const TextStyle(fontSize: 11, color: CalamansiApp.textMuted, fontFamily: 'monospace')),
                        Text('Poly (Best): ${l['poly']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.primary, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
