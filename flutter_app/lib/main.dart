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

  static const primary = Color(0xff2E7D5B);
  static const primaryLight = Color(0xff5BBA8E);
  static const primaryDark = Color(0xff1B5E3F);
  static const accent = Color(0xffF5A623);
  static const bgLight = Color(0xffF4F8F5);
  static const cardBg = Colors.white;
  static const textDark = Color(0xff1A2B20);
  static const textMuted = Color(0xff6B8275);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calamansi Yield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xffD6F0E3),
          onPrimaryContainer: primaryDark,
          secondary: accent,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xffFFF3D6),
          onSecondaryContainer: const Color(0xff7A5800),
          surface: cardBg,
          onSurface: textDark,
          surfaceContainerHighest: const Color(0xffEDF3EE),
          onSurfaceVariant: textMuted,
          error: const Color(0xffD8483E),
          onError: Colors.white,
          outline: const Color(0xffC8D8CD),
          shadow: const Color(0x1A000000),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: bgLight,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textDark,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: textDark),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffC8D8CD)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xffC8D8CD)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          labelStyle: const TextStyle(color: textMuted, fontSize: 14),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xffE8EFE9), width: 1),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primary),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xffD6F0E3),
          indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: textDark, height: 1.2),
          headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textDark, height: 1.2),
          headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textDark, height: 1.3),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textDark),
          bodyLarge: TextStyle(fontSize: 15, color: textDark, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, color: textMuted, height: 1.5),
          bodySmall: TextStyle(fontSize: 12, color: textMuted, height: 1.4),
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
    if (loading) {
      return Scaffold(
        backgroundColor: CalamansiApp.bgLight,
        body: const Center(child: CircularProgressIndicator(color: CalamansiApp.primary)),
      );
    }
    if (user == null) return LoginScreen(auth: auth, onSignedIn: _signedIn);
    if (user!.isAdmin) return AdminScreen(user: user!, onSignOut: _signOut);
    return HomeScreen(user: user!, onSignOut: _signOut);
  }
}
