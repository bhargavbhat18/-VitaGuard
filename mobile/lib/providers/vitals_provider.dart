import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitalguard/models/vitals_model.dart';
import 'package:vitalguard/services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final s = WebSocketService();
  ref.onDispose(() => s.dispose());
  return s;
});

final vitalsStreamProvider = StreamProvider.family<VitalsModel, String>((ref, userId) {
  final ws = ref.watch(webSocketServiceProvider);
  ws.connect(userId);
  return ws.vitalsStream;
});
