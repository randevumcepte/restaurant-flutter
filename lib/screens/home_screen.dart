import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'masalar_screen.dart';
import 'paket_screen.dart';
import 'raporlar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  // Sekme degisince o ekran taze veriyle acilsin diye key ile yeniden olustur
  final List<Widget> _ekranlar = const [
    DashboardScreen(),
    MasalarScreen(),
    PaketScreen(),
    RaporlarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _ekranlar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0E7FF),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Özet'),
          NavigationDestination(icon: Icon(Icons.table_bar_outlined), selectedIcon: Icon(Icons.table_bar), label: 'Masalar'),
          NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Paket'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Raporlar'),
        ],
      ),
    );
  }
}
