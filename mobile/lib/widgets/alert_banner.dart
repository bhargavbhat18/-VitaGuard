import 'package:flutter/material.dart';

class AlertBanner extends StatelessWidget {
  final String message;
  const AlertBanner({super.key, required this.message});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, color: const Color(0xFFB6171E),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message, style: const TextStyle(
        color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13))),
    ]));
}
