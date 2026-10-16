import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/relay_model.dart';
import '../models/sensor_model.dart';

enum AppConnectionState {
  disconnected,
  connecting,
  connected,
}

class MQTTService extends ChangeNotifier {
  // ==================== KONFIGURASI ====================
  static const String _host = '82a3d01bd802462e9a414c755c593ea7.s1.eu.hivemq.cloud';
  static const int _port = 8883;
  static const String _username = 'esp32_gh';
  static const String _password = '!greenhouse123';
  // ====================================================

  // ==================== TOPIC MQTT ====================
  // Relay Topics
  static const String topicRelay1Set = 'relay/1/set';
  static const String topicRelay1Status = 'relay/1/status';
  static const String topicRelay2Set = 'relay/2/set';
  static const String topicRelay2Status = 'relay/2/status';

  // ✅ BARU: topic mode relay (App → ESP32) dan status mode (ESP32 → App)
  static const String topicRelay1Mode = 'relay/1/mode';
  static const String topicRelay2Mode = 'relay/2/mode';
  static const String topicRelay1ModeStatus = 'relay/1/mode/status';
  static const String topicRelay2ModeStatus = 'relay/2/mode/status';

  // Sensor Topics
  static const String topicSensorData = 'sensor/data';
  static const String topicThreshold = 'sensor/threshold';

  // Camera Topics
  static const String topicCameraIp = 'greenhouse/camera/ip';
  // ====================================================

  late MqttServerClient _client;

  AppConnectionState _connectionState = AppConnectionState.disconnected;
  AppConnectionState get connectionState => _connectionState;

  // ✅ Flag untuk mencegah "used after disposed"
  bool _disposed = false;

  // Relay Status
  final Map<String, RelayModel> _relays = {};
  Map<String, RelayModel> get relays => _relays;

  // Sensor Data
  SensorData? _currentSensorData;
  SensorData? get currentSensorData => _currentSensorData;

  // History untuk grafik
  final List<SensorData> _sensorHistory = [];
  List<SensorData> get sensorHistory => _sensorHistory;
  static const int maxHistoryLength = 60;

  // ==================== SIMPAN STATUS & MODE TERAKHIR ====================
  // ✅ Ini penting: retained message kadang datang sebelum listener siap
  final Map<String, bool> _lastRelayStatus = {'1': false, '2': false};
  final Map<String, String> _lastRelayMode = {'1': 'otomatis', '2': 'otomatis'};

  Map<String, bool> get lastRelayStatus => Map.from(_lastRelayStatus);
  Map<String, String> get lastRelayMode => Map.from(_lastRelayMode);

  // ==================== STREAM CONTROLLERS ====================
  final StreamController<SensorData> _sensorStreamController =
      StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _sensorStreamController.stream;

  final StreamController<Map<String, bool>> _relayStreamController =
      StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get relayStream => _relayStreamController.stream;

  // ✅ BARU: stream untuk mode relay
  final StreamController<Map<String, String>> _relayModeStreamController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get relayModeStream =>
      _relayModeStreamController.stream;

  final StreamController<String> _cameraStreamController =
      StreamController<String>.broadcast();
  Stream<String> get cameraStream => _cameraStreamController.stream;

  Timer? _reconnectTimer;
  bool _isSubscribed = false;
  bool _isListening = false;

  MQTTService() {
    _relays['1'] = RelayModel(id: '1', name: 'Relay 1');
    _relays['2'] = RelayModel(id: '2', name: 'Relay 2');
    _initClient();
  }

  // ==================== INIT CLIENT ====================
  void _initClient() {
    debugPrint('🔧 Initializing MQTT Client...');

    _client = MqttServerClient.withPort(
      _host,
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
      _port,
    );
    _client.secure = true;
    _client.keepAlivePeriod = 20;

    _client.onConnected = _onConnected;
    _client.onDisconnected = _onDisconnected;
    _client.onSubscribed = _onSubscribed;

    debugPrint('✅ MQTT Client initialized');
  }

  // ==================== MESSAGE LISTENER ====================
  void _setupMessageListener() {
    if (_disposed) return;
    if (_isListening) return;
    if (_client.updates == null) {
      debugPrint('⚠️ _client.updates is null, cannot setup listener');
      return;
    }

    debugPrint('📡 Setting up message listener...');

    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      if (_disposed) return;
      for (var event in events) {
        try {
          final topic = event.topic;
          final message = event.payload as MqttPublishMessage;
          final payload =
              MqttPublishPayload.bytesToStringAsString(message.payload.message);

          debugPrint('📩 [MQTT] Topic: $topic, Payload: "$payload"');

          // ---- Relay Status ----
          if (topic == topicRelay1Status) {
            _updateRelayStatus('1', payload);
          } else if (topic == topicRelay2Status) {
            _updateRelayStatus('2', payload);
          }
          // ---- Relay Mode Status (dari ESP32) ✅ BARU ----
          else if (topic == topicRelay1ModeStatus) {
            _updateRelayMode('1', payload);
          } else if (topic == topicRelay2ModeStatus) {
            _updateRelayMode('2', payload);
          }
          // ---- Sensor Data ----
          else if (topic == topicSensorData) {
            _handleSensorData(payload);
          }
          // ---- Camera IP ----
          else if (topic == topicCameraIp) {
            _handleCameraIp(payload);
          }
        } catch (e) {
          debugPrint('❌ Error processing event: $e');
        }
      }
    });

    _isListening = true;
    debugPrint('✅ Message listener setup complete');
  }

  // ==================== UPDATE RELAY STATUS ====================
  void _updateRelayStatus(String relayId, String status) {
    if (_disposed) return;
    if (_relays.containsKey(relayId)) {
      final isOn = status.toUpperCase() == 'ON';
      _relays[relayId]!.updateStatus(status);
      _lastRelayStatus[relayId] = isOn;

      _relayStreamController.add({relayId: isOn});
      notifyListeners();

      debugPrint('✅ Relay $relayId = ${isOn ? "ON" : "OFF"}');
    }
  }

  // ==================== UPDATE RELAY MODE ✅ BARU ====================
  void _updateRelayMode(String relayId, String mode) {
    if (_disposed) return;
    final normalized = mode.toLowerCase();
    // validasi: hanya "manual" atau "otomatis"
    final finalMode =
        (normalized == 'otomatis' || normalized == 'manual')
            ? normalized
            : 'otomatis';

    _lastRelayMode[relayId] = finalMode;
    _relayModeStreamController.add(Map.from(_lastRelayMode));
    notifyListeners();

    debugPrint('✅ Relay $relayId Mode = $finalMode');
  }

  // ==================== HANDLE SENSOR DATA ====================
  void _handleSensorData(String payload) {
    if (_disposed) return;
    try {
      final parts = payload.split(',');
      if (parts.length >= 3) {
        final sensorData = SensorData(
          suhu: double.tryParse(parts[0]) ?? 0,
          kelembapan: double.tryParse(parts[1]) ?? 0,
          intensitasCahaya: double.tryParse(parts[2]) ?? 0,
        );

        _currentSensorData = sensorData;
        _sensorHistory.add(sensorData);

        if (_sensorHistory.length > maxHistoryLength) {
          _sensorHistory.removeAt(0);
        }

        _sensorStreamController.add(sensorData);
        notifyListeners();

        debugPrint('✅ Sensor Data: $_currentSensorData');
      }
    } catch (e) {
      debugPrint('❌ Error parsing sensor data: $e');
    }
  }

  // ==================== HANDLE CAMERA IP ====================
  void _handleCameraIp(String ip) {
    if (_disposed) return;
    debugPrint('📷📷📷 Camera IP received: $ip');

    _updateCameraInFirestore(ip);
    _cameraStreamController.add(ip);
    notifyListeners();
  }

  void _updateCameraInFirestore(String ip) {
    try {
      final firestore = FirebaseFirestore.instance;
      firestore.collection('devices').doc('esp32cam').set({
        'ip': ip,
        'status': 'online',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('✅✅✅ Camera IP updated in Firestore: $ip');
    } catch (e) {
      debugPrint('❌ Error updating camera in Firestore: $e');
    }
  }

  // ==================== MQTT CONNECTION ====================
  void _onConnected() {
    if (_disposed) return;
    debugPrint('✅✅✅ MQTT Connected!');
    _connectionState = AppConnectionState.connected;
    _isSubscribed = false;
    notifyListeners();

    _setupMessageListener();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (_disposed) return;
      _subscribeToTopics();
    });
  }

  void _onDisconnected() {
    if (_disposed) return;
    debugPrint('❌❌❌ MQTT Disconnected');
    _connectionState = AppConnectionState.disconnected;
    _isSubscribed = false;
    _isListening = false;
    notifyListeners();
    _scheduleReconnect();
  }

  void _onSubscribed(String topic) {
    debugPrint('📡 Subscribed to: $topic');
  }

  Future<bool> connect() async {
    if (_disposed) return false;
    try {
      debugPrint('🔌 Connecting to MQTT broker...');
      _connectionState = AppConnectionState.connecting;
      notifyListeners();

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(_client.clientIdentifier)
          .withWillTopic('flutter/will')
          .withWillMessage('Disconnected')
          .startClean()
          .authenticateAs(_username, _password);

      _client.connectionMessage = connMessage;
      await _client.connect();

      final status = _client.connectionStatus;
      if (status != null && status.state == MqttConnectionState.connected) {
        _connectionState = AppConnectionState.connected;
        notifyListeners();
        debugPrint('✅ Connection successful!');
        return true;
      } else {
        _connectionState = AppConnectionState.disconnected;
        notifyListeners();
        debugPrint('❌ Connection failed');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Connection error: $e');
      _connectionState = AppConnectionState.disconnected;
      notifyListeners();
      _scheduleReconnect();
      return false;
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    if (!_disposed) {
      _client.disconnect();
    }
    _connectionState = AppConnectionState.disconnected;
    _isListening = false;
    if (!_disposed) notifyListeners();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_disposed) return;
      debugPrint('🔄 Attempting to reconnect...');
      connect();
    });
  }

  // ==================== SUBSCRIBE TOPICS ====================
  void _subscribeToTopics() {
    if (_disposed) return;
    if (_connectionState != AppConnectionState.connected) return;
    if (_isSubscribed) return;

    debugPrint('📡 Subscribing to topics...');

    // Relay status
    _client.subscribe(topicRelay1Status, MqttQos.atLeastOnce);
    _client.subscribe(topicRelay2Status, MqttQos.atLeastOnce);

    // ✅ BARU: Relay mode status (retained dari ESP32)
    _client.subscribe(topicRelay1ModeStatus, MqttQos.atLeastOnce);
    _client.subscribe(topicRelay2ModeStatus, MqttQos.atLeastOnce);

    // Sensor data
    _client.subscribe(topicSensorData, MqttQos.atLeastOnce);

    // Camera IP
    _client.subscribe(topicCameraIp, MqttQos.atLeastOnce);

    // Debug — wildcard
    _client.subscribe('relay/#', MqttQos.atLeastOnce);
    _client.subscribe('sensor/#', MqttQos.atLeastOnce);
    _client.subscribe('greenhouse/#', MqttQos.atLeastOnce);

    _isSubscribed = true;
    debugPrint('✅ Subscribed to all topics');

    // Request status awal
    Future.delayed(const Duration(seconds: 1), () {
      if (_disposed) return;
      _requestInitialStatus();
    });
  }

  void _requestInitialStatus() {
    if (_disposed) return;
    debugPrint('📤 Requesting initial status...');
    publish(topicRelay1Set, 'STATUS');
    publish(topicRelay2Set, 'STATUS');
  }

  // ==================== PUBLISH ====================
  void publish(String topic, String message) {
    if (_disposed) return;
    if (_connectionState != AppConnectionState.connected) {
      debugPrint('⚠️ Cannot publish: Not connected');
      return;
    }

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      final payload = builder.payload;
      if (payload != null) {
        _client.publishMessage(topic, MqttQos.atLeastOnce, payload);
        debugPrint('📤 Published to $topic: $message');
      }
    } catch (e) {
      debugPrint('❌ Publish error: $e');
    }
  }

  // ✅ Publish command relay ke topic /set dengan payload "ON"/"OFF"
  void publishRelay(String relayId, String state) {
    final topic = 'relay/$relayId/set';
    publish(topic, state.toUpperCase());
  }

  // ✅ Publish mode relay ke topic /mode
  void publishRelayMode(String relayId, String mode) {
    final topic = 'relay/$relayId/mode';
    publish(topic, mode.toLowerCase());
  }

  void publishSensorData(SensorData data) {
    final payload = '${data.suhu.toStringAsFixed(1)},'
        '${data.kelembapan.toStringAsFixed(1)},'
        '${data.intensitasCahaya.toStringAsFixed(0)}';
    publish(topicSensorData, payload);
  }

  void toggleRelay(String relayId) {
    if (_relays.containsKey(relayId)) {
      final currentState = _relays[relayId]!.isOn;
      final newState = !currentState;
      publishRelay(relayId, newState ? 'ON' : 'OFF');
    }
  }

  // ==================== GETTERS ====================
  bool getRelayStatus(String relayId) {
    return _relays[relayId]?.isOn ?? false;
  }

  RelayModel? getRelay(String relayId) {
    return _relays[relayId];
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

  // ==================== DISPOSE ====================
  @override
  void dispose() {
    _disposed = true; // ✅ cegah "used after disposed"
    _reconnectTimer?.cancel();
    _sensorStreamController.close();
    _relayStreamController.close();
    _relayModeStreamController.close();
    _cameraStreamController.close();
    try {
      _client.disconnect();
    } catch (_) {}
    super.dispose();
  }
}