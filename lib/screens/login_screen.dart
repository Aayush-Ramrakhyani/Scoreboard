import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'mode_select_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFF1B3A2D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  const Icon(Icons.sports_cricket,
                      color: Colors.greenAccent, size: 58),
                  const SizedBox(height: 14),
                  const Text(
                    'Cricket Scoreboard',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
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
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Google Sign-In ───────────────────────────────────────
                  _googleBtn(),
                  const SizedBox(height: 20),
                  _orDivider(),
                  const SizedBox(height: 20),

                  // ── Email ────────────────────────────────────────────────
                  _inputField(
                    ctrl: _emailCtrl,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  _inputField(
                    ctrl: _passCtrl,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _obscure,
                    suffix: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: Colors.white38,
                          size: 20),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  const SizedBox(height: 22),

                  ElevatedButton(
                    onPressed: _loading ? null : _emailAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Colors.green.shade900,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(_isRegister
                            ? 'Create Account'
                            : 'Sign In'),
                  ),
                  const SizedBox(height: 16),

                  // Toggle register / login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isRegister
                            ? 'Already have an account?'
                            : "Don't have an account?",
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _isRegister = !_isRegister),
                        child: Text(
                          _isRegister ? 'Sign In' : 'Register',
                          style: const TextStyle(
                              color: Colors.greenAccent,
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

  Widget _googleBtn() => OutlinedButton(
        onPressed: _loading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.white24),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: Colors.white.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(
                child: Text('G',
                    style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 14,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Continue with Google',
                style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      );

  Widget _orDivider() => Row(children: [
        const Expanded(child: Divider(color: Colors.white12)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('OR',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontSize: 11,
                  letterSpacing: 1)),
        ),
        const Expanded(child: Divider(color: Colors.white12)),
      ]);

  Widget _inputField({
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
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          suffixIcon: suffix,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.green.shade800),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(
                color: Colors.greenAccent, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: const Color(0xFF0D2B1E),
        ),
      );
}
