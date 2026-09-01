import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';
import '../services/api.dart';

/// Kasa (vardiya bazlı nakit çekmece):
///  - Kapalıyken: "Kasa Aç" (devir gir)
///  - Açıkken: beklenen nakit + giriş/çıkış + hareketler; Kasaya Koy / Kasadan Al; Kasa Kapat (say → fark)
/// Nakit satış/tahsilat/avans/gider OTOMATİK buraya işler (backend _kasaYaz).
class KasaScreen extends StatefulWidget {
  const KasaScreen({super.key});
  @override
  State<KasaScreen> createState() => _KasaScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _amber = Color(0xFFF59E0B);
const _gri = Color(0xFF94A3B8);

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';

class _KasaScreenState extends State<KasaScreen> {
  Map<String, dynamic>? d;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  String get _token => context.read<AuthProvider>().token!;

  Future<void> _yukle() async {
    setState(() => loading = true);
    try {
      final res = await Api.kasa(_token);
      if (!mounted) return;
      setState(() {
        d = res;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m, {Color? renk}) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: renk));
  }

  // Ortak tutar giris dialogu
  Future<double?> _tutarSor(String baslik, String etiket, {String onay = 'Tamam', Color renk = _mor1}) {
    final c = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            labelText: etiket,
            labelStyle: const TextStyle(color: _gri),
            suffixText: 'TL',
            suffixStyle: const TextStyle(color: _gri),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: renk)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: _gri))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: renk),
            onPressed: () {
              final v = double.tryParse(c.text.replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: Text(onay),
          ),
        ],
      ),
    );
  }

  Future<void> _kasaAc() async {
    final devir = await _tutarSor('Kasa Aç', 'Açılış devir (kasadaki mevcut nakit)', onay: 'Kasayı Aç', renk: _yesil);
    if (devir == null) return;
    final res = await Api.kasaAc(_token, devir);
    if (!mounted) return;
    _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '', renk: res['ok'] == 1 ? _yesil : _kirmizi);
    if (res['ok'] == 1) _yukle();
  }

  Future<void> _hareket(String yon) async {
    final tutar = await _tutarSor(
      yon == 'giris' ? 'Kasaya Koy' : 'Kasadan Al',
      yon == 'giris' ? 'Eklenecek nakit' : 'Çıkarılacak nakit',
      onay: yon == 'giris' ? 'Koy' : 'Al',
      renk: yon == 'giris' ? _yesil : _amber,
    );
    if (tutar == null || tutar <= 0) return;
    final res = await Api.kasaHareket(_token, yon: yon, tutar: tutar);
    if (!mounted) return;
    _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '', renk: res['ok'] == 1 ? _yesil : _kirmizi);
    if (res['ok'] == 1) _yukle();
  }

  Future<void> _kasaKapat() async {
    final sayilan = await _tutarSor('Kasa Kapat — Sayım', 'Sayılan nakit (fiziksel)', onay: 'Kapat & Hesapla', renk: _kirmizi);
    if (sayilan == null) return;
    final res = await Api.kasaKapat(_token, sayilan);
    if (!mounted) return;
    if (res['ok'] == 1) {
      final fark = _n(res['fark']).toDouble();
      // Fark sonucunu vurgulu goster
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _card,
          title: Row(children: [
            Icon(fark == 0 ? Icons.check_circle : Icons.error_outline, color: fark == 0 ? _yesil : (fark > 0 ? _mavi : _kirmizi)),
            const SizedBox(width: 8),
            Text(fark == 0 ? 'Kasa Tuttu' : (fark > 0 ? 'Fazla Var' : 'Açık Var'), style: const TextStyle(color: Colors.white, fontSize: 18)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _kapatSatir('Beklenen', _tl(res['beklenen'])),
            _kapatSatir('Sayılan', _tl(res['sayilan'])),
            const Divider(color: Color(0xFF2D3752)),
            _kapatSatir('Fark', '${fark > 0 ? '+' : ''}${_tl(fark)}', renk: fark == 0 ? _yesil : (fark > 0 ? _mavi : _kirmizi), kalin: true),
          ]),
          actions: [FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1), onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
        ),
      );
      _yukle();
    } else {
      _uyar(res['hata']?.toString() ?? 'Kapatılamadı', renk: _kirmizi);
    }
  }

  Widget _kapatSatir(String e, String v, {Color renk = Colors.white, bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(e, style: const TextStyle(color: _gri, fontSize: 14)),
          Text(v, style: TextStyle(color: renk, fontSize: kalin ? 18 : 15, fontWeight: kalin ? FontWeight.bold : FontWeight.w600)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final acik = d?['acik'] == true;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Kasa', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: _gri))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: _mor1,
              backgroundColor: _card,
              child: acik ? _acikGorunum() : _kapaliGorunum(),
            ),
    );
  }

  // ---- KASA KAPALI: Aç ----
  Widget _kapaliGorunum() {
    final sonDevir = _n(d?['son_devir']).toDouble();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 60),
        const Icon(Icons.point_of_sale, size: 64, color: Color(0xFF334155)),
        const SizedBox(height: 16),
        const Center(child: Text('Kasa kapalı', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
        const SizedBox(height: 6),
        const Center(child: Text('Vardiyayı başlatmak için kasayı açın.\nAçılış devir = şu an çekmecedeki nakit.', textAlign: TextAlign.center, style: TextStyle(color: _gri, fontSize: 13))),
        if (sonDevir > 0) ...[
          const SizedBox(height: 10),
          Center(child: Text('Son kapanış: ${_tl(sonDevir)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: _kasaAc,
          icon: const Icon(Icons.lock_open, color: Colors.white),
          label: const Text('Kasa Aç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  // ---- KASA AÇIK ----
  Widget _acikGorunum() {
    final beklenen = _n(d?['beklenen']).toDouble();
    final devir = _n(d?['devir']).toDouble();
    final giris = _n(d?['giris']).toDouble();
    final cikis = _n(d?['cikis']).toDouble();
    final hareketler = (d?['hareketler'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Beklenen nakit — büyük kart
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('Kasada Beklenen Nakit', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('Açık · ${d?['acilis'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ]),
            const SizedBox(height: 6),
            Text(_tl(beklenen), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Açan: ${d?['acan'] ?? '-'}  ·  Devir ${_tl(devir)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        // Giriş / Çıkış özet
        Row(children: [
          Expanded(child: _ozetMini('Giriş (+)', giris, _yesil, Icons.south_west)),
          const SizedBox(width: 10),
          Expanded(child: _ozetMini('Çıkış (−)', cikis, _kirmizi, Icons.north_east)),
        ]),
        const SizedBox(height: 12),
        // Aksiyonlar
        Row(children: [
          Expanded(child: _btn('Kasaya Koy', Icons.add, _yesil, () => _hareket('giris'))),
          const SizedBox(width: 10),
          Expanded(child: _btn('Kasadan Al', Icons.remove, _amber, () => _hareket('cikis'))),
        ]),
        const SizedBox(height: 10),
        _btn('Kasa Kapat (Say)', Icons.lock_outline, _kirmizi, _kasaKapat, dolu: true),
        const SizedBox(height: 18),
        const Text('Hareketler', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (hareketler.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: Text('Henüz hareket yok.', style: TextStyle(color: _gri))))
        else
          for (final h in hareketler) _hareketSatir(h as Map),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _ozetMini(String baslik, double v, Color renk, IconData ic) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF243049))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(ic, size: 14, color: renk), const SizedBox(width: 5), Text(baslik, style: const TextStyle(color: _gri, fontSize: 12))]),
          const SizedBox(height: 6),
          Text(_tl(v), style: TextStyle(color: renk, fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _btn(String label, IconData ic, Color renk, VoidCallback onTap, {bool dolu = false}) => SizedBox(
        height: 48,
        child: dolu
            ? FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: renk),
                onPressed: onTap,
                icon: Icon(ic, color: Colors.white, size: 19),
                label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
            : OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: renk, side: BorderSide(color: renk.withValues(alpha: 0.6)), backgroundColor: renk.withValues(alpha: 0.08)),
                onPressed: onTap,
                icon: Icon(ic, size: 19),
                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
      );

  Widget _hareketSatir(Map h) {
    final giris = h['yon'] == 'giris';
    final renk = giris ? _yesil : _kirmizi;
    const etiket = {'devir': 'Devir', 'satis': 'Nakit Satış', 'tahsilat': 'Tahsilat', 'gider': 'Gider', 'personel': 'Personel', 'al': 'Kasadan Al', 'koy': 'Kasaya Koy'};
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF243049))),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(9)),
          child: Icon(giris ? Icons.south_west : Icons.north_east, size: 17, color: renk),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiket[h['tip']] ?? h['tip'].toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${h['aciklama'] ?? ''}${h['personel'] != null ? ' · ${h['personel']}' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _gri, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${giris ? '+' : '−'}${_tl(h['tutar'])}', style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.bold)),
          Text(h['zaman']?.toString() ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
        ]),
      ]),
    );
  }

  // ==================== MASAÜSTÜ (PC/tablet) ====================
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final acik = d?['acik'] == true;
    return MasaustuSayfa(
      baslik: 'Kasa (Vardiya)',
      ikon: Icons.point_of_sale,
      altBaslik: acik ? 'Açık · ${d?['acilis'] ?? ''}' : 'Kapalı',
      araclar: [
        if (!loading && acik) ...[
          MButon('Kasaya Koy', t.yesil, () => _hareket('giris'), dolu: false, ikon: Icons.add),
          const SizedBox(width: 8),
          MButon('Kasadan Al', t.amber, () => _hareket('cikis'), dolu: false, ikon: Icons.remove),
          const SizedBox(width: 8),
          MButon('Kasa Kapat (Say)', t.kirmizi, _kasaKapat, ikon: Icons.lock_outline),
          const SizedBox(width: 8),
        ] else if (!loading) ...[
          MButon('Kasa Aç', t.yesil, _kasaAc, ikon: Icons.lock_open),
          const SizedBox(width: 8),
        ],
        IconButton(onPressed: _yukle, icon: Icon(Icons.refresh, color: t.sub2, size: 22), tooltip: 'Yenile'),
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : (acik ? _masaustuAcik(t) : _masaustuKapali(t)),
    );
  }

  Widget _masaustuKapali(TemaProvider t) {
    final sonDevir = _n(d?['son_devir']).toDouble();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: MKart(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.point_of_sale, size: 64, color: t.line),
            const SizedBox(height: 16),
            Text('Kasa kapalı', style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Vardiyayı başlatmak için kasayı açın.\nAçılış devir = şu an çekmecedeki nakit.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.sub, fontSize: 13),
            ),
            if (sonDevir > 0) ...[
              const SizedBox(height: 10),
              Text('Son kapanış: ${_tl(sonDevir)}', style: TextStyle(color: t.sub2, fontSize: 12)),
            ],
            const SizedBox(height: 24),
            SizedBox(width: 220, child: MButon('Kasa Aç', t.yesil, _kasaAc, ikon: Icons.lock_open)),
          ]),
        ),
      ),
    );
  }

  Widget _masaustuAcik(TemaProvider t) {
    final beklenen = _n(d?['beklenen']).toDouble();
    final devir = _n(d?['devir']).toDouble();
    final giris = _n(d?['giris']).toDouble();
    final cikis = _n(d?['cikis']).toDouble();
    final hareketler = (d?['hareketler'] as List?) ?? [];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Üst özet — 3 istatistik kartı
        LayoutBuilder(builder: (ctx, kis) {
          final genis = kis.maxWidth >= 720;
          final beklenenKart = MIstatKart(
            baslik: 'Kasada Beklenen Nakit',
            renk: t.mor1,
            buyukDeger: _tl(beklenen),
            satirlar: [
              MIstatSatir('Açan', (d?['acan'] ?? '-').toString()),
              MIstatSatir('Açılış devir', _tl(devir)),
            ],
          );
          final girisKart = MIstatKart(
            baslik: 'Giriş (+)',
            renk: t.yesil,
            buyukDeger: _tl(giris),
            satirlar: [MIstatSatir('Devir dahil kasaya eklenen', '', renk: t.sub)],
          );
          final cikisKart = MIstatKart(
            baslik: 'Çıkış (−)',
            renk: t.kirmizi,
            buyukDeger: _tl(cikis),
            satirlar: [MIstatSatir('Kasadan alınan', '', renk: t.sub)],
          );
          if (genis) {
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 12, child: beklenenKart),
              const SizedBox(width: 14),
              Expanded(flex: 9, child: girisKart),
              const SizedBox(width: 14),
              Expanded(flex: 9, child: cikisKart),
            ]);
          }
          return Column(children: [
            beklenenKart,
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: girisKart),
              const SizedBox(width: 14),
              Expanded(child: cikisKart),
            ]),
          ]);
        }),
        const SizedBox(height: 22),
        MBolumBaslik('Hareketler', renk: t.mor1, sayi: hareketler.length),
        const SizedBox(height: 4),
        if (hareketler.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(child: Text('Henüz hareket yok.', style: TextStyle(color: t.sub))),
          )
        else
          _masaustuTablo(t, hareketler),
      ],
    );
  }

  Widget _masaustuTablo(TemaProvider t, List hareketler) {
    const etiket = {'devir': 'Devir', 'satis': 'Nakit Satış', 'tahsilat': 'Tahsilat', 'gider': 'Gider', 'personel': 'Personel', 'al': 'Kasadan Al', 'koy': 'Kasaya Koy'};
    return MTablo(
      sutunlar: const [
        MSutun('Tip', flex: 14),
        MSutun('Açıklama', flex: 22),
        MSutun('Yön', flex: 10, hiza: TextAlign.center),
        MSutun('Tutar', flex: 12, hiza: TextAlign.right),
        MSutun('Zaman', flex: 12, hiza: TextAlign.right),
      ],
      satirlar: [
        for (final raw in hareketler)
          () {
            final h = raw as Map;
            final girisMi = h['yon'] == 'giris';
            final renk = girisMi ? t.yesil : t.kirmizi;
            return <Widget>[
              Text(etiket[h['tip']] ?? h['tip'].toString(), style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
              Text(
                '${h['aciklama'] ?? ''}${h['personel'] != null ? ' · ${h['personel']}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.sub, fontSize: 12),
              ),
              MRozet(girisMi ? 'Giriş' : 'Çıkış', renk, ikon: girisMi ? Icons.south_west : Icons.north_east),
              Text('${girisMi ? '+' : '−'}${_tl(h['tutar'])}', style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(h['zaman']?.toString() ?? '', style: TextStyle(color: t.sub2, fontSize: 12)),
            ];
          }(),
      ],
    );
  }
}
