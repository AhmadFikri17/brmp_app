import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../models/weather_data.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  late WeatherData _weatherData;
  String _userName = 'Admin';

  @override
  void initState() {
    super.initState();
    _weatherData = WeatherData(
      suhu: 28.6,
      kelembapan: 78.4,
      intensitasCahaya: 865,
      kecepatanAngin: 3.2,
      arahAngin: 21.6,
      curahHujan: 1.4,
      tanggal: '06 Jul 2026',
      waktu: '11.38',
    );
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseService.getCurrentUser();
    if (user != null) {
      final userData = await FirebaseService.getUserData(user.uid);
      if (userData != null && mounted) {
        setState(() {
          _userName = userData['nama'] ?? 'Admin';
        });
      }
    }
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
    // Warna background scaffold
    const bgColor = Color(0xFFF5F9F9);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background - Pure Green Gradient dengan transisi ke warna background
          Container(
            height: 280,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1B5E20), // Hijau tua
                  const Color(0xFF2E7D32), // Hijau sedang gelap
                  const Color(0xFF388E3C), // Hijau sedang
                  const Color(0xFF43A047), // Hijau terang
                  const Color(0xFF66BB6A), // Hijau muda
                  bgColor.withValues(alpha: 0.9), // Transisi ke warna background
                  bgColor, // Sama dengan background scaffold
                ],
                stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 0.9, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Decorative elements
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.03),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                // Decorative leaf/cloud shapes
                Positioned(
                  top: 30,
                  right: 80,
                  child: Container(
                    width: 60,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 120,
                  child: Container(
                    width: 40,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with admin info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/icons/logo.png',
                          width: 35,
                          height: 35,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'KACANG WEATHER',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.amber.shade600,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Halo, $_userName 👋',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                          onPressed: _logout,
                        ),
                      ),
                    ],
                  ),
                ),
                // Weather Cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Waktu Pengukuran
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.access_time,
                                  color: Color(0xFF2D6A4F),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Update: ${_weatherData.tanggal} ${_weatherData.waktu}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2D6A4F),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Live',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Grid Weather Cards
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.15,
                          children: [
                            _buildWeatherCard(
                              icon: Icons.thermostat,
                              title: 'Suhu Udara',
                              value: '${_weatherData.suhu.toStringAsFixed(1)}°C',
                              color: const Color(0xFFFF6B6B),
                              iconBg: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                            ),
                            _buildWeatherCard(
                              icon: Icons.water_drop,
                              title: 'Kelembapan',
                              value: '${_weatherData.kelembapan.toStringAsFixed(1)}%',
                              color: const Color(0xFF4ECDC4),
                              iconBg: const Color(0xFF4ECDC4).withValues(alpha: 0.15),
                            ),
                            _buildWeatherCard(
                              icon: Icons.wb_sunny,
                              title: 'Intensitas Cahaya',
                              value: '${_weatherData.intensitasCahaya} Lux',
                              color: const Color(0xFFFFD93D),
                              iconBg: const Color(0xFFFFD93D).withValues(alpha: 0.15),
                            ),
                            _buildWeatherCard(
                              icon: Icons.air,
                              title: 'Kecepatan Angin',
                              value: '${_weatherData.kecepatanAngin.toStringAsFixed(1)} m/s',
                              color: const Color(0xFF6C5CE7),
                              iconBg: const Color(0xFF6C5CE7).withValues(alpha: 0.15),
                            ),
                            _buildWeatherCard(
                              icon: Icons.explore,
                              title: 'Arah Angin',
                              value: '${_weatherData.arahAngin.toStringAsFixed(1)}°',
                              color: const Color(0xFF74B9FF),
                              iconBg: const Color(0xFF74B9FF).withValues(alpha: 0.15),
                            ),
                            _buildWeatherCard(
                              icon: Icons.umbrella,
                              title: 'Curah Hujan',
                              value: '${_weatherData.curahHujan.toStringAsFixed(1)} mm',
                              color: const Color(0xFF00B894),
                              iconBg: const Color(0xFF00B894).withValues(alpha: 0.15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Grafik Preview - click to navigate
                        GestureDetector(
                          onTap: () {
                            Navigator.pushReplacementNamed(context, '/grafik');
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  blurRadius: 15,
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
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2D6A4F).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.show_chart,
                                            color: Color(0xFF2D6A4F),
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Grafik 7 Hari',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        children: [
                                          Text(
                                            'Lihat Semua',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF2D6A4F),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_ios,
                                            size: 10,
                                            color: Color(0xFF2D6A4F),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 80,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: [
                                      _buildChartChip('Suhu', const Color(0xFFFF6B6B)),
                                      const SizedBox(width: 8),
                                      _buildChartChip('Kelembapan', const Color(0xFF4ECDC4)),
                                      const SizedBox(width: 8),
                                      _buildChartChip('Angin', const Color(0xFF6C5CE7)),
                                      const SizedBox(width: 8),
                                      _buildChartChip('Hujan', const Color(0xFF00B894)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _buildWeatherCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChartChip(String label, Color color) {
    return GestureDetector(
      onTap: () {
        Navigator.pushReplacementNamed(context, '/grafik');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}