import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';

class AuthService {
  AuthService(this.client);

  final SupabaseClient client;

  String _hash(String password) => sha256.convert(utf8.encode(password)).toString();

  Future<AppUser?> login(String username, String password) async {
    final response = await client
        .from('app_users')
        .select('id, username, role')
        .eq('username', username.trim())
        .eq('password', _hash(password))
        .maybeSingle();
    if (response == null) return null;
    final user = AppUser.fromMap(response);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_id', user.id);
    await prefs.setString('username', user.username);
    await prefs.setString('role', user.role);
    return user;
  }

  Future<String?> register(String username, String password) async {
    if (username.trim().isEmpty) return 'Username is required.';
    if (password.trim().length < 4) return 'Password must be at least 4 characters.';
    try {
      await client.from('app_users').insert({
        'username': username.trim(),
        'password': _hash(password),
        'role': 'user',
      });
      return null;
    } catch (_) {
      return 'That username is already taken.';
    }
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
    await prefs.clear();
  }
}
