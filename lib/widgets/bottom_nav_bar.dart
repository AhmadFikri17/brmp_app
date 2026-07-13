import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  String _userRole = 'user';
  late int _currentIndex;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;
    _loadUserRole();
  }

  @override
  void didUpdateWidget(BottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _currentIndex) {
      setState(() {
        _currentIndex = widget.selectedIndex;
      });
    }
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'user';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 60,
        color: Colors.white,
        child: const Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Hapus isAdmin local variable karena tidak digunakan
    // final isAdmin = _userRole == 'admin';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          widget.onTap(index);
          _navigateToScreen(context, index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2D6A4F),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 11,
        ),
        items: _buildNavItems(),
      ),
    );
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    final isAdmin = _userRole == 'admin';

    if (isAdmin) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings_remote),
          label: 'Kontrol',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Grafik',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Akun',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.show_chart),
          label: 'Grafik',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Akun',
        ),
      ];
    }
  }

  void _navigateToScreen(BuildContext context, int index) {
    final isAdmin = _userRole == 'admin';

    if (isAdmin) {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/admin-dashboard');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/kontrol');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/grafik');
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/riwayat');
          break;
        case 4:
          Navigator.pushReplacementNamed(context, '/akun');
          break;
      }
    } else {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/user-dashboard');
          break;
        case 1:
          Navigator.pushReplacementNamed(context, '/grafik');
          break;
        case 2:
          Navigator.pushReplacementNamed(context, '/riwayat');
          break;
        case 3:
          Navigator.pushReplacementNamed(context, '/akun');
          break;
      }
    }
  }
}