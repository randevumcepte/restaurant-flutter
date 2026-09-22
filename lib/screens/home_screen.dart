import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../ana_sekme.dart';
import '../responsive.dart';
import '../services/api.dart';
import 'package:url_launcher/url_launcher.dart';
import 'yonetim_drawer.dart';
import 'dashboard_screen.dart';
import 'garson_ozet_screen.dart';
import 'masalar_screen.dart';
import 'mutfak_screen.dart';
import 'paket_screen.dart';
import 'asistan_screen.dart';
import 'kasa_screen.dart';
import 'finans_screen.dart';
import 'isletme_hub_screen.dart';
import 'menu_yonetimi_screen.dart';
import 'tema_secim_screen.dart';
import 'indirimler_screen.dart';
import 'odeme_modu_screen.dart';
import 'cari_hesaplar_screen.dart';
import 'rezervasyon_screen.dart';
import 'personel_screen.dart';
import 'gider_screen.dart';
import 'raporlar_screen.dart';
import 'sebep_yonetimi_screen.dart';
import 'masa_atama_screen.dart';
import 'garson_performans_screen.dart';
import 'salon_sema_screen.dart';
import '../services/adim_servisi.dart';
import '../services/mesai_servisi.dart';
import 'mesai_kapisi_screen.dart';
import '../services/cihaz_servisi.dart';

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

  // Masaustunde SAG BOLME icin ic navigator — yonetim ekranlari burada acilir,
  // sol sabit menu KALIR (SepetTakip gibi).
  final GlobalKey<NavigatorState> _icerikNav = GlobalKey<NavigatorState>();

  // TELEFON govde ic navigator — alt cekilen sayfalar (Garson Perf., Salon Sema, ...)
  // BUNUN icinde acilir; boylece alt bar + mikrofon HER SAYFADA kalir.
  final GlobalKey<NavigatorState> _govdeNav = GlobalKey<NavigatorState>();

  // Alt bardan sekme sec: once acik alt sayfayi kapat, sonra sekmeye gec.
  void _sekmeSec(int i) {
    _govdeNav.currentState?.popUntil((r) => r.isFirst);
    anaSekme.value = i;
  }

  static const _bar = Colors.white; // beyaz bar -> belirgin, koyu app uzerinde ayrisir
  static const _secili = Color(0xFF7C3AED); // mor vurgu
  static const _pasif = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    anaSekme.addListener(_sekmeDinle); // Asistan gibi ekranlardan sekme degisince guncelle
    // Garson adim sayaci: giris token'iyla sensoru dinlemeye basla (izin ister)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final tok = auth.token;
      if (tok != null) {
        AdimServisi().baslat(tok);
        CihazServisi().baslat(tok, rol: auth.rol); // Bağlı Cihazlar: periyodik "buradayım" sinyali
        // Mesai kilidi: garson/personel mesai açmadan işletme bilgilerini göremez (patron/müdür serbest)
        MesaiServisi().baslat(tok, rolKilit: !(auth.rol == 'sahip' || auth.rol == 'mudur'));
      }
    });
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
    // Mesai kilidi: garson/personel mesai açmadan içeriyi göremez → QR kapısı.
    return ValueListenableBuilder<bool>(
      valueListenable: MesaiServisi().kilit,
      builder: (ctx, kilitli, _) => kilitli ? const MesaiKapisiScreen() : _uygulama(ctx),
    );
  }

  Widget _uygulama(BuildContext context) {
    final rol = context.watch<AuthProvider>().rol;
    final patron = rol == 'sahip' || rol == 'mudur';

    // Garson: KENDİ özeti + Masalar + Mutfak (Paket garsona kapalı — masaya bakar).
    // (İleride yetkiden tek tıkla Paket açılabilir: rol yerine yetki listesine bağlanır.)
    final List<Widget> ekranlar = patron
        ? const [DashboardScreen(), MasalarScreen(), MutfakScreen(), PaketScreen()]
        : const [GarsonOzetScreen(), MasalarScreen(), MutfakScreen()];

    if (_index >= ekranlar.length) anaSekme.value = 0;

    // ---- MASAUSTU: sol sabit menu + genis icerik ----
    if (genisMi(context)) {
      final tema = context.watch<TemaProvider>();
      final yanMenu = _YanMenu(
        patron: patron,
        aktifIndex: _index,
        sekmeler: _sekmeListesi(patron),
        onSekme: (i) {
          // Once sag bolmede acik yonetim ekranini kapat, sonra sekmeye gec
          _icerikNav.currentState?.popUntil((r) => r.isFirst);
          anaSekme.value = i;
        },
        onAsistan: patron
            ? () => _icerikNav.currentState?.push(MaterialPageRoute(builder: (_) => const AsistanScreen()))
            : null,
        // Yonetim menusu: SAG bolmede ac (sol menu kalir). Tek seferde bir ekran.
        onYonetim: (w) {
          _icerikNav.currentState?.popUntil((r) => r.isFirst);
          _icerikNav.currentState?.push(MaterialPageRoute(builder: (_) => w));
        },
      );
      // Sol menu DAR bir ikon serididir; fareyle uzerine gelince saga dogru acilir
      // (icerigi itmez, ustune biner) -> icerige daha cok yer kalir.
      return Scaffold(
        backgroundColor: tema.bg,
        body: Stack(children: [
          Row(children: [
            const SizedBox(width: _YanMenu.darGenislik), // rail'in kapladigi sabit yer
            Expanded(
              child: Navigator(
                key: _icerikNav,
                onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => _TabGovde(ekranlar: ekranlar)),
              ),
            ),
          ]),
          Positioned(left: 0, top: 0, bottom: 0, child: yanMenu),
        ]),
      );
    }

    // ---- TELEFON: alt bar + mikrofon HER SAYFADA (govde ic navigator) ----
    // Alt cekilen sayfalar bu ic navigator'da acilir; dis Scaffold'un alt bar'i
    // ve mikrofonu kalici kalir (daha kullanisli). Geri tusu once ic sayfayi kapatir.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _govdeNav.currentState;
        if (nav != null && nav.canPop()) { nav.pop(); return; }
        if (_index != 0) { anaSekme.value = 0; return; } // koke don
      },
      child: Scaffold(
        key: anaScaffoldKey,
        // Yonetim menusu HER SAYFADAN acilsin diye drawer dis Scaffold'da.
        // Secilen ekran _govdeNav'a push edilir -> alt bar + mikrofon kalici kalir (mevcut davranis).
        drawer: YonetimDrawer(
          onGit: (e) => _govdeNav.currentState?.push(MaterialPageRoute(builder: (_) => e)),
          onWeb: (p) async { try { await launchUrl(Uri.parse('${Api.base}$p'), mode: LaunchMode.externalApplication); } catch (_) {} },
        ),
        body: Navigator(
          key: _govdeNav,
          onGenerateRoute: (s) => MaterialPageRoute(builder: (_) => _TabGovde(ekranlar: ekranlar)),
        ),
        // Klavye acikken mikrofonu gizle: centerDocked FAB klavyenin ustune cikip
        // alt-ekran butonlarinin (ör. "Kaydet") uzerine biniyordu. Yazarken zaten gerekmez.
        floatingActionButton: (patron && MediaQuery.of(context).viewInsets.bottom < 1) ? _mikrofon() : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: patron ? _patronBar() : _personelBar(),
      ),
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
          _Sekme(Icons.insights_outlined, Icons.insights, 'Özetim'),
          _Sekme(Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
          _Sekme(Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
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
      elevation: 0,                       // notch cevresindeki siyah golge yayini kaldir
      shadowColor: Colors.transparent,
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
        _item(0, Icons.insights_outlined, Icons.insights, 'Özetim'),
        _item(1, Icons.table_bar_outlined, Icons.table_bar, 'Masalar'),
        _item(2, Icons.restaurant_menu_outlined, Icons.restaurant_menu, 'Mutfak'),
      ]),
    );
  }

  Widget _item(int i, IconData ikon, IconData seciliIkon, String label) {
    final secili = _index == i;
    final renk = secili ? _secili : _pasif;
    return Expanded(
      child: InkWell(
        onTap: () => _sekmeSec(i),
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

/// Masaustu sol menu — DAR ikon seridi; fareyle uzerine gelince saga dogru acilir
/// (icerigi itmez, ustune biner). Kapaliyken sadece ikonlar, acikken ikon + yazi.
class _YanMenu extends StatefulWidget {
  final bool patron;
  final int aktifIndex;
  final List<_Sekme> sekmeler;
  final ValueChanged<int> onSekme;
  final VoidCallback? onAsistan;
  final ValueChanged<Widget>? onYonetim;
  const _YanMenu({
    required this.patron,
    required this.aktifIndex,
    required this.sekmeler,
    required this.onSekme,
    required this.onAsistan,
    required this.onYonetim,
  });

  static const double darGenislik = 72;   // kapali (sadece ikon)
  static const double genisGenislik = 250; // acik (ikon + yazi)

  @override
  State<_YanMenu> createState() => _YanMenuState();
}

class _YanMenuState extends State<_YanMenu> {
  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final acik = _acik;
    final patron = widget.patron;

    // Yonetim ekranini SAG bolmede ac (sol menu kalir).
    void git(Widget ekran) => widget.onYonetim?.call(ekran);

    return MouseRegion(
      onEnter: (_) => setState(() => _acik = true),
      onExit: (_) => setState(() => _acik = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 190),
        curve: Curves.easeOutCubic,
        width: acik ? _YanMenu.genisGenislik : _YanMenu.darGenislik,
        decoration: BoxDecoration(
          color: t.card,
          border: Border(right: BorderSide(color: t.line)),
          boxShadow: acik ? [BoxShadow(color: Colors.black.withValues(alpha: 0.20), blurRadius: 26, offset: const Offset(5, 0))] : null,
        ),
        // Icerik hep GENIS olcude cizilir; dar durumda saga tasan kisim kirpilir
        // -> soldaki ikonlar hep gorunur, yazilar acilinca soldan saga "kayarak" belirir.
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: _YanMenu.genisGenislik,
            maxWidth: _YanMenu.genisGenislik,
            child: SizedBox(
              width: _YanMenu.genisGenislik,
              child: SafeArea(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _marka(t, auth, acik),
                  Divider(height: 1, color: t.line),
                  Expanded(
                    child: ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [
                      _baslik(t, 'PANEL', acik),
                      for (int i = 0; i < widget.sekmeler.length; i++)
                        _tab(t, widget.sekmeler[i], i == widget.aktifIndex, () => widget.onSekme(i)),
                      if (widget.onAsistan != null) ...[
                        const SizedBox(height: 6),
                        _asistanBtn(widget.onAsistan!, acik),
                      ],
                      const SizedBox(height: 10),
                      Divider(height: 1, color: t.line, indent: 14, endIndent: 14),
                      const SizedBox(height: 8),
                      _baslik(t, 'YÖNETİM', acik),
                      if (patron) _link(t, Icons.point_of_sale, 'Kasa (Vardiya)', () => git(const KasaScreen())),
                      if (patron) _link(t, Icons.analytics_outlined, 'Finans / Kâr-Zarar', () => git(const FinansScreen())),
                      if (patron) _link(t, Icons.inventory_2_outlined, 'Stok & Satın Alma', () => git(const IsletmeHubScreen())),
                      if (patron) _link(t, Icons.restaurant_menu, 'Menü Yönetimi', () => git(const MenuYonetimiScreen())),
                      if (patron) _link(t, Icons.palette_outlined, 'QR Menü Rengi', () => git(const TemaSecimScreen()), renk: t.gold),
                      if (patron) _link(t, Icons.local_offer_outlined, 'İndirimler', () => git(const IndirimlerScreen()), renk: t.yesil),
                      if (patron) _link(t, Icons.shield_outlined, 'Kaçak Önleme', () => git(const OdemeModuScreen()), renk: const Color(0xFFF43F5E)),
                      _link(t, Icons.account_balance_wallet_outlined, 'Cari / Açık Hesaplar', () => git(const CariHesaplarScreen())),
                      _link(t, Icons.event_available_outlined, 'Rezervasyonlar', () => git(const RezervasyonScreen())),
                      if (patron) _link(t, Icons.badge_outlined, 'Personel & Maaş', () => git(const PersonelScreen())),
                      if (patron) _link(t, Icons.table_restaurant_outlined, 'Masa & Bölge Atama', () => git(const MasaAtamaScreen())),
                      if (patron) _link(t, Icons.emoji_events_outlined, 'Garson Performansı', () => git(const GarsonPerformansScreen()), renk: t.yesil),
                      if (patron) _link(t, Icons.grid_on_outlined, 'Salon Şeması', () => git(const SalonSemaScreen()), renk: const Color(0xFF0EA5E9)),
                      if (patron) _link(t, Icons.receipt_long_outlined, 'Giderler', () => git(const GiderScreen())),
                      if (patron) _link(t, Icons.bar_chart_outlined, 'Raporlar', () => git(const RaporlarScreen())),
                      if (patron) _link(t, Icons.rule_folder_outlined, 'İptal / İkram Sebepleri', () => git(const SebepYonetimiScreen())),
                    ]),
                  ),
                  Divider(height: 1, color: t.line),
                  // Alt: tema + cikis
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: acik ? 8 : 0, vertical: 6),
                    child: Column(children: [
                      _link(t, t.koyu ? Icons.light_mode : Icons.dark_mode, t.koyu ? 'Açık moda geç' : 'Koyu moda geç',
                          () => context.read<TemaProvider>().cevir(), renk: t.gold),
                      _link(t, Icons.logout, 'Çıkış', () => context.read<AuthProvider>().cikis(), renk: const Color(0xFFF87171)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _marka(TemaProvider t, AuthProvider auth, bool acik) {
    final logo = Container(
      width: acik ? null : 40, height: 38, alignment: Alignment.center,
      padding: acik ? const EdgeInsets.symmetric(horizontal: 10) : EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_mor1, _mavi]),
        borderRadius: BorderRadius.circular(9),
      ),
      child: acik
          ? const Text('ResteOS', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
          : const Icon(Icons.restaurant_menu, color: Colors.white, size: 20),
    );
    if (!acik) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: SizedBox(width: _YanMenu.darGenislik, child: Center(child: logo)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(children: [
        logo,
        const SizedBox(width: 8),
        Expanded(child: Text(auth.sube ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _baslik(TemaProvider t, String s, bool acik) => acik
      ? Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 16, 6),
          child: Text(s, style: TextStyle(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        )
      : const SizedBox(height: 10);

  Widget _tab(TemaProvider t, _Sekme s, bool secili, VoidCallback onTap) {
    final ikon = Icon(secili ? s.aktifIkon : s.ikon, color: secili ? _mor1 : t.sub2, size: 22);
    // KAPALI: sadece ortalanmis ikon (secili ise arkasinda yuvarlak vurgu)
    if (!_acik) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: SizedBox(
          width: _YanMenu.darGenislik,
          child: Center(
            child: Material(
              color: secili ? _mor1.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                borderRadius: BorderRadius.circular(11),
                onTap: onTap,
                child: Container(width: 46, height: 40, alignment: Alignment.center, child: ikon),
              ),
            ),
          ),
        ),
      );
    }
    // ACIK: ikon + yazi
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: secili ? _mor1.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              ikon,
              const SizedBox(width: 14),
              Expanded(child: Text(s.label, maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                  style: TextStyle(color: secili ? t.ink : t.sub2, fontSize: 14, fontWeight: secili ? FontWeight.bold : FontWeight.w600))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _asistanBtn(VoidCallback onTap, bool acik) {
    if (!acik) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          width: _YanMenu.darGenislik,
          child: Center(
            child: Material(
              borderRadius: BorderRadius.circular(11), clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Container(
                  width: 46, height: 40, alignment: Alignment.center,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor1, _mavi])),
                  child: const Icon(Icons.mic, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor1, _mavi])),
            child: Row(children: const [
              Icon(Icons.mic, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Patron Asistan', maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _link(TemaProvider t, IconData ikon, String label, VoidCallback onTap, {Color? renk}) {
    final r = renk ?? t.sub2;
    // KAPALI: sadece ortalanmis ikon
    if (!_acik) {
      return SizedBox(
        width: _YanMenu.darGenislik,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(height: 42, alignment: Alignment.center, child: Icon(ikon, color: r, size: 20)),
          ),
        ),
      );
    }
    // ACIK: ikon + yazi
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(children: [
            Icon(ikon, color: r, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.clip, softWrap: false,
                style: TextStyle(color: r, fontSize: 13.5, fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

/// Masaüstü sağ bölmenin KÖK içeriği: aktif sekmeye göre tab ekranını gösterir.
/// anaSekme değişince güncellenir; yönetim ekranları bunun ÜSTÜNE push edilir
/// (sol sabit menü hep kalır).
class _TabGovde extends StatelessWidget {
  final List<Widget> ekranlar;
  const _TabGovde({required this.ekranlar});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: anaSekme,
      builder: (_, i, _) => IndexedStack(
        index: i.clamp(0, ekranlar.length - 1),
        children: ekranlar,
      ),
    );
  }
}
