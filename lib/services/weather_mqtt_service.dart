import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_data.dart';

enum WeatherConnectionState {
  disconnected,
  connecting,
  connected,
}

class WeatherMQTTService extends ChangeNotifier {
  // ==================== KONFIGURASI WEATHER MQTT ====================
  static const String _host = '335c4f56e51e42f4a5a82c5a477c3e96.s1.eu.hivemq.cloud';
  static const int _port = 8883;
  static const String _username = 'esp32sensoriklim';
  static const String _password = '12345678aBz';
  // ================================================================

  // ==================== TOPIC MQTT ====================
  static const String topicWeather = 'weatherstation/sensors';
  static const String topicStatus = 'weatherstation/status';
  // ====================================================

  late MqttServerClient _client;

  WeatherConnectionState _connectionState = WeatherConnectionState.disconnected;
  WeatherConnectionState get connectionState => _connectionState;

  // Weather Data
  WeatherData? _currentWeather;
  WeatherData? get currentWeather => _currentWeather;

  // History untuk grafik (data per jam)
  final List<WeatherData> _weatherHistory = [];
  List<WeatherData> get weatherHistory => _weatherHistory;
  
  // Buffer untuk data mentah (untuk perhitungan rata-rata per jam)
  final List<WeatherData> _rawDataBuffer = [];
  String _currentHourKey = '';
  
  // Batas maksimum data history (per jam)
  static const int maxHistoryLength = 720; // 30 hari x 24 jam

  // Stream Controllers
  final StreamController<WeatherData> _weatherStreamController = 
      StreamController<WeatherData>.broadcast();
  Stream<WeatherData> get weatherStream => _weatherStreamController.stream;

  Timer? _reconnectTimer;
  bool _isSubscribed = false;
  bool _isListening = false;

  WeatherMQTTService() {
    _initClient();
    _loadHistoryFromStorage();
  }

  // ==================== LOAD HISTORY DARI STORAGE ====================
  Future<void> _loadHistoryFromStorage() async {
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
        _weatherHistory.clear();
        _weatherHistory.addAll(history);
        debugPrint('📂 Loaded ${_weatherHistory.length} hourly data from storage');
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  // ==================== SIMPAN HISTORY KE STORAGE ====================
  Future<void> _saveHistoryToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> historyJson = [];
      
      for (var data in _weatherHistory) {
        final json = '${data.suhu}|${data.kelembapan}|${data.intensitasCahaya}|'
                     '${data.kecepatanAngin}|${data.kecepatanAnginKnot}|'
                     '${data.arahAngin}|${data.curahHujan}|'
                     '${data.tanggal}|${data.waktu}';
        historyJson.add(json);
      }
      
      await prefs.setStringList('weather_history_hourly', historyJson);
      debugPrint('💾 Saved ${_weatherHistory.length} hourly data to storage');
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  // ==================== INIT CLIENT ====================
  void _initClient() {
    debugPrint('🌤️ Initializing Weather MQTT Client...');
    
    _client = MqttServerClient.withPort(
      _host, 
      'flutter_weather_${DateTime.now().millisecondsSinceEpoch}',
      _port
    );
    _client.secure = true;
    _client.keepAlivePeriod = 20;
    
    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;
    
    debugPrint('✅ Weather MQTT Client initialized');
  }

  // ==================== MESSAGE LISTENER ====================
  void _setupMessageListener() {
    if (_isListening) return;
    if (_client.updates == null) {
      debugPrint('⚠️ _client.updates is null, cannot setup listener');
      return;
    }
    
    debugPrint('📡 Setting up weather message listener...');
    
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (var event in events) {
        try {
          final topic = event.topic;
          final message = event.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
          
          debugPrint('📩 [Weather MQTT] Topic: $topic, Payload: "$payload"');
          
          if (topic == topicWeather) {
            _handleWeatherData(payload);
          } else if (topic == topicStatus) {
            _handleStatusData(payload);
          }
        } catch (e) {
          debugPrint('❌ Error processing weather event: $e');
        }
      }
    });
    
    _isListening = true;
    debugPrint('✅ Weather message listener setup complete');
  }

  // ==================== HANDLE WEATHER DATA ====================
  void _handleWeatherData(String payload) {
    try {
      // Parse JSON dari ESP32
      String clean = payload.trim();
      if (!clean.startsWith('{') || !clean.endsWith('}')) return;
      
      clean = clean.substring(1, clean.length - 1);
      final parts = clean.split(',');
      
      String timestamp = '';
      double temperature = 0;
      double humidity = 0;
      double windSpeed = 0;
      double windKnot = 0;
      double windAngle = 0;
      // windDirection digunakan untuk debug
      String windDirection = '--';
      double rainDaily = 0;
      int lux = 0;
      
      for (var part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length != 2) continue;
        
        final key = keyValue[0].trim().replaceAll('"', '');
        final value = keyValue[1].trim().replaceAll('"', '');
        
        switch (key) {
          case 'ts':
            timestamp = value;
            break;
          case 'tmp':
            temperature = double.tryParse(value) ?? 0;
            break;
          case 'hum':
            humidity = double.tryParse(value) ?? 0;
            break;
          case 'wnd':
            windSpeed = double.tryParse(value) ?? 0;
            break;
          case 'knt':
            windKnot = double.tryParse(value) ?? 0;
            break;
          case 'ang':
            windAngle = double.tryParse(value) ?? 0;
            break;
          case 'dir':
            windDirection = value;
            break;
          case 'rn':
            rainDaily = double.tryParse(value) ?? 0;
            break;
          case 'lx':
            lux = int.tryParse(value) ?? 0;
            break;
        }
      }
      
      // Parse timestamp
      String date = '';
      String time = '';
      String hourKey = '';
      
      if (timestamp.isNotEmpty) {
        final parts2 = timestamp.split(' ');
        if (parts2.length == 2) {
          final dateParts = parts2[0].split('-');
          if (dateParts.length == 3) {
            final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
            final month = months[int.parse(dateParts[1]) - 1];
            date = '${int.parse(dateParts[2])} $month ${dateParts[0]}';
          }
          
          // Ambil jam untuk key (YYYY-MM-DD HH)
          hourKey = '${parts2[0]} ${parts2[1].substring(0, 2)}';
          
          final timeParts = parts2[1].split(':');
          if (timeParts.length >= 2) {
            time = '${timeParts[0]}.${timeParts[1]}';
          }
        }
      }
      
      final weatherData = WeatherData(
        suhu: temperature,
        kelembapan: humidity,
        intensitasCahaya: lux,
        kecepatanAngin: windSpeed,
        kecepatanAnginKnot: windKnot,
        arahAngin: windAngle,
        curahHujan: rainDaily,
        tanggal: date,
        waktu: time,
      );
      
      _currentWeather = weatherData;
      _weatherStreamController.add(weatherData);
      notifyListeners();
      
      // ===== PROSES DATA PER JAM =====
      _processHourlyData(weatherData, hourKey);
      
      // Gunakan windDirection untuk debug
      debugPrint('✅ Weather: $_currentWeather, Direction: $windDirection');
      
    } catch (e) {
      debugPrint('❌ Error parsing weather data: $e');
      debugPrint('Payload: $payload');
    }
  }

  // ===== PROSES DATA PER JAM (RATA-RATA) =====
  void _processHourlyData(WeatherData data, String hourKey) {
    if (hourKey.isEmpty) return;
    
    // Jika jam baru, simpan rata-rata jam sebelumnya
    if (_currentHourKey.isNotEmpty && _currentHourKey != hourKey) {
      _saveHourlyAverage();
    }
    
    // Tambahkan ke buffer
    _rawDataBuffer.add(data);
    _currentHourKey = hourKey;
  }

  // ===== SIMPAN RATA-RATA PER JAM =====
  void _saveHourlyAverage() {
    if (_rawDataBuffer.isEmpty) return;
    
    // Hitung rata-rata
    double avgSuhu = 0;
    double avgKelembapan = 0;
    double avgCahaya = 0;
    double avgAngin = 0;
    double avgAnginKnot = 0;
    double avgArah = 0;
    double totalHujan = 0;
    
    for (var d in _rawDataBuffer) {
      avgSuhu += d.suhu;
      avgKelembapan += d.kelembapan;
      avgCahaya += d.intensitasCahaya;
      avgAngin += d.kecepatanAngin;
      avgAnginKnot += d.kecepatanAnginKnot;
      avgArah += d.arahAngin;
      totalHujan += d.curahHujan;
    }
    
    final count = _rawDataBuffer.length;
    avgSuhu /= count;
    avgKelembapan /= count;
    avgCahaya /= count;
    avgAngin /= count;
    avgAnginKnot /= count;
    avgArah /= count;
    
    // Ambil data terakhir untuk tanggal/waktu
    final lastData = _rawDataBuffer.last;
    
    // Buat data rata-rata per jam
    final hourlyData = WeatherData(
      suhu: avgSuhu,
      kelembapan: avgKelembapan,
      intensitasCahaya: avgCahaya.round(),
      kecepatanAngin: avgAngin,
      kecepatanAnginKnot: avgAnginKnot,
      arahAngin: avgArah,
      curahHujan: totalHujan,
      tanggal: lastData.tanggal,
      waktu: '${lastData.waktu.substring(0, 2)}.00', // Format: HH.00
    );
    
    // Tambahkan ke history (hapus duplikat jam yang sama)
    _weatherHistory.removeWhere((d) => 
      d.tanggal == hourlyData.tanggal && 
      d.waktu.substring(0, 2) == hourlyData.waktu.substring(0, 2)
    );
    
    _weatherHistory.add(hourlyData);
    
    // Batasi jumlah data
    while (_weatherHistory.length > maxHistoryLength) {
      _weatherHistory.removeAt(0);
    }
    
    // Kosongkan buffer
    _rawDataBuffer.clear();
    
    // Simpan ke storage
    _saveHistoryToStorage();
    
    debugPrint('📊 Hourly average saved: ${hourlyData.tanggal} ${hourlyData.waktu}');
  }

  // ===== FLUSH DATA SAAT APLIKASI DITUTUP =====
  void flushHourlyData() {
    if (_rawDataBuffer.isNotEmpty) {
      _saveHourlyAverage();
    }
  }

  void _handleStatusData(String payload) {
    debugPrint('📊 Weather Status: $payload');
  }

  // ==================== MQTT CONNECTION ====================
  void _onConnected() {
    debugPrint('🌤️ Weather MQTT Connected!');
    _connectionState = WeatherConnectionState.connected;
    _isSubscribed = false;
    notifyListeners();
    
    _setupMessageListener();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _subscribeToTopics();
    });
  }

  void _onDisconnected() {
    debugPrint('❌ Weather MQTT Disconnected');
    _connectionState = WeatherConnectionState.disconnected;
    _isSubscribed = false;
    _isListening = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    debugPrint('📡 Subscribed to weather topic: $topic');
  }

  Future<bool> connect() async {
    try {
      debugPrint('🌤️ Connecting to Weather MQTT broker...');
      _connectionState = WeatherConnectionState.connecting;
      notifyListeners();

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier)
          .withWillTopic('flutter_weather/will')
          .withWillMessage('Disconnected')
          .startClean()
          .authenticateAs(_username, _password);

      _client.connectionMessage = connMessage;
      await _client.connect();

      final status = _client.connectionStatus;
      if (status != null && status.state == MqttConnectionState.connected) {
        _connectionState = WeatherConnectionState.connected;
        notifyListeners();
        debugPrint('✅ Weather connection successful!');
        return true;
      } else {
        _connectionState = WeatherConnectionState.disconnected;
        notifyListeners();
        debugPrint('❌ Weather connection failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Weather connection error: $e');
      _connectionState = WeatherConnectionState.disconnected;
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  void disconnect() {
    flushHourlyData(); // Simpan data terakhir sebelum disconnect
    _reconnectTimer?.cancel();
    _client.disconnect();
    _connectionState = WeatherConnectionState.disconnected;
    _isListening = false;
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('🔄 Attempting to reconnect weather...');
      connect();
    });
  }

  // ==================== SUBSCRIBE TOPICS ====================
  void _subscribeToTopics() {
    if (_connectionState != WeatherConnectionState.connected) return;
    if (_isSubscribed) return;
    
    debugPrint('📡 Subscribing to weather topics...');
    
    _client.subscribe(topicWeather, MqttQos.atLeastOnce);
    _client.subscribe(topicStatus, MqttQos.atLeastOnce);
    _client.subscribe('weatherstation/#', MqttQos.atLeastOnce);
    
    _isSubscribed = true;
    debugPrint('✅ Subscribed to weather topics');
  }

  // ==================== GETTERS ====================
  List<double> getSuhuHistory() {
    return _weatherHistory.map((data) => data.suhu).toList();
  }

  List<double> getKelembapanHistory() {
    return _weatherHistory.map((data) => data.kelembapan).toList();
  }

  List<double> getCahayaHistory() {
    return _weatherHistory.map((data) => data.intensitasCahaya.toDouble()).toList();
  }

  List<double> getAnginHistory() {
    return _weatherHistory.map((data) => data.kecepatanAngin).toList();
  }

  List<double> getAnginKnotHistory() {
    return _weatherHistory.map((data) => data.kecepatanAnginKnot).toList();
  }

  List<double> getHujanHistory() {
    return _weatherHistory.map((data) => data.curahHujan).toList();
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    flushHourlyData(); // Simpan data terakhir
    _reconnectTimer?.cancel();
    _weatherStreamController.close();
    _client.disconnect();
    super.dispose();
  }
}