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
    return MaterialApp(
      title: 'Calamansi Yield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff167d65),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xfff7faf6),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AppUser? user;
  bool loading = true;
  late final AuthService auth;

  @override
  void initState() {
    super.initState();
    auth = AuthService(Supabase.instance.client);
    _restore();
  }

  Future<void> _restore() async {
    final savedUser = await auth.restore();
    if (mounted) setState(() { user = savedUser; loading = false; });
  }

  void _signedIn(AppUser signedInUser) => setState(() => user = signedInUser);

  Future<void> _signOut() async {
    await auth.logout();
    if (mounted) setState(() => user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (user == null) return LoginScreen(auth: auth, onSignedIn: _signedIn);
    if (user!.isAdmin) return AdminScreen(user: user!, onSignOut: _signOut);
    return HomeScreen(user: user!, onSignOut: _signOut);
  }
}
