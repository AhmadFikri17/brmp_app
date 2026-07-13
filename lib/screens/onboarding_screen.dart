import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Palet warna senada dengan login screen: hijau tua, hijau, krem, aksen emas
  static const _darkGreen = Color(0xFF1B5E20);
  static const _green = Color(0xFF2D6A4F);
  static const _lightGreen = Color(0xFF66BB6A);
  static const _accentGold = Color(0xFFFFB300);
  static const _cream = Color(0xFFF5F9F3);

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Selamat Datang di',
      'subtitle': 'WEATHER STATION',
      'description': 'Aplikasi monitoring cuaca cerdas untuk pertanian aneka kacang yang berkualitas dan berkelanjutan.',
      'icon': Icons.grass,
      'color': _lightGreen,
    },
    {
      'title': 'BRMP Aneka Kacang',
      'subtitle': 'Balai Perakitan & Pengujian',
      'description': 'Unit kerja Eselon III di bawah Pusat Perakitan dan Modernisasi Tanaman Pangan - Kementerian Pertanian.',
      'icon': Icons.account_balance,
      'color': _accentGold,
      'link': 'https://brmp.pertanian.go.id',
    },
    {
      'title': 'Sejarah & Perjalanan',
      'subtitle': '1968 - 2025',
      'description': 'Berdiri sejak 1968 sebagai LP3, terus berkembang hingga menjadi BRMP Aneka Kacang dengan komoditas unggulan kedelai, kacang tanah, dan kacang hijau.',
      'icon': Icons.timeline,
      'color': _lightGreen,
    },
    {
      'title': 'Visi & Misi',
      'subtitle': 'Pertanian Maju, Mandiri, Modern',
      'description': 'Mewujudkan pertanian maju, mandiri, dan modern untuk mendukung Indonesia Emas 2045 melalui perekayasaan dan perakitan teknologi pertanian terapan.',
      'icon': Icons.emoji_events,
      'color': _accentGold,
      'link': 'https://brmp.pertanian.go.id/organisasi/visi-dan-misi',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient baru: hijau tua -> hijau -> krem hangat (senada login)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _darkGreen,
                  _green,
                  _lightGreen,
                  _cream,
                ],
                stops: [0.0, 0.35, 0.65, 1.0],
              ),
            ),
          ),
          // Decorative circles, salah satunya diberi tint emas
          Positioned(
            top: -screenWidth * 0.3,
            right: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 0.6,
              height: screenWidth * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accentGold.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.4,
            left: -screenWidth * 0.2,
            child: Container(
              width: screenWidth * 0.4,
              height: screenWidth * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar dengan Login & Skip
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.015,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo kecil
                      Row(
                        children: [
                          Image.asset(
                            'assets/icons/logo.png',
                            width: screenWidth * 0.07,
                            height: screenWidth * 0.07,
                          ),
                          SizedBox(width: screenWidth * 0.02),
                          Text(
                            'KACANG',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'WEATHER',
                            style: TextStyle(
                              fontSize: screenWidth * 0.035,
                              fontWeight: FontWeight.w300,
                              color: Colors.white70,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      // Login & Skip buttons
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              'Login',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              'Skip',
                              style: TextStyle(
                                fontSize: screenWidth * 0.035,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _onboardingData.length,
                    itemBuilder: (context, index) {
                      return _buildOnboardingPage(
                        context,
                        _onboardingData[index],
                        screenWidth,
                        screenHeight,
                      );
                    },
                  ),
                ),
                // Bottom controls
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.05,
                    vertical: screenHeight * 0.025,
                  ),
                  child: Column(
                    children: [
                      // Dot indicators, dot aktif pakai warna emas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _onboardingData.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.01,
                            ),
                            width: _currentPage == index
                                ? screenWidth * 0.12
                                : screenWidth * 0.025,
                            height: screenWidth * 0.025,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _accentGold
                                  : Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(
                                screenWidth * 0.05,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      // Next/Get Started button
                      GestureDetector(
                        onTap: () {
                          if (_currentPage == _onboardingData.length - 1) {
                            Navigator.pushReplacementNamed(context, '/login');
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: Container(
                          width: screenWidth * 0.5,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.06,
                            vertical: screenHeight * 0.018,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                _darkGreen,
                                _green,
                                _lightGreen,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.08,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _darkGreen.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _onboardingData.length - 1
                                      ? 'Mulai Sekarang'
                                      : 'Selanjutnya',
                                  style: TextStyle(
                                    fontSize: screenWidth * 0.04,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: screenWidth * 0.02),
                                Icon(
                                  _currentPage == _onboardingData.length - 1
                                      ? Icons.arrow_forward
                                      : Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: screenWidth * 0.045,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingPage(
    BuildContext context,
    Map<String, dynamic> data,
    double screenWidth,
    double screenHeight,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.06,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon dengan background
          Container(
            width: screenWidth * 0.3,
            height: screenWidth * 0.3,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  (data['color'] as Color).withValues(alpha: 0.3),
                  (data['color'] as Color).withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (data['color'] as Color).withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              data['icon'] as IconData,
              size: screenWidth * 0.12,
              color: data['color'] as Color,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),
          // Title
          Text(
            data['title'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.75),
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: screenHeight * 0.005),
          Text(
            data['subtitle'] as String,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.075,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          // Description - card putih/krem, kontras dengan background hijau
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.015,
            ),
            decoration: BoxDecoration(
              color: _cream.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
              border: Border.all(
                color: _cream.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              data['description'] as String,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.038,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.6,
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          // Link if available
          if (data['link'] != null)
            GestureDetector(
              onTap: () => _launchUrl(data['link'] as String),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.01,
                ),
                decoration: BoxDecoration(
                  color: _cream,
                  borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  boxShadow: [
                    BoxShadow(
                      color: _darkGreen.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new,
                      color: _green,
                      size: screenWidth * 0.04,
                    ),
                    SizedBox(width: screenWidth * 0.015),
                    Text(
                      'Kunjungi Website',
                      style: TextStyle(
                        fontSize: screenWidth * 0.035,
                        color: _green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: _accentGold,
                      size: screenWidth * 0.03,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}