import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dashboard_screen.dart';
import 'masalar_screen.dart';
import 'mutfak_screen.dart';
import 'paket_screen.dart';
import 'raporlar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final rol = context.watch<AuthProvider>().rol;
    final patron = rol == 'sahip' || rol == 'mudur';

    // Patron: Özet + Masalar + Mutfak + Paket + Raporlar
    // Garson/Kasa/Mutfak: Masalar + Mutfak + Paket (patron ekranlari gizli)
    final List<Widget> ekranlar = patron
        ? const [DashboardScreen(), MasalarScreen(), MutfakScreen(), PaketScreen(), RaporlarScreen()]
        : const [MasalarScreen(), MutfakScreen(), PaketScreen()];

    final List<NavigationDestination> hedefler = patron
        ? const [
            NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Özet'),
            NavigationDestination(icon: Icon(Icons.table_bar_outlined), selectedIcon: Icon(Icons.table_bar), label: 'Masalar'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Mutfak'),
            NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Paket'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Raporlar'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.table_bar_outlined), selectedIcon: Icon(Icons.table_bar), label: 'Masalar'),
            NavigationDestination(icon: Icon(Icons.restaurant_menu_outlined), selectedIcon: Icon(Icons.restaurant_menu), label: 'Mutfak'),
            NavigationDestination(icon: Icon(Icons.delivery_dining_outlined), selectedIcon: Icon(Icons.delivery_dining), label: 'Paket'),
          ];

    if (_index >= ekranlar.length) _index = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: ekranlar),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE0E7FF),
        destinations: hedefler,
      ),
    );
  }
}
