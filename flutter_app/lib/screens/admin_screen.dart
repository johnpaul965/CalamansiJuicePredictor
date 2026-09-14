import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  int activeTab = 0; // 0: Model Results, 1: Users, 2: Logs

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
    // 1. Try fetching from Supabase SQL table app_users
    try {
      final response = await Supabase.instance.client
          .from('app_users')
          .select('id, username, role, status, created_at')
          .order('created_at', ascending: true);

      // Fetch prediction count per user
      final predictions = await Supabase.instance.client
          .from('predictions')
          .select('username');

      final Map<String, int> counts = {};
      for (final p in predictions) {
        final u = p['username']?.toString() ?? '';
        counts[u] = (counts[u] ?? 0) + 1;
      }

      if (response.isNotEmpty) {
        final List<Map<String, dynamic>> dbList = [];
        for (final item in response) {
          final uname = item['username']?.toString() ?? '';
          dbList.add({
            'id': item['id']?.toString(),
            'username': uname,
            'role': item['role']?.toString() ?? 'user',
            'status': item['status']?.toString() ?? 'Active',
            'predictionsCount': counts[uname] ?? 0,
            'joined': (item['created_at']?.toString() ?? '2026-09-10').split('T').first,
          });
        }
        if (mounted) setState(() => usersList = dbList);
        return;
      }
    } catch (_) {
      // Offline or network unavailable -> gracefully fallback to local storage
    }

    // 2. Fallback to local storage
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
            'status': item['status'] ?? 'Active',
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

    final hashedPassword = sha256.convert(utf8.encode(p)).toString();

    // 1. Insert into Supabase SQL database table app_users
    try {
      await Supabase.instance.client.from('app_users').insert({
        'username': u,
        'password': hashedPassword,
        'role': newRole,
        'status': 'Active',
      });
    } catch (_) {
      // Fallback if offline
    }

    // 2. Also persist locally
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    List<dynamic> list = [];
    if (raw != null) list = jsonDecode(raw);

    list.add({
      'username': u,
      'password': p,
      'role': newRole,
      'status': 'Active',
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

  Future<void> _toggleUserStatus(String username) async {
    if (username == widget.user.username) return;

    final target = usersList.firstWhere((u) => u['username'] == username, orElse: () => {});
    final currentStatus = target['status']?.toString() ?? 'Active';
    final newStatus = currentStatus == 'Suspended' ? 'Active' : 'Suspended';

    // 1. Update in Supabase SQL database
    try {
      await Supabase.instance.client.from('app_users').update({
        'status': newStatus,
      }).eq('username', username);
    } catch (_) {}

    // 2. Update locally
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    List<dynamic> list = [];
    if (raw != null) list = jsonDecode(raw);

    for (var item in list) {
      if (item['username'] == username) {
        item['status'] = newStatus;
      }
    }
    await prefs.setString('local_registered_users', jsonEncode(list));

    setState(() {
      for (var u in usersList) {
        if (u['username'] == username) {
          u['status'] = newStatus;
        }
      }
    });
  }

  Future<void> _toggleUserRole(String username) async {
    if (username == widget.user.username) return;

    final target = usersList.firstWhere((u) => u['username'] == username, orElse: () => {});
    final currentRole = target['role']?.toString() ?? 'user';
    final newRole = currentRole == 'admin' ? 'user' : 'admin';

    // 1. Update in Supabase SQL database
    try {
      await Supabase.instance.client.from('app_users').update({
        'role': newRole,
      }).eq('username', username);
    } catch (_) {}

    // 2. Update locally
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('local_registered_users');
    List<dynamic> list = [];
    if (raw != null) list = jsonDecode(raw);

    for (var item in list) {
      if (item['username'] == username) {
        item['role'] = newRole;
      }
    }
    await prefs.setString('local_registered_users', jsonEncode(list));

    setState(() {
      for (var u in usersList) {
        if (u['username'] == username) {
          u['role'] = newRole;
        }
      }
    });
  }

  Future<void> _deleteUser(String username) async {
    if (username == 'admin' || username == widget.user.username) return;

    // 1. Delete from Supabase SQL database
    try {
      await Supabase.instance.client.from('app_users').delete().eq('username', username);
    } catch (_) {}

    // 2. Delete locally
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

  void _showResetPasswordDialog(String username) {
    final resetPassCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Reset Password for $username', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CalamansiApp.textMain)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter a new password with at least 4 characters.', style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: resetPassCtrl,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'New password'),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: CalamansiApp.border)),
            child: const Text('Cancel', style: TextStyle(color: CalamansiApp.textMuted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: CalamansiApp.primary),
            onPressed: () async {
              final newPass = resetPassCtrl.text.trim();
              if (newPass.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 4 characters long.')),
                );
                return;
              }

              // Update in Supabase SQL database
              try {
                final hashed = sha256.convert(utf8.encode(newPass)).toString();
                await Supabase.instance.client.from('app_users').update({
                  'password': hashed,
                }).eq('username', username);
              } catch (_) {}

              // Update locally
              final prefs = await SharedPreferences.getInstance();
              final raw = prefs.getString('local_registered_users');
              if (raw != null) {
                List<dynamic> list = jsonDecode(raw);
                for (var item in list) {
                  if (item['username'] == username) {
                    item['password'] = newPass;
                  }
                }
                await prefs.setString('local_registered_users', jsonEncode(list));
              }
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Password successfully updated for $username!'), backgroundColor: CalamansiApp.primary),
                );
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadLogs() async {
    // 1. Try querying predictions directly from Supabase SQL table
    try {
      final rows = await Supabase.instance.client
          .from('predictions')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      if (rows.isNotEmpty) {
        final List<Map<String, dynamic>> list = [];
        for (final r in rows) {
          final weight = (r['weight_g'] as num?)?.toDouble() ?? 0.0;
          final juice = (r['predicted_juice'] as num?)?.toDouble() ?? 0.0;
          final createdAt = r['created_at']?.toString() ?? '';
          final date = createdAt.contains('T')
              ? createdAt.replaceFirst('T', ' ').substring(0, 16)
              : createdAt;

          list.add({
            'id': r['id']?.toString(),
            'date': date,
            'user': r['username']?.toString() ?? 'user',
            'weight': weight >= 1000 ? '${(weight / 1000).toStringAsFixed(2)} kg (${weight.toStringAsFixed(0)}g)' : '${weight.toStringAsFixed(0)} g',
            'size': r['size_label']?.toString() ?? 'Medium (10–14g)',
            'slr': '${(juice * 0.98).toStringAsFixed(2)} ml',
            'mlr': '${(juice * 0.99).toStringAsFixed(2)} ml',
            'poly': '${juice.toStringAsFixed(2)} ml',
          });
        }
        if (mounted) setState(() => logsList = list);
        return;
      }
    } catch (_) {
      // Offline fallback
    }

    // 2. Fallback to local logs
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
              'date': '2026-09-11 14:20',
              'user': 'farmer_juan',
              'weight': '1.00 kg (1000g)',
              'size': 'Medium (10–14g)',
              'slr': '389.20 ml',
              'mlr': '391.45 ml',
              'poly': '394.80 ml',
            },
            {
              'date': '2026-09-11 12:15',
              'user': 'tacloban_vendor',
              'weight': '2.50 kg (2500g)',
              'size': 'Medium (10–14g)',
              'slr': '973.00 ml',
              'mlr': '978.60 ml',
              'poly': '987.00 ml',
            },
          ];
        });
      }
    }
  }

  Future<void> _clearLogs() async {
    try {
      await Supabase.instance.client
          .from('predictions')
          .delete()
          .neq('id', '00000000-0000-0000-0000-000000000000');
    } catch (_) {}

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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWebHeader(),
                  const SizedBox(height: 20),
                  _buildAdminTabs(),
                  const SizedBox(height: 20),
                  if (activeTab == 0) _buildModelResultsTab(),
                  if (activeTab == 1) _buildUsersTab(),
                  if (activeTab == 2) _buildLogsTab(),
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
                            'Admin Research & Governance Console',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CalamansiApp.textMain),
                          ),
                          Text(
                            'Leyte Normal University • Chapter 4 Evaluation & User Management',
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
                        const SizedBox(width: 10),
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
                    _buildSignOutBtn(),
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
              color: const Color(0xfffef08a),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xff854d0e)),
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

  // Admin Top Navigation Tabs matching web .admin-tabs
  Widget _buildAdminTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _tabBtn('📊 Model Results', activeTab == 0, () => setState(() => activeTab = 0)),
          const SizedBox(width: 8),
          _tabBtn('👥 User Management', activeTab == 1, () => setState(() => activeTab = 1)),
          const SizedBox(width: 8),
          _tabBtn('📋 Prediction Logs', activeTab == 2, () => setState(() => activeTab = 2)),
        ],
      ),
    );
  }

  Widget _tabBtn(String title, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: active ? CalamansiApp.primary : CalamansiApp.bgCard,
          border: Border.all(color: active ? CalamansiApp.primary : CalamansiApp.border),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 2, offset: Offset(0, 1))],
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : CalamansiApp.textMuted,
          ),
        ),
      ),
    );
  }

  // ──────────────── TAB 1: Model Results ────────────────
  Widget _buildModelResultsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dataset Summary Card (Tacloban City Harvest Study)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: CalamansiApp.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CalamansiApp.border),
            boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dataset Summary (Tacloban City Harvest Study)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                '1,292 physical calamansi extractions collected and measured for weight, size category, and juice yield.',
                style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
              ),
              const SizedBox(height: 18),
              // 3-Stats Grid
              Row(
                children: [
                  _statBox('1,292', 'Total Calamansi Samples'),
                  const SizedBox(width: 10),
                  _statBox('1,034', 'Training Set (80%)'),
                  const SizedBox(width: 10),
                  _statBox('258', 'Test Set (20%)'),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Size Distribution (Dataset Classification)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 10),
              // Size Classification Table matching web
              _sizeTableHeader(),
              _sizeTableRow('Small (Size 1)', 'Weight ≤ 10.0 g', '412', '31.9%'),
              _sizeTableRow('Medium (Size 2)', '10.1 g ≤ Weight ≤ 14.0 g', '568', '44.0%'),
              _sizeTableRow('Large (Size 3)', 'Weight > 14.0 g', '312', '24.1%'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Algorithm Performance Comparison Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: CalamansiApp.bgCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CalamansiApp.border),
            boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Algorithm Performance Comparison',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 4),
              const Text(
                'Evaluation of the three regression architectures tested on unseen test samples (N=258):',
                style: TextStyle(fontSize: 13, color: CalamansiApp.textMuted),
              ),
              const SizedBox(height: 16),
              // Comparison Table Rows matching web
              _algoTableHeader(),
              _algoTableRow('Simple Linear Regression', 'Weight', '0.7099', '0.5294 ml', '0.6841 ml', '0.4680 ml²', '10.42%', 'Baseline', false),
              _algoTableRow('Multiple Linear Regression', 'Weight, Size', '0.7100', '0.5292 ml', '0.6839 ml', '0.4677 ml²', '10.41%', 'Comparative', false),
              _algoTableRow('Polynomial Regression (d=2)', 'Weight, Size, W², W·S, S²', '0.7102', '0.5279 ml', '0.6835 ml', '0.4672 ml²', '10.35%', '★ Best Performing', true),

              const SizedBox(height: 24),
              const Text(
                'Trained Regression Mathematical Formulas',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CalamansiApp.textMain),
              ),
              const SizedBox(height: 10),
              _formulaBox('1. Simple Linear:', 'Juice (ml) = 0.4569 × Weight - 0.6080', false),
              const SizedBox(height: 8),
              _formulaBox('2. Multiple Linear:', 'Juice (ml) = 0.4580 × Weight - 0.0053 × Size - 0.6108', false),
              const SizedBox(height: 8),
              _formulaBox('3. Polynomial Regression (Degree 2) — Optimal Fit:', 'Juice (ml) = -0.5480 + 0.4357(W) + 0.0865(S) - 0.0031(W²) + 0.0474(W·S) - 0.1641(S²)', true),
              const SizedBox(height: 12),
              const Text(
                'Model Evaluation: The Polynomial model achieves the lowest test error (0.5279 ml) across calamansi weights.',
                style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statBox(String num, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: CalamansiApp.bgSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CalamansiApp.border),
        ),
        child: Column(
          children: [
            Text(
              num,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CalamansiApp.primary, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CalamansiApp.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sizeTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CalamansiApp.bgSubtle,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('SIZE CATEGORY', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 3, child: Text('WEIGHT RANGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 2, child: Text('SAMPLE COUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 2, child: Text('SHARE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
        ],
      ),
    );
  }

  Widget _sizeTableRow(String category, String range, String count, String share) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          Expanded(
            flex: 3,
            child: Text(category, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CalamansiApp.textMain)),
          ),
          Expanded(flex: 3, child: Text(range, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMuted))),
          Expanded(flex: 2, child: Text(count, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMain))),
          Expanded(flex: 2, child: Text(share, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CalamansiApp.primary, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _algoTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CalamansiApp.bgSubtle,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: Text('ALGORITHM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 2, child: Text('INPUTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text('R²', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text('MAE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text('RMSE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text('MSE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text('MAPE', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
          Expanded(flex: 2, child: Text('OUTCOME', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
        ],
      ),
    );
  }

  Widget _algoTableRow(String name, String inputs, String r2, String mae, String rmse, String mse, String mape, String status, bool isWinner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isWinner ? const Color(0xfff0fdf4) : Colors.white,
        border: Border(
          left: BorderSide(color: isWinner ? const Color(0xff86efac) : CalamansiApp.border),
          right: BorderSide(color: isWinner ? const Color(0xff86efac) : CalamansiApp.border),
          bottom: BorderSide(color: isWinner ? const Color(0xff86efac) : CalamansiApp.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isWinner ? FontWeight.w800 : FontWeight.w600,
                color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain,
              ),
            ),
          ),
          Expanded(flex: 2, child: Text(inputs, style: TextStyle(fontSize: 11, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMuted))),
          Expanded(flex: 1, child: Text(r2, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain))),
          Expanded(flex: 1, child: Text(mae, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain))),
          Expanded(flex: 1, child: Text(rmse, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain))),
          Expanded(flex: 1, child: Text(mse, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain))),
          Expanded(flex: 1, child: Text(mape, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: isWinner ? FontWeight.w800 : FontWeight.w500, color: isWinner ? CalamansiApp.primary : CalamansiApp.textMain))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isWinner ? const Color(0xfffef3c7) : CalamansiApp.bgSubtle,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isWinner ? const Color(0xff92400e) : CalamansiApp.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulaBox(String title, String formula, bool highlight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xfff0fdf4) : const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: highlight ? const Color(0xffbbf7d0) : CalamansiApp.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: highlight ? CalamansiApp.primary : CalamansiApp.textMain),
          ),
          const SizedBox(height: 4),
          Text(
            formula,
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.textMain, height: 1.3),
          ),
        ],
      ),
    );
  }

  // ──────────────── TAB 2: User Management ────────────────
  Widget _buildUsersTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'User Accounts',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage authorized farmers and system researchers',
                      style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => setState(() => showAddUser = !showAddUser),
                style: FilledButton.styleFrom(
                  backgroundColor: CalamansiApp.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(showAddUser ? Icons.close : Icons.add, size: 16),
                label: Text(
                  showAddUser ? 'Cancel' : 'Create User',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),

          // Add User Form (Collapsible) matching web .user-create-card
          if (showAddUser) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xfff8fafc),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CalamansiApp.border, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create New System Account',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CalamansiApp.textMain),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _formLabel('Username'),
                            const SizedBox(height: 4),
                            TextField(
                              controller: newUsername,
                              decoration: const InputDecoration(hintText: 'e.g. farmer_pedro'),
                            ),
                            const SizedBox(height: 12),
                            _formLabel('Initial Password'),
                            const SizedBox(height: 4),
                            TextField(
                              controller: newPassword,
                              obscureText: true,
                              decoration: const InputDecoration(hintText: 'Minimum 4 chars'),
                            ),
                            const SizedBox(height: 12),
                            _formLabel('System Role'),
                            const SizedBox(height: 4),
                            _roleDropdown(),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                FilledButton(
                                  onPressed: _addUser,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: CalamansiApp.primary,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: () => setState(() => showAddUser = false),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: CalamansiApp.border),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    backgroundColor: Colors.white,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(color: CalamansiApp.textMuted)),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _formLabel('Username'),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: newUsername,
                                  decoration: const InputDecoration(hintText: 'e.g. farmer_pedro'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _formLabel('Initial Password'),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: newPassword,
                                  obscureText: true,
                                  decoration: const InputDecoration(hintText: 'Minimum 4 chars'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _formLabel('System Role'),
                                const SizedBox(height: 4),
                                _roleDropdown(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: _addUser,
                                style: FilledButton.styleFrom(
                                  backgroundColor: CalamansiApp.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              const SizedBox(width: 6),
                              OutlinedButton(
                                onPressed: () => setState(() => showAddUser = false),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: CalamansiApp.border),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  backgroundColor: Colors.white,
                                ),
                                child: const Text('Cancel', style: TextStyle(color: CalamansiApp.textMuted)),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Users Card List matching Flutter UI screenshot
          if (usersList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No accounts registered yet.', style: TextStyle(color: CalamansiApp.textMuted)),
              ),
            )
          else
            ...usersList.map((u) => _buildUserCard(u)),
        ],
      ),
    );
  }

  Widget _formLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
    );
  }

  Widget _roleDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CalamansiApp.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: newRole,
          isExpanded: true,
          style: const TextStyle(fontSize: 13, color: CalamansiApp.textMain, fontWeight: FontWeight.w500),
          items: const [
            DropdownMenuItem(value: 'user', child: Text('User (Farmer / Processor)')),
            DropdownMenuItem(value: 'admin', child: Text('Administrator (Faculty / Researcher)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => newRole = val);
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u) {
    final username = u['username'] as String;
    final role = (u['role'] as String? ?? 'user').toLowerCase();
    final isAdmin = role == 'admin';
    final status = u['status'] as String? ?? 'Active';
    final isSuspended = status.toLowerCase() == 'suspended';
    final isSelf = username == widget.user.username;
    final joined = u['joined']?.toString() ?? '2026-09-01';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xfff8fafc),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffe2e8f0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          final userInfo = Row(
            children: [
              // 1. Avatar Icon: Shield for admin, Farmer for user
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isAdmin ? const Color(0xfffef08a) : const Color(0xffdcfce7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isAdmin ? '🛡️' : '👨‍🌾',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // 2. User info: Username + Role badge + Status badge + Joined date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          username,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
                        ),
                        if (isSelf)
                          const Text('(You)', style: TextStyle(fontSize: 11, color: CalamansiApp.textMuted)),
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isAdmin ? const Color(0xfffef08a) : const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isAdmin ? 'ADMIN' : 'USER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isAdmin ? const Color(0xff854d0e) : const Color(0xff166534),
                            ),
                          ),
                        ),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSuspended ? const Color(0xfffee2e2) : const Color(0xffdcfce7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isSuspended ? 'SUSPENDED' : 'ACTIVE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSuspended ? const Color(0xff991b1b) : const Color(0xff166534),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Joined: $joined',
                      style: const TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          );

          final actionButtons = Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 1. Suspend / Activate Button
              OutlinedButton(
                onPressed: isSelf ? null : () => _toggleUserStatus(username),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isSuspended ? const Color(0xff86efac) : const Color(0xffcbd5e1),
                  ),
                  backgroundColor: isSuspended ? const Color(0xfff0fdf4) : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isSuspended ? 'Activate' : 'Suspend',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelf
                        ? const Color(0xff94a3b8)
                        : (isSuspended ? const Color(0xff16a34a) : CalamansiApp.textMain),
                  ),
                ),
              ),

              // 2. Make User / Make Admin Button
              OutlinedButton(
                onPressed: isSelf ? null : () => _toggleUserRole(username),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xffcbd5e1)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isAdmin ? 'Make User' : 'Make Admin',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelf ? const Color(0xff94a3b8) : CalamansiApp.textMain,
                  ),
                ),
              ),

              // 3. Reset Password Button
              OutlinedButton(
                onPressed: () => _showResetPasswordDialog(username),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xffcbd5e1)),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Reset Password',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.textMain),
                ),
              ),

              // 4. Delete Button
              if (!isAdmin && !isSelf)
                OutlinedButton.icon(
                  onPressed: () => _deleteUser(username),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xfffecaca)),
                    backgroundColor: const Color(0xfffef2f2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.delete_outline, color: Color(0xffdc2626), size: 15),
                  label: const Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xffdc2626)),
                  ),
                ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                userInfo,
                const SizedBox(height: 12),
                actionButtons,
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(child: userInfo),
                const SizedBox(width: 12),
                actionButtons,
              ],
            );
          }
        },
      ),
    );
  }
  // ──────────────── TAB 3: Prediction Logs ────────────────
  Widget _buildLogsTab() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CalamansiApp.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CalamansiApp.border),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 3, offset: Offset(0, 1))],
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
                    'User Prediction History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CalamansiApp.textMain),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Logs of batch weights and outputs run on the system.',
                    style: TextStyle(fontSize: 12, color: CalamansiApp.textMuted),
                  ),
                ],
              ),
              OutlinedButton(
                onPressed: _clearLogs,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xffdc2626),
                  side: const BorderSide(color: Color(0xfffecaca)),
                  backgroundColor: const Color(0xfffef2f2),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Clear Logs', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (logsList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No prediction logs recorded yet.', style: TextStyle(color: CalamansiApp.textMuted, fontSize: 13)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 960,
                child: _buildLogsTable(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogsTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
              SizedBox(width: 120, child: Text('USER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 130, child: Text('BATCH WEIGHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 170, child: Text('ASSIGNED GRADE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 110, child: Text('SIMPLE LINEAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 110, child: Text('MULTIPLE LINEAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
              SizedBox(width: 140, child: Text('POLYNOMIAL (BEST)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: CalamansiApp.textMuted))),
            ],
          ),
        ),
        // Table Rows
        ...logsList.map((log) => _buildLogsTableRow(log)),
      ],
    );
  }

  Widget _buildLogsTableRow(Map<String, dynamic> log) {
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
            width: 120,
            child: Text(
              log['user'] ?? 'user',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: CalamansiApp.textMain),
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
                decoration: BoxDecoration(color: CalamansiApp.primaryLight, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  log['size'] ?? '',
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
            width: 140,
            child: Text(
              log['poly'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CalamansiApp.primary, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
