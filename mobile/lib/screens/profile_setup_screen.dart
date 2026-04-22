import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vitalguard/config/app_config.dart';
import 'package:vitalguard/screens/dashboard_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String uid, email;
  const ProfileSetupScreen({super.key, required this.uid, required this.email});
  @override State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age  = TextEditingController();
  final _address = TextEditingController();
  final _drName = TextEditingController();
  final _drPhone = TextEditingController();
  final _drHosp = TextEditingController();
  
  List<_FamilyMemberEntry> _familyMembers = [];
  
  LatLng? _location;
  final MapController _mapController = MapController();
  String _blood = 'O+';
  String _rel   = 'Spouse';
  bool _loading = false;
  static const _bloods = ['A+','A-','B+','B-','AB+','AB-','O+','O-'];
  static const _rels   = ['Father', 'Mother', 'Brother', 'Sister', 'Spouse', 'Child', 'Friend', 'Other'];

  @override
  void initState() {
    super.initState();
    // Start with one family member entry by default
    _familyMembers.add(_FamilyMemberEntry());
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _updateLocation(LatLng(pos.latitude, pos.longitude));
  }

  Future<void> _updateLocation(LatLng latlng) async {
    setState(() => _location = latlng);
    _mapController.move(latlng, 15);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latlng.latitude, latlng.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        _address.text = "${p.name}, ${p.subLocality}, ${p.locality}, ${p.postalCode}";
      }
    } catch (_) {}
  }

  Future<void> _pickDoctor() async {
    setState(() => _loading = true);
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/hospital/'));
      if (r.statusCode != 200) throw 'Failed to fetch hospitals';
      final List hospitals = jsonDecode(r.body);
      setState(() => _loading = false);

      if (!mounted) return;
      
      final selectedHosp = await showModalBottomSheet<Map>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SelectionSheet(
          title: 'Select Hospital',
          items: hospitals,
          itemTitle: (h) => h['name'],
          itemSub: (h) => h['specializations'].join(', '),
        ),
      );

      if (selectedHosp == null) return;

      final List doctors = selectedHosp['doctors'] ?? [];
      if (doctors.isEmpty) {
        setState(() {
          _drHosp.text = selectedHosp['name'];
          _drName.clear();
          _drPhone.clear();
        });
        return;
      }

      if (!mounted) return;
      final selectedDoc = await showModalBottomSheet<Map>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _SelectionSheet(
          title: 'Select Doctor at ${selectedHosp['name']}',
          items: doctors,
          itemTitle: (d) => d['name'],
          itemSub: (d) => d['specialization'],
        ),
      );

      if (selectedDoc != null) {
        setState(() {
          _drHosp.text = selectedHosp['name'];
          _drName.text = selectedDoc['name'];
          _drPhone.text = selectedDoc['phone'];
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await http.post(Uri.parse('${AppConfig.baseUrl}/auth/profile'),
        headers: {'Authorization': 'Bearer ${widget.uid}',
                  'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': widget.uid, 'email': widget.email,
          'full_name': _name.text.trim(), 'blood_group': _blood,
          'age': int.tryParse(_age.text) ?? 0,
          'emergency_contact_name': _familyMembers.isNotEmpty ? _familyMembers[0].name.text.trim() : '',
          'emergency_contact_phone': _familyMembers.isNotEmpty ? _familyMembers[0].phone.text.trim() : '',
          'emergency_contact_relation': _familyMembers.isNotEmpty ? _familyMembers[0].relationship : 'Other',
          'family_members': _familyMembers.map((m) => {
            'name': m.name.text.trim(),
            'phone': m.phone.text.trim(),
            'relationship': m.relationship
          }).toList(),
          'doctor_name': _drName.text.trim().isNotEmpty ? _drName.text.trim() : null,
          'doctor_phone': _drPhone.text.trim().isNotEmpty ? _drPhone.text.trim() : null,
          'doctor_hospital': _drHosp.text.trim().isNotEmpty ? _drHosp.text.trim() : null,
          'location': _location != null ? {
            'lat': _location!.latitude,
            'lng': _location!.longitude,
            'address': _address.text.trim()
          } : null,
        }));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_id', widget.uid);
      await prefs.setString('user_name', _name.text.trim());
      if (mounted) Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => DashboardScreen(userId: widget.uid)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'), backgroundColor: const Color(0xFFBA1A1A)));
    } finally { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF9F9F9),
    body: SafeArea(child: Column(children: [
      Container(color: Colors.white, padding: const EdgeInsets.fromLTRB(20,16,20,20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFF3F3F3),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Color(0xFF1A1C1C)))),
          const SizedBox(height: 16),
          const Text('Complete Profile', style: TextStyle(fontSize: 26,
            fontWeight: FontWeight.w900, color: Color(0xFF1A1C1C))),
          const Text('Step 2 of 2 — Emergency & Doctor details',
            style: TextStyle(fontSize: 13, color: Color(0xFF5B403D))),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(value: 1.0,
              backgroundColor: Color(0xFFE8E8E8), color: Color(0xFFB6171E), minHeight: 5)),
        ])),
      Expanded(child: Form(key: _formKey, child: ListView(
        padding: const EdgeInsets.all(20), children: [
        _Section(Icons.person_rounded, 'Personal Information', null, null),
        const SizedBox(height: 12),
        _F('Full Name *', _name, Icons.badge_outlined, required: true),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _F('Age *', _age, Icons.cake_outlined,
            required: true, kb: TextInputType.number)),
          const SizedBox(width: 10),
          Expanded(child: Container(
            decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
            child: DropdownButtonFormField<String>(value: _blood,
              decoration: const InputDecoration(labelText: 'Blood Group *',
                prefixIcon: Icon(Icons.bloodtype_outlined, size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
              items: _bloods.map((g) => DropdownMenuItem(value: g,
                child: Text(g, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
              onChanged: (v) => setState(() => _blood = v!)))),
        ]),
        const SizedBox(height: 20),
        _Section(Icons.location_on_rounded, 'Home Address',
          'Validated location for emergency services', const Color(0xFFE8F5E9)),
        const SizedBox(height: 12),
        _F('Residential Address *', _address, Icons.home_outlined, 
          required: true, 
          onSuffixTap: _getCurrentLocation,
          suffixIcon: Icons.my_location_rounded),
        const SizedBox(height: 10),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _location ?? const LatLng(12.9716, 77.5946),
                    initialZoom: 15,
                    onTap: (_, latlng) => _updateLocation(latlng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vitalguard.app',
                    ),
                    if (_location != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: _location!,
                          width: 40, height: 40,
                          child: const Icon(Icons.location_pin, color: Color(0xFFB6171E), size: 30),
                        ),
                      ]),
                  ],
                ),
                Positioned(
                  bottom: 12, right: 12,
                  child: FloatingActionButton.small(
                    onPressed: _getCurrentLocation,
                    backgroundColor: const Color(0xFFB6171E),
                    elevation: 4,
                    child: const Icon(Icons.my_location, color: Colors.white, size: 18),
                  ),
                ),
                if (_location == null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.05),
                      child: const Center(
                        child: Text('Tap map or "Locate Me" to set home',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1C))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SizedBox(height: 20),
        _Section(Icons.family_restroom_rounded, 'Add Family Members',
          'Registered family members will be notified during emergencies', const Color(0xFFFFDAD6)),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _familyMembers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final member = _familyMembers[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Member #${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB6171E))),
                      if (_familyMembers.length > 1)
                        GestureDetector(
                          onTap: () => setState(() => _familyMembers.removeAt(index)),
                          child: const Icon(Icons.remove_circle_outline, color: Color(0xFFBA1A1A), size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _F('Full Name *', member.name, Icons.person_outlined, required: true),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                    child: DropdownButtonFormField<String>(
                      value: member.relationship,
                      decoration: const InputDecoration(
                        labelText: 'Relationship *',
                        prefixIcon: Icon(Icons.people_outline, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                      items: _rels.map((r) => DropdownMenuItem(value: r,
                        child: Text(r, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)))).toList(),
                      onChanged: (v) => setState(() => member.relationship = v!))),
                  const SizedBox(height: 10),
                  _F('Phone Number *', member.phone, Icons.phone_outlined, required: true, kb: TextInputType.phone, isPhone: true),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _familyMembers.add(_FamilyMemberEntry())),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Another Member', 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB6171E),
            side: const BorderSide(color: Color(0xFFB6171E)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        _Section(Icons.local_hospital_outlined, 'Doctor Details',
          'Shared with emergency responders', const Color(0xFFE6F1FB)),
        const SizedBox(height: 12),
        _F('Doctor Name *', _drName, Icons.medical_services_outlined, required: true),
        const SizedBox(height: 10),
        _F('Doctor Phone *', _drPhone, Icons.phone_outlined, required: true, kb: TextInputType.phone, isPhone: true),
        const SizedBox(height: 10),
        _F('Hospital / Clinic', _drHosp, Icons.location_city_outlined),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loading ? null : _pickDoctor,
          icon: const Icon(Icons.search_rounded, size: 18),
          label: const Text('Search & Select from Hospital List', 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB6171E),
            side: const BorderSide(color: Color(0xFFB6171E)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 28),
        GestureDetector(onTap: _loading ? null : _save,
          child: Container(height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFB6171E), Color(0xFFDA3433)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: const Color(0xFFB6171E).withOpacity(0.35),
                blurRadius: 14, offset: const Offset(0, 5))]),
            child: Center(child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Save & Open Dashboard', style: TextStyle(color: Colors.white,
                  fontSize: 16, fontWeight: FontWeight.w800))))),
        const SizedBox(height: 20),
      ]))),
    ])));
}

class _Section extends StatelessWidget {
  final IconData icon; final String title; final String? sub; final Color? bg;
  const _Section(this.icon, this.title, this.sub, this.bg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: bg ?? const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, size: 20, color: const Color(0xFF1A1C1C)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14,
          fontWeight: FontWeight.w800, color: Color(0xFF1A1C1C))),
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    ]));
}

class _F extends StatelessWidget {
  final String label; final TextEditingController ctrl; final IconData icon;
  final bool required; final String? hint; final TextInputType kb;
  final VoidCallback? onSuffixTap; final IconData? suffixIcon;
  final bool isPhone;
  const _F(this.label, this.ctrl, this.icon, {this.required=false,
    this.hint, this.kb = TextInputType.text, this.onSuffixTap, this.suffixIcon, this.isPhone = false});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
    child: TextFormField(controller: ctrl, keyboardType: kb,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)] : null,
      validator: (v) {
        if (required && (v == null || v.trim().isEmpty)) return 'Required';
        if (isPhone && (v == null || v.length != 10)) return 'Please enter a valid 10-digit phone number.';
        return null;
      },
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(labelText: label, hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: Colors.grey[400]),
        suffixIcon: onSuffixTap != null ? IconButton(
          icon: Icon(suffixIcon ?? Icons.my_location, size: 18, color: const Color(0xFFB6171E)),
          onPressed: onSuffixTap,
        ) : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14))));
}

class _SelectionSheet extends StatelessWidget {
  final String title; final List items;
  final String Function(dynamic) itemTitle;
  final String Function(dynamic) itemSub;

  const _SelectionSheet({required this.title, required this.items, required this.itemTitle, required this.itemSub});

  @override
  Widget build(BuildContext context) => Container(
    height: MediaQuery.of(context).size.height * 0.7,
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: Column(children: [
      const SizedBox(height: 12),
      Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
      Padding(padding: const EdgeInsets.all(20), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) => ListTile(
          onTap: () => Navigator.pop(context, items[i]),
          title: Text(itemTitle(items[i]), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Text(itemSub(items[i]), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      )),
    ]),
  );
}

class _FamilyMemberEntry {
  final name = TextEditingController();
  final phone = TextEditingController();
  String relationship = 'Spouse';
}
