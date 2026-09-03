class SensorData {
  final double suhu;
  final double kelembapan;
  final double intensitasCahaya;
  final DateTime timestamp;

  SensorData({
    required this.suhu,
    required this.kelembapan,
    required this.intensitasCahaya,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'suhu': suhu,
    'kelembapan': kelembapan,
    'cahaya': intensitasCahaya,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SensorData.fromJson(Map<String, dynamic> json) => SensorData(
    suhu: json['suhu']?.toDouble() ?? 0,
    kelembapan: json['kelembapan']?.toDouble() ?? 0,
    intensitasCahaya: json['cahaya']?.toDouble() ?? 0,
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
  );

  @override
  String toString() => 'Suhu: ${suhu.toStringAsFixed(1)}°C, '
      'Kelembapan: ${kelembapan.toStringAsFixed(1)}%, '
      'Cahaya: ${intensitasCahaya.toStringAsFixed(0)} Lux';
}