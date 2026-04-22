import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalguard/screens/login_screen.dart';
import 'package:vitalguard/screens/dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SS();
}

class _SS extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _fade;
  @override void initState() { super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeIn);
    _ac.forward(); _check(); }
  @override void dispose() { _ac.dispose(); super.dispose(); }

  Future<void> _check() async {
    await Future.delayed(const Duration(seconds: 2));
    final prefs  = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => userId != null ? DashboardScreen(userId: userId) : const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: FadeTransition(opacity: _fade,
      child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 90, height: 90,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.3), blurRadius: 20, offset: const Offset(0,8))]),
          child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 48)),
        const SizedBox(height: 24),
        const Text('VITALGUARD', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: Color(0xFFB6171E), letterSpacing: 3, fontStyle: FontStyle.italic)),
        const SizedBox(height: 8),
        const Text('Real-Time Health Monitoring', style: TextStyle(fontSize: 14,
          color: Color(0xFF5B403D), fontWeight: FontWeight.w500)),
        const SizedBox(height: 48),
        const SizedBox(width: 28, height: 28,
          child: CircularProgressIndicator(color: Color(0xFFB6171E), strokeWidth: 2.5)),
      ]))));
}
