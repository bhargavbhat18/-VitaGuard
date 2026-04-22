import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vitalguard/config/app_config.dart';

class SosService {
  static const _h = {'Authorization':'Bearer LKT01','Content-Type':'application/json'};

  Future<Map<String,dynamic>?> triggerSos(String alertMessage,
      {double lat = 12.9716, double lng = 77.5946}) async {
    try {
      final r = await http.post(Uri.parse('${AppConfig.baseUrl}/sos/trigger'), headers: _h,
        body: jsonEncode({'alert_message':alertMessage,'location':{'lat':lat,'lng':lng}}));
      if (r.statusCode==200) return jsonDecode(r.body);
    } catch (e) { print('SOS error: $e'); }
    return null;
  }

  Future<Map<String,dynamic>?> getAmbulanceStatus(String sosId) async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/sos/ambulance/$sosId'), headers: _h);
      if (r.statusCode==200) return jsonDecode(r.body);
    } catch (e) { print('Amb error: $e'); }
    return null;
  }

  Future<bool> updateLocation(String sosId, double lat, double lng) async {
    try {
      final r = await http.post(Uri.parse('${AppConfig.baseUrl}/sos/user-location/$sosId'), headers: _h,
        body: jsonEncode({'lat':lat,'lng':lng}));
      return r.statusCode==200;
    } catch (_) {}
    return false;
  }

  Future<List<dynamic>> getTrafficLog() async {
    try {
      final r = await http.get(Uri.parse('${AppConfig.baseUrl}/sos/traffic/log'), headers: _h);
      if (r.statusCode==200) return jsonDecode(r.body);
    } catch (e) {}
    return [];
  }
}
