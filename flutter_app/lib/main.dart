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
  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (_) {
    // Allows app to start seamlessly even if network is offline
  }
  runApp(const CalamansiApp());
}

class CalamansiApp extends StatelessWidget {
  const CalamansiApp({super.key});

  // Color Palette from Web Stylesheet (styles.css)
  static const primary = Color(0xff15803d); // --calamansi-primary
  static const primaryDark = Color(0xff14532d); // --calamansi-dark
  static const primaryLight = Color(0xffdcfce7); // --calamansi-light
  static const primarySoft = Color(0xfff0fdf4);
  static const accent = Color(0xfff59e0b); // --calamansi-accent (amber star)
  static const bgPage = Color(0xfff8fafc); // --bg-page
  static const bgCard = Colors.white; // --bg-card
  static const bgSubtle = Color(0xfff1f5f9); // --bg-subtle
  static const border = Color(0xffe2e8f0); // --border
  static const borderFocus = Color(0xff16a34a); // --border-focus
  static const textMain = Color(0xff0f172a); // --text-main
  static const textDark = Color(0xff0f172a); // --text-dark
  static const textMuted = Color(0xff64748b); // --text-muted
  static const textDim = Color(0xff94a3b8); // --text-dim

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calamansi Yield Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        scaffoldBackgroundColor: bgPage,
        colorScheme: const ColorScheme(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: primaryLight,
          onPrimaryContainer: primaryDark,
          secondary: accent,
          onSecondary: Colors.white,
          surface: bgCard,
          onSurface: textMain,
          error: Color(0xffdc2626),
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            color: textMain,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: textMain),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: borderFocus, width: 1.5),
          ),
          labelStyle: const TextStyle(color: textMuted, fontSize: 14),
          hintStyle: const TextStyle(color: textDim, fontSize: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
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
    try {
      auth = AuthService(Supabase.instance.client);
    } catch (_) {
      // In case Supabase client initialization had an issue
      auth = AuthService(SupabaseClient(supabaseUrl, supabaseAnonKey));
    }
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
    if (loading) {
      return const Scaffold(
        backgroundColor: CalamansiApp.bgPage,
        body: Center(child: CircularProgressIndicator(color: CalamansiApp.primary)),
      );
    }
    if (user == null) return LoginScreen(auth: auth, onSignedIn: _signedIn);
    if (user!.isAdmin) return AdminScreen(user: user!, onSignOut: _signOut);
    return HomeScreen(user: user!, onSignOut: _signOut);
  }
}
