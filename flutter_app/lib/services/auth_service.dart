import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class AuthService {
  AuthService(this.client);

  final SupabaseClient client;

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

  // Demo fallback accounts matching web/app.js
  static final List<Map<String, String>> _defaultUsers = [
    {'username': 'farmer_juan', 'password': 'user123', 'role': 'user'},
    {'username': 'admin', 'password': 'admin123', 'role': 'admin'},
    {'username': 'tacloban_vendor', 'password': 'user123', 'role': 'user'},
  ];

  Future<AppUser?> login(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    // 1. Check local demo accounts first for instant offline/demo login
    for (final demo in _defaultUsers) {
      if (demo['username']!.toLowerCase() == cleanUsername && demo['password'] == cleanPassword) {
        final user = AppUser(
          id: demo['username']!,
          username: demo['username']!,
          role: demo['role']!,
        );
        await _saveSession(user);
        return user;
      }
    }

    // 2. Check local stored registered users
    final prefs = await SharedPreferences.getInstance();
    final localUsersJson = prefs.getString('local_registered_users');
    if (localUsersJson != null) {
      final List<dynamic> localUsers = jsonDecode(localUsersJson);
      for (final item in localUsers) {
        if (item['username'].toString().toLowerCase() == cleanUsername &&
            item['password'] == cleanPassword) {
          final user = AppUser(
            id: item['username'].toString(),
            username: item['username'].toString(),
            role: item['role']?.toString() ?? 'user',
          );
          await _saveSession(user);
          return user;
        }
      }
    }

    // 3. Try Supabase cloud database if available
    try {
      final response = await client
          .from('app_users')
          .select('id, username, role')
          .eq('username', cleanUsername)
          .eq('password', _hash(cleanPassword))
          .maybeSingle();

      if (response != null) {
        final user = AppUser.fromMap(response);
        await _saveSession(user);
        return user;
      }
    } catch (_) {
      // Offline or network error
    }

    return null;
  }

  Future<String?> register(String username, String password) async {
    final cleanUsername = username.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty) return 'Username is required.';
    if (cleanPassword.length < 4) return 'Password must be at least 4 characters.';

    // Check if username already exists in default users
    if (_defaultUsers.any((u) => u['username']!.toLowerCase() == cleanUsername)) {
      return 'That username is already registered.';
    }

    final prefs = await SharedPreferences.getInstance();
    final localUsersJson = prefs.getString('local_registered_users');
    List<dynamic> localUsers = [];
    if (localUsersJson != null) {
      localUsers = jsonDecode(localUsersJson);
      if (localUsers.any((u) => u['username'].toString().toLowerCase() == cleanUsername)) {
        return 'That username is already registered.';
      }
    }

    // Save locally
    localUsers.add({
      'username': cleanUsername,
      'password': cleanPassword,
      'role': 'user',
      'created_at': DateTime.now().toIso8601String(),
    });
    await prefs.setString('local_registered_users', jsonEncode(localUsers));

    // Also attempt remote save
    try {
      await client.from('app_users').insert({
        'username': cleanUsername,
        'password': _hash(cleanPassword),
        'role': 'user',
      });
    } catch (_) {}

    return null;
  }

  Future<void> _saveSession(AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('role', user.role);
  }

  Future<AppUser?> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('user_id');
    final username = prefs.getString('username');
    final role = prefs.getString('role');
    if (id == null || username == null || role == null) return null;
    return AppUser(id: id, username: username, role: role);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role');
  }
}
