import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalguard/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: VitalGuardApp()));
}

class VitalGuardApp extends StatelessWidget {
  const VitalGuardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VitalGuard',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB6171E)),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1A1C1C),
        elevation: 0, centerTitle: true)),
    home: const SplashScreen(),
  );
}
