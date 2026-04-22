import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalguard/models/vitals_model.dart';
import 'package:vitalguard/providers/vitals_provider.dart';
import 'package:vitalguard/screens/sos_screen.dart';
import 'package:vitalguard/screens/medication_screen.dart';
import 'package:vitalguard/screens/ambulance_map_screen.dart';
import 'package:vitalguard/screens/med_ai_chat_screen.dart';
import 'package:vitalguard/screens/full_report_screen.dart';
import 'package:vitalguard/screens/telehealth_screen.dart';
import 'package:vitalguard/services/sos_service.dart';
import 'package:vitalguard/services/threshold_service.dart';
import 'package:vitalguard/services/notification_service.dart';
import 'package:vitalguard/widgets/alert_banner.dart';
import 'package:geolocator/geolocator.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});
  @override ConsumerState<DashboardScreen> createState() => _DashState();
}

class _DashState extends ConsumerState<DashboardScreen> {
  int _tab = 0;
  bool _sosShowing = false;
  String? _lastAlert;
  final List<VitalsModel> _history = [];

  @override
  void initState() {
    super.initState();
    NotificationService().initialize();
    _connectTelehealth();
  }

  void _connectTelehealth() {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8000/ws/telehealth/${widget.userId}'),
    );
    channel.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'signal' && data['data']['sdp'] != null && data['data']['sdp']['type'] == 'offer') {
        _showIncomingCall(data['from'], data['data']['sdp']);
      } else if (data['type'] == 'chat') {
        NotificationService().showNotification('Doctor Message', data['data']['text']);
      }
    });
  }

  void _showIncomingCall(String doctorId, dynamic sdp) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Incoming Call', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Dr. Anand Rao is calling for a telehealth consultation.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('DECLINE', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => TelehealthScreen(
                userId: widget.userId,
                doctorId: doctorId,
                initialSdp: sdp,
              )));
            },
            child: const Text('ACCEPT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onAlert(VitalsModel v) {
    ThresholdService.checkAndNotify(v);
    if (v.alertTriggered && v.alertMessage != _lastAlert && !_sosShowing) {
      _lastAlert = v.alertMessage; _sosShowing = true;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SosScreen(
          alertMessage: v.alertMessage ?? 'Critical vitals detected',
          onCancelled: () { setState(() => _sosShowing = false); Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('SOS cancelled — monitoring continues'), backgroundColor: Colors.green)); },
          onSosTriggered: () async {
            double lat = 12.9716, lng = 77.5946;
            try {
              final p = await Geolocator.getCurrentPosition();
              lat = p.latitude; lng = p.longitude;
            } catch (_) {}

            final data = await SosService().triggerSos(v.alertMessage ?? 'Emergency', lat: lat, lng: lng);
            setState(() => _sosShowing = false);
            if (mounted) {
              Navigator.pop(context);
              if (data != null && data['sos_id'] != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  AmbulanceMapScreen(sosId: data['sos_id'],
                    patientLat: lat, patientLng: lng,
                    hospitalName: data['hospital']?['name'] ?? 'Apollo Hospital')));
              }
            }
          }))).then((_) => setState(() => _sosShowing = false));
    }
  }

  @override
  Widget build(BuildContext context) {
    final va = ref.watch(vitalsStreamProvider(widget.userId));
    final vitals = va.asData?.value;
    if (vitals != null) {
      if (_history.isEmpty || _history.last.timestamp != vitals.timestamp) {
        _history.add(vitals); if (_history.length > 24) _history.removeAt(0);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _onAlert(vitals));
    }

    final pages = [
      _HomePage(vitals: vitals, history: _history),
      _TrendsPage(history: _history),
      MedicationScreen(vitals: vitals),
      _ProfilePage(userId: widget.userId, history: _history),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: pages[_tab],
      bottomNavigationBar: _BottomBar(selected: _tab,
        onTap: (i) => setState(() => _tab = i)));
  }
}

// ── Bottom Nav ─────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int selected; final void Function(int) onTap;
  const _BottomBar({required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.9),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
        blurRadius: 20, offset: const Offset(0, -6))]),
    child: SafeArea(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(children: [
        _NI(Icons.home_rounded, 'Home', 0, selected, onTap),
        _NI(Icons.insights_rounded, 'Trends', 1, selected, onTap),
        _NI(Icons.medication_rounded, 'Meds', 2, selected, onTap),
        _NI(Icons.person_rounded, 'Profile', 3, selected, onTap),
      ]))));
}

class _NI extends StatelessWidget {
  final IconData icon; final String label; final int idx, sel;
  final void Function(int) onTap;
  const _NI(this.icon, this.label, this.idx, this.sel, this.onTap);
  @override
  Widget build(BuildContext context) {
    final a = idx == sel;
    return Expanded(child: GestureDetector(
      onTap: () => onTap(idx),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: a ? const Color(0xFFFFDAD6) : Colors.transparent,
          borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: a ? const Color(0xFFB6171E) : Colors.grey[400]),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(fontSize: 10,
            fontWeight: a ? FontWeight.w800 : FontWeight.w500,
            color: a ? const Color(0xFFB6171E) : Colors.grey[400])),
        ]))));
  }
}

// ── Home Page ──────────────────────────────────────────────────
class _HomePage extends StatelessWidget {
  final VitalsModel? vitals; final List<VitalsModel> history;
  const _HomePage({this.vitals, required this.history});
  bool get _alert => vitals?.alertTriggered ?? false;

  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20,16,20,0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          const Icon(Icons.monitor_heart_rounded, color: Color(0xFFB6171E), size: 22),
          const SizedBox(width: 8),
          const Text('VITALGUARD', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w900, color: Color(0xFFB6171E),
            letterSpacing: 1, fontStyle: FontStyle.italic)),
        ]),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
            borderRadius: BorderRadius.circular(25)),
          child: Material(color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(25),
              onTap: () {},
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                child: Text('SOS', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)))))),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFFB6171E)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TelehealthScreen(
            userId: vitals?.userId ?? 'Unknown',
            doctorId: 'DOC_001',
          ))),
        ),
      ]))),

    SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20,18,20,0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('MONITORING ACTIVE', style: TextStyle(fontSize: 10,
          color: Colors.grey[500], fontWeight: FontWeight.w700, letterSpacing: 2)),
        const SizedBox(height: 4),
        const Text('System Status', style: TextStyle(fontSize: 30,
          fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C), letterSpacing: -0.5)),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(children: [
            _PulseDot(color: _alert ? const Color(0xFFB6171E) : const Color(0xFF006578)),
            const SizedBox(width: 10),
            Text(_alert ? 'Alert Detected' : 'All Normal',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17,
                color: _alert ? const Color(0xFFB6171E) : const Color(0xFF006578))),
          ])),
      ]))),

    if (_alert) SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.fromLTRB(20,12,20,0),
      child: AlertBanner(message: vitals?.alertMessage ?? 'Abnormal vitals detected'))),

    SliverPadding(padding: const EdgeInsets.all(20),
      sliver: SliverList(delegate: SliverChildListDelegate([
        _HRCard(value: vitals?.heartRate, history: history),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _SmallCard('SPO2', vitals?.spo2, '%',
            Icons.air_rounded, const Color(0xFF006578), 92, 100)),
          const SizedBox(width: 12),
          Expanded(child: _BPCard(sys: vitals?.bpSystolic, dia: vitals?.bpDiastolic)),
        ]),
        const SizedBox(height: 14),
        _GlucoseCard(value: vitals?.glucose),
        const SizedBox(height: 14),
        _DarkCard(vitals: vitals, history: history),
        const SizedBox(height: 8),
        Center(child: Text(
          vitals != null
            ? 'Live · Updated ${vitals!.timestamp?.toLocal().toString().substring(11,19) ?? "--"}'
            : 'Waiting for simulator...',
          style: TextStyle(fontSize: 11, color: Colors.grey[400]))),
        const SizedBox(height: 16),
      ]))),
  ]));
}

class _PulseDot extends StatefulWidget {
  final Color color; const _PulseDot({required this.color});
  @override State<_PulseDot> createState() => _PulseDotState();
}
class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override void initState() { super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => SizedBox(width: 14, height: 14,
    child: Stack(alignment: Alignment.center, children: [
      ScaleTransition(scale: Tween(begin: 1.0, end: 2.2).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeOut)),
        child: Container(width: 8, height: 8,
          decoration: BoxDecoration(color: widget.color.withOpacity(0.3), shape: BoxShape.circle))),
      Container(width: 8, height: 8,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    ]));
}

class _HRCard extends StatefulWidget {
  final double? value; final List<VitalsModel> history;
  const _HRCard({this.value, required this.history});
  @override State<_HRCard> createState() => _HRCardState();
}
class _HRCardState extends State<_HRCard> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;
  @override void initState() { super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _a = Tween(begin: 1.0, end: 1.18).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  bool get _alert => widget.value != null && (widget.value! > 110 || widget.value! < 50);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0,6))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('HEART RATE', style: TextStyle(fontSize: 10, color: Colors.grey[500],
            fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(widget.value?.toStringAsFixed(1) ?? '--',
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900,
                color: _alert ? const Color(0xFFB6171E) : const Color(0xFFB6171E), letterSpacing: -2)),
            const SizedBox(width: 6),
            Text('bpm', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ]),
        ]),
        ScaleTransition(scale: _a, child: Icon(Icons.favorite_rounded,
          size: 48, color: const Color(0xFFDA3433).withOpacity(0.25))),
      ]),
      const SizedBox(height: 16),
      _BarSpark(values: widget.history.map((v) => v.heartRate).toList()),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Last 24 hours', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _alert ? const Color(0xFFFFDAD6) : const Color(0xFFE0F5F0),
            borderRadius: BorderRadius.circular(20)),
          child: Text(_alert ? 'ALERT' : 'Normal',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: _alert ? const Color(0xFFB6171E) : const Color(0xFF006578)))),
      ]),
    ]));
}



class _BarSpark extends StatelessWidget {
  final List<double> values; const _BarSpark({required this.values});
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return Row(crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(9, (i) => Expanded(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        height: 14.0 + i * 7,
        decoration: BoxDecoration(color: const Color(0xFFB6171E).withOpacity(0.08 + i * 0.04),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))))));
    final min = values.reduce((a,b) => a<b?a:b);
    final max = values.reduce((a,b) => a>b?a:b);
    final range = (max - min).clamp(1.0, double.infinity);
    return SizedBox(height: 80, child: Row(crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((v) {
        final r = (v - min) / range;
        final last = v == values.last;
        return Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          height: 16 + r * 60,
          decoration: BoxDecoration(
            color: last ? const Color(0xFFB6171E) : const Color(0xFFB6171E).withOpacity(0.12 + r * 0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))));
      }).toList()));
  }
}

class _SmallCard extends StatelessWidget {
  final String label; final double? value; final String unit;
  final IconData icon; final Color color; final double min, max;
  const _SmallCard(this.label, this.value, this.unit, this.icon, this.color, this.min, this.max);
  bool get _alert => value != null && (value! < min || value! > max);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Icon(icon, color: _alert ? const Color(0xFFB6171E) : color, size: 22),
        if (!_alert) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text('OPTIMAL', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
            letterSpacing: 1, color: color))),
      ]),
      const SizedBox(height: 14),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500],
        fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Text(value?.toStringAsFixed(1) ?? '--', style: TextStyle(fontSize: 36,
          fontWeight: FontWeight.w900,
          color: _alert ? const Color(0xFFB6171E) : const Color(0xFF1A1C1C))),
        Text(' $unit', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
      ]),
    ]));
}

class _BPCard extends StatelessWidget {
  final double? sys, dia; const _BPCard({this.sys, this.dia});
  bool get _alert => sys != null && sys! > 140;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.water_drop_rounded, color: _alert ? const Color(0xFFB6171E) : Colors.grey[500], size: 22),
      const SizedBox(height: 14),
      Text('BLOOD PRESSURE', style: TextStyle(fontSize: 10, color: Colors.grey[500],
        fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      const SizedBox(height: 4),
      Text(sys != null ? '${sys!.toStringAsFixed(0)}/${dia!.toStringAsFixed(0)}' : '--',
        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
          color: _alert ? const Color(0xFFB6171E) : const Color(0xFF1A1C1C))),
      Text('mmHg', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
    ]));
}

class _GlucoseCard extends StatelessWidget {
  final double? value; const _GlucoseCard({this.value});
  bool get _alert => value != null && (value! > 180 || value! < 70);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: const Color(0xFFE2E2E2), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('GLUCOSE', style: TextStyle(fontSize: 10, color: Colors.grey[600],
          fontWeight: FontWeight.w600, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value?.toStringAsFixed(1) ?? '--', style: TextStyle(fontSize: 40,
            fontWeight: FontWeight.w900,
            color: _alert ? const Color(0xFFB6171E) : const Color(0xFF1A1C1C))),
          Text(' mg/dL', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ]),
        Row(children: [
          Icon(Icons.schedule_rounded, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(_alert ? 'Threshold exceeded' : '2h post-meal',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
      ]),
      Container(width: 52, height: 52,
        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
        child: Icon(Icons.water_drop_rounded,
          color: _alert ? const Color(0xFFB6171E) : const Color(0xFFB6171E), size: 24)),
    ]));
}

class _DarkCard extends StatelessWidget {
  final VitalsModel? vitals;
  final List<VitalsModel> history;
  const _DarkCard({this.vitals, required this.history});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: const Color(0xFF1A1C1C), borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Predictive Health Analysis', style: TextStyle(fontSize: 22,
        fontWeight: FontWeight.w900, color: Colors.white)),
      const SizedBox(height: 10),
      Text(vitals?.alertTriggered ?? false
        ? 'Critical vitals detected. Emergency services can be dispatched.'
        : 'Based on last 24 readings. Cardiovascular trend is stabilizing.',
        style: const TextStyle(fontSize: 13, color: Colors.white60, height: 1.6)),
      const SizedBox(height: 16),
      // ── AI Assistant Banner ────────────────────────────────
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => MedAiChatScreen(vitals: vitals))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withOpacity(0.4),
              blurRadius: 12, offset: const Offset(0, 4))]),
          child: Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.assistant_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ask MedAI', style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              Text(
                vitals != null
                  ? 'Get personalised medication advice'
                  : 'Ask about medications & conditions',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
            ])),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ]))),
      // ── View Full Report button ────────────────────────────
      GestureDetector(
        onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => FullReportScreen(
            latestVitals: vitals, history: history))),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF006578),
            borderRadius: BorderRadius.circular(25)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.assignment_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Text('VIEW FULL REPORT', style: TextStyle(color: Colors.white,
              fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ]))),
    ]));
}

// ── Trends Page ────────────────────────────────────────────────
class _TrendsPage extends StatefulWidget {
  final List<VitalsModel> history; const _TrendsPage({required this.history});
  @override State<_TrendsPage> createState() => _TrendsPageState();
}
class _TrendsPageState extends State<_TrendsPage> {
  String _sel = 'Heart Rate';
  static const _chips = ['Heart Rate','SpO2','BP Systolic','Glucose'];
  static const _colors = {'Heart Rate':Color(0xFFB6171E),'SpO2':Color(0xFF006578),
    'BP Systolic':Color(0xFF9B59B6),'Glucose':Color(0xFFFF9F43)};
  static const _units = {'Heart Rate':'bpm','SpO2':'%','BP Systolic':'mmHg','Glucose':'mg/dL'};
  double _get(VitalsModel v) { switch(_sel) {
    case 'Heart Rate': return v.heartRate; case 'SpO2': return v.spo2;
    case 'BP Systolic': return v.bpSystolic; default: return v.glucose; }}
  @override
  Widget build(BuildContext context) {
    final c = _colors[_sel]!; final unit = _units[_sel]!;
    final data = widget.history.reversed.toList();
    final vals = data.map(_get).toList();
    return SafeArea(child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20,16,20,0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('WEEKLY ANALYSIS', style: TextStyle(fontSize: 10, color: Color(0xFF5B403D),
            fontWeight: FontWeight.w700, letterSpacing: 2)),
          const Text('Health Trends', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
            color: Color(0xFF1A1C1C), letterSpacing: -0.5)),
          const SizedBox(height: 16),
          SingleChildScrollView(scrollDirection: Axis.horizontal,
            child: Row(children: _chips.map((ch) {
              final sel = ch == _sel; final cc = _colors[ch]!;
              return GestureDetector(onTap: () => setState(() => _sel = ch),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? cc : Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: sel ? [BoxShadow(color: cc.withOpacity(0.3), blurRadius: 10, offset: const Offset(0,4))] : [],
                    border: sel ? null : Border.all(color: Colors.grey.shade200)),
                  child: Text(ch, style: TextStyle(color: sel ? Colors.white : Colors.grey[600],
                    fontSize: 12, fontWeight: FontWeight.w700))));
            }).toList())),
        ]))),
      SliverPadding(padding: const EdgeInsets.all(20),
        sliver: SliverList(delegate: SliverChildListDelegate([
          Container(padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0,4))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_sel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text('Last 24 Hours', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ]),
                if (vals.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${vals.first.toStringAsFixed(1)} $unit',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c)),
                ]),
              ]),
              const SizedBox(height: 20),
              SizedBox(height: 140, child: vals.length < 2
                ? Center(child: Text('Collecting data...', style: TextStyle(color: Colors.grey[400])))
                : CustomPaint(size: Size.infinite, painter: _LinePainter(values: vals, color: c))),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _StatBox('MIN', vals.isEmpty ? '--'
                  : vals.reduce((a,b)=>a<b?a:b).toStringAsFixed(1), unit, c)),
                const SizedBox(width: 12),
                Expanded(child: _StatBox('MAX', vals.isEmpty ? '--'
                  : vals.reduce((a,b)=>a>b?a:b).toStringAsFixed(1), unit, c)),
              ]),
            ])),
          const SizedBox(height: 16),
          Container(padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: const Color(0xFF1A1C1C), borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("CLINICIAN'S NOTE", style: TextStyle(fontSize: 10,
                color: Colors.white60, letterSpacing: 1.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('$_sel trends show high consistency. Cardiovascular recovery is progressing well.',
                style: const TextStyle(fontSize: 13, color: Colors.white70, height: 1.6)),
            ])),
          const SizedBox(height: 16),
        ]))),
    ]));
  }
}

class _StatBox extends StatelessWidget {
  final String label, value, unit; final Color color;
  const _StatBox(this.label, this.value, this.unit, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: const Color(0xFFF3F3F3), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
        color: Colors.grey[500], letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Text('$value $unit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
    ]));
}

class _LinePainter extends CustomPainter {
  final List<double> values; final Color color;
  _LinePainter({required this.values, required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final min = values.reduce((a,b)=>a<b?a:b) - 3;
    final max = values.reduce((a,b)=>a>b?a:b) + 3;
    final range = (max - min).clamp(1.0, double.infinity);
    double x(int i) => i / (values.length - 1) * size.width;
    double y(double v) => size.height - ((v - min) / range * size.height);
    final path = Path()..moveTo(x(0), y(values[0]));
    final fill = Path()..moveTo(x(0), size.height)..lineTo(x(0), y(values[0]));
    for (int i = 1; i < values.length; i++) {
      final cx = (x(i-1) + x(i)) / 2;
      path.cubicTo(cx, y(values[i-1]), cx, y(values[i]), x(i), y(values[i]));
      fill.cubicTo(cx, y(values[i-1]), cx, y(values[i]), x(i), y(values[i]));
    }
    fill..lineTo(x(values.length-1), size.height)..close();
    canvas.drawPath(fill, Paint()
      ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), Colors.transparent])
        .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);
    canvas.drawPath(path, Paint()
      ..color = color ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke ..strokeCap = StrokeCap.round);
    final peak = values.indexOf(values.reduce((a,b)=>a>b?a:b));
    canvas.drawCircle(Offset(x(peak), y(values[peak])), 6, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(x(peak), y(values[peak])), 4, Paint()..color = color);
  }
  @override bool shouldRepaint(_LinePainter o) => o.values != values;
}

// ── Profile Page ───────────────────────────────────────────────
class _ProfilePage extends StatefulWidget {
  final String userId; final List<VitalsModel> history;
  const _ProfilePage({required this.userId, required this.history});
  @override State<_ProfilePage> createState() => _ProfilePageState();
}
class _ProfilePageState extends State<_ProfilePage> {
  bool _sync = true;
  String _interval = '5m';
  String _userName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _userName = prefs.getString('user_name') ?? 'VitalGuard User';
    });
  }
  @override
  Widget build(BuildContext context) => SafeArea(child: CustomScrollView(slivers: [
    SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20,16,20,0),
      child: const Text('Profile', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900,
        color: Color(0xFF1A1C1C), letterSpacing: -0.5)))),
    SliverPadding(padding: const EdgeInsets.all(20),
      sliver: SliverList(delegate: SliverChildListDelegate([
        Container(padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFF1A1C1C), borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(width: 60, height: 60,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.person_rounded, color: Colors.white54, size: 30)),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Patient', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text(widget.userId, style: const TextStyle(color: Colors.white,
                fontSize: 22, fontWeight: FontWeight.w900)),
              Text(_userName, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ]),
          ])),
        const SizedBox(height: 14),
        _PCard('Monitoring Setup', [
          Container(padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Continuous Sync', style: TextStyle(fontSize: 14)),
              Switch(value: _sync, onChanged: (v) => setState(() => _sync = v),
                activeColor: const Color(0xFFB6171E)),
            ])),
          const SizedBox(height: 4),
          const Text('SAMPLING INTERVAL', style: TextStyle(fontSize: 10,
            fontWeight: FontWeight.w700, color: Color(0xFF5B403D), letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Row(children: ['5m','15m','1h'].map((t) => GestureDetector(
            onTap: () => setState(() => _interval = t),
            child: AnimatedContainer(duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: t == _interval ? const Color(0xFFB6171E) : const Color(0xFFE8E8E8),
                borderRadius: BorderRadius.circular(25)),
              child: Text(t, style: TextStyle(
                color: t == _interval ? Colors.white : const Color(0xFF1A1C1C),
                fontWeight: FontWeight.w700, fontSize: 13))))).toList()),
        ]),
        const SizedBox(height: 12),
        _PCard('Alert Thresholds', [
          _TRow('Heart Rate', '50 – 110 bpm', const Color(0xFFB6171E)),
          _TRow('SpO2', '≥ 92%', const Color(0xFF006578)),
          _TRow('Blood Pressure', '< 140 mmHg', Colors.purple),
          _TRow('Glucose', '70 – 180 mg/dL', Colors.orange),
        ]),
        const SizedBox(height: 12),
        _PCard('Monitoring History', [
          ...widget.history.reversed.take(5).map((v) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: v.alertTriggered ? const Color(0xFFB6171E) : const Color(0xFF006578),
                  shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Text(v.alertTriggered ? 'Alert Triggered' : 'Routine Checkpoint',
                style: const TextStyle(fontSize: 12))),
              Text(DateFormat('hh:mm:ss a').format(v.timestamp?.toLocal() ?? DateTime.now()),
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]))),
          if (widget.history.isEmpty)
            const Text('No history yet', style: TextStyle(color: Colors.grey, fontSize: 13)),
        ]),
      ]))),
  ]));
}

class _PCard extends StatelessWidget {
  final String title; final List<Widget> children;
  const _PCard(this.title, this.children);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
      const SizedBox(height: 14),
      ...children,
    ]));
}

class _TRow extends StatelessWidget {
  final String label, value; final Color color;
  const _TRow(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]));
}
