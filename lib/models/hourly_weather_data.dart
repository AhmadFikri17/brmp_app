import 'package:flutter/material.dart';

class HourlyWeatherData {
  final DateTime timestamp;
  final double temperature;
  final double humidity;
  final double windSpeedMs;
  final double windSpeedKnot;
  final double windAngle;
  final String windDirection;
  final double rainDailyMm;
  final double lux;

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

  // ===== FACTORY DARI JSON =====
  factory HourlyWeatherData.fromJson(Map<String, dynamic> json) {
    // Parse timestamp dengan normalisasi
    DateTime timestamp = DateTime.now();
    try {
      final tsStr = json['timestamp']?.toString() ?? '';
      if (tsStr.isNotEmpty) {
        final normalized = _normalizeTimestamp(tsStr);
        timestamp = DateTime.parse(normalized);
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing timestamp: $e');
      // Fallback: gunakan waktu sekarang
      timestamp = DateTime.now();
    }

    return HourlyWeatherData(
      timestamp: timestamp,
      temperature: _parseDouble(json['temperature']),
      humidity: _parseDouble(json['humidity']),
      windSpeedMs: _parseDouble(json['wind_speed_ms']),
      windSpeedKnot: _parseDouble(json['wind_speed_knot']),
      windAngle: _parseDouble(json['wind_angle']),
      windDirection: json['wind_direction']?.toString() ?? '--',
      rainDailyMm: _parseDouble(json['rain_daily_mm']),
      lux: _parseDouble(json['lux']),
    );
  }

  // ===== HELPER: PARSE NILAI APAPUN KE DOUBLE =====
  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // ===== HELPER: NORMALISASI TIMESTAMP =====
  // Handle format:
  // - "2026-09-10 8:00:00"  -> "2026-09-10 08:00:00"
  // - "2026-09-10 08:00:00" -> "2026-09-10 08:00:00"
  // - "2026-09-10T08:00:00" -> "2026-09-10 08:00:00"
  static String _normalizeTimestamp(String ts) {
    try {
      // Ganti 'T' jadi spasi
      String normalized = ts.replaceAll('T', ' ').trim();

      final parts = normalized.split(' ');
      if (parts.length != 2) return normalized;

      final datePart = parts[0]; // "2026-09-10"
      final timePart = parts[1]; // "8:00:00" atau "08:00:00"

      // Normalisasi tanggal: pad month & day
      final dateParts = datePart.split('-');
      if (dateParts.length == 3) {
        final year = dateParts[0];
        final month = dateParts[1].padLeft(2, '0');
        final day = dateParts[2].padLeft(2, '0');
        
        // Normalisasi waktu: pad hour, minute, second
        final timeParts = timePart.split(':');
        if (timeParts.length >= 2) {
          final hour = timeParts[0].padLeft(2, '0');
          final minute = timeParts[1].padLeft(2, '0');
          final second = timeParts.length > 2 
              ? timeParts[2].padLeft(2, '0') 
              : '00';

          return '$year-$month-$day $hour:$minute:$second';
        }
      }

      return normalized;
    } catch (e) {
      debugPrint('⚠️ Error normalizing timestamp: $e');
      return ts;
    }
  }

  // ===== TO JSON =====
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

  // ===== COPY WITH =====
  HourlyWeatherData copyWith({
    DateTime? timestamp,
    double? temperature,
    double? humidity,
    double? windSpeedMs,
    double? windSpeedKnot,
    double? windAngle,
    String? windDirection,
    double? rainDailyMm,
    double? lux,
  }) {
    return HourlyWeatherData(
      timestamp: timestamp ?? this.timestamp,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      windSpeedMs: windSpeedMs ?? this.windSpeedMs,
      windSpeedKnot: windSpeedKnot ?? this.windSpeedKnot,
      windAngle: windAngle ?? this.windAngle,
      windDirection: windDirection ?? this.windDirection,
      rainDailyMm: rainDailyMm ?? this.rainDailyMm,
      lux: lux ?? this.lux,
    );
  }

  @override
  String toString() {
    return 'HourlyWeatherData('
        'timestamp: $timestamp, '
        'temp: ${temperature.toStringAsFixed(1)}°C, '
        'hum: ${humidity.toStringAsFixed(1)}%, '
        'lux: ${lux.toStringAsFixed(1)}, '
        'wind: ${windSpeedMs.toStringAsFixed(1)} m/s)';
  }
}