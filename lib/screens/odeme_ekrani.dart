import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../services/yazici_servisi.dart';
import 'cari_hesaplar_screen.dart';

/// KASA ÖDEME EKRANI (POS) — büyük tutar + rakam tuş takımı + bölünmüş/kısmi ödeme
/// (nakit+kart karışık) + nakitte para üstü + ödeme bitince otomatik fiş & çekmece.
/// Her ödeme backend'de islem='ode' ile işlenir; kalan 0'a inince adisyon oto kapanır.
class OdemeEkrani extends StatefulWidget {
  final int adisyonId;
  const OdemeEkrani({super.key, required this.adisyonId});
  @override
  State<OdemeEkrani> createState() => _OdemeEkraniState();
}

class _OdemeEkraniState extends State<OdemeEkrani> {
  final _f = NumberFormat.decimalPattern('tr');
  Map? fis;             // Api.fis çıktısı (toplam + kalemler → fiş basımı)
  double toplam = 0;
  double kalan = 0;
  double odenen = 0;
  String giris = '';    // tuş takımından girilen tutar
  final List<Map<String, dynamic>> alinanlar = []; // {tip, tutar}
  bool loading = true;
  bool mesgul = false;

  static const _yesil = Color(0xFF10B981);
  static const _mavi = Color(0xFF3B82F6);
  static const _turuncu = Color(0xFFF59E0B);
  static const _mor = Color(0xFF7C3AED);
  static const _kirmizi = Color(0xFFF43F5E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? '${_f.format(d.round())} TL' : '${_f.format(d)} TL';
  }

  double get _girilen => double.tryParse(giris) ?? 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.fis(auth.token!, widget.adisyonId);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          fis = res;
          toplam = _n(res['toplam']).toDouble();
          kalan = toplam;
          loading = false;
        });
      } else {
        setState(() => loading = false);
        _snack(res['hata']?.toString() ?? 'Adisyon alınamadı', _kirmizi);
      }
    } catch (_) {
      if (mounted) { setState(() => loading = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, duration: const Duration(seconds: 2)));
  }

  void _bas(String d) {
    setState(() {
      if (d == '.' && giris.contains('.')) return;
      if (giris.length > 9) return;
      giris += d;
    });
  }

  void _sil() => setState(() { if (giris.isNotEmpty) giris = giris.substring(0, giris.length - 1); });
  void _temizle() => setState(() => giris = '');
  void _kalaniYaz() => setState(() => giris = kalan == kalan.roundToDouble() ? kalan.round().toString() : kalan.toStringAsFixed(2));

  Future<void> _ode(String tip, Color renk) async {
    if (mesgul || kalan <= 0) return;
    // Tutar girilmediyse: kalanın tamamı
    final istenen = giris.isEmpty ? kalan : _girilen;
    if (istenen <= 0) { _snack('Tutar girin', _kirmizi); return; }
    final uygulanan = istenen > kalan ? kalan : istenen;
    final paraUstu = (tip == 'nakit' && istenen > kalan) ? (istenen - kalan) : 0.0;

    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: 'ode', adisyonId: widget.adisyonId, odemeTip: tip, tutar: uygulanan);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          alinanlar.add({'tip': tip, 'tutar': uygulanan, 'renk': renk});
          odenen += uygulanan;
          kalan = _n(res['kalan']).toDouble();
          giris = '';
          mesgul = false;
        });
        if (res['kapandi'] == true) {
          await _bitir(paraUstu);
        } else if (paraUstu > 0) {
          _snack('Para üstü: ${_tl(paraUstu)}', _turuncu);
        }
      } else {
        setState(() => mesgul = false);
        _snack(res['hata']?.toString() ?? 'Ödeme alınamadı', _kirmizi);
      }
    } catch (_) {
      if (mounted) { setState(() => mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  Future<void> _acikHesap() async {
    if (mesgul || kalan <= 0) return;
    final cari = await Navigator.of(context).push<Map>(MaterialPageRoute(builder: (_) => const CariHesaplarScreen(secmeMod: true)));
    if (cari == null || !mounted) return;
    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: 'kapat', adisyonId: widget.adisyonId, odemeTip: 'acik_hesap', cariId: _n(cari['id']).toInt());
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { kalan = 0; mesgul = false; });
        await _bitir(0);
      } else {
        setState(() => mesgul = false);
        _snack(res['hata']?.toString() ?? 'İşlem başarısız', _kirmizi);
      }
    } catch (_) {
      if (mounted) { setState(() => mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  // Ödeme tamam: fiş bas (yazıcı ayarlıysa) + çekmece (hesapFisi içinde) + kapanış ekranı.
  Future<void> _bitir(double paraUstu) async {
    String? yaziciNot;
    try {
      final y = YaziciServisi();
      await y.yukle();
      if (y.ayarli && fis != null) {
        final s = await y.hesapFisi(fis!);
        if (s != 'ok') yaziciNot = s;
      }
    } catch (_) {}
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: _yesil.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: _yesil, size: 40)),
            const SizedBox(height: 14),
            Text('Ödeme Tamamlandı', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Masa kapatıldı.', style: TextStyle(color: t.sub, fontSize: 13)),
            if (paraUstu > 0) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12), border: Border.all(color: _turuncu.withValues(alpha: 0.4))),
                child: Column(children: [
                  Text('PARA ÜSTÜ', style: TextStyle(color: _turuncu, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  const SizedBox(height: 2),
                  Text(_tl(paraUstu), style: const TextStyle(color: _turuncu, fontSize: 28, fontWeight: FontWeight.bold)),
                ]),
              ),
            ],
            if (yaziciNot != null) ...[
              const SizedBox(height: 12),
              Text('Fiş basılamadı: $yaziciNot', textAlign: TextAlign.center, style: TextStyle(color: _kirmizi, fontSize: 11.5)),
            ],
          ]),
          actions: [
            SizedBox(width: double.infinity, child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Tamam', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ],
        );
      },
    );
    if (mounted) Navigator.of(context).pop(true); // detay'a "kapandı" sinyali
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Ödeme', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : SafeArea(child: Column(children: [
              _ozet(t),
              _girisAlani(t),
              if (alinanlar.isNotEmpty) _alinanlarSerit(t),
              const Spacer(),
              _tusTakimi(t),
              _yontemler(t),
              const SizedBox(height: 8),
            ])),
    );
  }

  Widget _ozet(TemaProvider t) => Container(
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 0), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Toplam', style: TextStyle(color: t.sub, fontSize: 12)),
            Text(_tl(toplam), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w600)),
            if (odenen > 0) ...[
              const SizedBox(height: 2),
              Text('Ödenen ${_tl(odenen)}', style: const TextStyle(color: _yesil, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('KALAN', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
            Text(_tl(kalan), style: TextStyle(color: kalan <= 0 ? _yesil : t.mor1, fontSize: 30, fontWeight: FontWeight.bold)),
          ]),
        ]),
      );

  Widget _girisAlani(TemaProvider t) => Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          GestureDetector(
            onTap: _kalaniYaz,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8), border: Border.all(color: t.mor1.withValues(alpha: 0.35))),
              child: Text('Kalanı Yaz', style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
          const Spacer(),
          Text(giris.isEmpty ? _tl(kalan) : '${_f.format(_girilen)} TL',
              style: TextStyle(color: giris.isEmpty ? t.sub : t.ink, fontSize: 26, fontWeight: FontWeight.bold)),
          if (giris.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(onTap: _temizle, child: Icon(Icons.close, color: t.sub, size: 20)),
          ],
        ]),
      );

  Widget _alinanlarSerit(TemaProvider t) => Container(
        margin: const EdgeInsets.fromLTRB(14, 10, 14, 0), height: 34,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final a in alinanlar)
            Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: (a['renk'] as Color).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20), border: Border.all(color: (a['renk'] as Color).withValues(alpha: 0.4))),
              child: Row(children: [
                Icon(Icons.check, size: 13, color: a['renk'] as Color),
                const SizedBox(width: 4),
                Text('${_yontemAd(a['tip'] as String)} ${_tl(a['tutar'] as num)}', style: TextStyle(color: a['renk'] as Color, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
      );

  String _yontemAd(String tip) => {'nakit': 'Nakit', 'kredi': 'Kart', 'yemek_karti': 'Yemek K.', 'acik_hesap': 'Açık H.'}[tip] ?? tip;

  Widget _tusTakimi(TemaProvider t) {
    Widget tus(String d, {IconData? ikon, VoidCallback? onTap, Color? renk}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Material(
              color: renk ?? t.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap ?? () => _bas(d),
                child: Container(
                  height: 52, alignment: Alignment.center,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                  child: ikon != null
                      ? Icon(ikon, color: t.ink, size: 22)
                      : Text(d, style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(children: [
        Row(children: [tus('1'), tus('2'), tus('3')]),
        Row(children: [tus('4'), tus('5'), tus('6')]),
        Row(children: [tus('7'), tus('8'), tus('9')]),
        Row(children: [tus('.'), tus('0'), tus('', ikon: Icons.backspace_outlined, onTap: _sil)]),
      ]),
    );
  }

  Widget _yontemler(TemaProvider t) {
    Widget btn(String tip, String ad, IconData ikon, Color renk, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Opacity(
              opacity: mesgul || kalan <= 0 ? 0.5 : 1,
              child: Material(
                color: renk, borderRadius: BorderRadius.circular(13),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: mesgul || kalan <= 0 ? null : onTap,
                  child: Container(
                    height: 60, alignment: Alignment.center,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(ikon, color: Colors.white, size: 22),
                      const SizedBox(height: 3),
                      Text(ad, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 9),
      child: Column(children: [
        Row(children: [
          btn('nakit', 'Nakit', Icons.payments_outlined, _yesil, () => _ode('nakit', _yesil)),
          btn('kredi', 'Kredi Kartı', Icons.credit_card, _mavi, () => _ode('kredi', _mavi)),
        ]),
        Row(children: [
          btn('yemek_karti', 'Yemek Kartı', Icons.restaurant, _turuncu, () => _ode('yemek_karti', _turuncu)),
          btn('acik_hesap', 'Açık Hesap', Icons.receipt_long, _mor, _acikHesap),
        ]),
      ]),
    );
  }
}
