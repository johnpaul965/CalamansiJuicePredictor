import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool registerMode = false;
  bool busy = false;
  bool obscurePassword = true;
  String? error;

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    try {
      if (registerMode) {
        final message = await widget.auth.register(username.text, password.text);
        if (message == null) {
          setState(() { registerMode = false; busy = false; });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Account created. You can now log in.'),
                backgroundColor: CalamansiApp.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
          return;
        }
        setState(() { error = message; busy = false; });
        return;
      }
      final user = await widget.auth.login(username.text, password.text);
      if (user == null) {
        setState(() { error = 'Incorrect username or password.'; busy = false; });
        return;
      }
      widget.onSignedIn(user);
      if (mounted) setState(() => busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Something went wrong: $e';
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: CalamansiApp.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 32),
                  Text(
                    registerMode ? 'Create Account' : 'Welcome Back',
                    style: theme.textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    registerMode
                        ? 'Sign up to start predicting calamansi juice yield'
                        : 'Predict juice yield from your batch weight',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildTextField(
                    controller: username,
                    label: 'Username',
                    icon: Icons.person_outline_rounded,
                    inputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 14),
                  _buildPasswordField(),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xffFDECEA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xffD8483E), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!, style: const TextStyle(color: Color(0xffD8483E), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    child: busy
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(registerMode ? 'Create account' : 'Log in'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: busy ? null : () => setState(() { registerMode = !registerMode; error = null; }),
                    child: Text(registerMode ? 'Already have an account? Log in' : 'Create a user account'),
                  ),
                  if (!registerMode) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFF3D6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Admin demo: admin / admin123',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff7A5800), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [CalamansiApp.primary, CalamansiApp.primaryLight],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: CalamansiApp.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 38),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputAction inputAction = TextInputAction.done,
    bool obscure = false,
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      textInputAction: inputAction,
      obscureText: obscure,
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: CalamansiApp.primary, size: 22),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: password,
      obscureText: obscurePassword,
      onSubmitted: (_) => submit(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: Icon(Icons.lock_outline_rounded, color: CalamansiApp.primary, size: 22),
        suffixIcon: IconButton(
          icon: Icon(
            obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: CalamansiApp.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => obscurePassword = !obscurePassword),
        ),
      ),
    );
  }
}
