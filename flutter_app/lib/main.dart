import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  runApp(const CalamansiApp());
}

class CalamansiApp extends StatelessWidget {
  const CalamansiApp({super.key});
  @override
  Widget build(BuildContext context) {
    const green = Color(0xff0b7c5c);
    final scheme = ColorScheme.fromSeed(seedColor: green, primary: green, secondary: const Color(0xffe2a537));
    return MaterialApp(
      title: 'Calamansi Yield', debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xfff7faf8),
        appBarTheme: const AppBarTheme(backgroundColor: green, foregroundColor: Colors.white, elevation: 0),
        cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Color(0xffe7efeb)))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.all(16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffd9e6df))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: green, width: 2))),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
        navigationBarTheme: NavigationBarThemeData(indicatorColor: green.withValues(alpha: .12)),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget { const AuthGate({super.key}); @override State<AuthGate> createState() => _AuthGateState(); }
class _AuthGateState extends State<AuthGate> {
  AppUser? user; bool loading = true; late final AuthService auth;
  @override void initState() { super.initState(); auth = AuthService(Supabase.instance.client); _restore(); }
  Future<void> _restore() async { final saved = await auth.restore(); if (mounted) setState(() { user = saved; loading = false; }); }
  void _signedIn(AppUser value) => setState(() => user = value);
  Future<void> _signOut() async { await auth.logout(); if (mounted) setState(() => user = null); }
  @override Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user == null) return LoginScreen(auth: auth, onSignedIn: _signedIn);
    return user!.isAdmin ? AdminScreen(user: user!, onSignOut: _signOut) : HomeScreen(user: user!, onSignOut: _signOut);
  }
}
