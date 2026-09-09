class WeatherData {
  final double suhu;
  final double kelembapan;
  final int intensitasCahaya;
  final double kecepatanAngin;
  final double kecepatanAnginKnot; // <-- FIELD BARU untuk knot
  final double arahAngin;
  final double curahHujan;
  final String tanggal;
  final String waktu;

  WeatherData({
    required this.suhu,
    required this.kelembapan,
    required this.intensitasCahaya,
    required this.kecepatanAngin,
    required this.kecepatanAnginKnot, // <-- PARAMETER BARU
    required this.arahAngin,
    required this.curahHujan,
    required this.tanggal,
    required this.waktu,
  });

  // Copy constructor untuk update data
  WeatherData copyWith({
    double? suhu,
    double? kelembapan,
    int? intensitasCahaya,
    double? kecepatanAngin,
    double? kecepatanAnginKnot, // <-- PARAMETER BARU
    double? arahAngin,
    double? curahHujan,
    String? tanggal,
    String? waktu,
  }) {
    return WeatherData(
      suhu: suhu ?? this.suhu,
      kelembapan: kelembapan ?? this.kelembapan,
      intensitasCahaya: intensitasCahaya ?? this.intensitasCahaya,
      kecepatanAngin: kecepatanAngin ?? this.kecepatanAngin,
      kecepatanAnginKnot: kecepatanAnginKnot ?? this.kecepatanAnginKnot, // <-- BARU
      arahAngin: arahAngin ?? this.arahAngin,
      curahHujan: curahHujan ?? this.curahHujan,
      tanggal: tanggal ?? this.tanggal,
      waktu: waktu ?? this.waktu,
    );
  }

  // Factory constructor dari JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      suhu: (json['suhu'] ?? 0).toDouble(),
      kelembapan: (json['kelembapan'] ?? 0).toDouble(),
      intensitasCahaya: json['intensitasCahaya'] ?? 0,
      kecepatanAngin: (json['kecepatanAngin'] ?? 0).toDouble(),
      kecepatanAnginKnot: (json['kecepatanAnginKnot'] ?? 0).toDouble(), // <-- BARU
      arahAngin: (json['arahAngin'] ?? 0).toDouble(),
      curahHujan: (json['curahHujan'] ?? 0).toDouble(),
      tanggal: json['tanggal'] ?? '',
      waktu: json['waktu'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'suhu': suhu,
      'kelembapan': kelembapan,
      'intensitasCahaya': intensitasCahaya,
      'kecepatanAngin': kecepatanAngin,
      'kecepatanAnginKnot': kecepatanAnginKnot, // <-- BARU
      'arahAngin': arahAngin,
      'curahHujan': curahHujan,
      'tanggal': tanggal,
      'waktu': waktu,
    };
  }

  @override
  String toString() {
    return 'Suhu: $suhu°C, Kelembapan: $kelembapan%, Cahaya: $intensitasCahaya Lux, Angin: $kecepatanAngin m/s ($kecepatanAnginKnot knot), Hujan: $curahHujan mm';
  }
}