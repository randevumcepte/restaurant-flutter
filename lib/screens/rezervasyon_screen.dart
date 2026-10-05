import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Online masa rezervasyonu — gün seçici + günlük özet + rezervasyon kartları
/// (onayla/geldi/gelmedi/iptal) + yeni rezervasyon ekleme.
class RezervasyonScreen extends StatefulWidget {
  const RezervasyonScreen({super.key});
  @override
  State<RezervasyonScreen> createState() => _RezervasyonScreenState();
}

class _RezervasyonScreenState extends State<RezervasyonScreen> {
  Map<String, dynamic>? data;
  Map<String, dynamic>? _panel; // analitik gosterge paneli verisi
  String _gorunum = 'panel';    // 'panel' | 'liste'
  bool loading = true;
  String tarih = '';

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor = Color(0xFF9D5DC8);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String get _token => context.read<AuthProvider>().token!;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({String? t}) async {
    setState(() => loading = true);
    try {
      final tt = t ?? (tarih.isEmpty ? null : tarih);
      final res = await Api.rezervasyonlar(_token, tarih: tt);
      Map<String, dynamic>? panel;
      try {
        panel = await Api.rezervasyonPanel(_token, tarih: tt);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        data = res;
        if (panel != null && panel['ok'] == 1) _panel = panel;
        tarih = res['tarih']?.toString() ?? tarih;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  // Tarihi gun bazinda kaydir (panel ok navigasyonu)
  void _kaydir(int d) {
    final base = DateTime.tryParse(tarih) ?? DateTime.now();
    final n = base.add(Duration(days: d));
    final iso = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    setState(() => tarih = iso);
    _yukle(t: iso);
  }

  static const _ayAd = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  String _tarihUzun(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day} ${_ayAd[d.month]} ${d.year}, ${_gunAd[d.weekday - 1]}';
  }

  String _yzStr(dynamic v) {
    final n = _n(v);
    final s = n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(1);
    return s.replaceAll('.', ',');
  }

  Future<void> _durum(int id, String durum) async {
    try {
      await Api.rezervasyonDurum(_token, id, durum);
      _yukle();
    } catch (_) {}
  }

  // ---- durum stili ----
  Color _renk(String d) => {
        'bekliyor': _amber, 'onaylandi': _mavi, 'geldi': _yesil, 'iptal': const Color(0xFF64748B), 'gelmedi': _kirmizi,
      }[d] ?? _mor;
  String _durumAd(String d) => {
        'bekliyor': 'BEKLİYOR', 'onaylandi': 'ONAYLI', 'geldi': 'GELDİ', 'iptal': 'İPTAL', 'gelmedi': 'GELMEDİ',
      }[d] ?? d.toUpperCase();
  String _kaynakIkon(String k) => {'web': '🌐', 'telefon': '📞', 'qr': '📱', 'walk_in': '🚶', 'walkin': '🚶', 'admin': '🖥️'}[k] ?? '•';

  // ---- gün etiketi ----
  static const _gunAd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  String _gunKisa(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final bugun = DateTime.now();
    final fark = DateTime(d.year, d.month, d.day).difference(DateTime(bugun.year, bugun.month, bugun.day)).inDays;
    if (fark == 0) return 'Bugün';
    if (fark == 1) return 'Yarın';
    return _gunAd[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final t = context.watch<TemaProvider>();
    final rezervasyonlar = (data?['rezervasyonlar'] as List?) ?? [];
    final ozet = (data?['ozet'] as Map?) ?? {};
    final gunler = (data?['gunler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        title: const Text('Rezervasyonlar', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _yukle(), icon: const Icon(Icons.refresh)), const MenuHamburger()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _mor,
        onPressed: _ekleDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Rezervasyon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading && data == null
          ? const Center(child: CircularProgressIndicator(color: _mor))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Align(alignment: Alignment.centerLeft, child: _segment(t)),
              ),
              Expanded(
                child: _gorunum == 'panel'
                    ? RefreshIndicator(
                        onRefresh: () => _yukle(), color: _mor, backgroundColor: _card,
                        child: _panelGovde(t, genis: false),
                      )
                    : Column(children: [
                        // Gün seçici (7 gün)
                        SizedBox(
                          height: 74,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                            children: [for (final g in gunler) _gunPill(g as Map)],
                          ),
                        ),
                        // Özet
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                          child: Row(children: [
                            _ozetChip('Bekleyen', _n(ozet['bekleyen']).toInt(), _amber),
                            const SizedBox(width: 8),
                            _ozetChip('Onaylı', _n(ozet['onayli']).toInt(), _mavi),
                            const SizedBox(width: 8),
                            _ozetChip('Geldi', _n(ozet['geldi']).toInt(), _yesil),
                            const SizedBox(width: 8),
                            _ozetChip('Kişi', _n(ozet['kisi']).toInt(), _mor),
                          ]),
                        ),
                        Expanded(
                          child: rezervasyonlar.isEmpty
                              ? _bos()
                              : RefreshIndicator(
                                  onRefresh: () => _yukle(),
                                  color: _mor, backgroundColor: _card,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                                    itemCount: rezervasyonlar.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                                    itemBuilder: (_, i) => _kart(rezervasyonlar[i] as Map),
                                  ),
                                ),
                        ),
                      ]),
              ),
            ]),
    );
  }

  // ================= MASAÜSTÜ (gece/gündüz) =================
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final rezervasyonlar = (data?['rezervasyonlar'] as List?) ?? [];
    final ozet = (data?['ozet'] as Map?) ?? {};
    final gunler = (data?['gunler'] as List?) ?? [];
    return MasaustuSayfa(
      baslik: 'Rezervasyonlar',
      ikon: Icons.event_available_outlined,
      altBaslik: tarih.isEmpty ? null : tarih,
      araclar: [
        _segment(t),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () => _yukle(),
          icon: Icon(Icons.refresh, color: t.sub2, size: 22),
          tooltip: 'Yenile',
        ),
        const SizedBox(width: 4),
        MButon('Yeni Rezervasyon', t.mor1, _ekleDialog, ikon: Icons.add),
      ],
      govde: (loading && data == null)
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : (_gorunum == 'panel'
              ? _panelGovde(t, genis: true)
              : ListView(padding: const EdgeInsets.all(24), children: [
                  _mGunSecici(t, gunler),
                  const SizedBox(height: 18),
                  _mOzet(t, ozet),
                  const SizedBox(height: 22),
                  MBolumBaslik('Rezervasyonlar', renk: t.mor1, sayi: rezervasyonlar.length),
                  if (rezervasyonlar.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(child: Text('Bu gün için rezervasyon yok.', style: TextStyle(color: t.sub))),
                    )
                  else
                    _mTablo(t, rezervasyonlar),
                ])),
    );
  }

  // ================= ANALİTİK PANEL (gösterge paneli) =================
  Widget _segment(TemaProvider t) {
    Widget seg(String key, String label, IconData ik) {
      final aktif = _gorunum == key;
      return GestureDetector(
        onTap: () => setState(() => _gorunum = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: aktif ? t.mor1 : Colors.transparent, borderRadius: BorderRadius.circular(9)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ik, size: 15, color: aktif ? Colors.white : t.sub),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: aktif ? Colors.white : t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('panel', 'Panel', Icons.donut_large),
        seg('liste', 'Liste', Icons.list_alt),
      ]),
    );
  }

  Widget _panelGovde(TemaProvider t, {required bool genis}) {
    final pg = (_panel?['gun'] as Map?) ?? {};
    final durum = (_panel?['durum_dagilim'] as List?) ?? [];
    final saat = (_panel?['saat_dagilim'] as List?) ?? [];
    final kaynak = (_panel?['kaynak_dagilim'] as List?) ?? [];
    final aylik = (_panel?['aylik'] as Map?) ?? {};
    final perf = (_panel?['performans'] as Map?) ?? {};
    final ayAdi = _panel?['ay_adi']?.toString() ?? '';
    final toplamGun = _n(pg['toplam']).toInt();
    final misafir = _n(pg['toplam_misafir']).toInt();
    // Ekstra bilgiler (mockup'ta yok): ortalama kisi + en yogun saat
    final ortKisi = toplamGun > 0 ? (misafir / toplamGun) : 0.0;
    String enYogunSaat = '—';
    int enYogunAdet = 0;
    for (final s in saat) {
      final a = _n((s as Map)['adet']).toInt();
      if (a > enYogunAdet) {
        enYogunAdet = a;
        enYogunSaat = '${s['saat']}:00';
      }
    }

    final statlar = [
      _pStat(t, Icons.event_note, 'Bugünün Rezervasyonları', '$toplamGun', t.mor1),
      _pStat(t, Icons.hourglass_bottom, 'Bekleyen', '${_n(pg['bekleyen']).toInt()}', t.amber),
      _pStat(t, Icons.check_circle_outline, 'Onaylanan', '${_n(pg['onaylanan']).toInt()}', t.yesil),
      _pStat(t, Icons.groups, 'Toplam Misafir', '$misafir', t.mavi),
      _pStat(t, Icons.person_outline, 'Ort. Kişi / Rez.', ortKisi == 0 ? '0' : ortKisi.toStringAsFixed(1).replaceAll('.', ','), const Color(0xFFEC4899)),
      _pStat(t, Icons.local_fire_department_outlined, 'En Yoğun Saat', enYogunSaat, const Color(0xFFFB7185)),
    ];

    return ListView(padding: EdgeInsets.all(genis ? 24 : 12), children: [
      // Tarih navigasyonu
      Row(children: [
        _okBtn(t, Icons.chevron_left, () => _kaydir(-1)),
        const SizedBox(width: 4),
        Text(_tarihUzun(tarih), style: TextStyle(color: t.ink, fontSize: genis ? 15 : 13.5, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        _okBtn(t, Icons.chevron_right, () => _kaydir(1)),
      ]),
      SizedBox(height: genis ? 16 : 12),
      // 6 stat kart (mockup'ta 4; ekstra 2 kart + masaustunde 3+3 duzen)
      if (genis) ...[
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: statlar[0]), const SizedBox(width: 14),
          Expanded(child: statlar[1]), const SizedBox(width: 14),
          Expanded(child: statlar[2]),
        ])),
        const SizedBox(height: 14),
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: statlar[3]), const SizedBox(width: 14),
          Expanded(child: statlar[4]), const SizedBox(width: 14),
          Expanded(child: statlar[5]),
        ])),
      ] else
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.55, mainAxisSpacing: 10, crossAxisSpacing: 10, children: statlar,
        ),
      SizedBox(height: genis ? 16 : 12),
      // Saat Dagilimi — tam genislik (mockup'ta orta kolondaydi)
      _pSaatKart(t, saat),
      SizedBox(height: genis ? 16 : 12),
      // Durum + Kaynak (mockup'ta 3'lu satirdaydi -> 2'li)
      if (genis)
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: _pDurumKart(t, durum, toplamGun)),
          const SizedBox(width: 14),
          Expanded(child: _pKaynakKart(t, kaynak)),
        ]))
      else ...[
        _pDurumKart(t, durum, toplamGun),
        const SizedBox(height: 12),
        _pKaynakKart(t, kaynak),
      ],
      SizedBox(height: genis ? 16 : 12),
      // Performans + Aylık özet (mockup'un TERSI: Performans solda)
      if (genis)
        IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: _pPerformansKart(t, perf)),
          const SizedBox(width: 14),
          Expanded(flex: 3, child: _pAylikKart(t, aylik, ayAdi)),
        ]))
      else ...[
        _pPerformansKart(t, perf),
        const SizedBox(height: 12),
        _pAylikKart(t, aylik, ayAdi),
      ],
      const SizedBox(height: 24),
    ]);
  }

  Widget _okBtn(TemaProvider t, IconData ik, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: t.line)),
          child: Icon(ik, size: 18, color: t.sub2),
        ),
      );

  Widget _pKartKutu(TemaProvider t, IconData ik, String baslik, Color renk, Widget govde, {Widget? sag}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)), child: Icon(ik, size: 16, color: renk)),
          const SizedBox(width: 8),
          Expanded(child: Text(baslik, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          ?sag,
        ]),
        const SizedBox(height: 14),
        govde,
      ]),
    );
  }

  Widget _pStat(TemaProvider t, IconData ik, String etiket, String deger, Color renk) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)), child: Icon(ik, size: 17, color: renk)),
          const SizedBox(width: 8),
          Expanded(child: Text(etiket, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
            child: Text(deger, style: TextStyle(color: renk, fontSize: 30, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Color _durumRenk(TemaProvider t, String d) => {
        'bekliyor': t.amber, 'onaylandi': t.mavi, 'geldi': t.yesil, 'gelmedi': t.kirmizi, 'iptal': const Color(0xFF64748B),
      }[d] ?? t.mor1;

  Widget _pDurumKart(TemaProvider t, List durum, int toplam) {
    return _pKartKutu(t, Icons.donut_large, 'Durum Dağılımı', t.mor1, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(height: 10, child: Row(children: [
          if (toplam == 0)
            Expanded(child: Container(color: t.card2))
          else
            for (final d in durum)
              if (_n((d as Map)['adet']).toInt() > 0)
                Expanded(flex: _n(d['adet']).toInt(), child: Container(color: _durumRenk(t, d['durum'].toString()))),
        ])),
      ),
      const SizedBox(height: 14),
      for (final d in durum) _pDurumSatir(t, d as Map),
      Divider(color: t.line, height: 22),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Toplam', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
        Text('$toplam', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    ]));
  }

  Widget _pDurumSatir(TemaProvider t, Map d) {
    final renk = _durumRenk(t, d['durum'].toString());
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(d['ad'].toString(), style: TextStyle(color: t.sub2, fontSize: 12.5))),
        Text('%${_yzStr(d['yuzde'])}', style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(width: 12),
        SizedBox(width: 22, child: Text('${_n(d['adet']).toInt()}', textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _pSaatKart(TemaProvider t, List saat) {
    final maks = saat.fold<int>(1, (a, e) => _n((e as Map)['adet']).toInt() > a ? _n(e['adet']).toInt() : a);
    return _pKartKutu(t, Icons.schedule, 'Saat Dağılımı', const Color(0xFFFB7185), Column(children: [
      SizedBox(
        height: 120,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final s in saat)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(
                    height: ((_n((s as Map)['adet']).toInt() / maks) * 104).clamp(3.0, 104.0),
                    decoration: BoxDecoration(
                      color: _n(s['adet']).toInt() > 0 ? const Color(0xFFFB7185) : t.card2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${saat.isNotEmpty ? (saat.first as Map)['saat'] : '10'}:00', style: TextStyle(color: t.sub, fontSize: 10)),
        Text('${saat.isNotEmpty ? (saat.last as Map)['saat'] : '23'}:00', style: TextStyle(color: t.sub, fontSize: 10)),
      ]),
    ]));
  }

  Widget _pKaynakKart(TemaProvider t, List kaynak) {
    final renkler = [t.mavi, t.yesil, t.amber, t.kirmizi, t.mor1];
    final maks = kaynak.fold<int>(1, (a, e) => _n((e as Map)['adet']).toInt() > a ? _n(e['adet']).toInt() : a);
    return _pKartKutu(t, Icons.layers_outlined, 'Kaynak Dağılımı', t.mavi, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (kaynak.isEmpty)
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('Kayıt yok', style: TextStyle(color: t.sub, fontSize: 12)))
      else
        for (int i = 0; i < kaynak.length; i++) _pKaynakSatir(t, kaynak[i] as Map, renkler[i % renkler.length], maks),
    ]));
  }

  Widget _pKaynakSatir(TemaProvider t, Map k, Color renk, int maks) {
    final adet = _n(k['adet']).toInt();
    final oran = maks > 0 ? (adet / maks).clamp(0.0, 1.0).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(k['ad'].toString(), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600))),
          Text('$adet  (%${_n(k['yuzde']).toInt()})', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(value: oran, minHeight: 7, backgroundColor: t.card2, valueColor: AlwaysStoppedAnimation(renk)),
        ),
      ]),
    );
  }

  Widget _pAylikKart(TemaProvider t, Map aylik, String ayAdi) {
    final gunler = (aylik['gunler'] as List?) ?? [];
    final ilkGun = _n(aylik['ilk_gun_hafta']).toInt().clamp(1, 7);
    final maks = gunler.fold<int>(1, (a, e) => _n((e as Map)['adet']).toInt() > a ? _n(e['adet']).toInt() : a);
    const haftaAd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final hucreler = <Widget>[for (final h in haftaAd) Center(child: Text(h, style: TextStyle(color: t.sub, fontSize: 10, fontWeight: FontWeight.w600)))];
    for (int i = 1; i < ilkGun; i++) {
      hucreler.add(const SizedBox());
    }
    for (final g in gunler) {
      hucreler.add(_pAyGun(t, g as Map, maks));
    }
    return _pKartKutu(t, Icons.calendar_month, 'Aylık Özet', t.mor1,
      GridView.count(
        crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 5, crossAxisSpacing: 5, childAspectRatio: 1.1, children: hucreler,
      ),
      sag: Text(ayAdi, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600)));
  }

  Widget _pAyGun(TemaProvider t, Map g, int maks) {
    final adet = _n(g['adet']).toInt();
    final gt = g['tarih'].toString();
    final secili = gt == tarih;
    final yog = maks > 0 ? adet / maks : 0.0;
    final bg = adet == 0 ? t.card2 : Color.lerp(t.mor1.withValues(alpha: 0.22), t.mor1, yog)!;
    return GestureDetector(
      onTap: () { setState(() => tarih = gt); _yukle(t: gt); },
      child: Container(
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: secili ? Border.all(color: t.gold, width: 2) : null,
        ),
        child: Center(child: Text('${_n(g['gun']).toInt()}',
            style: TextStyle(color: adet > 0 ? Colors.white : t.sub, fontSize: 11, fontWeight: FontWeight.w600))),
      ),
    );
  }

  Widget _pPerformansKart(TemaProvider t, Map perf) {
    return _pKartKutu(t, Icons.speed, 'Performans Oranları', const Color(0xFFFB7185), Column(children: [
      _pPerfSatir(t, Icons.check_circle, 'Tamamlanma Oranı', _n(perf['tamamlanma']).toInt(), t.yesil),
      const SizedBox(height: 16),
      _pPerfSatir(t, Icons.cancel_outlined, 'İptal Oranı', _n(perf['iptal']).toInt(), t.kirmizi),
    ]));
  }

  Widget _pPerfSatir(TemaProvider t, IconData ik, String etiket, int yuzde, Color renk) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(ik, size: 16, color: renk),
        const SizedBox(width: 8),
        Expanded(child: Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13))),
        Text('%$yuzde', style: TextStyle(color: renk, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(value: (yuzde / 100).clamp(0.0, 1.0), minHeight: 8, backgroundColor: t.card2, valueColor: AlwaysStoppedAnimation(renk)),
      ),
    ]);
  }

  Widget _mGunSecici(TemaProvider t, List gunler) {
    return SizedBox(
      height: 76,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final g in gunler) _mGunPill(t, g as Map),
        ],
      ),
    );
  }

  Widget _mGunPill(TemaProvider t, Map g) {
    final gt = g['tarih'].toString();
    final aktif = gt == tarih;
    final adet = _n(g['adet']).toInt();
    return GestureDetector(
      onTap: () { setState(() => tarih = gt); _yukle(t: gt); },
      child: Container(
        width: 66,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: aktif ? t.mor1 : t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: aktif ? t.mor1 : t.line),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_gunKisa(gt), style: TextStyle(color: aktif ? Colors.white : t.sub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${DateTime.tryParse(gt)?.day ?? ''}', style: TextStyle(color: aktif ? Colors.white : t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (adet > 0)
            Positioned(
              right: 5, top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: aktif ? Colors.white24 : t.mavi, borderRadius: BorderRadius.circular(20)),
                child: Text('$adet', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _mOzet(TemaProvider t, Map ozet) {
    Widget kart(String etiket, int deger, Color renk) => Expanded(
          child: MKart(
            child: Column(children: [
              Text('$deger', style: TextStyle(color: renk, fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(etiket, style: TextStyle(color: t.sub, fontSize: 12.5)),
            ]),
          ),
        );
    return Row(children: [
      kart('Bekleyen', _n(ozet['bekleyen']).toInt(), t.amber),
      const SizedBox(width: 14),
      kart('Onaylı', _n(ozet['onayli']).toInt(), t.mavi),
      const SizedBox(width: 14),
      kart('Geldi', _n(ozet['geldi']).toInt(), t.yesil),
      const SizedBox(width: 14),
      kart('Kişi', _n(ozet['kisi']).toInt(), t.mor1),
    ]);
  }

  Color _renkT(TemaProvider t, String d) => {
        'bekliyor': t.amber, 'onaylandi': t.mavi, 'geldi': t.yesil, 'iptal': const Color(0xFF64748B), 'gelmedi': t.kirmizi,
      }[d] ?? t.mor1;

  Widget _mTablo(TemaProvider t, List rezervasyonlar) {
    return MTablo(
      sutunlar: const [
        MSutun('Saat', flex: 8),
        MSutun('Müşteri', flex: 26),
        MSutun('Kişi', flex: 8, hiza: TextAlign.center),
        MSutun('Masa', flex: 12),
        MSutun('Durum', flex: 14, hiza: TextAlign.center),
        MSutun('İşlem', flex: 22, hiza: TextAlign.right),
      ],
      satirlar: [
        for (final r in rezervasyonlar)
          () {
            final rm = r as Map;
            final durum = rm['durum'].toString();
            final renk = _renkT(t, durum);
            final pasif = durum == 'iptal' || durum == 'gelmedi';
            final not = (rm['not']?.toString() ?? '');
            final tel = (rm['telefon']?.toString() ?? '');
            final masa = (rm['masa_ad']?.toString() ?? '');
            return <Widget>[
              Text(rm['saat'].toString(), style: TextStyle(color: renk, fontSize: 15, fontWeight: FontWeight.bold)),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _detayAc(_n(rm['id']).toInt()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(
                        rm['ad'].toString(),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: pasif ? t.sub : t.ink, fontSize: 14, fontWeight: FontWeight.bold,
                          decoration: pasif ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(_kaynakIkon(rm['kaynak'].toString()), style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    const Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
                  ]),
                  if (tel.isNotEmpty)
                    Text('📞 $tel', style: TextStyle(color: t.sub, fontSize: 12)),
                  if (not.isNotEmpty)
                    Text('📝 $not', style: TextStyle(color: t.sub2, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              Text('${_n(rm['kisi']).toInt()}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(masa.isEmpty ? '—' : 'Masa $masa', style: TextStyle(color: masa.isEmpty ? t.sub : t.ink, fontSize: 13)),
              Align(alignment: Alignment.center, child: MRozet(_durumAd(durum), renk)),
              _mAksiyonlar(t, rm, durum),
            ];
          }(),
      ],
    );
  }

  Widget _mAksiyonlar(TemaProvider t, Map r, String durum) {
    final id = _n(r['id']).toInt();
    final btns = <Widget>[];
    if (durum == 'bekliyor') {
      btns.add(MButon('Onayla', t.yesil, () => _durum(id, 'onaylandi'), ikon: Icons.check));
      btns.add(const SizedBox(width: 8));
      btns.add(MButon('İptal', t.kirmizi, () => _durum(id, 'iptal'), dolu: false, ikon: Icons.close));
    } else if (durum == 'onaylandi') {
      btns.add(MButon('Oturt', _mor, () => _oturtVeyaDetay(id, r), ikon: Icons.login));
      btns.add(const SizedBox(width: 8));
      btns.add(MButon('Gelmedi', t.kirmizi, () => _durum(id, 'gelmedi'), dolu: false, ikon: Icons.person_off));
    } else {
      return Align(alignment: Alignment.centerRight, child: Text('—', style: TextStyle(color: t.sub)));
    }
    return Row(mainAxisAlignment: MainAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: btns);
  }

  Widget _gunPill(Map g) {
    final t = g['tarih'].toString();
    final aktif = t == tarih;
    final adet = _n(g['adet']).toInt();
    return GestureDetector(
      onTap: () { setState(() => tarih = t); _yukle(t: t); },
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: aktif ? _mor : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: aktif ? _mor : const Color(0xFF2D3752)),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_gunKisa(t), style: TextStyle(color: aktif ? Colors.white : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${DateTime.tryParse(t)?.day ?? ''}', style: TextStyle(color: aktif ? Colors.white : const Color(0xFFCBD5E1), fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (adet > 0)
            Positioned(
              right: 5, top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: aktif ? Colors.white24 : _mavi, borderRadius: BorderRadius.circular(20)),
                child: Text('$adet', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _ozetChip(String etiket, int deger, Color renk) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$deger', style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(etiket, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ]),
        ),
      );

  Widget _kart(Map r) {
    final durum = r['durum'].toString();
    final renk = _renk(durum);
    final pasif = durum == 'iptal' || durum == 'gelmedi';
    final not = (r['not']?.toString() ?? '');
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _detayAc(_n(r['id']).toInt()),
      child: Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: renk, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Saat
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['saat'].toString(), style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['ad'].toString(),
                    style: TextStyle(color: pasif ? const Color(0xFF64748B) : Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold,
                        decoration: pasif ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.people_outline, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text('${_n(r['kisi']).toInt()} kişi', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  const SizedBox(width: 10),
                  Text(_kaynakIkon(r['kaynak'].toString()), style: const TextStyle(fontSize: 12)),
                  if ((r['masa_ad']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.table_restaurant, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text('Masa ${r['masa_ad']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  ],
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: Text(_durumAd(durum), style: TextStyle(color: renk, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ]),
          if (not.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('📝 $not', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5)),
            ),
          if ((r['telefon']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('📞 ${r['telefon']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
            ),
          // Aksiyonlar
          if (!pasif && durum != 'geldi') ...[
            const SizedBox(height: 12),
            Row(children: _aksiyonlar(r, durum)),
          ],
        ]),
      ),
      ),
    );
  }

  List<Widget> _aksiyonlar(Map r, String durum) {
    final id = _n(r['id']).toInt();
    final btns = <Widget>[];
    void ekle(String etiket, IconData ikon, Color renk, String yeni) {
      btns.add(Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            onPressed: () => _durum(id, yeni),
            style: OutlinedButton.styleFrom(
              foregroundColor: renk, side: BorderSide(color: renk.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(ikon, size: 15),
            label: Text(etiket, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ),
      ));
    }
    void ekleCustom(String etiket, IconData ikon, Color renk, VoidCallback onPressed) {
      btns.add(Expanded(child: Padding(padding: const EdgeInsets.only(right: 8),
        child: OutlinedButton.icon(onPressed: onPressed,
          style: OutlinedButton.styleFrom(foregroundColor: renk, side: BorderSide(color: renk.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          icon: Icon(ikon, size: 15), label: Text(etiket, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold))))));
    }
    if (durum == 'bekliyor') {
      ekle('Onayla', Icons.check, _yesil, 'onaylandi');
      ekle('İptal', Icons.close, _kirmizi, 'iptal');
    } else if (durum == 'onaylandi') {
      ekleCustom('Oturt', Icons.login, _mor, () => _oturtVeyaDetay(id, r));
      ekle('Gelmedi', Icons.person_off, _kirmizi, 'gelmedi');
    }
    return btns;
  }

  // Rezervasyonu oturt: masa atanmissa direkt ac, degilse detaydan masa sec
  void _oturtVeyaDetay(int id, Map r) {
    if (r['masa_id'] != null) {
      _oturt(id);
    } else {
      _detayAc(id);
    }
  }

  Future<void> _oturt(int id, {int? masaId}) async {
    try {
      final r = await Api.rezervasyonOturt(_token, id, masaId: masaId);
      if (!mounted) return;
      final ok = r['ok'] == 1;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? (r['mesaj']?.toString() ?? 'Masa açıldı') : (r['hata']?.toString() ?? 'Oturtulamadı')),
        backgroundColor: ok ? _yesil : _kirmizi, duration: const Duration(seconds: 3)));
      if (ok) _yukle();
    } catch (_) {}
  }

  // Rezervasyon detay: müşteri geçmişi/alerji + özel istek etiketleri + ön sipariş + masaya oturt
  Future<void> _detayAc(int id) async {
    Map? det;
    try { det = await Api.rezervasyonDetay(_token, id); } catch (_) {}
    if (!mounted || det == null || det['ok'] != 1) return;
    final rez = (det['rezervasyon'] as Map?) ?? {};
    final musteri = det['musteri'] as Map?;
    final etiketler = (det['etiketler'] as List?) ?? [];
    final kalemler = (det['kalemler'] as List?) ?? [];
    final durum = rez['durum'].toString();
    int? secMasa = rez['masa_id'] != null ? _n(rez['masa_id']).toInt() : null;
    List bosMasalar = [];
    try {
      final m = await Api.masalar(_token);
      bosMasalar = ((m['masalar'] as List?) ?? []).where((x) => (x as Map)['adisyon_id'] == null).toList();
    } catch (_) {}
    if (!mounted) return;

    await showModalBottomSheet(useRootNavigator: true, context: context, backgroundColor: _card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final onToplam = kalemler.fold<double>(0, (a, b) => a + _n((b as Map)['fiyat']).toDouble() * _n(b['adet']).toInt());
        final masaItems = <DropdownMenuItem<int?>>[const DropdownMenuItem<int?>(value: null, child: Text('— Masa seç —'))];
        final idsSet = <int>{};
        for (final m in bosMasalar) {
          final mid = _n((m as Map)['id']).toInt();
          idsSet.add(mid);
          masaItems.add(DropdownMenuItem<int?>(value: mid, child: Text('Masa ${m['ad']}')));
        }
        if (secMasa != null && !idsSet.contains(secMasa)) {
          masaItems.insert(1, DropdownMenuItem<int?>(value: secMasa, child: Text('Masa ${rez['masa_ad'] ?? secMasa} (atanmış)')));
        }
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 18, right: 18, top: 14),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 14),
            Row(children: [
              Text(rez['saat'].toString(), style: TextStyle(color: _renk(durum), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(child: Text(rez['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _renk(durum).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Text(_durumAd(durum), style: TextStyle(color: _renk(durum), fontSize: 10.5, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 6),
            Text('${_n(rez['kisi']).toInt()} kişi · ${rez['telefon'] ?? '—'}${(rez['masa_ad']?.toString().isNotEmpty ?? false) ? ' · Masa ${rez['masa_ad']}' : ''}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            if (musteri != null) ...[
              const SizedBox(height: 10),
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _mor.withValues(alpha: 0.4))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [const Icon(Icons.badge_outlined, size: 15, color: _mor), const SizedBox(width: 6),
                    Expanded(child: Text('${musteri['ad']} · ${_n(musteri['siparis_sayisi']).toInt()} ziyaret · ${_yzStr(musteri['toplam_harcama'])} ₺', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)))]),
                  if (musteri['notlar']?.toString().isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 3), child: Text('⚠️ ${musteri['notlar']}', style: const TextStyle(color: _amber, fontSize: 11.5))),
                ])),
            ],
            if (etiketler.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final e in etiketler) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFF0F1424), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2D3752))),
                child: Text(e.toString(), style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)))]),
            ],
            if (kalemler.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Ön Sipariş', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              for (final k in kalemler) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
                Text('${_n((k as Map)['adet']).toInt()}×', style: const TextStyle(color: _mor, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(child: Text(k['urun_adi'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                Text('${_yzStr(_n(k['fiyat']).toDouble() * _n(k['adet']).toInt())} ₺', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ])),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('Toplam: ${_yzStr(onToplam)} ₺', style: const TextStyle(color: _yesil, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
            if (rez['not']?.toString().isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 10), child: Text('📝 ${rez['not']}', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5))),
            if (durum != 'geldi' && durum != 'iptal') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(initialValue: secMasa, dropdownColor: _card, style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(labelText: 'Masa', labelStyle: const TextStyle(color: Color(0xFF94A3B8)), filled: true, fillColor: const Color(0xFF0F1424), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                items: masaItems, onChanged: (v) => setSt(() => secMasa = v)),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: secMasa == null ? null : () { Navigator.pop(ctx); _oturt(id, masaId: secMasa); },
                icon: const Icon(Icons.login, color: Colors.white),
                label: Text('Masaya Oturt${kalemler.isNotEmpty ? ' (${kalemler.length} ön sipariş mutfağa)' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
            ],
            const SizedBox(height: 22),
          ])),
        );
      }),
    );
  }

  Widget _bos() => ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.event_available, size: 56, color: Color(0xFF334155)),
        SizedBox(height: 12),
        Center(child: Text('Bu gün için rezervasyon yok.', style: TextStyle(color: Color(0xFF64748B)))),
      ]);

  // ---- Yeni rezervasyon (müşteri CRM + masa + özel istek + ön sipariş) ----
  Future<void> _ekleDialog() async {
    // Masa + menü önden yükle (ön sipariş + masa seçimi için)
    List bosMasalar = [];
    List menuUrun = [];
    try {
      final m = await Api.masalar(_token);
      bosMasalar = ((m['masalar'] as List?) ?? []).where((x) => (x as Map)['adisyon_id'] == null).toList();
    } catch (_) {}
    try {
      final mn = await Api.menu(_token);
      menuUrun = (mn['urunler'] as List?) ?? [];
    } catch (_) {}
    if (!mounted) return;

    final adC = TextEditingController();
    final telC = TextEditingController();
    final notC = TextEditingController();
    final musteriNotC = TextEditingController();
    int kisi = 2;
    String saat = '19:30';
    DateTime secilenTarih = DateTime.tryParse(tarih) ?? DateTime.now();
    int? masaId;
    final seciliEtiket = <String>{};
    final onSiparis = <Map<String, dynamic>>[]; // {urun_id, ad, fiyat, adet}
    Map? musteriKart;
    String? sonZiyaret;
    bool musteriAraniyor = false;
    final saatler = <String>[for (int h = 12; h <= 23; h++) for (final mm in ['00', '30']) '${h.toString().padLeft(2, '0')}:$mm'];
    const etiketSecenek = ['🎂 Doğum günü', '💍 Yıldönümü', '🪟 Pencere kenarı', '👶 Bebek sandalyesi', '♿ Tekerlekli sandalye', '⚠️ Alerji', '⭐ VIP', '🤫 Sessiz köşe'];

    await showModalBottomSheet(useRootNavigator: true,
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        InputDecoration dec(String h) => InputDecoration(
              labelText: h, labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true, fillColor: const Color(0xFF0F1424),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            );

        Future<void> musteriAra() async {
          final tel = telC.text.trim();
          if (tel.length < 7) { setSt(() { musteriKart = null; sonZiyaret = null; }); return; }
          setSt(() => musteriAraniyor = true);
          try {
            final r = await Api.musteriBul(_token, tel);
            if (r['ok'] == 1 && r['bulundu'] == true) {
              final mm = r['musteri'] as Map;
              setSt(() {
                musteriKart = mm;
                sonZiyaret = r['son_ziyaret']?.toString();
                if (adC.text.trim().isEmpty) adC.text = mm['ad']?.toString() ?? '';
                if (musteriNotC.text.trim().isEmpty && (mm['notlar']?.toString().isNotEmpty ?? false)) musteriNotC.text = mm['notlar'].toString();
              });
            } else {
              setSt(() { musteriKart = null; sonZiyaret = null; });
            }
          } catch (_) {}
          if (ctx.mounted) setSt(() => musteriAraniyor = false);
        }

        Future<void> urunEkleSheet() async {
          String ara = '';
          await showModalBottomSheet(useRootNavigator: true, context: ctx, backgroundColor: _card, isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
            builder: (c2) => StatefulBuilder(builder: (c2, setS2) {
              final liste = menuUrun.where((u) => ara.isEmpty || (u as Map)['ad'].toString().toLowerCase().contains(ara.toLowerCase())).toList();
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(c2).viewInsets.bottom, left: 16, right: 16, top: 14),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Ürün Ekle (ön sipariş)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextField(autofocus: true, style: const TextStyle(color: Colors.white), decoration: dec('Ürün ara'), onChanged: (v) => setS2(() => ara = v)),
                  const SizedBox(height: 8),
                  SizedBox(height: 320, child: ListView.builder(itemCount: liste.length, itemBuilder: (_, i) {
                    final u = liste[i] as Map;
                    return ListTile(
                      dense: true,
                      title: Text(u['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: Text('${_yzStr(u['fiyat'])} ₺', style: const TextStyle(color: _mor, fontWeight: FontWeight.bold)),
                      onTap: () {
                        final id = _n(u['id']).toInt();
                        final mevcut = onSiparis.firstWhere((x) => x['urun_id'] == id, orElse: () => {});
                        if (mevcut.isEmpty) { onSiparis.add({'urun_id': id, 'ad': u['ad'], 'fiyat': _n(u['fiyat']), 'adet': 1}); }
                        else { mevcut['adet'] = _n(mevcut['adet']).toInt() + 1; }
                        Navigator.pop(c2);
                        setSt(() {});
                      },
                    );
                  })),
                  const SizedBox(height: 12),
                ]),
              );
            }),
          );
        }

        final onToplam = onSiparis.fold<double>(0, (a, b) => a + _n(b['fiyat']).toDouble() * _n(b['adet']).toInt());

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 18, right: 18, top: 14),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 14),
              const Text('Yeni Rezervasyon', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(controller: telC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white),
                decoration: dec('Telefon').copyWith(suffixIcon: musteriAraniyor
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _mor)))
                    : IconButton(icon: const Icon(Icons.search, color: Color(0xFF94A3B8)), onPressed: musteriAra)),
                onSubmitted: (_) => musteriAra()),
              if (musteriKart != null) ...[
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _mor.withValues(alpha: 0.4))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [const Icon(Icons.badge_outlined, size: 15, color: _mor), const SizedBox(width: 6),
                      Expanded(child: Text('${musteriKart!['ad']} · ${_n(musteriKart!['siparis_sayisi']).toInt()} ziyaret', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)))]),
                    if (sonZiyaret != null) Padding(padding: const EdgeInsets.only(top: 3), child: Text('Son ziyaret: $sonZiyaret · Toplam: ${_yzStr(musteriKart!['toplam_harcama'])} ₺', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11))),
                    if (musteriKart!['notlar']?.toString().isNotEmpty ?? false) Padding(padding: const EdgeInsets.only(top: 3), child: Text('⚠️ ${musteriKart!['notlar']}', style: const TextStyle(color: _amber, fontSize: 11))),
                  ])),
              ],
              const SizedBox(height: 10),
              TextField(controller: adC, style: const TextStyle(color: Colors.white), decoration: dec('Ad Soyad')),
              const SizedBox(height: 12),
              Row(children: [
                const Text('Kişi:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(width: 10),
                Expanded(child: Slider(value: kisi.toDouble(), min: 1, max: 16, divisions: 15, activeColor: _mor, label: '$kisi', onChanged: (v) => setSt(() => kisi = v.round()))),
                Text('$kisi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ]),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: secilenTarih, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 120)));
                    if (d != null) setSt(() => secilenTarih = d);
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF2D3752)), padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.calendar_today, size: 15),
                  label: Text('${secilenTarih.day}.${secilenTarih.month}.${secilenTarih.year}', style: const TextStyle(fontSize: 13)))),
                const SizedBox(width: 10),
                Expanded(child: DropdownButtonFormField<String>(initialValue: saat, dropdownColor: _card, decoration: dec('Saat'), style: const TextStyle(color: Colors.white),
                  items: [for (final s in saatler) DropdownMenuItem(value: s, child: Text(s))], onChanged: (v) => setSt(() => saat = v ?? saat))),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(initialValue: masaId, dropdownColor: _card, decoration: dec('Masa (opsiyonel)'), style: const TextStyle(color: Colors.white),
                items: [const DropdownMenuItem<int?>(value: null, child: Text('— Masa atama —')), for (final m in bosMasalar) DropdownMenuItem<int?>(value: _n((m as Map)['id']).toInt(), child: Text('Masa ${m['ad']}'))],
                onChanged: (v) => setSt(() => masaId = v)),
              const SizedBox(height: 14),
              const Text('Özel İstek', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final e in etiketSecenek) GestureDetector(
                onTap: () => setSt(() => seciliEtiket.contains(e) ? seciliEtiket.remove(e) : seciliEtiket.add(e)),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: seciliEtiket.contains(e) ? _mor : const Color(0xFF0F1424), borderRadius: BorderRadius.circular(20), border: Border.all(color: seciliEtiket.contains(e) ? _mor : const Color(0xFF2D3752))),
                  child: Text(e, style: TextStyle(color: seciliEtiket.contains(e) ? Colors.white : const Color(0xFF94A3B8), fontSize: 12))))]),
              const SizedBox(height: 12),
              TextField(controller: notC, style: const TextStyle(color: Colors.white), decoration: dec('Serbest not (opsiyonel)')),
              const SizedBox(height: 10),
              TextField(controller: musteriNotC, style: const TextStyle(color: Colors.white), decoration: dec('Müşteri notu / alerji (kalıcı)')),
              const SizedBox(height: 14),
              Row(children: [
                const Text('Ön Sipariş (ne yiyecek)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(onPressed: urunEkleSheet, icon: const Icon(Icons.add, size: 16, color: _mor), label: const Text('Ürün Ekle', style: TextStyle(color: _mor, fontSize: 12))),
              ]),
              if (onSiparis.isEmpty)
                const Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Henüz ürün eklenmedi.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)))
              else ...[
                for (final k in onSiparis) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
                  Expanded(child: Text('${k['ad']}', style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  IconButton(iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.remove_circle_outline, color: Color(0xFF94A3B8)),
                    onPressed: () => setSt(() { final a = _n(k['adet']).toInt() - 1; if (a <= 0) { onSiparis.remove(k); } else { k['adet'] = a; } })),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('${_n(k['adet']).toInt()}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  IconButton(iconSize: 18, padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.add_circle_outline, color: _mor), onPressed: () => setSt(() => k['adet'] = _n(k['adet']).toInt() + 1)),
                  const SizedBox(width: 8),
                  Text('${_yzStr(_n(k['fiyat']).toDouble() * _n(k['adet']).toInt())} ₺', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ])),
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ön sipariş toplamı: ${_yzStr(onToplam)} ₺', style: const TextStyle(color: _yesil, fontSize: 12, fontWeight: FontWeight.bold))),
              ],
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (adC.text.trim().isEmpty) return;
                  final iso = '${secilenTarih.year}-${secilenTarih.month.toString().padLeft(2, '0')}-${secilenTarih.day.toString().padLeft(2, '0')}';
                  Navigator.pop(ctx);
                  try {
                    await Api.rezervasyonEkle(_token, ad: adC.text.trim(), telefon: telC.text.trim(), kisi: kisi, tarih: iso, saat: saat,
                      masaId: masaId, not: notC.text.trim(), musteriNot: musteriNotC.text.trim(),
                      etiketler: seciliEtiket.toList(),
                      onSiparis: onSiparis.map((e) => <String, dynamic>{'urun_id': e['urun_id'], 'adet': _n(e['adet']).toInt()}).toList());
                    setState(() => tarih = iso);
                    _yukle(t: iso);
                  } catch (_) {}
                },
                child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)))),
              const SizedBox(height: 20),
            ]),
          ),
        );
      }),
    );
  }
}
