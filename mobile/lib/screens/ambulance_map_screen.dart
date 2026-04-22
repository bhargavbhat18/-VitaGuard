import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:vitalguard/config/app_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vitalguard/services/sos_service.dart';

class AmbulanceMapScreen extends StatefulWidget {
  final String sosId;
  final double patientLat, patientLng;
  final String hospitalName;
  const AmbulanceMapScreen({super.key, required this.sosId,
    required this.patientLat, required this.patientLng,
    this.hospitalName = 'Apollo Hospital'});
  @override State<AmbulanceMapScreen> createState() => _AmbulanceMapScreenState();
}

class _AmbulanceMapScreenState extends State<AmbulanceMapScreen> with TickerProviderStateMixin {
  Timer? _timer;
  StreamSubscription<Position>? _userSub;
  Map<String, dynamic>? _status;
  final MapController _mapController = MapController();
  LatLng? _liveUserPos;
  bool _autoFollow = true;

  // Animation for smooth ambulance movement
  late AnimationController _ambAnimController;
  Animation<LatLng>? _ambLatLngAnim;
  LatLng _lastAmbPos = const LatLng(0, 0);

  LatLng get _patientPos {
    if (_liveUserPos != null) return _liveUserPos!;
    if (_status != null && _status!['user_location'] != null) {
      return LatLng(_status!['user_location']['lat'], _status!['user_location']['lng']);
    }
    return LatLng(widget.patientLat, widget.patientLng);
  }
  LatLng get _ambPos {
    if (_ambLatLngAnim != null) return _ambLatLngAnim!.value;
    if (_status == null) return _patientPos;
    return LatLng(
      (_status!['current_lat'] as num?)?.toDouble() ?? widget.patientLat,
      (_status!['current_lng'] as num?)?.toDouble() ?? widget.patientLng);
  }
  LatLng get _hospPos {
    if (_status == null) return LatLng(12.9252, 77.6011);
    return LatLng(
      (_status!['destination_lat'] as num?)?.toDouble() ?? 12.9252,
      (_status!['destination_lng'] as num?)?.toDouble() ?? 77.6011);
  }
  
  List<LatLng> get _routePoints {
    if (_status == null || _status!['waypoints'] == null) return [_hospPos, _ambPos, _patientPos];
    final List<dynamic> pts = _status!['waypoints'];
    return pts.map((p) => LatLng(p['lat'], p['lng'])).toList();
  }
  
  String get _distRemaining {
    if (_status == null || _status!['distance_remaining'] == null) return '-- km';
    final meters = (_status!['distance_remaining'] as num).toDouble();
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  bool get _arrived => _status?['status'] == 'arrived';
  double get _progress {
    if (_status == null) return 0.0;
    return (_status!['progress'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  void initState() {
    super.initState();
    _ambAnimController = AnimationController(vsync: this, duration: const Duration(seconds: 3));
    _ambAnimController.addListener(() => setState(() {}));
    
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _startUserTracking();
  }

  void _startUserTracking() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    
    _userSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
    ).listen((p) {
      if (!mounted) return;
      final newPos = LatLng(p.latitude, p.longitude);
      setState(() => _liveUserPos = newPos);
      _syncLocationToBackend(newPos);
      _fitMapBounds();
    });
  }

  Future<void> _syncLocationToBackend(LatLng pos) async {
    await SosService().updateLocation(widget.sosId, pos.latitude, pos.longitude);
  }

  void _fitMapBounds({bool animated = true}) {
    if (!mounted) return;
    try {
      final bounds = LatLngBounds.fromPoints([_patientPos, _ambPos, _hospPos]);
      if (animated) {
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)));
      } else {
        _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(70)));
      }
    } catch (_) {}
  }

  Future<void> _poll() async {
    try {
      final r = await http.get(
        Uri.parse('${AppConfig.baseUrl}/sos/ambulance/${widget.sosId}'),
        headers: {'Authorization': 'Bearer LKT01'});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final newAmbPos = LatLng(
          (data['current_lat'] as num).toDouble(),
          (data['current_lng'] as num).toDouble()
        );

        if (_lastAmbPos.latitude != 0) {
          _ambLatLngAnim = Tween<LatLng>(begin: _lastAmbPos, end: newAmbPos)
              .animate(CurvedAnimation(parent: _ambAnimController, curve: Curves.linear));
          _ambAnimController.forward(from: 0);
        }
        
        _lastAmbPos = newAmbPos;
        setState(() => _status = data);
        if (_autoFollow) _fitMapBounds();
        if (_arrived) _timer?.cancel();
      }
    } catch (_) {}
  }

  @override
  void dispose() { 
    _timer?.cancel(); 
    _userSub?.cancel();
    _ambAnimController.dispose();
    super.dispose(); 
  }

  @override
  Widget build(BuildContext context) {
    final eta = _status?['eta_minutes'] ?? '--';
    final hospital = _status?['hospital'] ?? widget.hospitalName;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Live Ambulance Tracking',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true),
      body: Column(children: [

        // Live map & Controls
        Expanded(flex: 6,
          child: Stack(children: [
            ClipRRect(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _patientPos,
                  initialZoom: 13.0,
                  onMapReady: () => _fitMapBounds()),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.vitalguard.app'),

                  // Road-accurate route polyline
                  PolylineLayer(polylines: [
                    Polyline(points: _routePoints,
                      strokeWidth: 5, color: const Color(0xFFB6171E),
                      isDotted: false),
                  ]),

                  MarkerLayer(markers: [
                    // Patient home marker
                    Marker(point: _patientPos, width: 56, height: 56,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFB6171E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25),
                              blurRadius: 8, offset: const Offset(0, 3))]),
                          child: const Icon(Icons.home_rounded, color: Colors.white, size: 20)),
                      ])),

                    // Hospital marker
                    Marker(point: _hospPos, width: 56, height: 56,
                      child: Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16a34a),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2),
                            blurRadius: 8, offset: const Offset(0, 3))]),
                        child: const Icon(Icons.local_hospital_rounded,
                          color: Colors.white, size: 20))),

                    // Ambulance marker (moving)
                    Marker(point: _ambPos, width: 56, height: 56,
                      child: Container(width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4),
                            blurRadius: 12, offset: const Offset(0, 4))]),
                        child: const Text('🚑', style: TextStyle(fontSize: 20)))),
                  ]),
                ],
              ),
            ),
            
            // Map controls overlay
            Positioned(top: 10, right: 10, child: Column(children: [
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                onPressed: () => _fitMapBounds(),
                child: const Icon(Icons.my_location, color: Color(0xFF1A1C1C))),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'autofollow',
                backgroundColor: _autoFollow ? const Color(0xFFB6171E) : Colors.white,
                onPressed: () => setState(() => _autoFollow = !_autoFollow),
                child: Icon(Icons.navigation, color: _autoFollow ? Colors.white : Colors.grey)),
            ])),
          ]),
        ),

        // Status card
        Container(color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(children: [
            // ETA
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ESTIMATED ARRIVAL', style: TextStyle(fontSize: 10,
                  color: Colors.grey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                const SizedBox(height: 4),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic, children: [
                  Text(_arrived ? '0' : '$eta',
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1C1C))),
                  const SizedBox(width: 6),
                  Text(_arrived ? 'ARRIVED!' : 'min',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                      color: _arrived ? const Color(0xFF16a34a) : Colors.grey)),
                  const SizedBox(width: 12),
                  if (!_arrived) Text('($_distRemaining)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                ]),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _arrived ? const Color(0xFFF0FDF4) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(25)),
                child: Text(_arrived ? '✓ On Scene' : '🚑 On Route',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _arrived ? const Color(0xFF16a34a) : const Color(0xFF2563EB)))),
            ]),
            const SizedBox(height: 14),
            // Progress bar
            ClipRRect(borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress,
                backgroundColor: const Color(0xFFBFDBFE),
                color: _arrived ? const Color(0xFF16a34a) : const Color(0xFF2563EB),
                minHeight: 8)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(hospital, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('${(_progress * 100).toStringAsFixed(0)}% complete',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: Color(0xFF2563EB))),
            ]),
            const SizedBox(height: 14),
            // Legend
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _LegendItem(Colors.red, 'Your Home'),
              _LegendItem(const Color(0xFF2563EB), 'Ambulance'),
              _LegendItem(const Color(0xFF16a34a), 'Hospital'),
            ]),
          ])),
      ]),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color; final String label;
  const _LegendItem(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
  ]);
}
