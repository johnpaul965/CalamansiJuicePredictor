import 'package:flutter/material.dart';
import '../main.dart';
import '../models.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onSignedIn});
  final AuthService auth;
  final void Function(AppUser user) onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  final confirmPassword = TextEditingController();

  bool registerMode = false;
  bool busy = false;
  bool obscurePassword = true;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final u = username.text.trim();
    final p = password.text;

    if (u.isEmpty) {
      setState(() => error = 'Please enter a username.');
      return;
    }
    if (p.isEmpty) {
      setState(() => error = 'Please enter a password.');
      return;
    }

    if (registerMode) {
      if (p.length < 4) {
        setState(() => error = 'Password must be at least 4 characters.');
        return;
      }
      if (p != confirmPassword.text) {
        setState(() => error = 'Passwords do not match. Please verify.');
        return;
      }
    }

    setState(() { busy = true; error = null; });

    try {
      if (registerMode) {
        final message = await widget.auth.register(u, p);
        if (message == null) {
          // Auto login after registration
          final user = await widget.auth.login(u, p);
          if (user != null) {
            widget.onSignedIn(user);
            return;
          }
          setState(() {
            registerMode = false;
            busy = false;
            password.clear();
            confirmPassword.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created! You can now sign in.'),
                backgroundColor: CalamansiApp.primary,
              ),
            );
          }
          return;
        }
        setState(() { error = message; busy = false; });
        return;
      }

      final user = await widget.auth.login(u, p);
      if (user == null) {
        setState(() {
          error = 'Incorrect username or password. Please verify and try again.';
          busy = false;
        });
        return;
      }
      widget.onSignedIn(user);
    } catch (e) {
      setState(() {
        error = 'Authentication error. Please try again.';
        busy = false;
      });
    }
  }

  void _fillAndSubmit(String u, String p) {
    setState(() {
      registerMode = false;
      username.text = u;
      password.text = p;
      error = null;
    });
    submit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CalamansiApp.bgPage,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: CalamansiApp.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CalamansiApp.border, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0a000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lemon Header matching Web
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: CalamansiApp.primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('🍋', style: TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Calamansi Yield Predictor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: CalamansiApp.textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Leyte Normal University • Tacloban City Harvest Study',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: CalamansiApp.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Predict pure juice extraction yield using trained regression algorithms',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: CalamansiApp.textDim,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Auth Tabs (Sign In vs Create Account)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: CalamansiApp.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CalamansiApp.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _tabButton(
                              title: 'Sign In',
                              active: !registerMode,
                              onTap: () {
                                if (registerMode) {
                                  setState(() {
                                    registerMode = false;
                                    error = null;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: _tabButton(
                              title: 'Create Account',
                              active: registerMode,
                              onTap: () {
                                if (!registerMode) {
                                  setState(() {
                                    registerMode = true;
                                    error = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Username field
                    Text(
                      registerMode ? 'Choose Username' : 'Username',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CalamansiApp.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: username,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        hintText: registerMode ? 'e.g. farmer_elena' : 'Enter your username',
                        prefixIcon: const Icon(Icons.person_outline, size: 20, color: CalamansiApp.textMuted),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Password field
                    Text(
                      registerMode ? 'Create Password' : 'Password',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: CalamansiApp.textMain,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: password,
                      obscureText: obscurePassword,
                      textInputAction: registerMode ? TextInputAction.next : TextInputAction.done,
                      onSubmitted: (_) {
                        if (!registerMode) submit();
                      },
                      decoration: InputDecoration(
                        hintText: registerMode ? 'At least 4 characters' : 'Enter your password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 20, color: CalamansiApp.textMuted),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20,
                            color: CalamansiApp.textMuted,
                          ),
                          onPressed: () => setState(() => obscurePassword = !obscurePassword),
                        ),
                      ),
                    ),

                    // Confirm Password (Register mode only)
                    if (registerMode) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: CalamansiApp.textMain,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: confirmPassword,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => submit(),
                        decoration: const InputDecoration(
                          hintText: 'Re-enter password',
                          prefixIcon: Icon(Icons.lock_outline, size: 20, color: CalamansiApp.textMuted),
                        ),
                      ),
                    ],

                    // Error text display
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xfffef2f2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xfffecaca)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: Color(0xffdc2626)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error!,
                                style: const TextStyle(fontSize: 12, color: Color(0xffdc2626)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Primary submit button
                    SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: busy ? null : submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: CalamansiApp.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                registerMode ? 'Create Account & Sign In' : 'Sign In to Predictor',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                      ),
                    ),

                    // Demo Accounts section
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: CalamansiApp.border)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'DEMO ACCOUNTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: CalamansiApp.textDim,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: CalamansiApp.border)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Demo Credentials Info Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: CalamansiApp.bgSubtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: CalamansiApp.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('👤 User Account:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.textMain)),
                              Text('farmer_juan / user123', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: CalamansiApp.primaryDark, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('🛡️ Admin Account:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CalamansiApp.textMain)),
                              Text('admin / admin123', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xff7c3aed), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick buttons matching Web
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : () => _fillAndSubmit('farmer_juan', 'user123'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: CalamansiApp.primary,
                              side: const BorderSide(color: CalamansiApp.border),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Text('👤', style: TextStyle(fontSize: 14)),
                            label: const Text('Quick User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : () => _fillAndSubmit('admin', 'admin123'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff7c3aed),
                              side: const BorderSide(color: CalamansiApp.border),
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Text('🛡️', style: TextStyle(fontSize: 14)),
                            label: const Text('Quick Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton({required String title, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? CalamansiApp.primary : CalamansiApp.textMuted,
          ),
        ),
      ),
    );
  }
}
