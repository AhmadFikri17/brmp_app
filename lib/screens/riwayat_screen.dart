import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/hourly_data_service.dart';
import '../models/hourly_weather_data.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedIndex = 0;
  
  // Data dari API
  List<HourlyWeatherData> _historicalData = [];
  List<HourlyWeatherData> _todayData = [];
  List<HourlyWeatherData> _previousData = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  
  // Periode
  String _selectedPeriod = 'Hari Ini';
  final List<String> _periodOptions = ['Hari Ini', '7 Hari', '30 Hari'];

  @override
  void initState() {
    super.initState();
    _checkRoleAndSetIndex();
    _loadHistoricalData();
  }

  Future<void> _checkRoleAndSetIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'user';
    setState(() {
      _selectedIndex = role == 'admin' ? 3 : 2;
    });
  }

  // ===== LOAD DATA DARI API =====
  Future<void> _loadHistoricalData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Tentukan start date berdasarkan periode
      DateTime startDate;
      switch (_selectedPeriod) {
        case '7 Hari':
          startDate = today.subtract(const Duration(days: 6));
          break;
        case '30 Hari':
          startDate = today.subtract(const Duration(days: 29));
          break;
        default:
          startDate = today;
      }

      debugPrint('📊 Fetching riwayat: $startDate to $now');

      final data = await HourlyDataService.getHourlyData(
        start: startDate,
        end: now,
      );

      // Proses data: unique + sorted
      final processed = _processData(data);
      
      // Pisahkan data hari ini dan sebelumnya
      final todayDataList = <HourlyWeatherData>[];
      final previousDataList = <HourlyWeatherData>[];
      
      for (var d in processed) {
        final date = DateTime(d.timestamp.year, d.timestamp.month, d.timestamp.day);
        if (date.isAtSameMomentAs(today)) {
          todayDataList.add(d);
        } else {
          previousDataList.add(d);
        }
      }

      setState(() {
        _historicalData = processed;
        _todayData = todayDataList;
        _previousData = previousDataList.reversed.toList(); // Terbaru di atas
        _isLoading = false;
        _errorMessage = null;
      });
      
      debugPrint('📊 Loaded ${processed.length} data (${todayDataList.length} hari ini, ${previousDataList.length} sebelumnya)');
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      debugPrint('❌ Error loading riwayat: $e');
    }
  }

  // ===== PROSES DATA: UNIQUE + SORTED =====
  List<HourlyWeatherData> _processData(List<HourlyWeatherData> data) {
    if (data.isEmpty) return [];
    
    final Map<String, HourlyWeatherData> uniqueData = {};
    
    for (var d in data) {
      final key = '${d.timestamp.year}-'
                  '${d.timestamp.month.toString().padLeft(2, '0')}-'
                  '${d.timestamp.day.toString().padLeft(2, '0')}_'
                  '${d.timestamp.hour.toString().padLeft(2, '0')}';
      
      if (!uniqueData.containsKey(key)) {
        uniqueData[key] = d;
      } else {
        if (d.timestamp.isAfter(uniqueData[key]!.timestamp)) {
          uniqueData[key] = d;
        }
      }
    }
    
    final result = uniqueData.values.toList();
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    
    return result;
  }

  // ===== GROUP DATA PER TANGGAL =====
  Map<String, List<HourlyWeatherData>> _groupByDate(List<HourlyWeatherData> data) {
    final Map<String, List<HourlyWeatherData>> grouped = {};
    
    for (var d in data) {
      final key = _formatDateKey(d.timestamp);
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(d);
    }
    
    return grouped;
  }

  // ===== FORMAT TANGGAL =====
  String _formatDateKey(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
                    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateForGroup(DateTime date) {
    final days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
                    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // ===== STATISTIK PER PARAMETER =====
  String _getRange(List<HourlyWeatherData> data, String parameter) {
    if (data.isEmpty) return '-';
    
    List<double> values;
    String unit;
    
    switch (parameter) {
      case 'Suhu':
        values = data.map((d) => d.temperature).toList();
        unit = '°C';
        break;
      case 'Kelembapan':
        values = data.map((d) => d.humidity).toList();
        unit = '%';
        break;
      case 'Cahaya':
        values = data.map((d) => d.lux.toDouble()).toList();
        unit = ' Lux';
        break;
      case 'Angin':
        values = data.map((d) => d.windSpeedMs).toList();
        unit = ' m/s';
        break;
      case 'Hujan':
        values = data.map((d) => d.rainDailyMm).toList();
        unit = ' mm';
        break;
      default:
        return '-';
    }
    
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    
    if (parameter == 'Cahaya') {
      return '${min.toInt()} - ${max.toInt()}$unit';
    }
    return '${min.toStringAsFixed(1)} - ${max.toStringAsFixed(1)}$unit';
  }

  // ===== GROUP BY DATE (untuk 7/30 Hari) =====
  List<Widget> _buildGroupedHistory(List<HourlyWeatherData> data) {
    final grouped = _groupByDate(data);
    final sortedDates = grouped.keys.toList()
      ..sort((a, b) {
        // Sort berdasarkan tanggal (descending - terbaru di atas)
        final dateA = _parseDateKey(a);
        final dateB = _parseDateKey(b);
        return dateB.compareTo(dateA);
      });

    final widgets = <Widget>[];
    
    for (var dateKey in sortedDates) {
      final dayData = grouped[dateKey]!;
      if (dayData.isEmpty) continue;
      
      final firstData = dayData.first;
      final dateLabel = _formatDateForGroup(firstData.timestamp);
      
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
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
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: Color(0xFF2D6A4F),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D6A4F),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${dayData.length} data',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2D6A4F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildHistoryItem('Suhu', _getRange(dayData, 'Suhu')),
              _buildHistoryItem('Kelembapan', _getRange(dayData, 'Kelembapan')),
              _buildHistoryItem('Intensitas Cahaya', _getRange(dayData, 'Cahaya')),
              _buildHistoryItem('Kecepatan Angin', _getRange(dayData, 'Angin')),
              _buildHistoryItem('Curah Hujan', _getRange(dayData, 'Hujan')),
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }

  DateTime _parseDateKey(String dateKey) {
    try {
      final parts = dateKey.split(' ');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
                        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
        final month = months.indexOf(parts[1]) + 1;
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      debugPrint('Error parsing date key: $e');
    }
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        title: const Text('Riwayat Data Cuaca'),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadHistoricalData,
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
                      child: DropdownButton<String>(
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
                        items: _periodOptions.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text(period),
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
                    _historicalData.isNotEmpty 
                        ? '${_historicalData.length} data' 
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF2D6A4F),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Memuat riwayat data...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
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
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
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
                  ),
                )
              : _historicalData.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 60,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada data riwayat',
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
                  : RefreshIndicator(
                      onRefresh: _loadHistoricalData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ===== DATA HARI INI =====
                            if (_todayData.isNotEmpty) ...[
                              const Text(
                                'Hari Ini',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
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
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Icon(
                                            Icons.today,
                                            color: Color(0xFF2D6A4F),
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _formatDateForGroup(_todayData.first.timestamp),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2D6A4F),
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${_todayData.length} data',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF2D6A4F),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildHistoryItem('Suhu', _getRange(_todayData, 'Suhu')),
                                    _buildHistoryItem('Kelembapan', _getRange(_todayData, 'Kelembapan')),
                                    _buildHistoryItem('Intensitas Cahaya', _getRange(_todayData, 'Cahaya')),
                                    _buildHistoryItem('Kecepatan Angin', _getRange(_todayData, 'Angin')),
                                    _buildHistoryItem('Curah Hujan', _getRange(_todayData, 'Hujan')),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // ===== RIWAYAT SEBELUMNYA =====
                            if (_previousData.isNotEmpty) ...[
                              Text(
                                _selectedPeriod == 'Hari Ini' 
                                    ? 'Riwayat Sebelumnya' 
                                    : 'Riwayat $_selectedPeriod',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._buildGroupedHistory(_previousData),
                            ],
                            
                            // ===== KOSONG =====
                            if (_todayData.isEmpty && _previousData.isEmpty) ...[
                              const SizedBox(height: 32),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Tidak ada data untuk periode ini',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            const SizedBox(height: 80),
                          ],
                        ),
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

  Widget _buildHistoryItem(String parameter, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              parameter,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D6A4F),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}