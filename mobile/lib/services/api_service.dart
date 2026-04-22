import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vitalguard/config/app_config.dart';
import 'package:vitalguard/models/user_model.dart';

class ApiService {
  static const _h = {'Authorization':'Bearer LKT01','Content-Type':'application/json'};
  Future<void> saveProfile(UserModel u) async =>
    await http.post(Uri.parse('${AppConfig.baseUrl}/auth/profile'), headers: _h, body: jsonEncode(u.toJson()));
  Future<Map<String,dynamic>?> getLatestVitals() async {
    final r = await http.get(Uri.parse('${AppConfig.baseUrl}/vitals/latest'), headers: _h);
    if (r.statusCode==200) return jsonDecode(r.body);
    return null;
  }
}
