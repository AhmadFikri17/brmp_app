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
  
  // Sensor Topics
  static const String topicSensorData = 'sensor/data';
  
  // Camera Topics
  static const String topicCameraIp = 'greenhouse/camera/ip';
  // ====================================================

  late MqttServerClient _client;

  AppConnectionState _connectionState = AppConnectionState.disconnected;
  AppConnectionState get connectionState => _connectionState;

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

  // Stream Controllers
  final StreamController<SensorData> _sensorStreamController = 
      StreamController<SensorData>.broadcast();
  Stream<SensorData> get sensorStream => _sensorStreamController.stream;

  final StreamController<Map<String, bool>> _relayStreamController = 
      StreamController<Map<String, bool>>.broadcast();
  Stream<Map<String, bool>> get relayStream => _relayStreamController.stream;

  final StreamController<String> _cameraStreamController = 
      StreamController<String>.broadcast();
  Stream<String> get cameraStream => _cameraStreamController.stream;

  Timer? _reconnectTimer;
  bool _isSubscribed = false;
  bool _isListening = false;

  MQTTService() {
    // Inisialisasi relay default
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
      _port
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
    if (_isListening) return;
    if (_client.updates == null) {
      debugPrint('⚠️ _client.updates is null, cannot setup listener');
      return;
    }
    
    debugPrint('📡 Setting up message listener...');
    
    _client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> events) {
      for (var event in events) {
        try {
          final topic = event.topic;
          final message = event.payload as MqttPublishMessage;
          final payload = MqttPublishPayload.bytesToStringAsString(message.payload.message);
          
          debugPrint('📩 [MQTT] Topic: $topic, Payload: "$payload"');
          
          // Handle Relay Status
          if (topic == topicRelay1Status) {
            _updateRelayStatus('1', payload);
          } else if (topic == topicRelay2Status) {
            _updateRelayStatus('2', payload);
          }
          // Handle Sensor Data
          else if (topic == topicSensorData) {
            _handleSensorData(payload);
          }
          // Handle Camera IP
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
    if (_relays.containsKey(relayId)) {
      final isOn = status.toUpperCase() == 'ON';
      _relays[relayId]!.updateStatus(status);
      
      // Kirim ke stream
      _relayStreamController.add({relayId: isOn});
      notifyListeners();
      
      debugPrint('✅ Relay $relayId = ${isOn ? "ON" : "OFF"}');
    }
  }

  // ==================== HANDLE SENSOR DATA ====================
  void _handleSensorData(String payload) {
    try {
      // Parse data sensor (format: "suhu,kelembapan,cahaya")
      final parts = payload.split(',');
      if (parts.length >= 3) {
        final sensorData = SensorData(
          suhu: double.tryParse(parts[0]) ?? 0,
          kelembapan: double.tryParse(parts[1]) ?? 0,
          intensitasCahaya: double.tryParse(parts[2]) ?? 0,
        );
        
        _currentSensorData = sensorData;
        _sensorHistory.add(sensorData);
        
        // Batasi history
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
    debugPrint('📷📷📷 Camera IP received: $ip');
    
    // Update ke Firestore
    _updateCameraInFirestore(ip);
    
    // Kirim ke stream
    _cameraStreamController.add(ip);
    
    // Notify listeners
    notifyListeners();
  }

  // ==================== UPDATE CAMERA IP TO FIRESTORE ====================
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
    debugPrint('✅✅✅ MQTT Connected!');
    _connectionState = AppConnectionState.connected;
    _isSubscribed = false;
    notifyListeners();
    
    _setupMessageListener();
    
    Future.delayed(const Duration(milliseconds: 500), () {
      _subscribeToTopics();
    });
  }

  void _onDisconnected() {
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
    _client.disconnect();
    _connectionState = AppConnectionState.disconnected;
    _isListening = false;
    notifyListeners();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('🔄 Attempting to reconnect...');
      connect();
    });
  }

  // ==================== SUBSCRIBE TOPICS ====================
  void _subscribeToTopics() {
    if (_connectionState != AppConnectionState.connected) return;
    if (_isSubscribed) return;
    
    debugPrint('📡 Subscribing to topics...');
    
    // Subscribe ke relay status
    _client.subscribe(topicRelay1Status, MqttQos.atLeastOnce);
    _client.subscribe(topicRelay2Status, MqttQos.atLeastOnce);
    
    // Subscribe ke sensor data
    _client.subscribe(topicSensorData, MqttQos.atLeastOnce);
    
    // 🔥 Subscribe ke camera IP
    _client.subscribe(topicCameraIp, MqttQos.atLeastOnce);
    
    // Subscribe ke semua topic untuk debugging
    _client.subscribe('relay/#', MqttQos.atLeastOnce);
    _client.subscribe('sensor/#', MqttQos.atLeastOnce);
    _client.subscribe('greenhouse/#', MqttQos.atLeastOnce);
    
    _isSubscribed = true;
    debugPrint('✅ Subscribed to all topics');
    
    // Request status awal
    Future.delayed(const Duration(seconds: 1), () {
      _requestInitialStatus();
    });
  }

  void _requestInitialStatus() {
    debugPrint('📤 Requesting initial status...');
    publish(topicRelay1Set, 'STATUS');
    publish(topicRelay2Set, 'STATUS');
  }

  // ==================== PUBLISH METHODS ====================
  void publish(String topic, String message) {
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

  void publishRelay(String relayId, String state) {
    final topic = 'relay/$relayId/set';
    publish(topic, state.toUpperCase());
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
    _reconnectTimer?.cancel();
    _sensorStreamController.close();
    _relayStreamController.close();
    _cameraStreamController.close();
    _client.disconnect();
    super.dispose();
  }
}