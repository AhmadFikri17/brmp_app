import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
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

  // Stream Controllers
  final StreamController<WeatherData> _weatherStreamController = 
      StreamController<WeatherData>.broadcast();
  Stream<WeatherData> get weatherStream => _weatherStreamController.stream;

  Timer? _reconnectTimer;
  bool _isSubscribed = false;
  bool _isListening = false;

  WeatherMQTTService() {
    _initClient();
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
      
      // ===== PARSE TIMESTAMP DENGAN FALLBACK =====
      String date = '';
      String time = '';
      
      if (timestamp.isNotEmpty) {
        try {
          final parts2 = timestamp.split(' ');
          if (parts2.length == 2) {
            // Parse tanggal (YYYY-MM-DD)
            final dateParts = parts2[0].split('-');
            if (dateParts.length == 3) {
              final year = int.tryParse(dateParts[0]) ?? 0;
              final month = int.tryParse(dateParts[1]) ?? 1;
              final day = int.tryParse(dateParts[2]) ?? 1;
              
              final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
                              'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
              final monthName = (month >= 1 && month <= 12) ? months[month - 1] : 'Jan';
              date = '$day $monthName $year';
            }
            
            // Parse waktu (HH:MM:SS)
            final timeParts = parts2[1].split(':');
            if (timeParts.length >= 2) {
              time = '${timeParts[0]}.${timeParts[1]}';
            }
          }
        } catch (e) {
          debugPrint('Error parsing timestamp: $e');
        }
      }
      
      // FALLBACK: Jika parsing gagal, gunakan waktu sekarang
      if (date.isEmpty || time.isEmpty) {
        final now = DateTime.now();
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
                        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        
        if (date.isEmpty) {
          date = '${now.day} ${months[now.month - 1]} ${now.year}';
        }
        if (time.isEmpty) {
          time = '${now.hour.toString().padLeft(2, '0')}.${now.minute.toString().padLeft(2, '0')}';
        }
        
        debugPrint('⚠️ Using fallback time: $date $time');
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
      
      debugPrint('✅ Weather: $date $time | Temp: $temperature°C, Hum: $humidity%, Dir: $windDirection');
      
    } catch (e) {
      debugPrint('❌ Error parsing weather data: $e');
      debugPrint('Payload: $payload');
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

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _weatherStreamController.close();
    _client.disconnect();
    super.dispose();
  }
}