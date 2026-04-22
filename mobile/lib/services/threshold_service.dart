import 'package:vitalguard/models/vitals_model.dart';
import 'package:vitalguard/services/notification_service.dart';

class ThresholdService {
  static String? _lastAlert;

  static void checkAndNotify(VitalsModel v) {
    final alerts = <String>[];

    // Heart Rate
    if (v.heartRate > 110)
      alerts.add('High heart rate: ${v.heartRate.toStringAsFixed(0)} bpm');
    else if (v.heartRate < 50)
      alerts.add('Low heart rate: ${v.heartRate.toStringAsFixed(0)} bpm');

    // SpO2 — if SpO2 < 92%
    if (v.spo2 < 92)
      alerts.add('Low SpO2: ${v.spo2.toStringAsFixed(1)}%');

    // Blood Pressure
    if (v.bpSystolic > 140)
      alerts.add('High BP: ${v.bpSystolic.toStringAsFixed(0)}/${v.bpDiastolic.toStringAsFixed(0)} mmHg');
    else if (v.bpSystolic < 60)
      alerts.add('Low BP: ${v.bpSystolic.toStringAsFixed(0)}/${v.bpDiastolic.toStringAsFixed(0)} mmHg');

    // Glucose
    if (v.glucose > 180)
      alerts.add('High glucose: ${v.glucose.toStringAsFixed(0)} mg/dL');
    else if (v.glucose < 70)
      alerts.add('Low glucose: ${v.glucose.toStringAsFixed(0)} mg/dL');

    // Temperature — normal 36.1–37.2°C
    if (v.temperature >= 39.0)
      alerts.add('HIGH FEVER: ${v.temperature.toStringAsFixed(1)}°C');
    else if (v.temperature > 37.5)
      alerts.add('Elevated temp: ${v.temperature.toStringAsFixed(1)}°C');
    else if (v.temperature < 35.0)
      alerts.add('Hypothermia risk: ${v.temperature.toStringAsFixed(1)}°C');

    if (alerts.isNotEmpty) {
      final message = alerts.join(' | ');
      if (message != _lastAlert) {
        _lastAlert = message;
        NotificationService.showAlert('VitalGuard Alert', message);
        print('[THRESHOLD] $message');
      }
    } else {
      _lastAlert = null;
    }
  }
}
