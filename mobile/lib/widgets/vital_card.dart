import 'package:flutter/material.dart';

class VitalCard extends StatelessWidget {
  final String label, unit;
  final double? value, secondaryValue;
  final IconData icon;
  final Color color;
  final double minVal, maxVal;
  const VitalCard({super.key, required this.label, required this.value,
    this.secondaryValue, required this.unit, required this.icon,
    required this.color, required this.minVal, required this.maxVal});

  bool get _alert => value != null && (value! < minVal || value! > maxVal);

  @override
  Widget build(BuildContext context) {
    final c = _alert ? Colors.red : color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: _alert ? Border.all(color: Colors.red, width: 2) : null,
        boxShadow: [BoxShadow(color: c.withOpacity(0.12),
          blurRadius: 12, offset: const Offset(0, 4))]),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: c.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: c, size: 18)),
          if (_alert) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
            child: const Text('!', style: TextStyle(color: Colors.white,
              fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          value == null
            ? SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: c))
            : Text(
                secondaryValue != null
                  ? '${value!.toStringAsFixed(0)}/${secondaryValue!.toStringAsFixed(0)}'
                  : value!.toStringAsFixed(1),
                style: TextStyle(fontSize: secondaryValue != null ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: _alert ? Colors.red : const Color(0xFF1A1C1C))),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Text(unit, style: TextStyle(fontSize: 10, color: c.withOpacity(0.7))),
        ]),
      ]),
    );
  }
}
