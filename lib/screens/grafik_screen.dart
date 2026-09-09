import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/bottom_nav_bar.dart';
import '../services/weather_mqtt_service.dart';
import '../services/hourly_data_service.dart';
import '../models/weather_data.dart';
import '../models/hourly_weather_data.dart';

enum HistoricalPeriod {
  today,
  sevenDays,
  thirtyDays,
}

extension HistoricalPeriodExtension on HistoricalPeriod {
  String get label {
    switch (this) {
      case HistoricalPeriod.today:
        return 'Hari Ini';
      case HistoricalPeriod.sevenDays:
        return '7 Hari';
      case HistoricalPeriod.thirtyDays:
        return '30 Hari';
    }
  }

  int get days {
    switch (this) {
      case HistoricalPeriod.today:
        return 0;
      case HistoricalPeriod.sevenDays:
        return 7;
      case HistoricalPeriod.thirtyDays:
        return 30;
    }
  }
}

class GrafikScreen extends StatefulWidget {
  const GrafikScreen({super.key});

  @override
  State<GrafikScreen> createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen> {
  int _selectedIndex = 0;
  String _selectedChart = 'Suhu';
  
  // Data dari MQTT (real-time)
  List<WeatherData> _weatherHistory = [];
  List<WeatherData> _filteredHistory = [];
  
  // Data dari API (historis) - RAW dari API
  List<HourlyWeatherData> _historicalData = [];
  
  // Data yang sudah diproses (unique + sorted)
  List<HourlyWeatherData> _processedHistoricalData = [];
  
  // Data agregasi untuk grafik
  List<HourlyWeatherData> _aggregatedData = [];
  
  bool _isLoadingHistorical = false;
  String? _historicalError;
  
  // Filter periode
  HistoricalPeriod _selectedPeriod = HistoricalPeriod.today;

  bool _isLoading = true;
  bool _isExporting = false;

  // Warna untuk setiap chart
  final Map<String, Color> _chartColors = {
    'Suhu': const Color(0xFFFF6B6B),
    'Kelembapan': const Color(0xFF4ECDC4),
    'Cahaya': const Color(0xFFFFD93D),
    'Angin': const Color(0xFF6C5CE7),
    'Hujan': const Color(0xFF00B894),
  };

  // Icon untuk setiap chart
  final Map<String, IconData> _chartIcons = {
    'Suhu': Icons.thermostat,
    'Kelembapan': Icons.water_drop,
    'Cahaya': Icons.wb_sunny,
    'Angin': Icons.air,
    'Hujan': Icons.umbrella,
  };

  // Unit untuk setiap chart
  final Map<String, String> _chartUnits = {
    'Suhu': '°C',
    'Kelembapan': '%',
    'Cahaya': ' Lux',
    'Angin': ' m/s',
    'Hujan': ' mm',
  };

  @override
  void initState() {
    super.initState();
    _checkRoleAndSetIndex();
    _loadWeatherHistory();
    _loadHistoricalData();
    
    // Listen untuk update data dari MQTT
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final weatherMQTT = Provider.of<WeatherMQTTService>(context, listen: false);
      weatherMQTT.weatherStream.listen((data) {
        _loadWeatherHistory();
      });
    });
  }

  Future<void> _checkRoleAndSetIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'user';
    setState(() {
      _selectedIndex = role == 'admin' ? 2 : 1;
    });
  }

  // ===== PROSES DATA HISTORIS: UNIQUE + SORTED =====
  List<HourlyWeatherData> _getProcessedHistoricalData() {
    if (_historicalData.isEmpty) return [];
    
    final Map<String, HourlyWeatherData> uniqueData = {};
    
    for (var data in _historicalData) {
      final key = '${data.timestamp.year}-${data.timestamp.month}-${data.timestamp.day}_${data.timestamp.hour}';
      
      if (!uniqueData.containsKey(key)) {
        uniqueData[key] = data;
      } else {
        if (data.timestamp.isAfter(uniqueData[key]!.timestamp)) {
          uniqueData[key] = data;
        }
      }
    }
    
    List<HourlyWeatherData> result = uniqueData.values.toList();
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return result;
  }

  // ===== AGREGASI DATA BERDASARKAN PERIODE =====
  List<HourlyWeatherData> _getAggregatedData() {
    if (_processedHistoricalData.isEmpty) return [];
    
    switch (_selectedPeriod) {
      case HistoricalPeriod.today:
        return _processedHistoricalData;
      case HistoricalPeriod.sevenDays:
        return _aggregateByDay(_processedHistoricalData);
      case HistoricalPeriod.thirtyDays:
        return _aggregateByWeek(_processedHistoricalData);
    }
  }

  // ===== AGREGASI PER HARI (untuk 7 Hari) =====
  List<HourlyWeatherData> _aggregateByDay(List<HourlyWeatherData> data) {
    if (data.isEmpty) return [];
    
    final Map<String, List<HourlyWeatherData>> groupedByDay = {};
    
    for (var d in data) {
      final key = '${d.timestamp.year}-${d.timestamp.month}-${d.timestamp.day}';
      if (!groupedByDay.containsKey(key)) {
        groupedByDay[key] = [];
      }
      groupedByDay[key]!.add(d);
    }
    
    final List<HourlyWeatherData> result = [];
    final sortedKeys = groupedByDay.keys.toList()..sort();
    
    for (var key in sortedKeys) {
      final dayData = groupedByDay[key]!;
      if (dayData.isEmpty) continue;
      
      double avgTemp = 0;
      double avgHum = 0;
      double avgLux = 0;
      double avgWind = 0;
      double avgRain = 0;
      
      for (var d in dayData) {
        avgTemp += d.temperature;
        avgHum += d.humidity;
        avgLux += d.lux;
        avgWind += d.windSpeedMs;
        avgRain += d.rainDailyMm;
      }
      
      final count = dayData.length;
      avgTemp /= count;
      avgHum /= count;
      avgLux /= count;
      avgWind /= count;
      avgRain /= count;
      
      final firstData = dayData.first;
      final aggregatedDate = DateTime(
        firstData.timestamp.year,
        firstData.timestamp.month,
        firstData.timestamp.day,
        12, 0, 0
      );
      
      result.add(HourlyWeatherData(
        timestamp: aggregatedDate,
        temperature: avgTemp,
        humidity: avgHum,
        windSpeedMs: avgWind,
        windSpeedKnot: avgWind * 1.94384,
        windAngle: 0,
        windDirection: '--',
        rainDailyMm: avgRain,
        lux: avgLux.round(),
      ));
    }
    
    return result;
  }

  // ===== AGREGASI PER MINGGU (untuk 30 Hari) =====
  List<HourlyWeatherData> _aggregateByWeek(List<HourlyWeatherData> data) {
    if (data.isEmpty) return [];
    
    final Map<int, List<HourlyWeatherData>> groupedByWeek = {};
    
    for (var d in data) {
      final firstDate = data.first.timestamp;
      final diff = d.timestamp.difference(firstDate);
      final weekNumber = (diff.inDays / 7).floor();
      
      if (!groupedByWeek.containsKey(weekNumber)) {
        groupedByWeek[weekNumber] = [];
      }
      groupedByWeek[weekNumber]!.add(d);
    }
    
    final List<HourlyWeatherData> result = [];
    final sortedKeys = groupedByWeek.keys.toList()..sort();
    
    for (var key in sortedKeys) {
      final weekData = groupedByWeek[key]!;
      if (weekData.isEmpty) continue;
      
      double avgTemp = 0;
      double avgHum = 0;
      double avgLux = 0;
      double avgWind = 0;
      double avgRain = 0;
      
      for (var d in weekData) {
        avgTemp += d.temperature;
        avgHum += d.humidity;
        avgLux += d.lux;
        avgWind += d.windSpeedMs;
        avgRain += d.rainDailyMm;
      }
      
      final count = weekData.length;
      avgTemp /= count;
      avgHum /= count;
      avgLux /= count;
      avgWind /= count;
      avgRain /= count;
      
      final firstData = weekData.first;
      final midWeek = DateTime(
        firstData.timestamp.year,
        firstData.timestamp.month,
        firstData.timestamp.day + 3,
        12, 0, 0
      );
      
      result.add(HourlyWeatherData(
        timestamp: midWeek,
        temperature: avgTemp,
        humidity: avgHum,
        windSpeedMs: avgWind,
        windSpeedKnot: avgWind * 1.94384,
        windAngle: 0,
        windDirection: '--',
        rainDailyMm: avgRain,
        lux: avgLux.round(),
      ));
    }
    
    return result;
  }

  // ===== GET SKALA Y =====
  Map<String, double> _getYAxisConfig(List<double> values) {
    if (values.isEmpty) {
      return {'minY': 0, 'maxY': 10, 'interval': 1};
    }

    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);

    switch (_selectedChart) {
      case 'Suhu':
        return _getSuhuConfig(minValue, maxValue);
      case 'Kelembapan':
        return _getKelembapanConfig(minValue, maxValue);
      case 'Cahaya':
        return _getCahayaConfig(minValue, maxValue);
      case 'Angin':
        return _getAnginConfig(minValue, maxValue);
      case 'Hujan':
        return _getHujanConfig(minValue, maxValue);
      default:
        return {'minY': 0, 'maxY': 10, 'interval': 1};
    }
  }

  Map<String, double> _getSuhuConfig(double minValue, double maxValue) {
    const double defaultMin = 0;
    const double defaultMax = 100;
    const double interval = 10;
    
    double minY = defaultMin;
    double maxY = defaultMax;
    
    if (minValue < minY) {
      minY = (minValue / interval).floorToDouble() * interval;
      if (minY < 0) minY = 0;
    }
    if (maxValue > maxY) {
      maxY = (maxValue / interval).ceilToDouble() * interval;
    }
    
    return {'minY': minY, 'maxY': maxY, 'interval': interval};
  }

  Map<String, double> _getKelembapanConfig(double minValue, double maxValue) {
    return {'minY': 0, 'maxY': 100, 'interval': 10};
  }

  Map<String, double> _getCahayaConfig(double minValue, double maxValue) {
    double maxY = maxValue;
    
    if (maxY <= 100) {
      maxY = 100;
    } else if (maxY <= 500) {
      maxY = (maxY / 100).ceilToDouble() * 100;
    } else if (maxY <= 1000) {
      maxY = (maxY / 100).ceilToDouble() * 100;
    } else if (maxY <= 5000) {
      maxY = (maxY / 500).ceilToDouble() * 500;
    } else {
      maxY = (maxY / 1000).ceilToDouble() * 1000;
    }
    
    double interval;
    if (maxY <= 100) {
      interval = 10;
    } else if (maxY <= 500) {
      interval = 50;
    } else if (maxY <= 1000) {
      interval = 100;
    } else if (maxY <= 5000) {
      interval = 500;
    } else {
      interval = 1000;
    }
    
    return {'minY': 0, 'maxY': maxY, 'interval': interval};
  }

  Map<String, double> _getAnginConfig(double minValue, double maxValue) {
    const double minY = 0;
    const double interval = 2;
    double maxY = 20;
    
    if (maxValue > maxY) {
      maxY = (maxValue / interval).ceilToDouble() * interval;
    }
    
    return {'minY': minY, 'maxY': maxY, 'interval': interval};
  }

  Map<String, double> _getHujanConfig(double minValue, double maxValue) {
    const double minY = 0;
    const double interval = 10;
    double maxY = 100;
    
    if (maxValue > maxY) {
      maxY = (maxValue / interval).ceilToDouble() * interval;
    }
    
    return {'minY': minY, 'maxY': maxY, 'interval': interval};
  }

  String _formatYLabel(double value) {
    if (_selectedChart == 'Cahaya') {
      return value.toInt().toString();
    }
    return value.toInt().toString();
  }

  // ===== LOAD HISTORICAL DATA =====
  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoadingHistorical = true;
      _historicalError = null;
    });

    try {
      final now = DateTime.now();
      final startDate = _getStartDate(now);
      final endDate = now;

      debugPrint('📊 Fetching historical data: ${startDate.toIso8601String()} to ${endDate.toIso8601String()}');

      final data = await HourlyDataService.getHourlyData(
        start: startDate,
        end: endDate,
      );

      setState(() {
        _historicalData = data;
        _processedHistoricalData = _getProcessedHistoricalData();
        _aggregatedData = _getAggregatedData();
        _isLoadingHistorical = false;
        _historicalError = null;
        
        debugPrint('📊 Loaded ${_historicalData.length} raw data, processed to ${_processedHistoricalData.length} unique data, aggregated to ${_aggregatedData.length} data');
      });
    } catch (e) {
      setState(() {
        _historicalError = e.toString();
        _isLoadingHistorical = false;
      });
    }
  }

  DateTime _getStartDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    
    switch (_selectedPeriod) {
      case HistoricalPeriod.today:
        return today;
      case HistoricalPeriod.sevenDays:
        return today.subtract(const Duration(days: 6));
      case HistoricalPeriod.thirtyDays:
        return today.subtract(const Duration(days: 29));
    }
  }

  // ===== FILTER DATA =====
  void _applyFilter() {
    if (_weatherHistory.isEmpty) {
      setState(() => _filteredHistory = []);
      return;
    }

    final sortedData = List<WeatherData>.from(_weatherHistory)
      ..sort((a, b) {
        final dateA = _parseDate(a.tanggal);
        final dateB = _parseDate(b.tanggal);
        return dateB.compareTo(dateA);
      });

    setState(() {
      _filteredHistory = sortedData.take(7).toList();
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      final parts = dateStr.split(' ');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final monthNames = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'Mei': 5, 'Jun': 6,
          'Jul': 7, 'Agu': 8, 'Sep': 9, 'Okt': 10, 'Nov': 11, 'Des': 12
        };
        final month = monthNames[parts[1]] ?? 1;
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
      
      final parts2 = dateStr.split('-');
      if (parts2.length == 3) {
        return DateTime(
          int.parse(parts2[0]),
          int.parse(parts2[1]),
          int.parse(parts2[2]),
        );
      }
    } catch (e) {
      debugPrint('Error parsing date: $e');
    }
    return DateTime.now();
  }

  // ===== LOAD DATA DARI SHAREDPREFERENCES =====
  Future<void> _loadWeatherHistory() async {
    setState(() => _isLoading = true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getStringList('weather_history_hourly') ?? [];
      
      if (historyJson.isNotEmpty) {
        final List<WeatherData> history = [];
        for (var json in historyJson) {
          try {
            final parts = json.split('|');
            if (parts.length == 9) {
              final data = WeatherData(
                suhu: double.tryParse(parts[0]) ?? 0,
                kelembapan: double.tryParse(parts[1]) ?? 0,
                intensitasCahaya: int.tryParse(parts[2]) ?? 0,
                kecepatanAngin: double.tryParse(parts[3]) ?? 0,
                kecepatanAnginKnot: double.tryParse(parts[4]) ?? 0,
                arahAngin: double.tryParse(parts[5]) ?? 0,
                curahHujan: double.tryParse(parts[6]) ?? 0,
                tanggal: parts[7],
                waktu: parts[8],
              );
              history.add(data);
            }
          } catch (e) {
            debugPrint('Error parsing history: $e');
          }
        }
        
        setState(() {
          _weatherHistory = history.reversed.toList();
          _isLoading = false;
        });
        
        _applyFilter();
        debugPrint('📂 Loaded ${_weatherHistory.length} data from storage');
      } else {
        setState(() {
          _weatherHistory = [];
          _filteredHistory = [];
          _isLoading = false;
        });
        debugPrint('📂 No data found in storage');
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() {
        _weatherHistory = [];
        _filteredHistory = [];
        _isLoading = false;
      });
    }
  }

  // ===== EXPORT CSV =====
  Future<void> _exportCSV() async {
    // Ambil data yang akan diekspor (prioritaskan data agregasi)
    List<dynamic> dataToExport = [];
    String header = '';
    
    // Cek apakah ada data historis
    if (_aggregatedData.isNotEmpty) {
      dataToExport = _aggregatedData;
      header = 'Tanggal,Jam,Suhu(°C),Kelembapan(%),Cahaya(Lux),Angin(m/s),Hujan(mm)\n';
    } else if (_processedHistoricalData.isNotEmpty) {
      dataToExport = _processedHistoricalData;
      header = 'Tanggal,Jam,Suhu(°C),Kelembapan(%),Cahaya(Lux),Angin(m/s),Hujan(mm)\n';
    } else if (_filteredHistory.isNotEmpty) {
      dataToExport = _filteredHistory;
      header = 'Tanggal,Waktu,Suhu(°C),Kelembapan(%),Cahaya(Lux),Angin(m/s),Angin(knot),Arah(°),Hujan(mm)\n';
    } else if (_weatherHistory.isNotEmpty) {
      dataToExport = _weatherHistory;
      header = 'Tanggal,Waktu,Suhu(°C),Kelembapan(%),Cahaya(Lux),Angin(m/s),Angin(knot),Arah(°),Hujan(mm)\n';
    } else {
      _showSnackbar('Tidak ada data untuk diekspor');
      return;
    }

    setState(() => _isExporting = true);

    try {
      String csv = header;
      
      if (dataToExport.isNotEmpty && dataToExport.first is HourlyWeatherData) {
        // Export data historis
        for (var data in dataToExport as List<HourlyWeatherData>) {
          final dateStr = '${data.timestamp.year}-${_padZero(data.timestamp.month)}-${_padZero(data.timestamp.day)}';
          final timeStr = '${_padZero(data.timestamp.hour)}:00';
          csv += '$dateStr,$timeStr,'
                 '${data.temperature.toStringAsFixed(1)},'
                 '${data.humidity.toStringAsFixed(1)},'
                 '${data.lux},'
                 '${data.windSpeedMs.toStringAsFixed(1)},'
                 '${data.rainDailyMm.toStringAsFixed(1)}\n';
        }
      } else if (dataToExport.isNotEmpty && dataToExport.first is WeatherData) {
        // Export data MQTT
        for (var data in dataToExport as List<WeatherData>) {
          csv += '${data.tanggal},${data.waktu},'
                 '${data.suhu.toStringAsFixed(1)},'
                 '${data.kelembapan.toStringAsFixed(1)},'
                 '${data.intensitasCahaya},'
                 '${data.kecepatanAngin.toStringAsFixed(1)},'
                 '${data.kecepatanAnginKnot.toStringAsFixed(1)},'
                 '${data.arahAngin.toStringAsFixed(1)},'
                 '${data.curahHujan.toStringAsFixed(1)}\n';
        }
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'weather_data_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Data Cuaca ${dataToExport.length} Data',
      );

      _showSnackbar('CSV berhasil diekspor (${dataToExport.length} data)');
    } catch (e) {
      _showSnackbar('Gagal mengekspor CSV: $e');
      debugPrint('Error exporting CSV: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  String _padZero(int value) {
    return value.toString().padLeft(2, '0');
  }

  // ===== EXPORT PDF =====
  Future<void> _exportPDF() async {
    // Ambil data yang akan diekspor
    List<dynamic> dataToExport = [];
    String title = '';
    
    if (_aggregatedData.isNotEmpty) {
      dataToExport = _aggregatedData;
      title = 'Data Historis ${_selectedPeriod.label} (Agregasi)';
    } else if (_processedHistoricalData.isNotEmpty) {
      dataToExport = _processedHistoricalData;
      title = 'Data Historis ${_selectedPeriod.label}';
    } else if (_filteredHistory.isNotEmpty) {
      dataToExport = _filteredHistory;
      title = 'Data Real-time (Terakhir)';
    } else if (_weatherHistory.isNotEmpty) {
      dataToExport = _weatherHistory;
      title = 'Data Real-time';
    } else {
      _showSnackbar('Tidak ada data untuk diekspor');
      return;
    }

    setState(() => _isExporting = true);

    try {
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Text(
                  'Laporan Data Cuaca',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  title,
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Total Data: ${dataToExport.length}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.SizedBox(height: 10),
              
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FixedColumnWidth(60),
                  1: const pw.FixedColumnWidth(40),
                  2: const pw.FixedColumnWidth(50),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FixedColumnWidth(50),
                  5: const pw.FixedColumnWidth(50),
                  6: const pw.FixedColumnWidth(50),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Tanggal', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Jam', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Suhu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Kelembapan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Cahaya', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Angin', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('Hujan', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  ...dataToExport.map((data) {
                    if (data is HourlyWeatherData) {
                      final dateStr = '${data.timestamp.day}/${data.timestamp.month}/${data.timestamp.year}';
                      final timeStr = '${data.timestamp.hour.toString().padLeft(2, '0')}:00';
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(timeStr, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.temperature.toStringAsFixed(1)}°C', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.humidity.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.lux} Lux', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.windSpeedMs.toStringAsFixed(1)} m/s', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.rainDailyMm.toStringAsFixed(1)} mm', style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    } else if (data is WeatherData) {
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(data.tanggal, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(data.waktu, style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.suhu.toStringAsFixed(1)}°C', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.kelembapan.toStringAsFixed(1)}%', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.intensitasCahaya} Lux', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.kecepatanAngin.toStringAsFixed(1)} m/s', style: const pw.TextStyle(fontSize: 9)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('${data.curahHujan.toStringAsFixed(1)} mm', style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ],
                      );
                    }
                    return const pw.TableRow(children: []);
                  }),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              pw.Center(
                child: pw.Text(
                  'Dicetak pada: ${DateTime.now().toString().substring(0, 19)}',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      final directory = await getTemporaryDirectory();
      final fileName = 'weather_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Data Cuaca ${dataToExport.length} Data',
      );

      _showSnackbar('PDF berhasil diekspor (${dataToExport.length} data)');
    } catch (e) {
      _showSnackbar('Gagal mengekspor PDF: $e');
      debugPrint('Error exporting PDF: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: message.contains('berhasil') ? Colors.green : Colors.red,
      ),
    );
  }

  // ===== GET NILAI CHART (MQTT) =====
  List<double> getChartValues() {
    final data = _filteredHistory.isEmpty ? _weatherHistory : _filteredHistory;
    if (data.isEmpty) return [];
    
    switch (_selectedChart) {
      case 'Suhu':
        return data.map((d) => d.suhu).toList();
      case 'Kelembapan':
        return data.map((d) => d.kelembapan).toList();
      case 'Cahaya':
        return data.map((d) => d.intensitasCahaya.toDouble()).toList();
      case 'Angin':
        return data.map((d) => d.kecepatanAngin).toList();
      case 'Hujan':
        return data.map((d) => d.curahHujan).toList();
      default:
        return data.map((d) => d.suhu).toList();
    }
  }

  List<String> getDayLabels() {
    final data = _filteredHistory.isEmpty ? _weatherHistory : _filteredHistory;
    if (data.isEmpty) return [];
    return data.map((d) {
      final dateParts = d.tanggal.split(' ');
      if (dateParts.length >= 3) {
        return '${dateParts[0]} ${dateParts[1]}\n${d.waktu}';
      }
      return '${d.tanggal}\n${d.waktu}';
    }).toList();
  }

  String getDataCount() {
    final data = _filteredHistory.isEmpty ? _weatherHistory : _filteredHistory;
    return '${data.length} Data';
  }

  // ===== GET NILAI CHART HISTORIS =====
  List<double> getHistoricalChartValues() {
    final data = _aggregatedData.isEmpty ? _processedHistoricalData : _aggregatedData;
    if (data.isEmpty) return [];
    
    switch (_selectedChart) {
      case 'Suhu':
        return data.map((d) => d.temperature).toList();
      case 'Kelembapan':
        return data.map((d) => d.humidity).toList();
      case 'Cahaya':
        return data.map((d) => d.lux.toDouble()).toList();
      case 'Angin':
        return data.map((d) => d.windSpeedMs).toList();
      case 'Hujan':
        return data.map((d) => d.rainDailyMm).toList();
      default:
        return data.map((d) => d.temperature).toList();
    }
  }

  List<String> getHistoricalLabels() {
    final data = _aggregatedData.isEmpty ? _processedHistoricalData : _aggregatedData;
    if (data.isEmpty) return [];
    
    return data.map((d) {
      if (_selectedPeriod == HistoricalPeriod.today) {
        // Hari Ini: tampilkan jam (06, 07, 08, ... 18)
        return d.timestamp.hour.toString().padLeft(2, '0');
      } else if (_selectedPeriod == HistoricalPeriod.sevenDays) {
        // 7 Hari: tampilkan hari (Sen, Sel, Rab, dst)
        final days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
        return days[d.timestamp.weekday - 1];
      } else {
        // 30 Hari: tampilkan minggu ke berapa
        final firstDate = _aggregatedData.isNotEmpty ? _aggregatedData.first.timestamp : DateTime.now();
        final diff = d.timestamp.difference(firstDate);
        final weekNumber = (diff.inDays / 7).floor() + 1;
        return 'M$weekNumber';
      }
    }).toList();
  }

  String getHistoricalSubtitle() {
    final data = _aggregatedData.isEmpty ? _processedHistoricalData : _aggregatedData;
    final count = data.length;
    
    switch (_selectedPeriod) {
      case HistoricalPeriod.today:
        return '$count data per jam (06-18)';
      case HistoricalPeriod.sevenDays:
        return '$count data (rata-rata per hari)';
      case HistoricalPeriod.thirtyDays:
        return '$count data (rata-rata per minggu)';
    }
  }

  String _getDataUnit() {
    switch (_selectedPeriod) {
      case HistoricalPeriod.today:
        return 'Jam';
      case HistoricalPeriod.sevenDays:
        return 'Hari';
      case HistoricalPeriod.thirtyDays:
        return 'Minggu';
    }
  }

  String _getAggregationType() {
    switch (_selectedPeriod) {
      case HistoricalPeriod.today:
        return 'Data Per Jam (06-18)';
      case HistoricalPeriod.sevenDays:
        return 'Rata-rata Harian';
      case HistoricalPeriod.thirtyDays:
        return 'Rata-rata Mingguan';
    }
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final displayData = _aggregatedData.isEmpty ? _processedHistoricalData : _aggregatedData;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('Grafik Cuaca'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Tombol Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () {
              _loadWeatherHistory();
              _loadHistoricalData();
              _showSnackbar('Memuat ulang data...');
            },
          ),
          // Tombol Export
          PopupMenuButton<String>(
            icon: _isExporting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            onSelected: (value) {
              if (value == 'csv') {
                _exportCSV();
              } else if (value == 'pdf') {
                _exportPDF();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart, color: Color(0xFF2D6A4F)),
                    SizedBox(width: 8),
                    Text('Unduh CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf, color: Color(0xFFFF6B6B)),
                    SizedBox(width: 8),
                    Text('Unduh PDF'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF2D6A4F),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Periode:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<HistoricalPeriod>(
                        value: _selectedPeriod,
                        dropdownColor: const Color(0xFF2D6A4F),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        items: HistoricalPeriod.values.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text(period.label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedPeriod = value;
                            });
                            _loadHistoricalData();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayData.isNotEmpty 
                        ? '${displayData.length} data' 
                        : '0 data',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            _loadWeatherHistory(),
            _loadHistoricalData(),
          ]);
        },
        child: Column(
          children: [
            // Filter Chip Chart
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildFilterChip('Suhu', Icons.thermostat),
                    const SizedBox(width: 8),
                    _buildFilterChip('Kelembapan', Icons.water_drop),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cahaya', Icons.wb_sunny),
                    const SizedBox(width: 8),
                    _buildFilterChip('Angin', Icons.air),
                    const SizedBox(width: 8),
                    _buildFilterChip('Hujan', Icons.umbrella),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              child: _isLoadingHistorical
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            color: Color(0xFF2D6A4F),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Memuat data historis...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _historicalError != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 60,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Gagal memuat data',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _historicalError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadHistoricalData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2D6A4F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : displayData.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.show_chart,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Belum ada data historis',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Data akan muncul setelah sensor mengirim data',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  // Card Grafik
                                  _buildHistoricalChartCard(),
                                  const SizedBox(height: 16),
                                  // Info tambahan
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Informasi Data Historis',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2D6A4F),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('Periode', _selectedPeriod.label),
                                        _buildInfoRow('Total Data', '${displayData.length} ${_getDataUnit()}'),
                                        _buildInfoRow('Sumber Data', 'Google Sheets (Historical)'),
                                        _buildInfoRow('Tipe Agregasi', _getAggregationType()),
                                        _buildInfoRow('Rentang Waktu', 
                                          displayData.isNotEmpty
                                              ? '${displayData.first.timestamp.day} ${_getMonthName(displayData.first.timestamp.month)} - '
                                                '${displayData.last.timestamp.day} ${_getMonthName(displayData.last.timestamp.month)}'
                                              : '-'
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 80),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildHistoricalChartCard() {
    final data = _aggregatedData.isEmpty ? _processedHistoricalData : _aggregatedData;
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('Tidak ada data untuk ditampilkan'),
        ),
      );
    }

    final values = getHistoricalChartValues();
    final labels = getHistoricalLabels();
    final color = _chartColors[_selectedChart] ?? Colors.blue;
    final unit = _chartUnits[_selectedChart] ?? '';

    if (values.isEmpty || labels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text('Tidak ada data untuk ditampilkan'),
        ),
      );
    }

    final yConfig = _getYAxisConfig(values);
    final minY = yConfig['minY'] ?? 0;
    final maxY = yConfig['maxY'] ?? 10;
    final yInterval = yConfig['interval'] ?? 1;

    final double xInterval = values.length <= 13
        ? 1.0
        : (values.length / 10).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _chartIcons[_selectedChart],
                    color: _chartColors[_selectedChart],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Grafik $_selectedChart',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D6A4F),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${values.length} Data',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2D6A4F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            getHistoricalSubtitle(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          // Grafik
          SizedBox(
            height: 280,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Color(0xFFE8ECEF),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatYLabel(value),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: xInterval,
                      getTitlesWidget: (value, meta) {
                        final index = value.round();
                        
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            labels[index],
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6B7280),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: const Color(0xFFE8ECEF),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: (values.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      values.length,
                      (index) => FlSpot(index.toDouble(), values[index]),
                    ),
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      color: color.withValues(alpha: 0.1),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: color,
                        );
                      },
                    ),
                    aboveBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        double value = spot.y;
                        String displayValue;
                        if (_selectedChart == 'Cahaya') {
                          displayValue = '${value.toInt()}$unit';
                        } else {
                          displayValue = '${value.toStringAsFixed(1)}$unit';
                        }
                        String label = index < labels.length ? labels[index] : '';
                        return LineTooltipItem(
                          '$label\n$displayValue',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                    getTooltipColor: (spot) {
                      return const Color(0xFF2D6A4F);
                    },
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildHistoricalStats(values),
        ],
      ),
    );
  }

  Widget _buildHistoricalStats(List<double> values) {
    if (values.isEmpty) return const SizedBox();

    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final current = values.last;
    String unit = _chartUnits[_selectedChart] ?? '';

    String formatValue(double value) {
      if (_selectedChart == 'Cahaya') {
        return '${value.toInt()}$unit';
      }
      return '${value.toStringAsFixed(1)}$unit';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Rata-rata', formatValue(avg), Colors.blue),
          _buildStatItem('Tertinggi', formatValue(max), Colors.red),
          _buildStatItem('Terendah', formatValue(min), Colors.green),
          _buildStatItem('Terakhir', formatValue(current), const Color(0xFF2D6A4F)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D6A4F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedChart == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedChart = label;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D6A4F) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF2D6A4F) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}