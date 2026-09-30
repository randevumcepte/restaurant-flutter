import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import 'detay_screen.dart';
import 'asistan_screen.dart';
import 'personel_screen.dart';
import 'gider_screen.dart';
import 'isletme_hub_screen.dart';
import 'finans_screen.dart';
import 'kasa_screen.dart';
import 'cari_hesaplar_screen.dart';
import 'sebep_yonetimi_screen.dart';
import 'menu_yonetimi_screen.dart';
import 'masa_atama_screen.dart';
import 'garson_performans_screen.dart';
import 'salon_sema_screen.dart';
import 'mesai_qr_screen.dart';
import 'puantaj_screen.dart';
import 'isletme_konum_screen.dart';
import 'tema_secim_screen.dart';
import 'indirimler_screen.dart';
import 'odeme_modu_screen.dart';
import 'garson_cagrilari_screen.dart';
import 'ai_bildirim_screen.dart';
import 'raporlar_screen.dart';
import 'bagli_cihazlar_screen.dart';
import 'hareketler_screen.dart';
import 'yazici_ayarlari_screen.dart';
import 'rezervasyon_screen.dart';
import 'uretim_riski_screen.dart';
import 'sayim_screen.dart';
import 'musteri_detay_screen.dart';
import 'package:url_launcher/url_launcher.dart';

/// Patron ana paneli — Kerzz BOSS yogunlugunda: tek ekranda her sey.
/// Donem secici + karsilastirma + kayip radari + food-cost + odeme/servis dagilimi + 10 gunluk grafik.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? hata;
  String period = 'haftalik';
  final _f = NumberFormat.decimalPattern('tr');

  // read (watch DEGIL): _t getter'i tiklama/callback'lerde de kullaniliyor (ör. _detayAc -> barrierColor: _bg).
  // context.watch build DISINDA cagrilinca DEBUG build'de HATA firlatir -> kart tiklaninca acilmaz/siyah kalir
  // (release'de assert kapali oldugu icin gizli kalmisti). Temaya duyarli yeniden-cizim icin build() icinde
  // ACIK context.watch<TemaProvider>() var; boylece tema toggle'i yine canli calisir.
  TemaProvider get _t => context.read<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _sub2 => _t.sub2;
  Color get _line => _t.line;

  static const _mor1 = Color(0xFF7C3AED);
  static const _mor2 = Color(0xFF9D5DC8);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  // Kisa para formati: 1.2M / 350K / 980
  String _k(num v) {
    final a = v.abs();
    if (a >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M TL';
    if (a >= 1000) return '${(v / 1000).toStringAsFixed(2)}K TL';
    return '${_f.format(v.round())}TL';
  }

  String _tam(num v) => '${_f.format(v.round())}TL';

  // Sayarak artan sayi (donem degisince sifirdan yukselir). key=period -> her degisimde yeniden animasyon.
  Widget _sayiAnim(num deger, TextStyle style, {String Function(num)? bicim}) {
    final f = bicim ?? _tam;
    return TweenAnimationBuilder<double>(
      key: ValueKey('n-$period-${deger.round()}'),
      tween: Tween(begin: 0, end: deger.toDouble()),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Text(f(v), style: style),
    );
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.patronOzet(auth.token!, period: period);
      if (!mounted) return;
      if (res['ok'] == 1) {
        // Patron adini sunucudan tazele (yeniden giris gerekmeden guncellensin)
        if (res['patronAd'] != null) context.read<AuthProvider>().adGuncelle(res['patronAd'].toString());
        setState(() {
          data = res;
          loading = false;
        });
      } else {
        setState(() {
          hata = 'Veri alınamadı';
          loading = false;
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (mounted) {
        setState(() {
          hata = 'Bağlantı hatası';
          loading = false;
        });
      }
    }
  }

  void _donemDegis(String p) {
    if (p == period) return;
    setState(() => period = p);
    _yukle();
  }

  // Drill-down: kart tiklaninca detay ekranini ac.
  // Koyu zeminli FADE gecis -> zoom gecisindeki beyaz parlama olmaz.
  void _detayAc({required String tip, int? id, String? alt, String baslik = 'Detay'}) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      opaque: true,
      barrierColor: _bg,
      pageBuilder: (_, _, _) => DetayScreen(tip: tip, id: id, alt: alt, period: period, baslikFallback: baslik),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  Widget _kayipTap(String alt, Widget child) => GestureDetector(
        onTap: () => _detayAc(tip: 'kayip', alt: alt, baslik: 'Kayıp Detayı'),
        child: child,
      );

  // Web araci (kurye harita / cagri ekran / masa QR afis) tarayicida ac
  Future<void> _webAc(String path) async {
    try {
      await launchUrl(Uri.parse('${Api.base}$path'), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Sol ust menu (drawer) — yonetim sayfalarina hizli gecis
  Widget _drawer(BuildContext context, AuthProvider auth) {
    final patron = auth.rol == 'sahip' || auth.rol == 'mudur';
    void git(Widget ekran) {
      Navigator.of(context).pop(); // drawer'i kapat
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ekran));
    }

    Widget oge(IconData ikon, String baslik, VoidCallback onTap, {Color? renk}) {
      final r = renk ?? _ink;
      return ListTile(
        leading: Icon(ikon, color: r, size: 22),
        title: Text(baslik, style: TextStyle(color: r, fontSize: 15, fontWeight: FontWeight.w600)),
        onTap: onTap,
        dense: true,
        visualDensity: const VisualDensity(vertical: -1),
      );
    }

    return Drawer(
      backgroundColor: _card,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor1, _mavi])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ResteOS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(auth.sube ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text('${auth.ad ?? ''} · ${_rolAd(auth.rol)}', style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              if (patron) oge(Icons.point_of_sale, 'Kasa (Vardiya)', () => git(const KasaScreen())),
              if (patron) oge(Icons.analytics_outlined, 'Finans / Kâr-Zarar', () => git(const FinansScreen())),
              if (patron) oge(Icons.inventory_2_outlined, 'Stok & Satın Alma', () => git(const IsletmeHubScreen())),
              if (patron) oge(Icons.warning_amber_outlined, 'Üretim Riski', () => git(const UretimRiskiScreen()), renk: const Color(0xFFF59E0B)),
              if (patron) oge(Icons.fact_check_outlined, 'Sayım (Envanter)', () => git(const SayimScreen()), renk: const Color(0xFF0EA5E9)),
              if (patron) oge(Icons.restaurant_menu, 'Menü Yönetimi', () => git(const MenuYonetimiScreen())),
              if (patron) oge(Icons.palette_outlined, 'QR Menü Rengi', () => git(const TemaSecimScreen()), renk: const Color(0xFFF6CE63)),
              if (patron) oge(Icons.local_offer_outlined, 'İndirimler', () => git(const IndirimlerScreen()), renk: const Color(0xFF22C55E)),
              if (patron) oge(Icons.shield_outlined, 'Kaçak Önleme', () => git(const OdemeModuScreen()), renk: const Color(0xFFF43F5E)),
              oge(Icons.notifications_active, 'Garson Çağrıları', () => git(const GarsonCagrilariScreen()), renk: _kirmizi),
              oge(Icons.account_balance_wallet_outlined, 'Cari / Açık Hesaplar', () => git(const CariHesaplarScreen())),
              oge(Icons.event_available_outlined, 'Rezervasyonlar', () => git(const RezervasyonScreen())),
              if (patron) oge(Icons.map_outlined, 'Canlı Kurye Haritası', () { Navigator.of(context).pop(); _webAc('/kurye-canli'); }, renk: const Color(0xFF10B981)),
              if (patron) oge(Icons.phone_in_talk_outlined, 'Gelen Çağrı Ekranı', () { Navigator.of(context).pop(); _webAc('/cagri-ekran'); }),
              if (patron) oge(Icons.qr_code_2, 'Masa QR Afişleri (yazdır)', () { Navigator.of(context).pop(); _webAc('/masa-afisler'); }, renk: const Color(0xFFF6CE63)),
              if (patron) oge(Icons.badge_outlined, 'Personel & Maaş', () => git(const PersonelScreen())),
              if (patron) oge(Icons.table_restaurant_outlined, 'Masa & Bölge Atama', () => git(const MasaAtamaScreen())),
              if (patron) oge(Icons.emoji_events_outlined, 'Garson Performansı', () => git(const GarsonPerformansScreen()), renk: const Color(0xFF10B981)),
              if (patron) oge(Icons.grid_on_outlined, 'Salon Şeması', () => git(const SalonSemaScreen()), renk: const Color(0xFF0EA5E9)),
              if (patron) oge(Icons.qr_code_2, 'Kasa Mesai QR', () => git(const MesaiQrScreen()), renk: const Color(0xFF14B8A6)),
              if (patron) oge(Icons.my_location, 'İşletme Konumu (Mesai)', () => git(const IsletmeKonumScreen()), renk: const Color(0xFF14B8A6)),
              if (patron) oge(Icons.how_to_reg_outlined, 'Puantaj (Mesai)', () => git(const PuantajScreen()), renk: const Color(0xFF10B981)),
              if (patron) oge(Icons.receipt_long_outlined, 'Giderler', () => git(const GiderScreen())),
              if (patron) oge(Icons.bar_chart_outlined, 'Raporlar', () => git(const RaporlarScreen())),
              if (patron) oge(Icons.devices_other_outlined, 'Bağlı Cihazlar', () => git(const BagliCihazlarScreen()), renk: const Color(0xFF0EA5E9)),
              if (patron) oge(Icons.history, 'Hareketler (Log)', () => git(const HareketlerScreen()), renk: const Color(0xFF7C3AED)),
              if (patron) oge(Icons.print_outlined, 'Yazıcı Ayarları', () => git(const YaziciAyarlariScreen()), renk: const Color(0xFF14B8A6)),
              if (patron) oge(Icons.rule_folder_outlined, 'İptal / İkram Sebepleri', () => git(const SebepYonetimiScreen())),
              oge(Icons.auto_awesome, 'Patron Asistan', () => git(const AsistanScreen()), renk: const Color(0xFFC4B5FD)),
            ]),
          ),
          Divider(height: 1, color: _line),
          oge(Icons.logout, 'Çıkış', () { Navigator.of(context).pop(); context.read<AuthProvider>().cikis(); }, renk: const Color(0xFFF87171)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  String _rolAd(String? rol) {
    switch (rol) {
      case 'sahip': return 'Sahip';
      case 'mudur': return 'Müdür';
      case 'kasa': return 'Kasa';
      case 'garson': return 'Garson';
      case 'mutfak': return 'Mutfak';
      default: return rol ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    context.watch<TemaProvider>(); // tema degisince dashboard yeniden cizilsin (_t artik read)
    final bildirimler = (data?['bildirimler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      drawer: _drawer(context, auth),
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: _sub),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_mor1, _mavi]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('ResteOS', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text(auth.sube ?? '', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _t.koyu ? 'Açık moda geç' : 'Koyu moda geç',
            onPressed: () => context.read<TemaProvider>().cevir(),
            icon: Icon(_t.koyu ? Icons.light_mode : Icons.dark_mode, color: _t.gold, size: 23),
          ),
          _bildirimCani(bildirimler),
          // Masaustunde navigasyon sol sabit menude; hamburger sadece telefonda.
          if (!genisMi(context))
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menü',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
                icon: Icon(Icons.menu, color: _sub2, size: 24),
              ),
            ),
        ],
      ),
      body: data == null
          ? (hata != null ? _hataGorunum() : const Center(child: CircularProgressIndicator(color: _mor2)))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: _mor2,
              backgroundColor: _card,
              child: Stack(children: [
                _icerik(),
                // Donem degisince tum ekrani spinner'a cevirme -> icerik kalir, ustte ince cizgi
                if (loading)
                  const Positioned(
                    top: 0, left: 0, right: 0,
                    child: LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent, color: _mor2),
                  ),
              ]),
            ),
    );
  }

  Widget _hataGorunum() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hata!, style: const TextStyle(color: _kirmizi)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _yukle, child: const Text('Tekrar Dene')),
          ],
        ),
      );

  Widget _icerik() {
    final d = data!;
    final auth = context.read<AuthProvider>();
    final ciro = _n(d['ciro']);
    final ciroYuzde = d['ciroYuzde'] == null ? null : _n(d['ciroYuzde']).toDouble();
    final info = (d['info'] as Map?) ?? {};
    final comp = (d['comp'] as Map?) ?? {};
    final kayip = (d['kayip'] as Map?) ?? {};
    final odeme = (d['odemeTipleri'] as List?) ?? [];
    final servis = (d['servisTipleri'] as List?) ?? [];
    final gunluk = (d['gunluk'] as List?) ?? [];
    final urunler = (d['urunler'] as List?) ?? [];
    final maliyet = _n(d['maliyet']);
    final maliyetYuzde = _n(d['maliyetYuzde']).toInt();

    return LayoutBuilder(builder: (ctx, cons) {
      // Genis icerik alani -> masaustu cok-sutunlu pano; dar -> telefon kolonu.
      if (cons.maxWidth >= 900) {
        return _genisPano(
          w: cons.maxWidth, d: d, ciro: ciro, ciroYuzde: ciroYuzde,
          info: info, comp: comp, kayip: kayip, odeme: odeme, servis: servis,
          gunluk: gunluk, urunler: urunler, maliyet: maliyet, maliyetYuzde: maliyetYuzde,
        );
      }
      return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        _donemSecici(),
        const SizedBox(height: 12),

        // Mavi Toplam Ciro karti (SADECE telefon Ozet'inde — masaustune eklenmedi)
        _ciroHero(ciro, ciroYuzde, info, comp),
        const SizedBox(height: 12),

        // MODERN OZET: selam + 3 ciro + hizli bilgi + masa + POS (mockup'tan farkli sira)
        _selamKart(auth),
        const SizedBox(height: 12),
        IntrinsicHeight(child: _uclCiro(d)),
        const SizedBox(height: 12),
        _hizliBilgi(d, genis: false),
        const SizedBox(height: 12),
        _masaKart(d),
        const SizedBox(height: 12),
        _posKart(d),
        const SizedBox(height: 12),

        // Maliyet (food-cost halkasi) — modern ustun altinda detay
        GestureDetector(
          onTap: () => _detayAc(tip: 'maliyet', baslik: 'Food-Cost'),
          child: _maliyetKart(maliyet, maliyetYuzde, ciro),
        ),
        const SizedBox(height: 14),

        // KAYIP RADARI
        _baslik('🎯 Kayıp Radarı', 'Ciroya oranla — sızıntı takibi'),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            _kayipTap('iskonto', _kayipKart('İskonto', kayip['iskonto'], Icons.local_offer_outlined)),
            _kayipTap('ikram', _kayipKart('İkram', kayip['ikram'], Icons.card_giftcard)),
            _kayipTap('silinen', _kayipKart('Silinen Ürün', kayip['silinen'], Icons.remove_circle_outline)),
            _kayipTap('iptal', _kayipKart('İptal Adisyon', kayip['iptal'], Icons.delete_outline)),
            _kayipTap('fire', _kayipKart('Fire / Zayi', kayip['fire'], Icons.delete_sweep_outlined)),
            _kayipTap('odenmez', _kayipKart('Tahsil Edilemeyen', kayip['odenmez'], Icons.money_off)),
          ],
        ),
        const SizedBox(height: 14),

        // Odeme tipi + Servis tipi
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _dagilimKart('💳 Ödeme Tipi', odeme, 'tip', ciro)),
          const SizedBox(width: 10),
          Expanded(child: _dagilimKart('🍽️ Servis Tipi', servis, 'ad', ciro)),
        ]),
        const SizedBox(height: 14),

        // 10 gunluk grafik
        _grafikKart(gunluk),
        const SizedBox(height: 14),

        // Sales & Costs (urun bazinda satis + maliyet)
        _salesCostsKart(urunler),
        const SizedBox(height: 8),
        Center(child: Text('Tek bakışta, anlık ve doğru. · AI çok yakında', style: TextStyle(color: _sub, fontSize: 11))),
      ],
        ),
      ),
    );
    });
  }

  // ===== MASAUSTU: cok sutunlu pano (genis ekran) — ayni kartlar, ekrani dolduran yerlesim =====
  Widget _genisPano({
    required double w,
    required Map d,
    required num ciro,
    required double? ciroYuzde,
    required Map info,
    required Map comp,
    required Map kayip,
    required List odeme,
    required List servis,
    required List gunluk,
    required List urunler,
    required num maliyet,
    required int maliyetYuzde,
  }) {
    final kayipCols = w >= 1400 ? 6 : 3;
    final kayipOran = kayipCols == 6 ? 1.55 : 2.6;
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        // Donem secici (sola yasli, dar)
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: _donemSecici()),
        ),
        const SizedBox(height: 16),
        // MODERN OZET: selam kart (tam genislik)
        _selamKart(context.read<AuthProvider>()),
        const SizedBox(height: 16),
        // 3 ciro karti (bugun / hafta / ay)
        IntrinsicHeight(child: _uclCiro(d)),
        const SizedBox(height: 16),
        // Hizli bilgi kartlari (mockup'ta yok)
        _hizliBilgi(d, genis: true),
        const SizedBox(height: 16),
        // Masa Durumu (sol) + POS (sag genis) — mockup'un TERSI yerlesim
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: _masaKart(d)),
          const SizedBox(width: 16),
          Expanded(flex: 6, child: _posKart(d)),
        ]),
        const SizedBox(height: 16),
        // Maliyet (food-cost halkasi)
        GestureDetector(
          onTap: () => _detayAc(tip: 'maliyet', baslik: 'Food-Cost'),
          child: _maliyetKart(maliyet, maliyetYuzde, ciro),
        ),
        const SizedBox(height: 20),
        _baslik('🎯 Kayıp Radarı', 'Ciroya oranla — sızıntı takibi'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: kayipCols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: kayipOran,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            _kayipTap('iskonto', _kayipKart('İskonto', kayip['iskonto'], Icons.local_offer_outlined)),
            _kayipTap('ikram', _kayipKart('İkram', kayip['ikram'], Icons.card_giftcard)),
            _kayipTap('silinen', _kayipKart('Silinen Ürün', kayip['silinen'], Icons.remove_circle_outline)),
            _kayipTap('iptal', _kayipKart('İptal Adisyon', kayip['iptal'], Icons.delete_outline)),
            _kayipTap('fire', _kayipKart('Fire / Zayi', kayip['fire'], Icons.delete_sweep_outlined)),
            _kayipTap('odenmez', _kayipKart('Tahsil Edilemeyen', kayip['odenmez'], Icons.money_off)),
          ],
        ),
        const SizedBox(height: 20),
        // Grafik + Satış-Maliyet (sol genis) + Odeme/Servis (sag kolon) — bosluk kalmasin
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 6, child: Column(children: [
            _grafikKart(gunluk),
            const SizedBox(height: 16),
            _salesCostsKart(urunler),
          ])),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: Column(children: [
            _dagilimKart('💳 Ödeme Tipi', odeme, 'tip', ciro),
            const SizedBox(height: 12),
            _dagilimKart('🍽️ Servis Tipi', servis, 'ad', ciro),
          ])),
        ]),
        const SizedBox(height: 10),
        Center(child: Text('Tek bakışta, anlık ve doğru. · ResteOS', style: TextStyle(color: _sub, fontSize: 11))),
      ],
    );
  }

  // ---- Donem secici ----
  Widget _donemSecici() {
    const donemler = {'gunluk': 'Günlük', 'haftalik': 'Haftalık', 'aylik': 'Aylık', 'yillik': 'Yıllık'};
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), boxShadow: _t.golge),
      child: Row(
        children: donemler.entries.map((e) {
          final aktif = period == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => _donemDegis(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: aktif ? const LinearGradient(colors: [_mor1, _mavi]) : null,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(e.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: aktif ? Colors.white : _sub,
                        fontSize: 13,
                        fontWeight: aktif ? FontWeight.bold : FontWeight.w500)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // ===== MODERN OZET (mockup): selam + 3 ciro + POS + masa =====
  // ============================================================

  String _saat() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
  }

  // Selamlama karti: gunun saatine gore selam + sube + saat/QR/rezervasyon cipleri
  Widget _selamKart(AuthProvider auth) {
    final s = DateTime.now().hour;
    final selam = s < 6 ? 'İyi geceler' : (s < 12 ? 'Günaydın' : (s < 18 ? 'İyi günler' : 'İyi akşamlar'));
    final ikon = (s < 6 || s >= 19) ? Icons.nightlight_round : Icons.wb_sunny_rounded;
    final ad = (auth.ad ?? '').trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFB923C), Color(0xFFF43F5E)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(ikon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$selam${ad.isNotEmpty ? ', $ad!' : '!'}',
                style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(auth.sube ?? '', style: TextStyle(color: _sub, fontSize: 12.5), overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Wrap(spacing: 7, runSpacing: 6, alignment: WrapAlignment.end, children: [
          _selamCip(Icons.access_time, _saat(), _yesil, null),
          _selamCip(Icons.qr_code_2, 'QR Menü', _kirmizi, () => _webAc('/qr-menu')),
          _selamCip(Icons.event_available, 'Rezervasyon', const Color(0xFFEC4899),
              () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RezervasyonScreen()))),
        ]),
      ]),
    );
  }

  Widget _selamCip(IconData ik, String yazi, Color renk, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ik, size: 14, color: renk),
          const SizedBox(width: 5),
          Text(yazi, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // 3 ciro karti: Bugun / Hafta / Ay (sabit; secili donemden bagimsiz)
  Widget _uclCiro(Map d) {
    final k = (d['kartlar'] as Map?) ?? {};
    Map g(String key) => (k[key] as Map?) ?? {};
    double? yz(Map m) => m['yuzde'] == null ? null : _n(m['yuzde']).toDouble();
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(child: _ciroMini('Bugünkü Ciro', _n(g('bugun')['ciro']), yz(g('bugun')), 'düne göre', _kirmizi, Icons.today)),
      const SizedBox(width: 10),
      Expanded(child: _ciroMini('Haftalık Ciro', _n(g('hafta')['ciro']), yz(g('hafta')), 'geçen haftaya', _mavi, Icons.date_range)),
      const SizedBox(width: 10),
      Expanded(child: _ciroMini('Bu Ay Cirosu', _n(g('ay')['ciro']), yz(g('ay')), 'geçen aya', _mor1, Icons.calendar_month)),
    ]);
  }

  Widget _ciroMini(String baslik, num ciro, double? yuzde, String kiyas, Color renk, IconData ik) {
    final up = (yuzde ?? 0) >= 0;
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), boxShadow: _t.golge),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // sol renk cubugu (mockup'taki ust seridin yerine)
          Container(width: 5, color: renk),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
                    child: Icon(ik, size: 17, color: renk),
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(baslik, style: TextStyle(color: _sub, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                ]),
                const SizedBox(height: 10),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                    child: _sayiAnim(ciro, TextStyle(color: _ink, fontSize: 27, fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                if (yuzde != null)
                  Row(children: [
                    Icon(up ? Icons.trending_up : Icons.trending_down, size: 14, color: up ? _yesil : _kirmizi),
                    const SizedBox(width: 4),
                    Flexible(child: Text('%${yuzde.abs().toStringAsFixed(1).replaceAll('.', ',')} $kiyas',
                        style: TextStyle(color: up ? _yesil : _kirmizi, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                  ])
                else
                  Text('kıyas verisi yok', style: TextStyle(color: _sub, fontSize: 11)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // Yeni: hizli bilgi kartlari (mevcut ozet verisinden) — mockup'ta yok, ekrani ozgunlestirir
  Widget _hizliBilgi(Map d, {required bool genis}) {
    final ciro = _n(d['ciro']);
    final maliyet = _n(d['maliyet']);
    final maliyetY = _n(d['maliyetYuzde']).toInt();
    final urunler = (d['urunler'] as List?) ?? [];
    final enCok = urunler.isNotEmpty ? (urunler.first as Map) : null;
    final fcRenk = maliyetY >= 40 ? _kirmizi : (maliyetY >= 30 ? const Color(0xFFF59E0B) : _yesil);
    final kartlar = [
      _bilgiKart(Icons.savings_outlined, 'Brüt Kâr', _k(ciro - maliyet), 'food-cost sonrası', _yesil),
      _bilgiKart(Icons.receipt_long_outlined, 'Ort. Adisyon', _tam(_n(d['adisyonOrt'])), 'adisyon başı', _mavi),
      _bilgiKart(Icons.local_fire_department_outlined, 'Food-Cost', '%$maliyetY', _k(maliyet), fcRenk),
      _bilgiKart(Icons.star_outline, 'En Çok Satan',
          enCok?['ad']?.toString() ?? '—', enCok != null ? '${_n(enCok['adet']).toInt()}× · ${_k(_n(enCok['satis']))}' : 'satış yok', _mor1, tekSatir: true),
    ];
    if (genis) {
      return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (int i = 0; i < kartlar.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: kartlar[i])],
      ]));
    }
    return Column(children: [
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: kartlar[0]), const SizedBox(width: 10), Expanded(child: kartlar[1]),
      ])),
      const SizedBox(height: 10),
      IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(child: kartlar[2]), const SizedBox(width: 10), Expanded(child: kartlar[3]),
      ])),
    ]);
  }

  Widget _bilgiKart(IconData ik, String baslik, String deger, String alt, Color renk, {bool tekSatir = false}) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(15), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 26, height: 26, decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)), child: Icon(ik, size: 15, color: renk)),
          const SizedBox(width: 7),
          Expanded(child: Text(baslik, style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 9),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(deger, maxLines: 1, style: TextStyle(color: _ink, fontSize: tekSatir ? 17 : 22, fontWeight: FontWeight.bold))),
        const SizedBox(height: 3),
        Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _sub, fontSize: 11)),
      ]),
    );
  }

  // POS karti: Toplam Tahsilat + 4 mini kart + servis turune gore ciro
  Widget _posKart(Map d) {
    final ciro = _n(d['ciro']);
    final cy = d['ciroYuzde'] == null ? null : _n(d['ciroYuzde']).toDouble();
    final info = (d['info'] as Map?) ?? {};
    final servis = (d['servis'] as List?) ?? [];
    final servisMax = servis.fold<num>(1, (a, e) => _n((e as Map)['tutar']) > a ? _n(e['tutar']) : a);
    final up = (cy ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: _kirmizi.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.point_of_sale, size: 17, color: _kirmizi)),
          const SizedBox(width: 8),
          Text('POS', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        // Toplam Tahsilat (buyuk yesil)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Toplam Tahsilat', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                  child: _sayiAnim(ciro, const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold))),
            ])),
            if (cy != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(up ? Icons.trending_up : Icons.trending_down, size: 14, color: Colors.white),
                  const SizedBox(width: 3),
                  Text('%${cy.abs().toStringAsFixed(1).replaceAll('.', ',')}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _detayAc(tip: 'acik', baslik: 'Açık Adisyonlar'),
            child: _posMini('Açık Adisyon', '${_n(d['acikAdet']).toInt()}', _k(_n(d['acikTutar'])), const Color(0xFFF59E0B)),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _detayAc(tip: 'kapali', baslik: 'Kapanan Adisyonlar'),
            child: _posMini('Kapalı Adisyon', '${_n(d['kapaliAdet']).toInt()}', _k(_n(d['kapaliTutar'])), _yesil),
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MusteriDetayScreen(period: period))),
            child: _posMini('Kişi Sayısı', _f.format(_n(info['misafir']).toInt()), _tam(_n(info['kisi_basi'])), _mavi),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _detayAc(tip: 'kapali', baslik: 'Adisyonlar'),
            child: _posMini('Toplam Adisyon', '${_n(d['toplamAdisyon']).toInt()}', _tam(_n(d['adisyonOrt'])), const Color(0xFFEC4899)),
          )),
        ]),
        const SizedBox(height: 16),
        Text('Servis Türüne Göre Ciro', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (servis.isEmpty)
          Text('Bu dönemde satış yok.', style: TextStyle(color: _sub, fontSize: 12))
        else
          for (final s in servis) _servisBar((s as Map)['ad']?.toString() ?? '', _n(s['tutar']), servisMax),
      ]),
    );
  }

  Widget _posMini(String baslik, String buyuk, String alt, Color renk) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: renk.withValues(alpha: 0.22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik, style: TextStyle(color: _sub2, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(buyuk, style: TextStyle(color: renk, fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(child: Text(alt, textAlign: TextAlign.right,
              style: TextStyle(color: _sub, fontSize: 11.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
      ]),
    );
  }

  Widget _servisBar(String ad, num tutar, num maks) {
    final oran = maks > 0 ? (tutar / maks).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(children: [
        SizedBox(width: 52, child: Text(ad, style: TextStyle(color: _sub2, fontSize: 12, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              key: ValueKey('svc-$period-$ad-${tutar.round()}'),
              tween: Tween(begin: 0, end: oran),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v, minHeight: 9, backgroundColor: _t.card2,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFB7185)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(_tam(tutar), style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // Masa Durumu karti: Toplam/Musait/Dolu + doluluk % + bekleyen masalar
  Widget _masaKart(Map d) {
    final m = (d['masa'] as Map?) ?? {};
    final toplam = _n(m['toplam']).toInt();
    final musait = _n(m['musait']).toInt();
    final dolu = _n(m['dolu']).toInt();
    final doluluk = _n(m['doluluk']).toInt();
    final yogunluk = m['yogunluk']?.toString() ?? '';
    final bekleyen = (m['bekleyen'] as List?) ?? [];
    final yogunRenk = doluluk >= 70 ? _kirmizi : (doluluk >= 35 ? const Color(0xFFF59E0B) : _yesil);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: _mor1.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
              child: Icon(Icons.table_restaurant, size: 17, color: _mor1)),
          const SizedBox(width: 8),
          Text('Masa Durumu', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _masaSayac('Toplam', toplam, Icons.grid_view_rounded, const Color(0xFFF97316))),
          const SizedBox(width: 10),
          Expanded(child: _masaSayac('Müsait', musait, Icons.check_circle_outline, _yesil)),
          const SizedBox(width: 10),
          Expanded(child: _masaSayac('Dolu', dolu, Icons.circle, _kirmizi)),
        ]),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('%$doluluk', style: TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.bold, height: 1)),
          const SizedBox(width: 8),
          if (yogunluk.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: yogunRenk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.trending_up, size: 13, color: yogunRenk),
                  const SizedBox(width: 3),
                  Text(yogunluk, style: TextStyle(color: yogunRenk, fontWeight: FontWeight.bold, fontSize: 11)),
                ]),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("$toplam masanın $dolu'i dolu", style: TextStyle(color: _sub, fontSize: 11), textAlign: TextAlign.right),
          ),
        ]),
        const SizedBox(height: 3),
        Text('Doluluk', style: TextStyle(color: _sub, fontSize: 11)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: (doluluk / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: _t.card2, valueColor: AlwaysStoppedAnimation(yogunRenk)),
        ),
        const SizedBox(height: 16),
        Text('Bekleyen Masalar', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (bekleyen.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Bekleyen masa yok', style: TextStyle(color: _sub, fontSize: 12)))
        else
          for (final b in bekleyen) _bekleyenSatir((b as Map)['ad']?.toString() ?? 'Masa', _n(b['dk']).toInt()),
      ]),
    );
  }

  Widget _masaSayac(String etiket, int deger, IconData ik, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: renk.withValues(alpha: 0.22)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(ik, size: 12, color: renk),
          const SizedBox(width: 4),
          Flexible(child: Text(etiket, style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 6),
        Text('$deger', style: TextStyle(color: renk, fontSize: 26, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // Okunur sure: 52 dk / 3 sa 10 dk / 2 gün
  String _sure(int dk) {
    if (dk >= 1440) return '${dk ~/ 1440} gün';
    if (dk >= 60) {
      final s = dk ~/ 60, k = dk % 60;
      return k > 0 ? '$s sa $k dk' : '$s sa';
    }
    return '$dk dk';
  }

  Widget _bekleyenSatir(String ad, int dk) {
    final renk = dk >= 45 ? _kirmizi : (dk >= 25 ? const Color(0xFFF59E0B) : _yesil);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Text(ad, style: TextStyle(color: _sub2, fontSize: 12.5, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
        Text(_sure(dk), style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ---- AI Bildirim cani (AppBar) — uyarilari toplayan badge'li ikon ----
  Widget _bildirimCani(List bildirimler) {
    final n = bildirimler.length;
    Color badge = _mor2;
    if (bildirimler.any((x) => (x as Map)['seviye'] == 'riskli')) {
      badge = _kirmizi;
    } else if (bildirimler.any((x) => (x as Map)['seviye'] == 'uyari')) {
      badge = const Color(0xFFF59E0B);
    }
    return Stack(clipBehavior: Clip.none, children: [
      IconButton(
        tooltip: 'AI Bildirimleri',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AiBildirimScreen(bildirimler: bildirimler, period: period)),
        ),
        // AI bildirim -> normal can degil, mor gradientli sparkle (AI icgorusu hissi)
        icon: ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            colors: [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ).createShader(r),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
        ),
      ),
      if (n > 0)
        Positioned(
          right: 6,
          top: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            constraints: const BoxConstraints(minWidth: 18),
            decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(20), border: Border.all(color: _bg, width: 1.5)),
            child: Text('$n', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
    ]);
  }

  // ---- Mavi Toplam Ciro hero karti (SADECE telefon Ozet'i cagirir; _genisPano cagirmaz) ----
  Widget _ciroHero(num ciro, double? yuzde, Map info, Map comp) {
    final up = (yuzde ?? 0) >= 0;
    final oncekiVar = _n(data?['compCiro']) > 0 || _n(comp['folyo']) > 0 || _n(comp['misafir']) > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Toplam Ciro', style: TextStyle(color: Colors.white70, fontSize: 14)),
          if (yuzde != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
              child: Text('${up ? "▲" : "▼"} %${yuzde.abs().toStringAsFixed(1)}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 4),
        _sayiAnim(ciro, const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(oncekiVar ? 'önceki dönem: ${_tam(_n(data!['compCiro']))}' : 'karşılaştırılacak önceki dönem verisi yok',
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _kib('Folyo', '${_n(info['folyo']).toInt()}', '${_n(comp['folyo']).toInt()}', oncekiVar: oncekiVar),
            _kib('Ort. Adisyon', _tam(_n(info['folyo_ort'])), _tam(_n(comp['folyo_ort'])), oncekiVar: oncekiVar),
            _kib('Misafir', '${_n(info['misafir']).toInt()}', '${_n(comp['misafir']).toInt()}', oncekiVar: oncekiVar),
            _kib('Kişi Başı', _tam(_n(info['kisi_basi'])), _tam(_n(comp['kisi_basi'])), son: true, oncekiVar: oncekiVar),
          ]),
        ),
      ]),
    );
  }

  Widget _kib(String etiket, String simdi, String onceki, {bool son = false, bool oncekiVar = true}) {
    return Expanded(
      child: Container(
        decoration: son ? null : const BoxDecoration(border: Border(right: BorderSide(color: Colors.white24))),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          Text(etiket, style: const TextStyle(color: Colors.white60, fontSize: 9)),
          const SizedBox(height: 3),
          FittedBox(child: Text(simdi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
          FittedBox(child: Text(oncekiVar ? onceki : '—', style: const TextStyle(color: Colors.white38, fontSize: 10))),
        ]),
      ),
    );
  }

  Widget _maliyetKart(num maliyet, int yuzde, num ciro) {
    final renk = yuzde >= 40 ? _kirmizi : (yuzde >= 30 ? const Color(0xFFF59E0B) : _yesil);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Toplam Maliyet (Food-Cost)', style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(_tam(maliyet), style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Brüt kâr: ${_tam(ciro - maliyet)}', style: TextStyle(color: _sub, fontSize: 11)),
          ]),
        ),
        SizedBox(
          width: 66,
          height: 66,
          child: TweenAnimationBuilder<double>(
            key: ValueKey('ring-$period-$yuzde'),
            tween: Tween(begin: 0, end: (yuzde / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Stack(alignment: Alignment.center, children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 7,
                  backgroundColor: _t.card2,
                  valueColor: AlwaysStoppedAnimation(renk),
                ),
              ),
              Text('%${(v * 100).round()}', style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _baslik(String t, String alt) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(alt, style: TextStyle(color: _sub, fontSize: 11)),
        ]),
      );

  Widget _kayipKart(String baslik, dynamic k, IconData ikon) {
    final m = (k as Map?) ?? {};
    final tutar = _n(m['tutar']);
    final yuzde = _n(m['yuzde']);
    final adet = m['adet'];
    final vurgu = yuzde >= 5 || (baslik == 'İskonto' && yuzde >= 3);
    // Her kayip turune kendi rengi (kritik olanlar koyu/vurgulu, digerleri yumusak ton)
    final renk = <String, Color>{
      'İskonto': const Color(0xFFF59E0B),
      'İkram': const Color(0xFF8B5CF6),
      'Silinen Ürün': const Color(0xFFEF4444),
      'İptal Adisyon': const Color(0xFFEC4899),
      'Fire / Zayi': const Color(0xFFF97316),
      'Tahsil Edilemeyen': const Color(0xFFF43F5E),
    }[baslik] ?? _mor1;
    final yuzdeStr = '%${yuzde % 1 == 0 ? yuzde.toInt() : yuzde.toStringAsFixed(1).replaceAll('.', ',')}';
    const beyaz = Colors.white;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Normal: temiz kart + sol renk cubugu. Kritik: dolgun renkli (uyari).
        color: vurgu ? null : _card,
        gradient: vurgu
            ? LinearGradient(colors: [renk, Color.lerp(renk, Colors.black, 0.4)!], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        borderRadius: BorderRadius.circular(16),
        border: vurgu ? null : Border.all(color: _t.card2),
        boxShadow: _t.golge,
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, color: vurgu ? beyaz.withValues(alpha: 0.35) : renk),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(color: vurgu ? beyaz.withValues(alpha: 0.22) : renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Icon(ikon, size: 19, color: vurgu ? beyaz : renk),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: vurgu ? beyaz.withValues(alpha: 0.22) : renk.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(9)),
                    child: Text(yuzdeStr, style: TextStyle(color: vurgu ? beyaz : renk, fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                      child: Text(_tam(tutar), style: TextStyle(color: vurgu ? beyaz : _ink, fontSize: 26, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 3),
                  Text(adet != null ? '$baslik · ${_n(adet).toInt()} adet' : baslik,
                      style: TextStyle(color: vurgu ? beyaz.withValues(alpha: 0.85) : _sub, fontSize: 12.5, fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _dagilimKart(String baslik, List liste, String adKey, num ciro) {
    final toplam = liste.fold<num>(0, (a, e) => a + _n((e as Map)['tutar']));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik, style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (liste.isEmpty)
          Text('Kayıt yok', style: TextStyle(color: _sub, fontSize: 12))
        else
          for (final e in liste.take(4)) _dagilimSatir((e as Map)[adKey]?.toString() ?? '-', _n(e['tutar']), _n(e['adet']).toInt(), toplam),
      ]),
    );
  }

  Widget _dagilimSatir(String ad, num tutar, int adet, num toplam) {
    final oran = toplam > 0 ? (tutar / toplam).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(ad.toUpperCase(), overflow: TextOverflow.ellipsis, style: TextStyle(color: _sub2, fontSize: 11, fontWeight: FontWeight.w600))),
          Text(_k(tutar), style: TextStyle(color: _ink, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: oran,
            minHeight: 5,
            backgroundColor: _t.card2,
            valueColor: const AlwaysStoppedAnimation(_mor2),
          ),
        ),
        const SizedBox(height: 2),
        Text('$adet işlem', style: TextStyle(color: _sub, fontSize: 9)),
      ]),
    );
  }

  Widget _grafikKart(List gunluk) {
    final maks = gunluk.fold<num>(1, (a, e) => _n((e as Map)['ciro']) > a ? _n(e['ciro']) : a);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('📈 Son 10 Gün', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 14),
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: gunluk.asMap().entries.map<Widget>((entry) {
              final i = entry.key;
              final m = entry.value as Map;
              final v = _n(m['ciro']);
              final h = maks > 0 ? (v / maks * 96).clamp(3.0, 96.0).toDouble() : 3.0;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}K' : '${v.toInt()}',
                        style: TextStyle(color: _sub, fontSize: 8)),
                    const SizedBox(height: 2),
                    // Asagidan yukselen animasyon (donem degisince/ilk yuklemede sifirdan)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('bar-$period-$i'),
                      tween: Tween(begin: 0, end: h),
                      duration: Duration(milliseconds: 500 + i * 45),
                      curve: Curves.easeOutCubic,
                      builder: (_, hv, child) => Container(
                        height: hv,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [_mor2, _mor1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(m['gun'].toString(), style: TextStyle(color: _sub, fontSize: 8)),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _salesCostsKart(List urunler) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), boxShadow: _t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('🧾 Ürün Satış & Maliyet', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.bold)),
          Text('maliyet %', style: TextStyle(color: _sub, fontSize: 10)),
        ]),
        const SizedBox(height: 10),
        if (urunler.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Bu dönemde satış yok.', style: TextStyle(color: _sub)))
        else
          for (final u in urunler.take(15))
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _detayAc(tip: 'urun', id: _n((u as Map)['urun_id']).toInt(), baslik: u['ad'].toString()),
              child: _urunSatir(u),
            ),
      ]),
    );
  }

  Widget _urunSatir(Map u) {
    final yuzde = _n(u['yuzde']).toInt();
    final renk = yuzde >= 35 ? _kirmizi : (yuzde >= 25 ? const Color(0xFFF59E0B) : _yesil);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 40,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(6)),
          child: Text('${_n(u['adet']).toInt()}×', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(u['ad'].toString(), overflow: TextOverflow.ellipsis, style: TextStyle(color: _sub2, fontSize: 12))),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_k(_n(u['satis'])), style: TextStyle(color: _ink, fontSize: 12, fontWeight: FontWeight.bold)),
          Text('mlt ${_k(_n(u['maliyet']))}', style: TextStyle(color: _sub, fontSize: 9)),
        ]),
        const SizedBox(width: 8),
        Container(
          width: 38,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
          child: Text('%$yuzde', textAlign: TextAlign.center, style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
