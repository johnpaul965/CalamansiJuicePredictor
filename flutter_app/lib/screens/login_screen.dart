import 'package:flutter/material.dart';
import '../models.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth, required this.onSignedIn});
  final AuthService auth; final void Function(AppUser user) onSignedIn;
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController(); final password = TextEditingController();
  bool registerMode = false, busy = false, hidePassword = true; String? error;
  @override void dispose() { username.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async {
    FocusScope.of(context).unfocus();
    if (username.text.trim().isEmpty || password.text.isEmpty) { setState(() => error = 'Please enter both fields.'); return; }
    setState(() { busy = true; error = null; });
    if (registerMode) {
      final message = await widget.auth.register(username.text, password.text);
      if (!mounted) return;
      if (message == null) { setState(() { registerMode = false; busy = false; password.clear(); }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created. You can now sign in.'))); }
      else setState(() { error = message; busy = false; });
      return;
    }
    final user = await widget.auth.login(username.text, password.text);
    if (!mounted) return;
    if (user == null) setState(() { error = 'Incorrect username or password.'; busy = false; }); else widget.onSignedIn(user);
  }
  @override Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: SingleChildScrollView(child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(26, 32, 26, 40), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xff0d946b), Color(0xff07523e)]), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.local_drink_rounded, color: Colors.white, size: 34)),
        const SizedBox(height: 30), Text(registerMode ? 'Start tracking your yield' : 'Welcome back', style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(registerMode ? 'Create an account to save your predictions.' : 'Turn every batch into a smarter decision.', style: const TextStyle(color: Color(0xffc8e9df), fontSize: 15)),
      ])),
      Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 30), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(registerMode ? 'Create your account' : 'Sign in to continue', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 20),
        TextField(controller: username, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline))), const SizedBox(height: 14),
        TextField(controller: password, obscureText: hidePassword, onSubmitted: (_) => submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
        if (registerMode) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Use at least 4 characters.', style: Theme.of(context).textTheme.bodySmall)),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(error!, style: TextStyle(color: colors.error))), const SizedBox(height: 22),
        FilledButton(onPressed: busy ? null : submit, child: Text(busy ? 'Please wait...' : registerMode ? 'Create account' : 'Sign in')), const SizedBox(height: 10),
        OutlinedButton(onPressed: busy ? null : () => setState(() { registerMode = !registerMode; error = null; password.clear(); }), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text(registerMode ? 'Already have an account? Sign in' : 'Create a user account')),
        const SizedBox(height: 24), const Text('Your predictions are stored securely in the shared project database.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xff7b8d84), fontSize: 12, height: 1.4)),
      ]))),
    ]))));
  }
}
