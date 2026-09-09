import 'package:flutter/material.dart';
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
  String? error;

  Future<void> submit() async {
    setState(() { busy = true; error = null; });
    if (registerMode) {
      final message = await widget.auth.register(username.text, password.text);
      if (message == null) {
        setState(() { registerMode = false; busy = false; });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. You can now log in.')));
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(24)),
                    child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 52),
                  ),
                  const SizedBox(height: 28),
                  Text('Calamansi Yield', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(registerMode ? 'Create a simple account' : 'Predict juice yield from your batch weight.'),
                  const SizedBox(height: 28),
                  TextField(controller: username, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))),
                  const SizedBox(height: 16),
                  TextField(controller: password, obscureText: true, onSubmitted: (_) => submit(), decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline))),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    Text(error!, style: TextStyle(color: theme.colorScheme.error)),
                  ],
                  const SizedBox(height: 22),
                  FilledButton(onPressed: busy ? null : submit, child: Padding(padding: const EdgeInsets.all(14), child: Text(busy ? 'Please wait...' : registerMode ? 'Create account' : 'Log in'))),
                  const SizedBox(height: 10),
                  TextButton(onPressed: busy ? null : () => setState(() { registerMode = !registerMode; error = null; }), child: Text(registerMode ? 'Already have an account? Log in' : 'Create a user account')),
                  if (!registerMode) const Padding(padding: EdgeInsets.only(top: 18), child: Text('Admin demo account: admin / admin123', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
