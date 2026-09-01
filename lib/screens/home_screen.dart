import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../ana_sekme.dart';
import '../responsive.dart';
import 'dashboard_screen.dart';
import 'masalar_screen.dart';
import 'mutfak_screen.dart';
import 'paket_screen.dart';
import 'asistan_screen.dart';
import 'kasa_screen.dart';
import 'finans_screen.dart';
import 'isletme_hub_screen.dart';
import 'menu_yonetimi_screen.dart';
import 'tema_secim_screen.dart';
import 'cari_hesaplar_screen.dart';
import 'rezervasyon_screen.dart';
import 'personel_screen.dart';
import 'gider_screen.dart';
import 'raporlar_screen.dart';
import 'sebep_yonetimi_screen.dart';

/// Uygulama kabugu — iki yuz:
///  • TELEFON: koyu bar + ortada mikrofon (mevcut mobil deneyim, aynen korunur).
///  • MASAUSTU/TABLET (>= kGenisEsik): sol SABIT menu + genis icerik (SepetTakip tarzi
///    profesyonel, ekrani dolduran yerlesim). Alt bar/FAB masaustunde gizlenir.
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

    // ---- MASAUSTU: sol sabit menu + genis icerik ----
    if (genisMi(context)) {
      final tema = context.watch<TemaProvider>();
      return Scaffold(
        backgroundColor: tema.bg,
        body: Row(children: [
          _YanMenu(
            patron: patron,
            aktifIndex: _index,
            sekmeler: _sekmeListesi(patron),
            onSekme: (i) => anaSekme.value = i,
            onAsistan: patron ? _asistanAc : null,
          ),
          Expanded(child: IndexedStack(index: _index, children: ekranlar)),
        ]),
      );
    }

    // ---- TELEFON: mevcut alt bar + mikrofon ----
    return Scaffold(
      body: IndexedStack(index: _index, children: ekranlar),
      floatingActionButton: patron ? _mikrofon() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: patron ? _patronBar() : _personelBar(),
    );
  }

  // Sekme (tab) listesi — role gore. Index'ler ekranlar listesiyle birebir.
  List<_Sekme> _sekmeListesi(bool patron) => patron
      ? const [
          _Sekme(Icons.dashboard_outlined, Icons.dashboard, 'Özet'),
          _Sekme(Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
          _Sekme(Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
          _Sekme(Icons.delivery_dining_outlined, Icons.delivery_dining, 'Paket'),
        ]
      : const [
          _Sekme(Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
          _Sekme(Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
          _Sekme(Icons.delivery_dining_outlined, Icons.delivery_dining, 'Paket'),
        ];

  // Ortada yükseltilmiş mikrofon — Patron Asistan devreye girer.
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

// Sekme tanimi (masaustu sol menu + mobil alt bar ortak)
class _Sekme {
  final IconData ikon;
  final IconData aktifIkon;
  final String label;
  const _Sekme(this.ikon, this.aktifIkon, this.label);
}

/// Masaustu sol SABIT menu — marka + panel sekmeleri + yonetim kisayollari + tema/cikis.
class _YanMenu extends StatelessWidget {
  final bool patron;
  final int aktifIndex;
  final List<_Sekme> sekmeler;
  final ValueChanged<int> onSekme;
  final VoidCallback? onAsistan;
  const _YanMenu({
    required this.patron,
    required this.aktifIndex,
    required this.sekmeler,
    required this.onSekme,
    required this.onAsistan,
  });

  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();

    void git(Widget ekran) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ekran));

    return Container(
      width: 244,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Marka + isletme
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_mor1, _mavi]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('ResteOS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(auth.sube ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Divider(height: 1, color: t.line),

          // Kaydirilabilir orta bolum: panel sekmeleri + yonetim
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
              _baslik(t, 'PANEL'),
              for (int i = 0; i < sekmeler.length; i++)
                _tab(t, sekmeler[i], i == aktifIndex, () => onSekme(i)),
              if (onAsistan != null) ...[
                const SizedBox(height: 6),
                _asistanBtn(context, onAsistan!),
              ],
              const SizedBox(height: 10),
              Divider(height: 1, color: t.line, indent: 14, endIndent: 14),
              const SizedBox(height: 8),
              _baslik(t, 'YÖNETİM'),
              if (patron) _link(t, Icons.point_of_sale, 'Kasa (Vardiya)', () => git(const KasaScreen())),
              if (patron) _link(t, Icons.analytics_outlined, 'Finans / Kâr-Zarar', () => git(const FinansScreen())),
              if (patron) _link(t, Icons.inventory_2_outlined, 'Stok & Satın Alma', () => git(const IsletmeHubScreen())),
              if (patron) _link(t, Icons.restaurant_menu, 'Menü Yönetimi', () => git(const MenuYonetimiScreen())),
              if (patron) _link(t, Icons.palette_outlined, 'QR Menü Rengi', () => git(const TemaSecimScreen()), renk: t.gold),
              _link(t, Icons.account_balance_wallet_outlined, 'Cari / Açık Hesaplar', () => git(const CariHesaplarScreen())),
              _link(t, Icons.event_available_outlined, 'Rezervasyonlar', () => git(const RezervasyonScreen())),
              if (patron) _link(t, Icons.badge_outlined, 'Personel & Maaş', () => git(const PersonelScreen())),
              if (patron) _link(t, Icons.receipt_long_outlined, 'Giderler', () => git(const GiderScreen())),
              if (patron) _link(t, Icons.bar_chart_outlined, 'Raporlar', () => git(const RaporlarScreen())),
              if (patron) _link(t, Icons.rule_folder_outlined, 'İptal / İkram Sebepleri', () => git(const SebepYonetimiScreen())),
            ]),
          ),

          Divider(height: 1, color: t.line),
          // Alt: tema + cikis
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Column(children: [
              _link(t, t.koyu ? Icons.light_mode : Icons.dark_mode, t.koyu ? 'Açık moda geç' : 'Koyu moda geç',
                  () => context.read<TemaProvider>().cevir(), renk: t.gold),
              _link(t, Icons.logout, 'Çıkış', () => context.read<AuthProvider>().cikis(), renk: const Color(0xFFF87171)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _baslik(TemaProvider t, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 16, 6),
        child: Text(s, style: TextStyle(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
      );

  Widget _tab(TemaProvider t, _Sekme s, bool secili, VoidCallback onTap) {
    final renk = secili ? _mor1 : t.sub2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: secili ? _mor1.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Container(
                width: 3.5, height: 20,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: secili ? _mor1 : Colors.transparent, borderRadius: BorderRadius.circular(3)),
              ),
              Icon(secili ? s.aktifIkon : s.ikon, color: renk, size: 21),
              const SizedBox(width: 12),
              Text(s.label, style: TextStyle(color: secili ? t.ink : t.sub2, fontSize: 14, fontWeight: secili ? FontWeight.bold : FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _asistanBtn(BuildContext context, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor1, _mavi])),
            child: Row(children: const [
              Icon(Icons.mic, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Patron Asistan', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _link(TemaProvider t, IconData ikon, String label, VoidCallback onTap, {Color? renk}) {
    final r = renk ?? t.sub2;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          child: Row(children: [
            Icon(ikon, color: r, size: 19),
            const SizedBox(width: 12),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: r, fontSize: 13.5, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}
