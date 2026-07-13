import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class KontrolScreen extends StatefulWidget {
  const KontrolScreen({super.key});

  @override
  State<KontrolScreen> createState() => _KontrolScreenState();
}

class _KontrolScreenState extends State<KontrolScreen> {
  int _selectedIndex = 1; // Index untuk Kontrol (admin: 0:Dashboard, 1:Kontrol)
  bool _isLoading = false;

  // Data Sensor
  double _suhu = 28.6;
  double _kelembapan = 78.4;
  double _intensitasCahaya = 865;

  // Data Relay
  bool _relay1Status = false;
  bool _relay2Status = false;
  String _relay1Mode = 'manual';
  String _relay2Mode = 'manual';

  // Threshold
  double _suhuThreshold = 30.0;
  double _kelembapanThreshold = 80.0;
  double _cahayaThreshold = 500.0; // Tambahan threshold untuk cahaya

  // Faktor skala agar garis Cahaya (Lux, ratusan) muat di sumbu Y 0-100
  // yang sama dengan Suhu (°C) dan Kelembapan (%).
  static const double _cahayaScaleFactor = 10.0;

  // Data untuk grafik 7 hari
  final List<double> _suhuHistory = [25, 28, 26, 30, 27, 29, 28.6];
  final List<double> _kelembapanHistory = [75, 78, 76, 80, 77, 79, 78.4];
  final List<double> _cahayaHistory = [800, 850, 820, 900, 830, 880, 865];

  @override
  void initState() {
    super.initState();
    _loadData();
    _simulateRealTimeData();
  }

  // Simulasi data real-time
  void _simulateRealTimeData() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          // Simulasi perubahan data sensor
          _suhu = 28.6 + (DateTime.now().second % 3 - 1) * 0.5;
          _kelembapan = 78.4 + (DateTime.now().second % 4 - 2) * 0.3;
          _intensitasCahaya = 865 + (DateTime.now().second % 5 - 2) * 10;

          // Update history (geser data)
          _suhuHistory.removeAt(0);
          _suhuHistory.add(_suhu);
          _kelembapanHistory.removeAt(0);
          _kelembapanHistory.add(_kelembapan);
          _cahayaHistory.removeAt(0);
          _cahayaHistory.add(_intensitasCahaya);

          // Cek threshold untuk mode otomatis
          _checkAutoMode();
        });
        _simulateRealTimeData(); // Rekursif untuk update terus
      }
    });
  }

  void _checkAutoMode() {
    // Relay 1: Aktif jika suhu > threshold ATAU cahaya < threshold
    if (_relay1Mode == 'otomatis') {
      _relay1Status =
          (_suhu > _suhuThreshold) || (_intensitasCahaya < _cahayaThreshold);
    }

    // Relay 2: Aktif jika kelembapan < threshold
    if (_relay2Mode == 'otomatis') {
      _relay2Status = _kelembapan < _kelembapanThreshold;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
  }

  Future<void> _logout() async {
    await FirebaseService.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('GH-Pengering'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSensorCard(),
                  const SizedBox(height: 16),
                  _buildRelayCard(
                    title: 'Relay 1 - Kipas 1',
                    status: _relay1Status,
                    mode: _relay1Mode,
                    onToggle: () {
                      if (_relay1Mode == 'manual') {
                        setState(() {
                          _relay1Status = !_relay1Status;
                        });
                      } else {
                        _showModeWarning(context);
                      }
                    },
                    onModeChange: (mode) {
                      setState(() {
                        _relay1Mode = mode;
                        if (mode == 'otomatis') {
                          _checkAutoMode();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildRelayCard(
                    title: 'Relay 2 - Kipas 2',
                    status: _relay2Status,
                    mode: _relay2Mode,
                    onToggle: () {
                      if (_relay2Mode == 'manual') {
                        setState(() {
                          _relay2Status = !_relay2Status;
                        });
                      } else {
                        _showModeWarning(context);
                      }
                    },
                    onModeChange: (mode) {
                      setState(() {
                        _relay2Mode = mode;
                        if (mode == 'otomatis') {
                          _checkAutoMode();
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildThresholdCard(),
                  const SizedBox(height: 16),
                  _buildStatusInfo(),
                  const SizedBox(height: 80),
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

  void _showModeWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mode otomatis tidak bisa di toggle manual!'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSensorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, color: Color(0xFF2D6A4F)),
              const SizedBox(width: 8),
              const Text(
                'Monitor Sensor',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D6A4F),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSensorItem(
                  icon: Icons.thermostat,
                  label: 'Suhu',
                  value: '${_suhu.toStringAsFixed(1)} °C',
                  color: Colors.red,
                  status: _suhu > _suhuThreshold ? '⚠️ Tinggi' : '✅ Normal',
                ),
              ),
              Expanded(
                child: _buildSensorItem(
                  icon: Icons.water_drop,
                  label: 'Kelembapan',
                  value: '${_kelembapan.toStringAsFixed(1)} %',
                  color: Colors.blue,
                  status: _kelembapan < _kelembapanThreshold
                      ? '⚠️ Rendah'
                      : '✅ Normal',
                ),
              ),
              Expanded(
                child: _buildSensorItem(
                  icon: Icons.wb_sunny,
                  label: 'Cahaya',
                  value: '${_intensitasCahaya.toStringAsFixed(0)} Lux',
                  color: Colors.orange,
                  status: _intensitasCahaya < _cahayaThreshold
                      ? '⚠️ Rendah'
                      : '✅ Normal',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Grafik dengan 3 garis (Cahaya diskalakan agar sebanding)
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  horizontalInterval: 10,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return const FlLine(
                      color: Colors.grey,
                      strokeWidth: 0.5,
                      dashArray: [5, 5],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = [
                          'Sen',
                          'Sel',
                          'Rab',
                          'Kam',
                          'Jum',
                          'Sab',
                          'Min'
                        ];
                        final index = value.toInt();
                        if (index < 0 || index > 6) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          days[index % 7],
                          style: const TextStyle(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt().clamp(
                            0, _suhuHistory.length - 1);
                        String label;
                        Color color;
                        switch (spot.barIndex) {
                          case 0:
                            label =
                                'Suhu: ${_suhuHistory[idx].toStringAsFixed(1)}°C';
                            color = Colors.red;
                            break;
                          case 1:
                            label =
                                'Kelembapan: ${_kelembapanHistory[idx].toStringAsFixed(1)}%';
                            color = Colors.blue;
                            break;
                          default:
                            label =
                                'Cahaya: ${_cahayaHistory[idx].toStringAsFixed(0)} Lux';
                            color = Colors.orange;
                        }
                        return LineTooltipItem(
                          label,
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // Garis Suhu (Merah) - sudah pas di skala 0-100
                  LineChartBarData(
                    spots: _suhuHistory.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.red.withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                  // Garis Kelembapan (Biru) - sudah pas di skala 0-100
                  LineChartBarData(
                    spots: _kelembapanHistory.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value);
                    }).toList(),
                    isCurved: true,
                    color: Colors.blue,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.blue.withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                  // Garis Cahaya (Orange) - DISKALA agar masuk rentang 0-100
                  LineChartBarData(
                    spots: _cahayaHistory.asMap().entries.map((e) {
                      return FlSpot(
                        e.key.toDouble(),
                        e.value / _cahayaScaleFactor,
                      );
                    }).toList(),
                    isCurved: true,
                    color: Colors.orange,
                    barWidth: 2,
                    belowBarData: BarAreaData(
                      show: true,
                      color: Colors.orange.withValues(alpha: 0.1),
                    ),
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.red, 'Suhu'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.blue, 'Kelembapan'),
              const SizedBox(width: 16),
              _buildLegendItem(Colors.orange, 'Cahaya'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '*Nilai Cahaya ditampilkan dalam skala ÷${_cahayaScaleFactor.toInt()} agar sebanding dengan garis lain. Sentuh grafik untuk melihat nilai asli.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSensorItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
              fontSize: 9,
              color: status.contains('⚠️') ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelayCard({
    required String title,
    required bool status,
    required String mode,
    required VoidCallback onToggle,
    required Function(String) onModeChange,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.electric_bolt,
                color: status ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildModeChip('Manual', mode == 'manual', () {
                      onModeChange('manual');
                    }),
                    _buildModeChip('Otomatis', mode == 'otomatis', () {
                      onModeChange('otomatis');
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color:
                        status ? Colors.green.shade50 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: status
                          ? Colors.green.shade200
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status ? Icons.check_circle : Icons.cancel,
                        color: status ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status ? 'AKTIF' : 'MATI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: status ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mode == 'otomatis'
                            ? '(Mode Otomatis)'
                            : '(Mode Manual)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: status ? Colors.green : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        alignment: status
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 28,
                          height: 28,
                          margin: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
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
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.blue.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title.contains('Kipas')
                          ? 'Aktif jika suhu > ${_suhuThreshold.toStringAsFixed(1)}°C ATAU cahaya < ${_cahayaThreshold.toStringAsFixed(0)} Lux'
                          : 'Aktif jika kelembapan < ${_kelembapanThreshold.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blue.shade700,
                      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D6A4F) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Threshold',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThresholdItem(
                  label: 'Suhu Maks',
                  value: _suhuThreshold,
                  onChanged: (val) {
                    setState(() {
                      _suhuThreshold = val;
                      if (_relay1Mode == 'otomatis') {
                        _checkAutoMode();
                      }
                    });
                  },
                  min: 20,
                  max: 40,
                  unit: '°C',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildThresholdItem(
                  label: 'Cahaya Min',
                  value: _cahayaThreshold,
                  onChanged: (val) {
                    setState(() {
                      _cahayaThreshold = val;
                      if (_relay1Mode == 'otomatis') {
                        _checkAutoMode();
                      }
                    });
                  },
                  min: 100,
                  max: 1000,
                  unit: 'Lux',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildThresholdItem(
                  label: 'Kelembapan Min',
                  value: _kelembapanThreshold,
                  onChanged: (val) {
                    setState(() {
                      _kelembapanThreshold = val;
                      if (_relay2Mode == 'otomatis') {
                        _checkAutoMode();
                      }
                    });
                  },
                  min: 60,
                  max: 90,
                  unit: '%',
                ),
              ),
              const SizedBox(width: 16),
              // Spacer untuk menjaga layout
              const Expanded(
                child: SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdItem({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required double min,
    required double max,
    required String unit,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              '$value $unit',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D6A4F),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: 20,
          activeColor: const Color(0xFF2D6A4F),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildStatusInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2D6A4F)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Sistem',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _relay1Status || _relay2Status
                            ? Colors.green
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _relay1Status || _relay2Status
                          ? 'Beberapa Relay Aktif'
                          : 'Semua Relay Mati',
                      style: TextStyle(
                        fontSize: 12,
                        color: _relay1Status || _relay2Status
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Suhu: ${_suhu.toStringAsFixed(1)}°C | ',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Cahaya: ${_intensitasCahaya.toStringAsFixed(0)} Lux',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}