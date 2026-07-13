import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/weather_card.dart';
import '../models/weather_data.dart';
import '../services/firebase_service.dart';
import 'login_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _selectedIndex = 0; // Dashboard = 0
  late WeatherData _weatherData;
  String _userName = 'User';

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
          _userName = userData['nama'] ?? 'User';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      body: Stack(
        children: [
          // Background
          Container(
            height: 220,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/mountain_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Header with user info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/icons/logo.png',
                        width: 40,
                        height: 40,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'USER',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white.withValues(alpha: 0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Halo, $_userName',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: _logout,
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
                          padding: const EdgeInsets.all(12),
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.access_time,
                                color: Color(0xFF2D6A4F),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Waktu Pengukuran: ${_weatherData.tanggal} ${_weatherData.waktu}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
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
                          childAspectRatio: 1.1,
                          children: [
                            WeatherCard(
                              icon: Icons.thermostat,
                              title: 'Suhu Udara',
                              value: '${_weatherData.suhu.toStringAsFixed(1)} °C',
                              color: const Color(0xFFFF6B6B),
                            ),
                            WeatherCard(
                              icon: Icons.water_drop,
                              title: 'Kelembapan',
                              value: '${_weatherData.kelembapan.toStringAsFixed(1)} %',
                              color: const Color(0xFF4ECDC4),
                            ),
                            WeatherCard(
                              icon: Icons.wb_sunny,
                              title: 'Intensitas Cahaya',
                              value: '${_weatherData.intensitasCahaya} Lux',
                              color: const Color(0xFFFFD93D),
                            ),
                            WeatherCard(
                              icon: Icons.air,
                              title: 'Kecepatan Angin',
                              value: '${_weatherData.kecepatanAngin.toStringAsFixed(1)} m/s',
                              color: const Color(0xFF6C5CE7),
                            ),
                            WeatherCard(
                              icon: Icons.explore,
                              title: 'Arah Angin',
                              value: '${_weatherData.arahAngin.toStringAsFixed(1)} °C',
                              color: const Color(0xFF74B9FF),
                            ),
                            WeatherCard(
                              icon: Icons.umbrella,
                              title: 'Curah Hujan',
                              value: '${_weatherData.curahHujan.toStringAsFixed(1)} mm',
                              color: const Color(0xFF00B894),
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
                                const Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                     Text(
                                      'Grafik',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Lihat Semua >',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF2D6A4F),
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