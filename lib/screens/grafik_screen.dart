import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrafikScreen extends StatefulWidget {
  const GrafikScreen({super.key});

  @override
  State<GrafikScreen> createState() => _GrafikScreenState();
}

class _GrafikScreenState extends State<GrafikScreen> {
  int _selectedIndex = 0;
  String _selectedChart = 'Suhu';
  
  // Data dummy untuk grafik
  final List<Map<String, dynamic>> _data = [
    {'hari': 'Sen', 'suhu': 25.0, 'kelembapan': 65, 'angin': 12, 'hujan': 0},
    {'hari': 'Sel', 'suhu': 28.0, 'kelembapan': 70, 'angin': 15, 'hujan': 0},
    {'hari': 'Rab', 'suhu': 26.0, 'kelembapan': 75, 'angin': 8, 'hujan': 5},
    {'hari': 'Kam', 'suhu': 30.0, 'kelembapan': 60, 'angin': 20, 'hujan': 0},
    {'hari': 'Jum', 'suhu': 27.0, 'kelembapan': 80, 'angin': 10, 'hujan': 10},
    {'hari': 'Sab', 'suhu': 29.0, 'kelembapan': 65, 'angin': 18, 'hujan': 0},
    {'hari': 'Min', 'suhu': 28.6, 'kelembapan': 72, 'angin': 14, 'hujan': 2},
  ];

  @override
  void initState() {
    super.initState();
    _checkRoleAndSetIndex();
  }

  Future<void> _checkRoleAndSetIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'user';
    setState(() {
      _selectedIndex = role == 'admin' ? 2 : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('Grafik Cuaca'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chip
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
                  _buildFilterChip('Angin', Icons.air),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hujan', Icons.umbrella),
                ],
              ),
            ),
          ),
          // Content - Scrollable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Grafik $_selectedChart',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2D6A4F),
                              ),
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
                              child: const Text(
                                '7 Hari',
                                style: TextStyle(
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
                          'Data 7 Hari Terakhir',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Grafik dengan tinggi fixed
                        SizedBox(
                          height: 280,
                          child: _buildChart(),
                        ),
                        // Info statistik
                        const SizedBox(height: 16),
                        _buildStats(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Card info tambahan
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
                          'Informasi Cuaca',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D6A4F),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Periode', '7 Hari Terakhir'),
                        _buildInfoRow('Total Data', '${_data.length} Hari'),
                        _buildInfoRow('Sumber Data', 'Stasiun Cuaca'),
                        _buildInfoRow('Update', 'Setiap 1 Jam'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
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

  Widget _buildChart() {
    // Warna berdasarkan jenis chart
    Color getChartColor() {
      switch (_selectedChart) {
        case 'Suhu':
          return const Color(0xFFFF6B6B);
        case 'Kelembapan':
          return const Color(0xFF4ECDC4);
        case 'Angin':
          return const Color(0xFF45B7D1);
        case 'Hujan':
          return const Color(0xFF6C5CE7);
        default:
          return const Color(0xFFFF6B6B);
      }
    }

    // Mendapatkan nilai berdasarkan jenis chart
    List<double> getValues() {
      switch (_selectedChart) {
        case 'Suhu':
          return _data.map((e) => e['suhu'] as double).toList();
        case 'Kelembapan':
          return _data.map((e) => (e['kelembapan'] as int).toDouble()).toList();
        case 'Angin':
          return _data.map((e) => (e['angin'] as int).toDouble()).toList();
        case 'Hujan':
          return _data.map((e) => (e['hujan'] as int).toDouble()).toList();
        default:
          return _data.map((e) => e['suhu'] as double).toList();
      }
    }

    final values = getValues();
    final color = getChartColor();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final padding = range * 0.15;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: (range / 5).clamp(1, 10),
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
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
              interval: (range / 5).clamp(1, 10),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < _data.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _data[index]['hari'],
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const Text('');
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
        maxX: 6,
        minY: minValue - padding,
        maxY: maxValue + padding,
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
                final value = spot.y;
                String unit = '';
                switch (_selectedChart) {
                  case 'Suhu':
                    unit = '°C';
                    break;
                  case 'Kelembapan':
                    unit = '%';
                    break;
                  case 'Angin':
                    unit = ' km/j';
                    break;
                  case 'Hujan':
                    unit = ' mm';
                    break;
                }
                return LineTooltipItem(
                  '${_data[index]['hari']}\n${value.toStringAsFixed(1)}$unit',
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
    );
  }

  Widget _buildStats() {
    // Mendapatkan nilai berdasarkan jenis chart
    List<double> getValues() {
      switch (_selectedChart) {
        case 'Suhu':
          return _data.map((e) => e['suhu'] as double).toList();
        case 'Kelembapan':
          return _data.map((e) => (e['kelembapan'] as int).toDouble()).toList();
        case 'Angin':
          return _data.map((e) => (e['angin'] as int).toDouble()).toList();
        case 'Hujan':
          return _data.map((e) => (e['hujan'] as int).toDouble()).toList();
        default:
          return _data.map((e) => e['suhu'] as double).toList();
      }
    }

    final values = getValues();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final current = values.last;

    String unit = '';
    switch (_selectedChart) {
      case 'Suhu':
        unit = '°C';
        break;
      case 'Kelembapan':
        unit = '%';
        break;
      case 'Angin':
        unit = ' km/j';
        break;
      case 'Hujan':
        unit = ' mm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Rata-rata', '${avg.toStringAsFixed(1)}$unit', Colors.blue),
          _buildStatItem('Tertinggi', '${max.toStringAsFixed(1)}$unit', Colors.red),
          _buildStatItem('Terendah', '${min.toStringAsFixed(1)}$unit', Colors.green),
          _buildStatItem('Terakhir', '${current.toStringAsFixed(1)}$unit', const Color(0xFF2D6A4F)),
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