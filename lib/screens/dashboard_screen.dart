import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
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
import 'tema_secim_screen.dart';
import 'ai_bildirim_screen.dart';
import 'raporlar_screen.dart';
import 'rezervasyon_screen.dart';

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

  TemaProvider get _t => context.watch<TemaProvider>();
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
              if (patron) oge(Icons.restaurant_menu, 'Menü Yönetimi', () => git(const MenuYonetimiScreen())),
              if (patron) oge(Icons.palette_outlined, 'QR Menü Rengi', () => git(const TemaSecimScreen()), renk: const Color(0xFFF6CE63)),
              oge(Icons.account_balance_wallet_outlined, 'Cari / Açık Hesaplar', () => git(const CariHesaplarScreen())),
              oge(Icons.event_available_outlined, 'Rezervasyonlar', () => git(const RezervasyonScreen())),
              if (patron) oge(Icons.badge_outlined, 'Personel & Maaş', () => git(const PersonelScreen())),
              if (patron) oge(Icons.receipt_long_outlined, 'Giderler', () => git(const GiderScreen())),
              if (patron) oge(Icons.bar_chart_outlined, 'Raporlar', () => git(const RaporlarScreen())),
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

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      children: [
        _donemSecici(),
        const SizedBox(height: 12),

        // ANA CIRO karti (Total Amount + comparison) — uyarilar artik AppBar'daki AI cani altinda
        _ciroHero(ciro, ciroYuzde, info, comp),
        const SizedBox(height: 10),

        // Acik / Kapali folio + Maliyet
        Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _detayAc(tip: 'acik', baslik: 'Açık Adisyonlar'),
              child: _folioKart('Açık Adisyon', _tam(_n(d['acikTutar'])), '${d['acikAdet'] ?? 0} folyo ›', _mavi, false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => _detayAc(tip: 'kapali', baslik: 'Kapanan Adisyonlar'),
              child: _folioKart('Kapanan', _k(_n(d['kapaliTutar'])), '${d['kapaliAdet'] ?? 0} folyo ›', _yesil, true),
            ),
          ),
        ]),
        const SizedBox(height: 10),
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
  }

  // ---- Donem secici ----
  Widget _donemSecici() {
    const donemler = {'gunluk': 'Günlük', 'haftalik': 'Haftalık', 'aylik': 'Aylık', 'yillik': 'Yıllık'};
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
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
        onPressed: () => Navigator.of(context).push(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 220),
          opaque: true,
          barrierColor: _bg,
          pageBuilder: (_, _, _) => AiBildirimScreen(bildirimler: bildirimler, period: period),
          transitionsBuilder: (_, anim, _, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        )),
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

  // ---- Ana ciro karti ----
  Widget _ciroHero(num ciro, double? yuzde, Map info, Map comp) {
    final up = (yuzde ?? 0) >= 0;
    // Onceki donemde veri var mi? (yoksa 0 yerine '—' gosterilir; or. yillikta gecen yil)
    final oncekiVar = _n(data?['compCiro']) > 0 || _n(comp['folyo']) > 0 || _n(comp['misafir']) > 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // Onceki donemde veri yoksa (or. yillikta gecen yil) '0TL' yerine bilgi ver
          Text(oncekiVar ? 'önceki dönem: ${_tam(_n(data!['compCiro']))}' : 'karşılaştırılacak önceki dönem verisi yok',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 14),
          // info vs comp satiri (Kerzz'in en yogun satiri)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              Row(children: [
                _kib('Folyo', '${_n(info['folyo']).toInt()}', '${_n(comp['folyo']).toInt()}', oncekiVar: oncekiVar),
                _kib('Ort. Adisyon', _tam(_n(info['folyo_ort'])), _tam(_n(comp['folyo_ort'])), oncekiVar: oncekiVar),
                _kib('Misafir', '${_n(info['misafir']).toInt()}', '${_n(comp['misafir']).toInt()}', oncekiVar: oncekiVar),
                _kib('Kişi Başı', _tam(_n(info['kisi_basi'])), _tam(_n(comp['kisi_basi'])), son: true, oncekiVar: oncekiVar),
              ]),
            ]),
          ),
        ],
      ),
    );
  }

  // key-info-block: bu donem (ustte) vs onceki (altta). Onceki yoksa '—'.
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

  Widget _folioKart(String baslik, String deger, String alt, Color renk, bool kapali) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(baslik, style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        Text(deger, style: TextStyle(color: _ink, fontSize: 19, fontWeight: FontWeight.bold)),
        Text(alt, style: TextStyle(color: _sub, fontSize: 11)),
      ]),
    );
  }

  Widget _maliyetKart(num maliyet, int yuzde, num ciro) {
    final renk = yuzde >= 40 ? _kirmizi : (yuzde >= 30 ? const Color(0xFFF59E0B) : _yesil);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
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
                  backgroundColor: const Color(0xFF243049),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: vurgu ? [const Color(0xFF7F1D1D), const Color(0xFF9F1239)] : [_card, _card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: vurgu ? _kirmizi.withValues(alpha: 0.5) : const Color(0xFF243049)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(ikon, size: 16, color: vurgu ? const Color(0xFFFCA5A5) : _sub),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: (vurgu ? _kirmizi : const Color(0xFF334155)).withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
            child: Text('%${yuzde % 1 == 0 ? yuzde.toInt() : yuzde}',
                style: TextStyle(color: vurgu ? const Color(0xFFFCA5A5) : _sub, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_tam(tutar), style: TextStyle(color: vurgu ? Colors.white : _ink, fontSize: 16, fontWeight: FontWeight.bold)),
          Text(adet != null ? '$baslik · ${_n(adet).toInt()} adet' : baslik,
              style: TextStyle(color: vurgu ? const Color(0xFFFCA5A5) : _sub, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _dagilimKart(String baslik, List liste, String adKey, num ciro) {
    final toplam = liste.fold<num>(0, (a, e) => a + _n((e as Map)['tutar']));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
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
            backgroundColor: const Color(0xFF243049),
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
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
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
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
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
          decoration: BoxDecoration(color: const Color(0xFF243049), borderRadius: BorderRadius.circular(6)),
          child: Text('${_n(u['adet']).toInt()}×', textAlign: TextAlign.center, style: TextStyle(color: _sub, fontSize: 11, fontWeight: FontWeight.bold)),
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
