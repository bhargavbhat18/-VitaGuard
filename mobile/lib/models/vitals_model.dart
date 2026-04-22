class VitalsModel {
  final String userId;
  final double heartRate, spo2, bpSystolic, bpDiastolic, glucose, temperature;
  final DateTime? timestamp;
  final bool alertTriggered;
  final String? alertMessage;

  VitalsModel({
    required this.userId, required this.heartRate, required this.spo2,
    required this.bpSystolic, required this.bpDiastolic,
    required this.glucose, required this.temperature,
    this.timestamp, this.alertTriggered = false, this.alertMessage,
  });

  factory VitalsModel.fromJson(Map<String, dynamic> json) => VitalsModel(
    userId:      json['user_id']?.toString() ?? '',
    heartRate:   ((json['heart_rate']   ?? 75.0)  as num).toDouble(),
    spo2:        ((json['spO2'] ?? json['spo2'] ?? 98.0) as num).toDouble(),
    bpSystolic:  ((json['bp_systolic']  ?? 120.0) as num).toDouble(),
    bpDiastolic: ((json['bp_diastolic'] ?? 80.0)  as num).toDouble(),
    glucose:     ((json['glucose']      ?? 100.0) as num).toDouble(),
    temperature: ((json['temperature']  ?? 36.6)  as num).toDouble(),
    timestamp:   json['timestamp'] != null
                   ? DateTime.tryParse(
                       json['timestamp'].toString().contains('+') ||
                       json['timestamp'].toString().endsWith('Z')
                         ? json['timestamp'].toString()
                         : '${json['timestamp']}Z')
                   : null,
    alertTriggered: json['alert_triggered'] ?? false,
    alertMessage:   json['alert_message']?.toString(),
  );
}
