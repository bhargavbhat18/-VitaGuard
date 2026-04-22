import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalguard/config/app_config.dart';
import 'package:vitalguard/screens/dashboard_screen.dart';
import 'package:vitalguard/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LS();
}

class _LS extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass  = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;

  Future<void> _login() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Please enter email and password'); return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/auth/profile'),
        headers: {'Authorization': 'Bearer LKT01'});
      if (r.statusCode == 200) {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        final fullName = (body['full_name'] as String?)?.trim() ?? '';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', 'LKT01');
        if (fullName.isNotEmpty) {
          await prefs.setString('user_name', fullName);
        }
        if (mounted) Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => const DashboardScreen(userId: 'LKT01')));
      } else {
        setState(() => _error = 'No account found. Please create an account first.');
      }
    } catch (_) {
      setState(() => _error = 'Cannot reach server. Is backend running on port 8000?');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 56),
        Center(child: Container(width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.3), blurRadius: 16, offset: const Offset(0,6))]),
          child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 38))),
        const SizedBox(height: 18),
        const Center(child: Text('VITALGUARD', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
          color: Color(0xFFB6171E), letterSpacing: 3, fontStyle: FontStyle.italic))),
        const Center(child: Text('Sign in to your account',
          style: TextStyle(fontSize: 13, color: Color(0xFF5B403D), fontWeight: FontWeight.w500))),
        const SizedBox(height: 44),
        _Lbl('Email Address'),
        const SizedBox(height: 6),
        _Box(controller: _email, hint: 'you@example.com', icon: Icons.email_outlined, kb: TextInputType.emailAddress),
        const SizedBox(height: 16),
        _Lbl('Password'),
        const SizedBox(height: 6),
        Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
          child: TextField(controller: _pass, obscureText: _obscure,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(hintText: '••••••••',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20),
              suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure)),
              border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)))),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFFFDAD6), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFBA1A1A), fontSize: 12, fontWeight: FontWeight.w500))),
            ])),
        ],
        const SizedBox(height: 28),
        GestureDetector(onTap: _loading ? null : _login,
          child: Container(height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.35), blurRadius: 14, offset: const Offset(0,5))]),
            child: Center(child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))))),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: Divider(color: Colors.grey[200])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('or', style: TextStyle(color: Colors.grey[400], fontSize: 13))),
          Expanded(child: Divider(color: Colors.grey[200]))]),
        const SizedBox(height: 18),
        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
          child: Container(height: 54,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFB6171E).withOpacity(0.3)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
            child: const Center(child: Text('Create Account',
              style: TextStyle(color: Color(0xFFB6171E), fontSize: 15, fontWeight: FontWeight.w800))))),
        const SizedBox(height: 32),
        Center(child: Text('VitalGuard v2.0 · Phase 1 + Phase 2',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
        const SizedBox(height: 20),
      ]))));
}

class _Lbl extends StatelessWidget {
  final String t; const _Lbl(this.t);
  @override Widget build(BuildContext context) => Text(t,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1C1C)));
}

class _Box extends StatelessWidget {
  final TextEditingController controller; final String hint; final IconData icon; final TextInputType kb;
  const _Box({required this.controller, required this.hint, required this.icon, required this.kb});
  @override Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0,2))]),
    child: TextField(controller: controller, keyboardType: kb,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))));
}
