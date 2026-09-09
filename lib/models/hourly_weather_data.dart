class HourlyWeatherData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double windSpeedMs;
  final double windSpeedKnot;
  final double windAngle;
  final String windDirection;
  final double rainDailyMm;
  final int lux;

  HourlyWeatherData({
    required this.timestamp,
    required this.temperature,
    required this.humidity,
    required this.windSpeedMs,
    required this.windSpeedKnot,
    required this.windAngle,
    required this.windDirection,
    required this.rainDailyMm,
    required this.lux,
  });

  factory HourlyWeatherData.fromJson(Map<String, dynamic> json) {
    // Parse timestamp "2026-09-09 06:00:00"
    DateTime timestamp = DateTime.now();
    try {
      timestamp = DateTime.parse(json['timestamp'] ?? '');
    } catch (e) {
      // Jika parsing gagal, gunakan waktu sekarang
    }

    return HourlyWeatherData(
      timestamp: timestamp,
      temperature: (json['temperature'] ?? 0).toDouble(),
      humidity: (json['humidity'] ?? 0).toDouble(),
      windSpeedMs: (json['wind_speed_ms'] ?? 0).toDouble(),
      windSpeedKnot: (json['wind_speed_knot'] ?? 0).toDouble(),
      windAngle: (json['wind_angle'] ?? 0).toDouble(),
      windDirection: json['wind_direction'] ?? '--',
      rainDailyMm: (json['rain_daily_mm'] ?? 0).toDouble(),
      lux: json['lux'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'temperature': temperature,
      'humidity': humidity,
      'wind_speed_ms': windSpeedMs,
      'wind_speed_knot': windSpeedKnot,
      'wind_angle': windAngle,
      'wind_direction': windDirection,
      'rain_daily_mm': rainDailyMm,
      'lux': lux,
    };
  }
}