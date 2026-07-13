import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  int _selectedIndex = 0; // Akan diisi sesuai role

  @override
  void initState() {
    super.initState();
    _checkRoleAndSetIndex();
  }

  Future<void> _checkRoleAndSetIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'user';
    setState(() {
      // USER: Riwayat di index 2, ADMIN: Riwayat di index 3
      _selectedIndex = role == 'admin' ? 3 : 2;
    });
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hari ini
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
                  const Text(
                    'Hari ini',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D6A4F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildHistoryItem('28 Mei 2026', 'Kelembapan', '65 - 85 %'),
                  _buildHistoryItem('28 Mei 2026', 'Intensitas Cahaya', '350 - 980 Lux'),
                  _buildHistoryItem('28 Mei 2026', 'Kecepatan Angin', '1.1 - 4.7 m/s'),
                  _buildHistoryItem('28 Mei 2026', 'Curah Hujan', '0 - 3.2 mm'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Riwayat sebelumnya
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
                  const Text(
                    'Riwayat Sebelumnya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D6A4F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildHistoryItem('27 Mei 2026', 'Kelembapan', '60 - 82 %'),
                  _buildHistoryItem('27 Mei 2026', 'Intensitas Cahaya', '300 - 950 Lux'),
                  _buildHistoryItem('26 Mei 2026', 'Kelembapan', '55 - 78 %'),
                  _buildHistoryItem('26 Mei 2026', 'Curah Hujan', '0 - 5.0 mm'),
                ],
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

  Widget _buildHistoryItem(String date, String parameter, String value) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  parameter,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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