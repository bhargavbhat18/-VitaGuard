import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vitalguard/models/vitals_model.dart';

class FullReportScreen extends StatefulWidget {
  final VitalsModel? latestVitals;
  final List<VitalsModel> history;

  const FullReportScreen({
    super.key,
    required this.latestVitals,
    required this.history,
  });

  @override
  State<FullReportScreen> createState() => _FullReportScreenState();
}

class _FullReportScreenState extends State<FullReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Computed stats ─────────────────────────────────────────────
  double? _avg(double Function(VitalsModel) f) {
    if (widget.history.isEmpty) return null;
    return widget.history.map(f).reduce((a, b) => a + b) / widget.history.length;
  }

  double? _min(double Function(VitalsModel) f) {
    if (widget.history.isEmpty) return null;
    return widget.history.map(f).reduce((a, b) => a < b ? a : b);
  }

  double? _max(double Function(VitalsModel) f) {
    if (widget.history.isEmpty) return null;
    return widget.history.map(f).reduce((a, b) => a > b ? a : b);
  }

  int get _alertCount => widget.history.where((v) => v.alertTriggered).length;

  String _status(double? val, double lo, double hi) {
    if (val == null) return '—';
    if (val < lo || val > hi) return 'Abnormal';
    return 'Normal';
  }

  Color _statusColor(double? val, double lo, double hi) {
    if (val == null) return Colors.grey;
    if (val < lo || val > hi) return const Color(0xFFB6171E);
    return const Color(0xFF16a34a);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18,
            color: Color(0xFF1A1C1C)),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Full Health Report',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900,
            color: Color(0xFF1A1C1C))),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFFB6171E),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFB6171E),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          tabs: const [
            Tab(text: 'SUMMARY'),
            Tab(text: 'VITALS'),
            Tab(text: 'HISTORY'),
          ]),
      ),
      body: TabBarView(controller: _tabs, children: [
        _SummaryTab(screen: this),
        _VitalsTab(screen: this),
        _HistoryTab(history: widget.history),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 1 — SUMMARY
// ══════════════════════════════════════════════════════════════════
class _SummaryTab extends StatelessWidget {
  final _FullReportScreenState screen;
  const _SummaryTab({required this.screen});

  @override
  Widget build(BuildContext context) {
    final v = screen.widget.latestVitals;
    final h = screen.widget.history;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Report header ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A1C1C), Color(0xFF2D2F30)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.assignment_rounded,
                  color: Colors.white, size: 22)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VitalGuard Report',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w900)),
                Text(DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 12),
            Row(children: [
              _HeaderStat('Readings', '${h.length}'),
              _HeaderStat('Alerts', '${screen._alertCount}'),
              _HeaderStat('Status', h.isEmpty ? '—'
                : screen._alertCount == 0 ? 'Stable' : 'Caution'),
            ]),
          ])),

        const SizedBox(height: 20),

        // ── Overall health score ─────────────────────────────────
        _SectionTitle('Health Score'),
        const SizedBox(height: 12),
        _HealthScoreCard(history: h, alerts: screen._alertCount),
        const SizedBox(height: 20),

        // ── Current snapshot ─────────────────────────────────────
        _SectionTitle('Current Snapshot'),
        const SizedBox(height: 12),
        if (v == null)
          _EmptyCard('No current vitals — simulator may not be running.')
        else
          Column(children: [
            Row(children: [
              Expanded(child: _SnapshotTile('Heart Rate',
                '${v.heartRate.toStringAsFixed(0)} bpm',
                Icons.favorite_rounded, const Color(0xFFB6171E),
                screen._status(v.heartRate, 50, 110),
                screen._statusColor(v.heartRate, 50, 110))),
              const SizedBox(width: 12),
              Expanded(child: _SnapshotTile('SpO2',
                '${v.spo2.toStringAsFixed(1)}%',
                Icons.air_rounded, const Color(0xFF006578),
                screen._status(v.spo2, 92, 100),
                screen._statusColor(v.spo2, 92, 100))),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _SnapshotTile('Blood Pressure',
                '${v.bpSystolic.toStringAsFixed(0)}/${v.bpDiastolic.toStringAsFixed(0)}',
                Icons.water_drop_rounded, const Color(0xFF9B59B6),
                screen._status(v.bpSystolic, 80, 140),
                screen._statusColor(v.bpSystolic, 80, 140))),
              const SizedBox(width: 12),
              Expanded(child: _SnapshotTile('Glucose',
                '${v.glucose.toStringAsFixed(0)} mg/dL',
                Icons.water_drop_outlined, const Color(0xFFFF9F43),
                screen._status(v.glucose, 70, 180),
                screen._statusColor(v.glucose, 70, 180))),
            ]),
          ]),

        const SizedBox(height: 20),

        // ── Clinical notes ───────────────────────────────────────
        _SectionTitle('Clinical Notes'),
        const SizedBox(height: 12),
        _ClinicalNotes(vitals: v, alertCount: screen._alertCount, total: h.length),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 2 — VITALS STATISTICS
// ══════════════════════════════════════════════════════════════════
class _VitalsTab extends StatelessWidget {
  final _FullReportScreenState screen;
  const _VitalsTab({required this.screen});

  @override
  Widget build(BuildContext context) {
    if (screen.widget.history.isEmpty) {
      return Center(child: _EmptyCard('No readings yet. Keep the simulator running.'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _VitalStatCard(
          label: 'Heart Rate',
          unit: 'bpm',
          icon: Icons.favorite_rounded,
          color: const Color(0xFFB6171E),
          avg: screen._avg((v) => v.heartRate),
          min: screen._min((v) => v.heartRate),
          max: screen._max((v) => v.heartRate),
          normalRange: '50 – 110 bpm',
          values: screen.widget.history.map((v) => v.heartRate).toList(),
        ),
        const SizedBox(height: 16),
        _VitalStatCard(
          label: 'SpO2',
          unit: '%',
          icon: Icons.air_rounded,
          color: const Color(0xFF006578),
          avg: screen._avg((v) => v.spo2),
          min: screen._min((v) => v.spo2),
          max: screen._max((v) => v.spo2),
          normalRange: '≥ 92%',
          values: screen.widget.history.map((v) => v.spo2).toList(),
        ),
        const SizedBox(height: 16),
        _VitalStatCard(
          label: 'Blood Pressure',
          unit: 'mmHg systolic',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF9B59B6),
          avg: screen._avg((v) => v.bpSystolic),
          min: screen._min((v) => v.bpSystolic),
          max: screen._max((v) => v.bpSystolic),
          normalRange: '< 140 mmHg',
          values: screen.widget.history.map((v) => v.bpSystolic).toList(),
        ),
        const SizedBox(height: 16),
        _VitalStatCard(
          label: 'Glucose',
          unit: 'mg/dL',
          icon: Icons.water_drop_outlined,
          color: const Color(0xFFFF9F43),
          avg: screen._avg((v) => v.glucose),
          min: screen._min((v) => v.glucose),
          max: screen._max((v) => v.glucose),
          normalRange: '70 – 180 mg/dL',
          values: screen.widget.history.map((v) => v.glucose).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  TAB 3 — READING HISTORY
// ══════════════════════════════════════════════════════════════════
class _HistoryTab extends StatelessWidget {
  final List<VitalsModel> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(child: _EmptyCard('No readings recorded yet.'));
    }
    final reversed = history.reversed.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      itemCount: reversed.length,
      itemBuilder: (_, i) => _HistoryRow(reading: reversed[i], index: i),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  REUSABLE WIDGETS
// ══════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) => Text(title,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
      color: Color(0xFF5B403D), letterSpacing: 1.2));
}

class _HeaderStat extends StatelessWidget {
  final String label, value;
  const _HeaderStat(this.label, this.value);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900,
        color: Colors.white)),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.6))),
    ]));
}

class _HealthScoreCard extends StatelessWidget {
  final List<VitalsModel> history;
  final int alerts;
  const _HealthScoreCard({required this.history, required this.alerts});

  int get score {
    if (history.isEmpty) return 0;
    final alertRate = alerts / history.length;
    return ((1 - alertRate) * 100).round().clamp(0, 100);
  }

  Color get scoreColor {
    if (score >= 80) return const Color(0xFF16a34a);
    if (score >= 60) return const Color(0xFFFF9F43);
    return const Color(0xFFB6171E);
  }

  String get scoreLabel {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Fair';
    return 'Needs Attention';
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
    child: Row(children: [
      SizedBox(
        width: 72, height: 72,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value: history.isEmpty ? 0 : score / 100,
            strokeWidth: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(scoreColor)),
          Text('$score', style: TextStyle(fontSize: 20,
            fontWeight: FontWeight.w900, color: scoreColor)),
        ])),
      const SizedBox(width: 20),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(scoreLabel, style: TextStyle(fontSize: 18,
          fontWeight: FontWeight.w900, color: scoreColor)),
        const SizedBox(height: 4),
        Text('Based on ${history.length} readings · $alerts alert${alerts == 1 ? '' : 's'} recorded',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: history.isEmpty ? 0 : score / 100,
            minHeight: 6,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(scoreColor))),
      ])),
    ]));
}

class _SnapshotTile extends StatelessWidget {
  final String label, value, statusText;
  final IconData icon;
  final Color color, statusColor;
  const _SnapshotTile(this.label, this.value, this.icon, this.color,
      this.statusText, this.statusColor);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: color, size: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Text(statusText, style: TextStyle(
            fontSize: 9, fontWeight: FontWeight.w800, color: statusColor))),
      ]),
      const SizedBox(height: 10),
      Text(label, style: TextStyle(fontSize: 10,
        color: Colors.grey[500], fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 18,
        fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
    ]));
}

class _VitalStatCard extends StatelessWidget {
  final String label, unit, normalRange;
  final IconData icon;
  final Color color;
  final double? avg, min, max;
  final List<double> values;

  const _VitalStatCard({
    required this.label, required this.unit, required this.icon,
    required this.color, required this.avg, required this.min,
    required this.max, required this.normalRange, required this.values,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
          Text('Normal: $normalRange',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ]),
      const SizedBox(height: 16),
      // Mini sparkline
      _MiniLine(values: values, color: color),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _StatPill('AVG', avg?.toStringAsFixed(1) ?? '—', unit, color)),
        const SizedBox(width: 8),
        Expanded(child: _StatPill('MIN', min?.toStringAsFixed(1) ?? '—', unit, Colors.grey.shade600)),
        const SizedBox(width: 8),
        Expanded(child: _StatPill('MAX', max?.toStringAsFixed(1) ?? '—', unit, const Color(0xFFB6171E))),
      ]),
    ]));
}

class _StatPill extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatPill(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F6FA), borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
        color: Colors.grey[500])),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      Text(unit, style: TextStyle(fontSize: 8, color: Colors.grey[400])),
    ]));
}

class _MiniLine extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _MiniLine({required this.values, required this.color});
  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return Container(height: 50,
        decoration: BoxDecoration(color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8)),
        child: Center(child: Text('Not enough data',
          style: TextStyle(color: Colors.grey[400], fontSize: 11))));
    }
    return SizedBox(height: 50,
      child: CustomPaint(size: Size.infinite,
        painter: _LinePainter(values: values, color: color)));
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values; final Color color;
  _LinePainter({required this.values, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final mn = values.reduce((a,b) => a<b?a:b) - 1;
    final mx = values.reduce((a,b) => a>b?a:b) + 1;
    final range = (mx - mn).clamp(1.0, double.infinity);
    double x(int i) => i / (values.length - 1) * size.width;
    double y(double v) => size.height - ((v - mn) / range * size.height);
    final fill = Path()..moveTo(x(0), size.height)..lineTo(x(0), y(values[0]));
    final line = Path()..moveTo(x(0), y(values[0]));
    for (int i = 1; i < values.length; i++) {
      final cx = (x(i-1) + x(i)) / 2;
      line.cubicTo(cx, y(values[i-1]), cx, y(values[i]), x(i), y(values[i]));
      fill.cubicTo(cx, y(values[i-1]), cx, y(values[i]), x(i), y(values[i]));
    }
    fill..lineTo(x(values.length-1), size.height)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.15), Colors.transparent])
        .createShader(Rect.fromLTWH(0,0,size.width,size.height))
      ..style = PaintingStyle.fill);
    canvas.drawPath(line, Paint()
      ..color = color ..strokeWidth = 2
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round);
  }
  @override bool shouldRepaint(_LinePainter o) => o.values != values;
}

class _HistoryRow extends StatelessWidget {
  final VitalsModel reading;
  final int index;
  const _HistoryRow({required this.reading, required this.index});

  @override
  Widget build(BuildContext context) {
    final isAlert = reading.alertTriggered;
    final time = reading.timestamp?.toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFFFF5F5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isAlert ? const Color(0xFFB6171E).withOpacity(0.2) : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Container(width: 8, height: 8,
              decoration: BoxDecoration(
                color: isAlert ? const Color(0xFFB6171E) : const Color(0xFF16a34a),
                shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(isAlert ? 'Alert Triggered' : 'Routine Checkpoint',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
                color: isAlert ? const Color(0xFFB6171E) : const Color(0xFF16a34a))),
          ]),
          Text(
            time != null ? DateFormat('hh:mm:ss a').format(time) : '--',
            style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          _VChip('HR', '${reading.heartRate.toStringAsFixed(0)} bpm',
            reading.heartRate > 110 || reading.heartRate < 50),
          _VChip('SpO2', '${reading.spo2.toStringAsFixed(1)}%',
            reading.spo2 < 92),
          _VChip('BP', '${reading.bpSystolic.toStringAsFixed(0)}/${reading.bpDiastolic.toStringAsFixed(0)}',
            reading.bpSystolic > 140),
          _VChip('Glucose', '${reading.glucose.toStringAsFixed(0)} mg/dL',
            reading.glucose > 180 || reading.glucose < 70),
        ]),
        if (isAlert && reading.alertMessage != null) ...[
          const SizedBox(height: 8),
          Text(reading.alertMessage!, style: const TextStyle(
            fontSize: 11, color: Color(0xFFB6171E), fontStyle: FontStyle.italic)),
        ],
      ]));
  }
}

class _VChip extends StatelessWidget {
  final String label, value; final bool alert;
  const _VChip(this.label, this.value, this.alert);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: alert ? const Color(0xFFFFDAD6) : const Color(0xFFF4F6FA),
      borderRadius: BorderRadius.circular(8)),
    child: RichText(text: TextSpan(
      style: const TextStyle(fontSize: 11),
      children: [
        TextSpan(text: '$label: ', style: TextStyle(
          color: Colors.grey[500], fontWeight: FontWeight.w500)),
        TextSpan(text: value, style: TextStyle(
          color: alert ? const Color(0xFFB6171E) : const Color(0xFF1A1C1C),
          fontWeight: FontWeight.w800)),
      ])));
}

class _ClinicalNotes extends StatelessWidget {
  final VitalsModel? vitals;
  final int alertCount, total;
  const _ClinicalNotes({this.vitals, required this.alertCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final notes = <String>[];
    if (total == 0) {
      notes.add('No readings collected yet. Ensure the simulator is active.');
    } else {
      final rate = (alertCount / total * 100).toStringAsFixed(0);
      notes.add('$alertCount alert${alertCount == 1 ? '' : 's'} detected in $total readings ($rate% alert rate).');
      if (alertCount == 0) {
        notes.add('All monitored vitals remained within safe thresholds.');
      }
      if (vitals != null) {
        if (vitals!.heartRate > 110) notes.add('Current HR (${vitals!.heartRate.toStringAsFixed(0)} bpm) is elevated — consider rest and beta-blocker if prescribed.');
        if (vitals!.heartRate < 50) notes.add('Current HR (${vitals!.heartRate.toStringAsFixed(0)} bpm) is below normal — monitor for symptoms.');
        if (vitals!.spo2 < 92) notes.add('SpO2 (${vitals!.spo2.toStringAsFixed(1)}%) is below safe level — use rescue inhaler or seek medical attention.');
        if (vitals!.bpSystolic > 140) notes.add('BP (${vitals!.bpSystolic.toStringAsFixed(0)}/${vitals!.bpDiastolic.toStringAsFixed(0)} mmHg) is elevated — rest and take prescribed antihypertensive.');
        if (vitals!.glucose > 180) notes.add('Glucose (${vitals!.glucose.toStringAsFixed(0)} mg/dL) is high — take prescribed insulin and avoid carbohydrates.');
        if (vitals!.glucose < 70) notes.add('Glucose (${vitals!.glucose.toStringAsFixed(0)} mg/dL) is critically low — consume 15g of sugar immediately.');
      }
      notes.add('Continue regular monitoring. Share this report with your healthcare provider.');
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: notes.map((n) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: Color(0xFFB6171E), fontSize: 14)),
            Expanded(child: Text(n, style: const TextStyle(
              fontSize: 13, color: Color(0xFF333333), height: 1.5))),
          ]))).toList()));
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(16)),
    child: Column(children: [
      Icon(Icons.info_outline_rounded, color: Colors.grey[300], size: 40),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
    ]));
}
