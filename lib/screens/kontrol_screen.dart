import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';
import '../providers/app_state.dart';
import '../models/sensor_model.dart';
import '../services/navigation_service.dart';
import '../services/mqtt_service.dart';

class KontrolScreen extends StatefulWidget {
  const KontrolScreen({super.key});

  @override
  State<KontrolScreen> createState() => _KontrolScreenState();
}

class _KontrolScreenState extends State<KontrolScreen> {
  int _selectedIndex = 1;
  bool _thresholdExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NavigationService().updateIndex(1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        final sensorData = appState.currentSensorData;
        final isLoading = appState.isLoading;
        final relay1Status = appState.getRelayStatus('1');
        final relay2Status = appState.getRelayStatus('2');
        final relay1Mode = appState.getRelayMode('1');
        final relay2Mode = appState.getRelayMode('2');
        final suhuThreshold = appState.suhuThreshold;
        final kelembapanThreshold = appState.kelembapanThreshold;
        final cahayaThreshold = appState.cahayaThreshold;
        final historyData = appState.sensorHistory;
        
        if (sensorData == null) {
          return _buildLoadingScaffold();
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F9F9),
          appBar: AppBar(
            title: const Text('GH-Pengering'),
            backgroundColor: const Color(0xFF2D6A4F),
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [_buildConnectionStatus(appState)],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildSensorCard(sensorData, suhuThreshold, kelembapanThreshold, cahayaThreshold),
                      const SizedBox(height: 12),
                      
                      // GRAFIK SUHU & KELEMBAPAN
                      _buildCombinedChartCard(historyData),
                      const SizedBox(height: 12),
                      
                      // GRAFIK CAHAYA
                      _buildLightChartCard(historyData),
                      const SizedBox(height: 12),
                      
                      // Button Lihat Kamera
                      _buildCameraButton(),
                      const SizedBox(height: 12),
                      
                      _buildRelayCard(
                        title: 'Kipas 1',
                        relayId: '1',
                        status: relay1Status,
                        mode: relay1Mode,
                        onToggle: () {
                          appState.toggleRelay('1');
                          // Kirim status ke ESP32
                          _sendRelayStatusToESP32('1', !relay1Status, appState);
                        },
                        onModeChange: (mode) {
                          appState.setRelayMode('1', mode);
                          _sendModeToESP32('1', mode, appState);
                        },
                        suhuThreshold: suhuThreshold,
                        cahayaThreshold: cahayaThreshold,
                        kelembapanThreshold: kelembapanThreshold,
                      ),
                      const SizedBox(height: 12),
                      _buildRelayCard(
                        title: 'Kipas 2',
                        relayId: '2',
                        status: relay2Status,
                        mode: relay2Mode,
                        onToggle: () {
                          appState.toggleRelay('2');
                          // Kirim status ke ESP32
                          _sendRelayStatusToESP32('2', !relay2Status, appState);
                        },
                        onModeChange: (mode) {
                          appState.setRelayMode('2', mode);
                          _sendModeToESP32('2', mode, appState);
                        },
                        suhuThreshold: suhuThreshold,
                        cahayaThreshold: cahayaThreshold,
                        kelembapanThreshold: kelembapanThreshold,
                      ),
                      const SizedBox(height: 12),
                      _buildThresholdCard(appState),
                      const SizedBox(height: 12),
                      _buildStatusInfo(appState),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
          bottomNavigationBar: BottomNavBar(
            selectedIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
              NavigationService().updateIndex(index);
            },
          ),
        );
      },
    );
  }

  // ==================== GRAFIK SUHU & KELEMBAPAN ====================
  Widget _buildCombinedChartCard(List<SensorData> historyData) {
    final displayCount = historyData.length > 20 ? 20 : historyData.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF2D6A4F), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Grafik Suhu & Kelembapan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$displayCount data',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: _buildCombinedLineChart(historyData),
          ),
          const SizedBox(height: 8),
          _buildChartLegend(
            colors: const [Colors.red, Colors.blue],
            labels: const ['Suhu (°C)', 'Kelembapan (%)'],
          ),
        ],
      ),
    );
  }

  // ==================== GRAFIK CAHAYA ====================
  Widget _buildLightChartCard(List<SensorData> historyData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny, color: Color(0xFF2D6A4F), size: 18),
              const SizedBox(width: 6),
              const Text(
                'Grafik Intensitas Cahaya',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${historyData.length} data',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: _buildLightLineChart(historyData),
          ),
          const SizedBox(height: 4),
          _buildChartLegend(
            colors: const [Colors.orange],
            labels: const ['Cahaya (Lux)'],
          ),
        ],
      ),
    );
  }

  // ==================== LINE CHART SUHU & KELEMBAPAN ====================
  Widget _buildCombinedLineChart(List<SensorData> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Ambil hanya 20 data terbaru
    final chartData = data.length > 20 ? data.sublist(data.length - 20) : data;

    double maxTemp = chartData.map((d) => d.suhu).reduce((a, b) => a > b ? a : b);
    double maxHum = chartData.map((d) => d.kelembapan).reduce((a, b) => a > b ? a : b);
    double maxValue = (maxTemp > maxHum ? maxTemp : maxHum) + 5;
    if (maxValue < 30) maxValue = 30;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < chartData.length) {
                  return Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 8),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 8),
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
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        lineBarsData: [
          // SUHU
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              int index = entry.key;
              SensorData d = entry.value;
              return FlSpot(index.toDouble(), d.suhu);
            }).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          // KELEMBAPAN
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              int index = entry.key;
              SensorData d = entry.value;
              return FlSpot(index.toDouble(), d.kelembapan);
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        minY: 0,
        maxY: maxValue,
        minX: 0,
        maxX: chartData.length > 1 ? (chartData.length - 1).toDouble() : 1,
      ),
    );
  }

  // ==================== LINE CHART CAHAYA ====================
  Widget _buildLightLineChart(List<SensorData> data) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada data',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Ambil hanya 20 data terbaru
    final chartData = data.length > 20 ? data.sublist(data.length - 20) : data;

    double maxLight = chartData.map((d) => d.intensitasCahaya).reduce((a, b) => a > b ? a : b);
    double maxValue = maxLight + 100;
    if (maxValue < 200) maxValue = 200;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.shade200,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (value, meta) {
                int index = value.toInt();
                if (index >= 0 && index < chartData.length) {
                  return Text(
                    '${index + 1}',
                    style: const TextStyle(fontSize: 8),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 8),
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
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              int index = entry.key;
              SensorData d = entry.value;
              return FlSpot(index.toDouble(), d.intensitasCahaya);
            }).toList(),
            isCurved: true,
            color: Colors.orange,
            barWidth: 2,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orange.withValues(alpha: 0.1),
            ),
          ),
        ],
        minY: 0,
        maxY: maxValue,
        minX: 0,
        maxX: chartData.length > 1 ? (chartData.length - 1).toDouble() : 1,
      ),
    );
  }

  // ==================== LEGEND ====================
  Widget _buildChartLegend({
    required List<Color> colors,
    required List<String> labels,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(colors.length, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 3,
                color: colors[index],
              ),
              const SizedBox(width: 4),
              Text(
                labels[index],
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ==================== BUTTON LIHAT KAMERA ====================
  Widget _buildCameraButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.videocam,
              color: Color(0xFF2D6A4F),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lihat Kamera',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Monitoring ruangan secara real-time',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/kamera');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D6A4F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Buka'),
          ),
        ],
      ),
    );
  }

  // ==================== LOADING ====================
  Widget _buildLoadingScaffold() {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('GH-Pengering'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menunggu data sensor...'),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          NavigationService().updateIndex(index);
        },
      ),
    );
  }

  // ==================== KIRIM KE ESP32 ====================
  void _sendModeToESP32(String relayId, String mode, AppState appState) {
    appState.mqttService.publish('relay/$relayId/mode', mode);
  }

  void _sendRelayStatusToESP32(String relayId, bool status, AppState appState) {
    appState.mqttService.publish('relay/$relayId/status', status ? '1' : '0');
  }

  void _sendThresholdToESP32(AppState appState) {
    final payload = '${appState.suhuThreshold.toStringAsFixed(1)},'
        '${appState.kelembapanThreshold.toStringAsFixed(1)},'
        '${appState.cahayaThreshold.toStringAsFixed(0)}';
    appState.mqttService.publish('sensor/threshold', payload);
  }

  // ==================== CONNECTION STATUS (APPBAR) ====================
  Widget _buildConnectionStatus(AppState appState) {
    final isConnected = appState.mqttService.connectionState == AppConnectionState.connected;
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 6, 
            height: 6, 
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.red, 
              shape: BoxShape.circle
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isConnected ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10, 
              color: isConnected ? Colors.green : Colors.red, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SENSOR CARD ====================
  Widget _buildSensorCard(SensorData data, double suhuT, double kelembapanT, double cahayaT) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: Color(0xFF2D6A4F), size: 18),
              SizedBox(width: 6),
              Text(
                'Sensor',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSensorItem(Icons.thermostat, 'Suhu', '${data.suhu.toStringAsFixed(1)}°C', Colors.red),
              _buildSensorItem(Icons.water_drop, 'Kelembapan', '${data.kelembapan.toStringAsFixed(1)}%', Colors.blue),
              _buildSensorItem(Icons.wb_sunny, 'Cahaya', '${data.intensitasCahaya.toStringAsFixed(0)} Lux', Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSensorItem(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  // ==================== RELAY CARD ====================
  Widget _buildRelayCard({
    required String title,
    required String relayId,
    required bool status,
    required String mode,
    required VoidCallback onToggle,
    required Function(String) onModeChange,
    required double suhuThreshold,
    required double cahayaThreshold,
    required double kelembapanThreshold,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.electric_bolt, color: status ? Colors.green : Colors.grey, size: 18),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const Spacer(),
              _buildModeChip('Manual', mode == 'manual', () => onModeChange('manual')),
              const SizedBox(width: 4),
              _buildModeChip('Otomatis', mode == 'otomatis', () => onModeChange('otomatis')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: status ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: status ? Colors.green.shade200 : Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(status ? Icons.check_circle : Icons.cancel, color: status ? Colors.green : Colors.grey, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        status ? 'AKTIF' : 'MATI',
                        style: TextStyle(fontWeight: FontWeight.bold, color: status ? Colors.green : Colors.grey, fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mode == 'otomatis' ? '(Otomatis)' : '(Manual)',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 50,
                  height: 28,
                  decoration: BoxDecoration(
                    color: status ? Colors.green : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        alignment: status ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (mode == 'otomatis')
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'ON: Kelembapan > ${kelembapanThreshold.toStringAsFixed(0)}% ATAU Suhu > ${suhuThreshold.toStringAsFixed(0)}°C ATAU Cahaya < ${cahayaThreshold.toStringAsFixed(0)} Lux',
                      style: TextStyle(fontSize: 9, color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D6A4F) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  // ==================== THRESHOLD CARD ====================
  Widget _buildThresholdCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _thresholdExpanded = !_thresholdExpanded),
            child: Row(
              children: [
                const Icon(Icons.tune, color: Color(0xFF2D6A4F), size: 18),
                const SizedBox(width: 6),
                const Text('Threshold', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  '${appState.suhuThreshold.toStringAsFixed(0)}°C | ${appState.kelembapanThreshold.toStringAsFixed(0)}% | ${appState.cahayaThreshold.toStringAsFixed(0)} Lux',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
                const SizedBox(width: 4),
                Icon(_thresholdExpanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey),
              ],
            ),
          ),
          if (_thresholdExpanded) ...[
            const Divider(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSliderItem(
                    label: 'Suhu Maks',
                    value: appState.suhuThreshold,
                    min: 30,
                    max: 55,
                    unit: '°C',
                    onChanged: (v) {
                      appState.setSuhuThreshold(v);
                      _sendThresholdToESP32(appState);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSliderItem(
                    label: 'Kelembapan Maks',
                    value: appState.kelembapanThreshold,
                    min: 50,
                    max: 85,
                    unit: '%',
                    onChanged: (v) {
                      appState.setKelembapanThreshold(v);
                      _sendThresholdToESP32(appState);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _buildSliderItem(
                    label: 'Cahaya Min',
                    value: appState.cahayaThreshold,
                    min: 100,
                    max: 800,
                    unit: 'Lux',
                    onChanged: (v) {
                      appState.setCahayaThreshold(v);
                      _sendThresholdToESP32(appState);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSliderItem({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            Text(
              unit == 'Lux' 
                  ? '${value.round()} $unit'
                  : '${value.toStringAsFixed(1)} $unit',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: const Color(0xFF2D6A4F),
          onChanged: (newValue) {
            double roundedValue;
            if (unit == 'Lux') {
              roundedValue = newValue.roundToDouble();
            } else {
              roundedValue = double.parse(newValue.toStringAsFixed(1));
            }
            onChanged(roundedValue);
          },
        ),
      ],
    );
  }

  // ==================== STATUS INFO ====================
  Widget _buildStatusInfo(AppState appState) {
    final isAnyOn = appState.getRelayStatus('1') || appState.getRelayStatus('2');
    final data = appState.currentSensorData;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: isAnyOn ? Colors.green : Colors.grey, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            isAnyOn ? '🟢 Relay Aktif' : '⚪ Semua Mati',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isAnyOn ? Colors.green : Colors.grey),
          ),
          const Spacer(),
          if (data != null)
            Text(
              '🌡${data.suhu.toStringAsFixed(1)}°C  💧${data.kelembapan.toStringAsFixed(1)}%  ☀${data.intensitasCahaya.toStringAsFixed(0)} Lux',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
            ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 1)),
      ],
    );
  }
}