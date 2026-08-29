import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../ana_sekme.dart';
import 'dashboard_screen.dart';
import 'masalar_screen.dart';
import 'mutfak_screen.dart';
import 'paket_screen.dart';
import 'asistan_screen.dart';

/// Yeni nesil alt menü: koyu bar + ortada yükseltilmiş mikrofon (Patron Asistan).
/// Patron: Özet · Masalar · [🎤] · Mutfak · Paket   (Raporlar üst menüde)
/// Personel: Masalar · Mutfak · Paket
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int get _index => anaSekme.value;

  static const _bar = Colors.white; // beyaz bar -> belirgin, koyu app uzerinde ayrisir
  static const _secili = Color(0xFF7C3AED); // mor vurgu
  static const _pasif = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    anaSekme.addListener(_sekmeDinle); // Asistan gibi ekranlardan sekme degisince guncelle
  }

  @override
  void dispose() {
    anaSekme.removeListener(_sekmeDinle);
    super.dispose();
  }

  void _sekmeDinle() { if (mounted) setState(() {}); }

  void _asistanAc() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AsistanScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rol = context.watch<AuthProvider>().rol;
    final patron = rol == 'sahip' || rol == 'mudur';

    final List<Widget> ekranlar = patron
        ? const [DashboardScreen(), MasalarScreen(), MutfakScreen(), PaketScreen()]
        : const [MasalarScreen(), MutfakScreen(), PaketScreen()];

    if (_index >= ekranlar.length) anaSekme.value = 0;

    return Scaffold(
      body: IndexedStack(index: _index, children: ekranlar),
      floatingActionButton: patron ? _mikrofon() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: patron ? _patronBar() : _personelBar(),
    );
  }

  // Ortada yükseltilmiş mikrofon — Patron Asistan devreye girer.
  // Beyaz kenar bar ile kaynasir (notch icinde kare artefakt olmaz), yumusak mor golge.
  Widget _mikrofon() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 6))],
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _asistanAc,
          child: const Center(child: Icon(Icons.mic, color: Colors.white, size: 27)),
        ),
      ),
    );
  }

  // Patron alt bar: notch'lu, 2 + [mic] + 2
  Widget _patronBar() {
    return BottomAppBar(
      color: _bar,
      elevation: 12,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.white,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      height: 66,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _item(0, Icons.dashboard_outlined, Icons.dashboard, 'Özet'),
          _item(1, Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
          const SizedBox(width: 64), // orta mikrofon boşluğu
          _item(2, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
          _item(3, Icons.delivery_dining_outlined, Icons.delivery_dining, 'Paket'),
        ],
      ),
    );
  }

  // Personel alt bar: sade 3 sekme (mic yok — asistan patrona özel)
  Widget _personelBar() {
    return BottomAppBar(
      color: _bar,
      elevation: 12,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.white,
      height: 64,
      padding: EdgeInsets.zero,
      child: Row(children: [
        _item(0, Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
        _item(1, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
        _item(2, Icons.delivery_dining_outlined, Icons.delivery_dining, 'Paket'),
      ]),
    );
  }

  Widget _item(int i, IconData ikon, IconData seciliIkon, String label) {
    final secili = _index == i;
    final renk = secili ? _secili : _pasif;
    return Expanded(
      child: InkWell(
        onTap: () => anaSekme.value = i,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Seçili göstergesi: küçük üst çizgi/nokta
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 3,
              width: secili ? 22 : 0,
              margin: const EdgeInsets.only(bottom: 5),
              decoration: BoxDecoration(color: _secili, borderRadius: BorderRadius.circular(3)),
            ),
            Icon(secili ? seciliIkon : ikon, color: renk, size: 23),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: renk, fontSize: 11, fontWeight: secili ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
