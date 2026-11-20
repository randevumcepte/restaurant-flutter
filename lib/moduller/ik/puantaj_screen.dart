import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// /puantaj — Puantaj (Mesai). Web ile aynı veri:
///  • Günlük detay: gün seçici + her mesai kaydı (giriş/çıkış/süre/adım) — web'deki /api/mesai/liste
///  • Dönem özeti: bugün / bu hafta / bu ay personel başına toplam süre + kayıtlar — web /puantaj?period=
class IkPuantajScreen extends StatefulWidget {
  const IkPuantajScreen({super.key});
  @override
  State<IkPuantajScreen> createState() => _IkPuantajScreenState();
}

String _sure(dynamic dk) {
  final d = tamOku(dk);
  final s = d ~/ 60, m = d % 60;
  return s > 0 ? '$s sa $m dk' : '$m dk';
}

String _gunStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _IkPuantajScreenState extends State<IkPuantajScreen> {
  String _mod = 'detay'; // detay | gun | hafta | ay
  DateTime _gun = DateTime.now();
  int _tazele = 0;

  bool get _bugunMu {
    final b = DateTime.now();
    return _gun.year == b.year && _gun.month == b.month && _gun.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/puantaj',
      q: {'period': _mod == 'detay' ? 'gun' : _mod},
      baslik: 'Puantaj (Mesai)',
      ikon: Icons.schedule,
      govde: (c, v, yenile) {
        Future<void> hepsi() async {
          setState(() => _tazele++);
          await yenile();
        }

        return KGovde(yenile: hepsi, children: [
          KCipler(
            secenekler: const [('detay', 'Günlük detay'), ('gun', 'Bugün özet'), ('hafta', 'Bu hafta'), ('ay', 'Bu ay')],
            secili: _mod,
            onSec: (k) => setState(() => _mod = k),
          ),
          if (_mod == 'detay') ...[
            _gunSecici(c),
            _GunlukDetay(key: ValueKey('${_gunStr(_gun)}-$_tazele'), gun: _gunStr(_gun)),
          ] else
            ..._ozet(c, liste(v['personeller'])),
        ]);
      },
    );
  }

  Widget _gunSecici(BuildContext c) {
    final t = c.watch<TemaProvider>();
    return KKart(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(children: [
        IconButton(
          tooltip: 'Önceki gün',
          onPressed: () => setState(() => _gun = _gun.subtract(const Duration(days: 1))),
          icon: Icon(Icons.chevron_left, color: t.ink),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () async {
              final s = await showDatePicker(context: c, initialDate: _gun, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (s != null) setState(() => _gun = s);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _bugunMu ? 'Bugün · ${tarihYaz(_gunStr(_gun), saat: false)}' : tarihYaz(_gunStr(_gun), saat: false),
                textAlign: TextAlign.center,
                style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Sonraki gün',
          onPressed: _bugunMu ? null : () => setState(() => _gun = _gun.add(const Duration(days: 1))),
          icon: Icon(Icons.chevron_right, color: _bugunMu ? t.line : t.ink),
        ),
      ]),
    );
  }

  List<Widget> _ozet(BuildContext c, List<Map<String, dynamic>> pers) {
    final t = c.watch<TemaProvider>();
    if (pers.isEmpty) {
      return [
        KBos(
          ikon: Icons.schedule,
          baslik: 'Bu dönemde mesai kaydı yok',
          aciklama: 'Mesai, personel uygulamadan "Mesai QR" okutup giriş yapınca oluşur. QR ekranı: Ayarlar › Mesai QR. '
              'Kayıt yoksa personel henüz giriş yapmamış ya da QR kapısı kurulmamış olabilir.',
        ),
      ];
    }
    final toplamDk = pers.fold<int>(0, (a, p) => a + tamOku(p['toplam_dk']));
    final mesaide = pers.where((p) => p['acik'] == true || p['acik'] == 1).length;
    final kayit = pers.fold<int>(0, (a, p) => a + liste(p['kayitlar']).length);
    return [
      KKpiIzgara([
        KKpi(etiket: 'Personel', deger: '${pers.length}', ikon: Icons.people_outline, renk: t.mor1),
        KKpi(etiket: 'Toplam çalışma', deger: _sure(toplamDk), ikon: Icons.timer_outlined, renk: t.mavi),
        KKpi(etiket: 'Şu an mesaide', deger: '$mesaide', ikon: Icons.login, renk: t.yesil),
        KKpi(etiket: 'Mesai kaydı', deger: '$kayit', ikon: Icons.list_alt, renk: t.amber),
      ]),
      for (final p in pers)
        KKart(
          renk: (p['acik'] == true || p['acik'] == 1) ? t.yesil : t.mor1,
          onTap: () => _kayitlarAc(c, p),
          child: Row(children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: t.mor1.withValues(alpha: .15),
              child: Text(metinOku(p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(metinOku(p['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${liste(p['kayitlar']).length} kayıt · dokun, ayrıntıyı gör', style: TextStyle(color: t.sub, fontSize: 12.5)),
              ]),
            ),
            if (p['acik'] == true || p['acik'] == 1) ...[KRozet('Mesaide', renk: t.yesil), const SizedBox(width: 8)],
            Text(_sure(p['toplam_dk']), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ),
    ];
  }

  void _kayitlarAc(BuildContext c, Map<String, dynamic> p) {
    kAltSayfa(c, baslik: '${metinOku(p['ad'])} — mesai kayıtları', icerik: (cc) {
      final ks = liste(p['kayitlar']);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (ks.isEmpty) const KBos(baslik: 'Kayıt yok'),
        for (final k in ks) _MesaiKart(m: {...k, 'ad': k['tarih']}),
      ]);
    });
  }
}

/// Günlük detay: /api/mesai/liste?gun= (web puantaj sayfasının kullandığı uç)
class _GunlukDetay extends StatefulWidget {
  final String gun;
  const _GunlukDetay({super.key, required this.gun});
  @override
  State<_GunlukDetay> createState() => _GunlukDetayState();
}

class _GunlukDetayState extends State<_GunlukDetay> {
  List<Map<String, dynamic>>? _kayit;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/api/mesai/liste', q: {'gun': widget.gun});
      if (!mounted) return;
      setState(() {
        if (c.ok) {
          _kayit = liste(c.j['kayitlar']);
          _hata = null;
        } else {
          _hata = c.hata;
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) setState(() => _hata = 'Mesai listesine erişim yok.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hata != null) return KHata(_hata!, tekrar: _yukle);
    if (_kayit == null) return const Padding(padding: EdgeInsets.all(30), child: KYukleniyor());
    if (_kayit!.isEmpty) {
      return const KBos(
        ikon: Icons.event_busy,
        baslik: 'Bu gün mesai kaydı yok',
        aciklama: 'Personel bu gün "Mesai QR" ile giriş yapmamış. Mesai kaydı, personel uygulamadan dönen QR kodu okutunca oluşur.',
      );
    }
    final w = MediaQuery.of(context).size.width;
    final kartlar = [for (final m in _kayit!) _MesaiKart(m: m)];
    if (w < 900) return Column(children: kartlar);
    return Wrap(spacing: 12, children: [for (final k in kartlar) SizedBox(width: (w.clamp(0, 1180) - 70) / 2, child: k)]);
  }
}

class _MesaiKart extends StatelessWidget {
  final Map<String, dynamic> m;
  const _MesaiKart({required this.m});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final acik = metinOku(m['durum']) == 'acik';
    final tip = metinOku(m['cikis_tip']);
    final eksik = !acik && (tip == 'geofence' || tip == 'kapanis');
    final dk = tamOku(m['dakika']);
    final adim = tamOku(m['adim']);
    final hedef = dk > 0 ? (dk / 60 * 1750).round() : 0;
    final yz = hedef > 0 ? (adim / hedef * 100).round() : 0;
    final hRenk = yz >= 90 ? t.yesil : (yz >= 50 ? t.amber : t.kirmizi);
    Widget kutu(IconData ik, String deger, String et, [Color? r]) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Icon(ik, size: 18, color: t.sub),
              const SizedBox(height: 4),
              Text(deger, style: TextStyle(color: r ?? t.ink, fontSize: 15, fontWeight: FontWeight.w800)),
              Text(et, style: TextStyle(color: t.sub, fontSize: 11.5)),
            ]),
          ),
        );
    return KKart(
      renk: acik ? t.yesil : (eksik ? t.amber : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: t.mor1.withValues(alpha: .15),
            child: Text(metinOku(m['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(metinOku(m['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          if (acik) KRozet('Mesaide', renk: t.yesil) else if (eksik) KRozet('Eksik çıkış', renk: t.amber),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          kutu(Icons.login, metinOku(m['giris'], '—'), 'Giriş'),
          const SizedBox(width: 8),
          kutu(Icons.logout, acik ? '—' : metinOku(m['cikis'], '?'), 'Çıkış', acik ? t.yesil : null),
          const SizedBox(width: 8),
          kutu(Icons.timer_outlined, _sure(dk), 'Süre'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.directions_walk, size: 18, color: t.sub),
          const SizedBox(width: 6),
          Text('${sayiYaz(adim)} adım', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
          const Spacer(),
          if (hedef > 0) KRozet('hedef ~${sayiYaz(hedef)} (%$yz)', renk: hRenk),
        ]),
      ]),
    );
  }
}
