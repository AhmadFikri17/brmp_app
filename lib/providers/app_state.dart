import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/mqtt_service.dart';
import '../models/sensor_model.dart';
import '../models/relay_model.dart';

enum AppRole {
  admin,
  user,
  guest,
}

enum AppConnectionStatus {
  connected,
  connecting,
  disconnected,
}

class AppState extends ChangeNotifier {
  // ==================== SINGLETON ====================
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  // ==================== SERVICES ====================
  MQTTService? _mqttService;

  MQTTService get mqttService {
    _mqttService ??= MQTTService();
    return _mqttService!;
  }

  // ==================== AUTH STATE ====================
  User? _currentUser;
  User? get currentUser => _currentUser;

  AppRole _userRole = AppRole.guest;
  AppRole get userRole => _userRole;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  // ==================== SENSOR STATE ====================
  SensorData? _currentSensorData;
  SensorData? get currentSensorData => _currentSensorData;

  final List<SensorData> _sensorHistory = [];
  List<SensorData> get sensorHistory => _sensorHistory;

  static const int maxHistoryLength = 60;

  // ==================== RELAY STATE ====================
  final Map<String, RelayModel> _relays = {};
  Map<String, RelayModel> get relays => _relays;

  // ✅ FIX: Default mode = 'otomatis' (sesuai kondisi ESP32 saat nyala)
  final Map<String, String> _relayModes = {
    '1': 'otomatis',
    '2': 'otomatis',
  };

  Map<String, String> get relayModes => _relayModes;

  // ==================== THRESHOLD STATE ====================
  double _suhuThreshold = 30.0;
  double get suhuThreshold => _suhuThreshold;

  double _kelembapanThreshold = 80.0;
  double get kelembapanThreshold => _kelembapanThreshold;

  double _cahayaThreshold = 500.0;
  double get cahayaThreshold => _cahayaThreshold;

  // ==================== UI STATE ====================
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  // ==================== INITIALIZATION ====================
  void initialize() {
    _relays['1'] = RelayModel(id: '1', name: 'Relay 1');
    _relays['2'] = RelayModel(id: '2', name: 'Relay 2');

    _setupMqttListeners();
    _connectMqtt();
  }

  void _setupMqttListeners() {
    // Sensor stream
    mqttService.sensorStream.listen((sensorData) {
      _updateSensorData(sensorData);
    });

    // Relay status stream
    mqttService.relayStream.listen((relayStatus) {
      relayStatus.forEach((relayId, status) {
        _updateRelayStatus(relayId, status);
      });
    });

    // ✅ BARU: Relay mode stream (dari ESP32)
    mqttService.relayModeStream.listen((relayModes) {
      relayModes.forEach((relayId, mode) {
        _relayModes[relayId] = mode;
      });
      notifyListeners();
    });
  }

  Future<void> _connectMqtt() async {
    setLoading(true);
    await mqttService.connect();

    // ✅ Sync status & mode terakhir dari MQTTService
    // (retained message yang sudah tersimpan sebelum listener siap)
    final lastStatus = mqttService.lastRelayStatus;
    lastStatus.forEach((relayId, status) {
      if (_relays.containsKey(relayId)) {
        _relays[relayId]!.isOn = status;
        _relays[relayId]!.status = status ? 'ON' : 'OFF';
      }
    });

    final lastMode = mqttService.lastRelayMode;
    lastMode.forEach((relayId, mode) {
      _relayModes[relayId] = mode;
    });

    setLoading(false);
    notifyListeners();
  }

  // ==================== SENSOR METHODS ====================
  void _updateSensorData(SensorData data) {
    _currentSensorData = data;
    _sensorHistory.add(data);

    if (_sensorHistory.length > maxHistoryLength) {
      _sensorHistory.removeAt(0);
    }

    _checkAutoMode();
    notifyListeners();
  }

  // ==================== RELAY METHODS ====================
  void _updateRelayStatus(String relayId, bool status) {
    if (_relays.containsKey(relayId)) {
      _relays[relayId]!.isOn = status;
      _relays[relayId]!.status = status ? 'ON' : 'OFF';
      notifyListeners();
    }
  }

  /// ✅ Toggle relay lokal — hanya untuk mode MANUAL.
  /// Publish ke ESP32 dilakukan di UI (`kontrol_screen._sendRelayCommandToESP32`)
  /// agar topic & payload konsisten.
  void toggleRelay(String relayId) {
    if (_relayModes[relayId] == 'otomatis') {
      debugPrint('⚠️ Cannot toggle $relayId in AUTO mode');
      return;
    }

    if (_relays.containsKey(relayId)) {
      final currentState = _relays[relayId]!.isOn;
      final newState = !currentState;

      // Update state lokal
      _relays[relayId]!.isOn = newState;
      _relays[relayId]!.status = newState ? 'ON' : 'OFF';

      // ❌ JANGAN publish di sini — biar UI yang handle
      notifyListeners();
    }
  }

  void setRelayMode(String relayId, String mode) {
    _relayModes[relayId] = mode;
    if (mode == 'otomatis') {
      _checkAutoMode();
    }
    notifyListeners();
  }

  // ==================== AUTO MODE (LOGIKA PENGERING) ====================
  // ✅ Samakan dengan logika ESP32:
  // ON jika kelembapan > threshold OR suhu > threshold OR cahaya < threshold
  void _checkAutoMode() {
    if (_currentSensorData == null) return;

    final data = _currentSensorData!;

    final shouldOn = (data.kelembapan > _kelembapanThreshold) ||
        (data.suhu > _suhuThreshold) ||
        (data.intensitasCahaya < _cahayaThreshold);

    // Relay 1
    if (_relayModes['1'] == 'otomatis') {
      if (_relays['1']?.isOn != shouldOn) {
        _relays['1']!.isOn = shouldOn;
        _relays['1']!.status = shouldOn ? 'ON' : 'OFF';
      }
    }

    // Relay 2
    if (_relayModes['2'] == 'otomatis') {
      if (_relays['2']?.isOn != shouldOn) {
        _relays['2']!.isOn = shouldOn;
        _relays['2']!.status = shouldOn ? 'ON' : 'OFF';
      }
    }
  }

  // ==================== THRESHOLD METHODS ====================
  void setSuhuThreshold(double value) {
    _suhuThreshold = value;
    _checkAutoMode();
    notifyListeners();
  }

  void setKelembapanThreshold(double value) {
    _kelembapanThreshold = value;
    _checkAutoMode();
    notifyListeners();
  }

  void setCahayaThreshold(double value) {
    _cahayaThreshold = value;
    _checkAutoMode();
    notifyListeners();
  }

  // ==================== AUTH METHODS ====================
  void setUser(User? user) {
    _currentUser = user;
    _isAuthenticated = user != null;
    notifyListeners();
  }

  void setUserRole(AppRole role) {
    _userRole = role;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _isAuthenticated = false;
    _userRole = AppRole.guest;
    mqttService.disconnect();
    notifyListeners();
  }

  // ==================== UI METHODS ====================
  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  // ==================== GETTER METHODS ====================
  bool getRelayStatus(String relayId) {
    return _relays[relayId]?.isOn ?? false;
  }

  String getRelayMode(String relayId) {
    return _relayModes[relayId] ?? 'otomatis';
  }

  List<double> getSuhuHistory() {
    return _sensorHistory.map((data) => data.suhu).toList();
  }

  List<double> getKelembapanHistory() {
    return _sensorHistory.map((data) => data.kelembapan).toList();
  }

  List<double> getCahayaHistory() {
    return _sensorHistory.map((data) => data.intensitasCahaya).toList();
  }

  List<String> getSuhuHistoryLabels() {
    return _sensorHistory.map((data) {
      return '${data.timestamp.hour}:${data.timestamp.minute.toString().padLeft(2, '0')}';
    }).toList();
  }

  // ==================== RESET ====================
  void resetState() {
    _currentSensorData = null;
    _sensorHistory.clear();
    _relays.clear();
    _relayModes.clear();
    _suhuThreshold = 30.0;
    _kelembapanThreshold = 80.0;
    _cahayaThreshold = 500.0;
    notifyListeners();
  }

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    mqttService.dispose();
    super.dispose();
  }
}