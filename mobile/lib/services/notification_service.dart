// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class NotificationService {
  static bool _granted = false;

  static Future<void> initialize() async {
    try {
      final permission = await html.Notification.requestPermission();
      _granted = permission == 'granted';
    } catch (e) { print('Notification init: $e'); }
  }

  static void showAlert(String title, String body) {
    if (!_granted) return;
    try {
      final safe = body.replaceAll("'","\\'").replaceAll('\n',' | ');
      html.Notification(title, body: safe);
    } catch (e) { print('Notification error: $e'); }
  }
}
