import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:vitalguard/models/vitals_model.dart';
import 'package:vitalguard/config/app_config.dart';

class WebSocketService {
  final StreamController<VitalsModel> _ctrl = StreamController.broadcast();
  Timer? _timer;
  Stream<VitalsModel> get vitalsStream => _ctrl.stream;

  void connect(String userId) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final r = await http.get(Uri.parse('${AppConfig.baseUrl}/vitals/latest'),
          headers: {'Authorization': 'Bearer $userId'});
        if (r.statusCode == 200) _ctrl.add(VitalsModel.fromJson(jsonDecode(r.body)));
      } catch (e) { print('Poll error: $e'); }
    });
  }

  void disconnect() { _timer?.cancel(); _timer = null; }
  void dispose()    { disconnect(); _ctrl.close(); }
}
