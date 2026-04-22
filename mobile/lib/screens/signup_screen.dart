import 'package:flutter/material.dart';
import 'package:vitalguard/screens/profile_setup_screen.dart';
import 'package:vitalguard/screens/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override State<SignupScreen> createState() => _SGS();
}

class _SGS extends State<SignupScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  final _conf  = TextEditingController();
  bool _o1 = true, _o2 = true;
  String? _error;

  void _next() {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = 'Enter a valid email address'); return;
    }
    if (_pass.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters'); return;
    }
    if (_pass.text != _conf.text) {
      setState(() => _error = 'Passwords do not match'); return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => ProfileSetupScreen(uid: 'LKT01', email: _email.text.trim())));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 16),
        GestureDetector(onTap: () => Navigator.pop(context),
          child: Container(width: 40, height: 40,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0,2))]),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Color(0xFF1A1C1C)))),
        const SizedBox(height: 24),
        const Text('Create Account', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: Color(0xFF1A1C1C), letterSpacing: -0.5)),
        const Text('Join VitalGuard — monitor your health in real time',
          style: TextStyle(fontSize: 13, color: Color(0xFF5B403D), fontWeight: FontWeight.w500)),
        const SizedBox(height: 28),
        // Step indicator
        Row(children: [
          _StepDot(n: 1, active: true), Container(width: 40, height: 3,
            color: const Color(0xFFB6171E), margin: const EdgeInsets.symmetric(horizontal: 6)),
          _StepDot(n: 2, active: false),
          const SizedBox(width: 12),
          Text('Step 1 of 2 — Account Details',
            style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 24),
        _SLbl('Email Address'),
        const SizedBox(height: 6),
        _SBox(controller: _email, hint: 'you@example.com', icon: Icons.email_outlined, kb: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _SLbl('Password'),
        const SizedBox(height: 6),
        _PBox(controller: _pass, hint: 'Min. 6 characters', obscure: _o1, onToggle: () => setState(() => _o1 = !_o1)),
        const SizedBox(height: 16),
        _SLbl('Confirm Password'),
        const SizedBox(height: 6),
        _PBox(controller: _conf, hint: 'Re-enter password', obscure: _o2, onToggle: () => setState(() => _o2 = !_o2)),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 16), const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12, fontWeight: FontWeight.w500))),
            ])),
        ],
        const SizedBox(height: 28),
        GestureDetector(onTap: _next,
          child: Container(height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.35), blurRadius: 14, offset: const Offset(0,5))]),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Next — Profile Setup', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ]))),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Already have an account? ', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          GestureDetector(onTap: () => Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const LoginScreen())),
            child: const Text('Sign In', style: TextStyle(color: Color(0xFFB6171E), fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 32),
      ]))));
}

class _StepDot extends StatelessWidget {
  final int n; final bool active;
  const _StepDot({required this.n, required this.active});
  @override Widget build(BuildContext context) => Container(width: 28, height: 28,
    decoration: BoxDecoration(color: active ? const Color(0xFFB6171E) : const Color(0xFFE8E8E8), shape: BoxShape.circle),
    child: Center(child: Text('$n', style: TextStyle(color: active ? Colors.white : Colors.grey[500],
      fontSize: 12, fontWeight: FontWeight.w800))));
}

class _SLbl extends StatelessWidget {
  final String t; const _SLbl(this.t);
  @override Widget build(BuildContext context) => Text(t,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1C)));
}

class _SBox extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData icon; final TextInputType kb;
  const _SBox({required this.controller, required this.hint, required this.icon, required this.kb});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
    child: TextField(controller: controller, keyboardType: kb,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))));
}

class _PBox extends StatelessWidget {
  final TextEditingController controller; final String hint; final bool obscure; final VoidCallback onToggle;
  const _PBox({required this.controller, required this.hint, required this.obscure, required this.onToggle});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
    child: TextField(controller: controller, obscureText: obscure,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20), onPressed: onToggle),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))));
}
