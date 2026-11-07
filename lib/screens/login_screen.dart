import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'mode_select_screen.dart';

/// Entry point for authentication — supports Google Sign-In, email/password
/// login, and new account registration. Navigates to [ModeSelectScreen] on success.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _goHome() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ModeSelectScreen()),
      );

  Future<void> _googleSignIn() async {
    setState(() => _loading = true);
    try {
      await FirebaseService.signInWithGoogle();
      if (mounted) _goHome();
    } catch (e) {
      if (mounted) _snack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _emailAction() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _snack('Enter email and password');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await FirebaseService.registerWithEmail(email, pass);
      } else {
        await FirebaseService.signInWithEmail(email, pass);
      }
      if (mounted) _goHome();
    } on FirebaseAuthException catch (e) {
      if (mounted) _snack(_authMsg(e.code));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _authMsg(String code) => switch (code) {
        'user-not-found' => 'No account found with that email',
        'wrong-password' || 'invalid-credential' =>
          'Incorrect email or password',
        'email-already-in-use' =>
          'Email already registered — sign in instead',
        'weak-password' => 'Password must be at least 6 characters',
        'invalid-email' => 'Invalid email address',
        _ => 'Error: $code',
      };

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.sports_cricket, color: cs.onSurface, size: 58),
                  const SizedBox(height: 14),
                  Text(
                    'Cricket Scoreboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      _isRegister
                          ? 'Create your account'
                          : 'Sign in to continue',
                      key: ValueKey(_isRegister),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 36),
                  _googleBtn(cs),
                  const SizedBox(height: 20),
                  _orDivider(cs),
                  const SizedBox(height: 20),
                  _inputField(
                    cs: cs,
                    ctrl: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _inputField(
                    cs: cs,
                    ctrl: _passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: cs.onSurface.withValues(alpha: 0.45),
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton(
                    onPressed: _loading ? null : _emailAction,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    child: _loading
                        ? SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: cs.onPrimary, strokeWidth: 2))
                        : Text(_isRegister ? 'Create Account' : 'Sign In'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister
                            ? 'Already have an account?'
                            : "Don't have an account?",
                        style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.55),
                            fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister ? 'Sign In' : 'Register',
                          style: TextStyle(
                              color: cs.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold),
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
    );
  }

  Widget _googleBtn(ColorScheme cs) => OutlinedButton(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: cs.onSurface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text('G',
                    style: TextStyle(
                        color: cs.surface,
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Text('Continue with Google',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.8), fontSize: 15)),
          ],
        ),
      );

  Widget _orDivider(ColorScheme cs) => Row(children: [
        Divider(color: cs.outlineVariant, endIndent: 0),
        Expanded(child: Divider(color: cs.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR',
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.35),
                  fontSize: 11,
                  letterSpacing: 1)),
        ),
        Expanded(child: Divider(color: cs.outlineVariant)),
      ]);

  Widget _inputField({
    required ColorScheme cs,
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscure = false,
    Widget? suffix,
  }) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffix,
        ),
      );
}
