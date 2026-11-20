import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /garson-yonetimi — web'de İşletme Düzeni'nin "Garson Yönetimi" sekmesi (/garson-yonetimi → /isletme-duzeni?gy=1).
/// Atama verisi /isletme-duzeni'den, canlı veri /garson-yonetimi/veri'den (30 sn'de bir), masa bilgisi /garson-yonetimi/masa-detay'dan.
/// İşlemler: genel bakış (kartlar + halkalar), garsonlar (ata/düzenle, mola başlat/bitir), aktivite (garson filtresi),
/// ısı haritası (pencere + garson filtresi, masaya dokun → hesaplar), performans raporu (dönem), yeni garson ekle, ayar bağlantıları.
class IkGarsonYonetimiScreen extends StatelessWidget {
  const IkGarsonYonetimiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/isletme-duzeni',
      baslik: 'Garson Yönetimi',
      ikon: Icons.groups_outlined,
      fab: (c, v, yenile) => FloatingActionButton.extended(
        heroTag: 'gy_yeni',
        onPressed: () => yeniGarsonEkle(c, yenile),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Yeni Garson', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (c, v, yenile) => GarsonYonetimiGovde(duzen: v, yenile: yenile),
    );
  }
}

/// Yeni garson (web gyYeniGarson formu: /personel/kaydet rol=garson, geri=/garson-yonetimi)
Future<void> yeniGarsonEkle(BuildContext context, Future<void> Function() yenile) async {
  final ad = TextEditingController(), tel = TextEditingController(), pin = TextEditingController();
  final tamam = await kAltSayfa<bool>(context,
      baslik: 'Yeni Garson Ekle',
      icerik: (sc) {
        final t = sc.watch<TemaProvider>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Ad Soyad', ad, zorunlu: true),
          KAlan('Telefon', tel, klavye: TextInputType.phone),
          KAlan('Giriş PIN\'i (en az 4 hane)', pin, klavye: TextInputType.number, zorunlu: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Maaş ve özlük bilgilerini sonra Personel ekranından ekleyebilirsiniz.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          ),
          KButon('Garson Ekle', ikon: Icons.add, genis: true, onTap: () {
            if (ad.text.trim().isEmpty) return kToast(sc, 'Ad Soyad girin.', hata: true);
            if (pin.text.replaceAll(RegExp(r'\D'), '').length < 4) return kToast(sc, 'PIN en az 4 haneli olmalı.', hata: true);
            Navigator.pop(sc, true);
          }),
        ]);
      });
  if (tamam != true || !context.mounted) return;
  final ok = await kopruGonder(context, '/personel/kaydet',
      {'ad': ad.text.trim(), 'telefon': tel.text.trim(), 'pin': pin.text.trim(), 'rol': 'garson', 'aktif': '1', 'geri': '/garson-yonetimi'},
      basariMesaji: 'Garson eklendi.');
  if (ok) await yenile();
}

/// Garson ataması (web _garson_ata_panelleri: /isletme-duzeni/garson-ata — bölge ∪ ekstra masa)
Future<void> garsonAtaAc(BuildContext context, Map<String, dynamic> duzen, int garsonId, Future<void> Function() yenile) async {
  final g = liste(duzen['garsonlar']).firstWhere((x) => tamOku(x['id']) == garsonId, orElse: () => {'id': garsonId, 'ad': 'Garson'});
  final bolgeler = liste(duzen['bolgeler']);
  final masalar = liste(duzen['masalar']);
  if (bolgeler.isEmpty || masalar.isEmpty) {
    kToast(context, 'Atama için önce bölge ve masa ekleyin (İşletme Düzeni > Masa Planı).', hata: true);
    return;
  }
  final secB = {for (final x in dizi(g['bolge_idler'])) tamOku(x)};
  final secM = {for (final x in dizi(g['masa_idler'])) tamOku(x)};
  final tamam = await kAltSayfa<bool>(context,
      baslik: '${metinOku(g['ad'])} — Masa / Bölge Ataması',
      icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
            final t = sc.watch<TemaProvider>();
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Bölge seçerseniz o bölgenin tüm masaları dahildir. Hiç seçmezseniz bu garson tüm masalara bakar.', style: TextStyle(color: t.sub, fontSize: 12.5)),
              ),
              for (final b in bolgeler)
                Builder(builder: (_) {
                  final bid = tamOku(b['id']);
                  final bSec = secB.contains(bid);
                  final bm = masalar.where((m) => tamOku(m['bolge_id']) == bid).toList();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        activeColor: t.mor1,
                        value: bSec,
                        onChanged: (v) => ss(() => v == true ? secB.add(bid) : secB.remove(bid)),
                        title: Text('${metinOku(b['ad'])} (tüm bölge)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
                      ),
                      if (bm.isNotEmpty)
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final m in bm)
                            FilterChip(
                              label: Text(metinOku(m['ad']), style: const TextStyle(fontSize: 13)),
                              selected: bSec || secM.contains(tamOku(m['id'])),
                              selectedColor: t.mor1.withValues(alpha: .18),
                              checkmarkColor: t.mor1,
                              onSelected: bSec ? null : (v) => ss(() => v ? secM.add(tamOku(m['id'])) : secM.remove(tamOku(m['id']))),
                            ),
                        ]),
                    ]),
                  );
                }),
              const SizedBox(height: 6),
              KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(sc, true)),
            ]);
          }));
  if (tamam != true || !context.mounted) return;
  // Bölgesi seçili masalar ayrıca gönderilmez (web'de disabled checkbox gönderilmez)
  final bolgeMasa = {for (final m in masalar) if (secB.contains(tamOku(m['bolge_id']))) tamOku(m['id'])};
  final ok = await kopruGonder(context, '/isletme-duzeni/garson-ata', {
    'personel_id': garsonId,
    'bolge_idler': secB.toList(),
    'masa_idler': secM.where((x) => !bolgeMasa.contains(x)).toList(),
  }, basariMesaji: 'Garson ataması kaydedildi.');
  if (ok) await yenile();
}

String garsonAtamaOzet(Map<String, dynamic> duzen, int id) {
  final g = liste(duzen['garsonlar']).firstWhere((x) => tamOku(x['id']) == id, orElse: () => const {});
  if (g.isEmpty) return 'Tüm masalar';
  final bAd = {for (final b in liste(duzen['bolgeler'])) tamOku(b['id']): metinOku(b['ad'])};
  final bl = [for (final x in dizi(g['bolge_idler'])) bAd[tamOku(x)] ?? ''].where((s) => s.isNotEmpty).toList();
  final mn = dizi(g['masa_idler']).length;
  if (bl.isEmpty && mn == 0) return 'Tüm masalar';
  return [if (bl.isNotEmpty) bl.join(', '), if (mn > 0) '+$mn masa'].join(' · ');
}

class GarsonYonetimiGovde extends StatefulWidget {
  final Map<String, dynamic> duzen;
  final Future<void> Function() yenile;
  const GarsonYonetimiGovde({super.key, required this.duzen, required this.yenile});
  @override
  State<GarsonYonetimiGovde> createState() => _GarsonYonetimiGovdeState();
}

class _GarsonYonetimiGovdeState extends State<GarsonYonetimiGovde> {
  Map<String, dynamic>? _gy;
  String? _hata;
  String _sekme = 'genel';
  String _stat = 'gunluk', _perf = 'haftalik', _pencere = 'bugun';
  int _olayGarson = 0, _isiGarson = 0;
  Timer? _zaman;

  @override
  void initState() {
    super.initState();
    _yukle();
    _zaman = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _yukle(sessiz: true);
    });
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> _yukle({bool sessiz = false}) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/garson-yonetimi/veri', q: {'stat': _stat, 'perf': _perf});
      if (!mounted) return;
      setState(() {
        if (c.ok) {
          _gy = c.j;
          _hata = null;
        } else if (!sessiz || _gy == null) {
          _hata = c.yetkisiz ? 'Bu bölüm için yetkiniz yok.' : (c.hata ?? 'Garson verisi alınamadı.');
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) setState(() => _hata = 'Oturum doğrulanamadı.');
    }
  }

  Future<void> _hepsiniYenile() async {
    await widget.yenile();
    await _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ust = <Widget>[
      KCipler(
        secenekler: const [('genel', 'Genel Bakış'), ('garsonlar', 'Garsonlar'), ('aktivite', 'Aktivite'), ('isi', 'Isı Haritası'), ('rapor', 'Performans'), ('ayarlar', 'Ayarlar')],
        secili: _sekme,
        onSec: (k) => setState(() => _sekme = k),
      ),
    ];
    if (_gy == null) {
      return KGovde(yenile: _hepsiniYenile, children: [
        ...ust,
        if (_hata != null) KHata(_hata!, tekrar: _yukle) else const Padding(padding: EdgeInsets.all(40), child: KYukleniyor(metin: 'Garson verisi yükleniyor…')),
      ]);
    }
    final gy = _gy!;
    List<Widget> govde;
    switch (_sekme) {
      case 'garsonlar':
        govde = _garsonlar(t, gy);
        break;
      case 'aktivite':
        govde = _aktivite(t, gy);
        break;
      case 'isi':
        govde = _isi(t, gy);
        break;
      case 'rapor':
        govde = _rapor(t, gy);
        break;
      case 'ayarlar':
        govde = _ayarlar(t);
        break;
      default:
        govde = _genel(t, gy);
    }
    return KGovde(yenile: _hepsiniYenile, children: [
      ...ust,
      if (_hata != null)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Son güncelleme başarısız: $_hata', style: TextStyle(color: t.amber, fontSize: 12.5))),
      ...govde,
    ]);
  }

  // ───────── yardımcılar ─────────
  String _sure(dynamic sn) {
    if (sn == null) return '—';
    final s = tamOku(sn);
    if (s < 60) return '$s sn';
    return '${(s / 60).floor()} dk ${s % 60 > 0 ? '${s % 60} sn' : ''}'.trim();
  }

  String _trend(dynamic v) {
    if (v == null) return '';
    final d = sayiOku(v);
    return '${d >= 0 ? '▲' : '▼'} %${d.abs().round()} düne göre';
  }

  Widget _durumRozet(TemaProvider t, Map<String, dynamic> g) {
    final d = metinOku(g['durum']);
    if (d == 'aktif') return KRozet('Aktif', renk: t.yesil);
    if (d == 'mola') return KRozet('Molada${g['mola_dk'] != null ? ' · ${tamOku(g['mola_dk'])} dk' : ''}', renk: t.amber);
    return KRozet('Çevrimdışı', renk: t.sub);
  }

  Widget _donemSec(String deger, ValueChanged<String> onSec) => KCipler(
        secenekler: const [('gunluk', 'Bugün'), ('haftalik', 'Bu Hafta'), ('aylik', 'Bu Ay')],
        secili: deger,
        onSec: onSec,
      );

  Future<void> _mola(Map<String, dynamic> g) async {
    final c = await kopruGonderCevap(context, '/garson-yonetimi/mola', {'personel_id': tamOku(g['id'])}, json: true);
    if (c == null || !mounted) return;
    if (c.ok) {
      kToast(context, c.j['molada'] == true ? 'Garson molaya alındı.' : 'Garson moladan çıkarıldı.');
      await _yukle();
    }
  }

  // ───────── GENEL BAKIŞ ─────────
  List<Widget> _genel(TemaProvider t, Map<String, dynamic> gy) {
    final k = harita(gy['kart']);
    final h = harita(gy['halka']);
    final garsonlar = liste(gy['garsonlar']);
    final perf = liste(gy['performans']);
    final olay = liste(gy['olaylar']);
    return [
      KKpiIzgara([
        KKpi(etiket: 'Aktif Garson', deger: '${tamOku(k['aktif'])} / ${tamOku(k['toplam'])}', ikon: Icons.person_outline, renk: t.yesil),
        KKpi(etiket: 'Ortalama Servis', deger: _sure(k['servis_sn']), alt: _trend(k['servis_trend']), ikon: Icons.timer_outlined, renk: t.mavi),
        KKpi(etiket: 'Tamamlanan Hesap', deger: '${tamOku(k['tamam'])}', alt: _trend(k['tamam_trend']), ikon: Icons.task_alt, renk: t.mor1),
        KKpi(etiket: 'Bugünkü Adım', deger: sayiYaz(k['adim']), ikon: Icons.directions_walk, renk: t.amber),
        KKpi(
          etiket: 'Memnuniyet (7 gün)',
          deger: k['memnuniyet'] == null ? '—' : sayiYaz(k['memnuniyet']),
          alt: k['memnuniyet'] == null ? 'Anket verisi yok' : _trend(k['memnuniyet_trend']),
          ikon: Icons.sentiment_satisfied_outlined,
          renk: const Color(0xFFDB2777),
        ),
      ]),
      if (tamOku(gy['cagri']) > 0)
        KKart(
          renk: t.kirmizi,
          onTap: () => _ac('/garson-cagrilari', 'Garson Çağrıları'),
          child: Row(children: [
            Icon(Icons.notifications_active_outlined, color: t.kirmizi),
            const SizedBox(width: 10),
            Expanded(child: Text('${tamOku(gy['cagri'])} masa garson çağırıyor', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right, color: t.sub),
          ]),
        ),
      KBaslik('Anlık İstatistikler', ikon: Icons.show_chart),
      _donemSec(_stat, (x) {
        setState(() => _stat = x);
        _yukle();
      }),
      KKpiIzgara([
        _halka(t, 'Masa Doluluğu', h['doluluk'], t.mor1),
        _halka(t, 'Tamamlama', h['tamamlama'], t.yesil),
        _halka(t, 'Verimlilik', h['verimlilik'], t.mavi),
        KKpi(etiket: 'Servis Süresi', deger: _sure(h['servis_sn']), ikon: Icons.timer_outlined, renk: t.amber),
      ]),
      KBaslik('Garsonlar & Aktiviteleri', ikon: Icons.groups_outlined, sag: TextButton(onPressed: () => setState(() => _sekme = 'garsonlar'), child: const Text('Tümü'))),
      if (garsonlar.isEmpty)
        const KBos(ikon: Icons.person_off_outlined, baslik: 'Aktif garson yok', aciklama: 'Rolü "Garson" olan aktif personel burada görünür. "Yeni Garson" ile ekleyin.')
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final g in garsonlar.take(6))
              KSatir(
                baslik: metinOku(g['ad']),
                alt: metinOku(g['son']).isEmpty ? garsonAtamaOzet(widget.duzen, tamOku(g['id'])) : '${metinOku(g['son'])}${g['dk'] != null ? ' · ${tamOku(g['dk'])} dk önce' : ''}',
                solIkon: _avatar(t, g),
                sag: _durumRozet(t, g),
              ),
          ]),
        ),
      KBaslik('Garson Performansı', ikon: Icons.emoji_events_outlined),
      _donemSec(_perf, (x) {
        setState(() => _perf = x);
        _yukle();
      }),
      if (perf.isEmpty)
        const KBos(ikon: Icons.leaderboard_outlined, baslik: 'Bu dönemde performans verisi yok', aciklama: 'Skor, garsonların açtığı/kapattığı adisyonlardan hesaplanır. Seçilen dönemde garson adına satış yoksa liste boş kalır.')
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < perf.length && i < 5; i++)
              KSatir(
                baslik: '${i + 1}. ${metinOku(perf[i]['ad'])}',
                alt: '${tamOku(perf[i]['adisyon'])} adisyon · ${tl(perf[i]['ciro'], kisa: true)} · ${tamOku(perf[i]['kalem'])} ürün',
                sag: KRozet('${tamOku(perf[i]['skor'])}', renk: t.mor1, ikon: Icons.star),
              ),
          ]),
        ),
      KBaslik('Son Aktiviteler', ikon: Icons.schedule, sag: TextButton(onPressed: () => setState(() => _sekme = 'aktivite'), child: const Text('Tümü'))),
      _olayListe(t, olay.take(8).toList()),
    ];
  }

  Widget _halka(TemaProvider t, String etiket, dynamic deger, Color r) {
    final yok = deger == null;
    final v = yok ? 0.0 : (sayiOku(deger) / 100).clamp(0.0, 1.0);
    return KKart(
      margin: EdgeInsets.zero,
      child: Row(children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: v, strokeWidth: 6, color: r, backgroundColor: r.withValues(alpha: .15)),
            Text(yok ? '—' : '%${tamOku(deger)}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _avatar(TemaProvider t, Map<String, dynamic> g) {
    final ad = metinOku(g['ad'], '?');
    final d = metinOku(g['durum']);
    final r = d == 'aktif' ? t.yesil : (d == 'mola' ? t.amber : t.sub);
    return CircleAvatar(
      radius: 19,
      backgroundColor: r.withValues(alpha: .16),
      child: Text(ad.substring(0, 1).toUpperCase(), style: TextStyle(color: r, fontWeight: FontWeight.w700)),
    );
  }

  // ───────── GARSONLAR ─────────
  List<Widget> _garsonlar(TemaProvider t, Map<String, dynamic> gy) {
    final l = liste(gy['garsonlar']);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Bugünkü rakamlar. Bölge seçerseniz o bölgenin tüm masaları dahildir; hiç seçmezseniz garson tüm masalara bakar.', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
      if (l.isEmpty)
        KBos(
          ikon: Icons.person_off_outlined,
          baslik: 'Aktif garson yok',
          aciklama: 'Rolü "Garson" olan aktif personel burada listelenir.',
          aksiyon: KButon('Yeni Garson Ekle', ikon: Icons.person_add_alt_1, onTap: () => yeniGarsonEkle(context, _hepsiniYenile)),
        )
      else
        LayoutBuilder(builder: (c, k) {
          final n = k.maxWidth >= 1000 ? 3 : (k.maxWidth >= 640 ? 2 : 1);
          final w = (k.maxWidth - 12 * (n - 1)) / n;
          return Wrap(spacing: 12, children: [
            for (final g in l)
              SizedBox(
                width: w,
                child: KKart(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _avatar(t, g),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(metinOku(g['ad']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(garsonAtamaOzet(widget.duzen, tamOku(g['id'])), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5)),
                        ]),
                      ),
                      _durumRozet(t, g),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      _mini(t, '${tamOku(g['adisyon'])}', 'Adisyon'),
                      _mini(t, '${tamOku(g['kalem'])}', 'Ürün'),
                      _mini(t, tl(g['ciro'], kisa: true), 'Ciro'),
                      _mini(t, sayiYaz(g['adim']), 'Adım'),
                    ]),
                    if (metinOku(g['son']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Son: ${metinOku(g['son'])}${g['dk'] != null ? ' · ${tamOku(g['dk'])} dk önce' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                      ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: KButon('Ata / Düzenle', ikon: Icons.tune, ikincil: true, onTap: () => garsonAtaAc(context, widget.duzen, tamOku(g['id']), _hepsiniYenile))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: KButon(metinOku(g['durum']) == 'mola' ? 'Molayı Bitir' : 'Molaya Al',
                            ikon: metinOku(g['durum']) == 'mola' ? Icons.play_arrow : Icons.free_breakfast_outlined, ikincil: true, renk: t.amber, onTap: () => _mola(g)),
                      ),
                    ]),
                  ]),
                ),
              ),
          ]);
        }),
    ];
  }

  Widget _mini(TemaProvider t, String d, String e) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(d, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          Text(e, style: TextStyle(color: t.sub, fontSize: 11.5)),
        ]),
      );

  // ───────── AKTİVİTE ─────────
  List<Widget> _aktivite(TemaProvider t, Map<String, dynamic> gy) {
    final kisiler = <int, String>{};
    for (final o in liste(gy['olaylar'])) {
      kisiler[tamOku(o['p'])] = metinOku(o['ad']);
    }
    final olay = liste(gy['olaylar']).where((o) => _olayGarson == 0 || tamOku(o['p']) == _olayGarson).toList();
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Son 12 saatteki sipariş, servis, ödeme, mesai ve mola hareketleri (30 sn\'de bir yenilenir).', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
      KSecim<int>('Personel', deger: _olayGarson, secenekler: [(0, 'Tüm personel'), for (final e in kisiler.entries) (e.key, e.value)], onSec: (v) => setState(() => _olayGarson = v ?? 0)),
      _olayListe(t, olay),
    ];
  }

  Widget _olayListe(TemaProvider t, List<Map<String, dynamic>> olay) {
    if (olay.isEmpty) {
      return const KBos(ikon: Icons.history, baslik: 'Henüz hareket yok', aciklama: 'Garsonların sipariş, servis, ödeme ve mola hareketleri burada akar. Son 12 saatte kayıt yok.');
    }
    const ikon = {'siparis': Icons.receipt_long_outlined, 'servis': Icons.room_service_outlined, 'odeme': Icons.payments_outlined, 'mesai': Icons.badge_outlined, 'mola': Icons.free_breakfast_outlined};
    return KKart(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(children: [
        for (final o in olay)
          KSatir(
            baslik: metinOku(o['m']),
            alt: '${metinOku(o['saat'])} · ${metinOku(o['ad'])}',
            solIkon: KIkon(ikon[metinOku(o['tip'])] ?? Icons.circle_outlined, renk: t.mor1, boyut: 34),
          ),
      ]),
    );
  }

  // ───────── ISI HARİTASI ─────────
  List<Widget> _isi(TemaProvider t, Map<String, dynamic> gy) {
    final isi = harita(harita(gy['isi'])[_pencere]);
    final masalar = liste(widget.duzen['masalar']);
    final bolgeler = liste(widget.duzen['bolgeler']);
    final garsonlar = liste(gy['garsonlar']);
    final yog = <int, int>{};
    for (final e in isi.entries) {
      final kisi = harita(e.value);
      var top = 0;
      for (final k in kisi.entries) {
        if (_isiGarson == 0 || tamOku(k.key) == _isiGarson) top += tamOku(k.value);
      }
      yog[tamOku(e.key)] = top;
    }
    final enCok = yog.values.fold<int>(0, (a, b) => b > a ? b : a);
    Color renk(int p) => p >= 90 ? const Color(0xFFEF4444) : (p >= 70 ? const Color(0xFFF97316) : (p >= 40 ? const Color(0xFFEAB308) : const Color(0xFF3B82F6)));
    final bolgeIdler = [for (final b in bolgeler) tamOku(b['id'])];
    final bolgesiz = masalar.where((m) => !bolgeIdler.contains(tamOku(m['bolge_id']))).toList();
    Widget grup(String ad, List<Map<String, dynamic>> ms) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KBaslik(ad, ikon: Icons.chair_outlined, alt: '${ms.length} masa'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final m in ms)
              Builder(builder: (_) {
                final n = yog[tamOku(m['id'])] ?? 0;
                final p = enCok > 0 ? (n * 100 / enCok).round() : 0;
                final r = n == 0 ? t.sub : renk(p);
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _masaDetay(m),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                    decoration: BoxDecoration(color: r.withValues(alpha: n == 0 ? .06 : .18), borderRadius: BorderRadius.circular(12), border: Border.all(color: r.withValues(alpha: .5))),
                    child: Column(children: [
                      Text(metinOku(m['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(n == 0 ? 'işlem yok' : '%$p · $n', style: TextStyle(color: r, fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                );
              }),
          ]),
          const SizedBox(height: 12),
        ]);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Sipariş, servis ve hesap işlemlerinden hesaplanır; garsonun işlem yaptığı masayı gösterir. Yüzde, seçilen aralıktaki en yoğun masaya göredir (en yoğun masa %100). Masaya dokunun: hesapları görün.',
            style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
      KCipler(secenekler: const [('saat', 'Son 1 Saat'), ('bugun', 'Bugün'), ('hafta', 'Bu Hafta')], secili: _pencere, onSec: (x) => setState(() => _pencere = x)),
      KSecim<int>('Garson', deger: _isiGarson, secenekler: [(0, 'Tüm garsonlar'), for (final g in garsonlar) (tamOku(g['id']), metinOku(g['ad']))], onSec: (v) => setState(() => _isiGarson = v ?? 0)),
      Wrap(spacing: 10, runSpacing: 6, children: [
        for (final (r, e) in const [(Color(0xFFEF4444), '%90–100 Çok yoğun'), (Color(0xFFF97316), '%70–90 Yoğun'), (Color(0xFFEAB308), '%40–70 Orta'), (Color(0xFF3B82F6), '%0–40 Sakin')])
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: r, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(e, style: TextStyle(color: t.sub2, fontSize: 12)),
          ]),
      ]),
      const SizedBox(height: 12),
      if (masalar.isEmpty)
        const KBos(ikon: Icons.table_restaurant_outlined, baslik: 'Masa yok', aciklama: 'Isı haritası için önce İşletme Düzeni > Masa Planı\'ndan masa ekleyin.')
      else ...[
        for (final b in bolgeler)
          if (masalar.any((m) => tamOku(m['bolge_id']) == tamOku(b['id']))) grup(metinOku(b['ad']), masalar.where((m) => tamOku(m['bolge_id']) == tamOku(b['id'])).toList()),
        if (bolgesiz.isNotEmpty) grup('Bölgesiz', bolgesiz),
        if (enCok == 0)
          Text('Seçilen aralıkta${_isiGarson > 0 ? ' bu garsonun' : ''} masa işlemi yok; tüm masalar "işlem yok" görünür.', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ],
    ];
  }

  Future<void> _masaDetay(Map<String, dynamic> m) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    KopruCevap c;
    try {
      c = await KopruApi.al(tok, '/garson-yonetimi/masa-detay', q: {'masa_id': '${tamOku(m['id'])}', 'pencere': _pencere, 'garson_id': '$_isiGarson'});
    } on ApiYetkiHatasi {
      return;
    }
    if (!mounted) return;
    if (!c.ok) {
      kToast(context, c.hata ?? 'Masa bilgisi alınamadı.', hata: true);
      return;
    }
    final masa = harita(c.j['masa']);
    final oz = harita(c.j['ozet']);
    final hesap = liste(c.j['hesaplar']);
    const pAd = {'saat': 'Son 1 saat', 'bugun': 'Bugün', 'hafta': 'Bu hafta'};
    await kAltSayfa(context,
        baslik: '${metinOku(masa['ad'])}${metinOku(masa['bolge']).isNotEmpty ? ' · ${metinOku(masa['bolge'])}' : ''}',
        icerik: (sc) {
          final t = sc.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${pAd[_pencere]} · ${tamOku(masa['kapasite'])} kişilik', style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 10),
            KKpiIzgara([
              KKpi(etiket: 'Açılan hesap', deger: '${tamOku(oz['acilis'])}', renk: t.mavi),
              KKpi(etiket: 'Ciro', deger: tl(oz['ciro'], kisa: true), renk: t.yesil),
              KKpi(etiket: 'Açık tutar', deger: tl(oz['acik_tutar'], kisa: true), renk: t.amber),
              KKpi(etiket: 'Ort. hesap', deger: tl(oz['ort'], kisa: true), renk: t.mor1),
              KKpi(etiket: 'Ort. süre', deger: oz['ort_sure'] == null ? '—' : '${tamOku(oz['ort_sure'])} dk', alt: '${tamOku(oz['misafir'])} misafir', renk: t.sub2),
            ]),
            if (hesap.isEmpty)
              const KBos(ikon: Icons.receipt_long_outlined, baslik: 'Bu aralıkta hesap yok', aciklama: 'Seçilen zaman aralığında bu masada açılan ya da kapanan hesap bulunmuyor.')
            else
              for (final h in hesap)
                KSatir(
                  baslik: '${metinOku(h['tarih'])} ${metinOku(h['acilis'])}${h['kapanis'] != null ? '–${metinOku(h['kapanis'])}' : ''} · ${metinOku(h['garson'])}',
                  alt: '${tamOku(h['sure_dk'])} dk · ${tamOku(h['misafir'])} misafir · ${tamOku(h['kalem'])} ürün${metinOku(h['odeme']).isNotEmpty ? ' · ${metinOku(h['odeme'])}' : ''}${h['once'] == true ? ' · aralıktan önce açıldı' : ''}',
                  sag: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(tl(h['tutar']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                    KRozet(metinOku(h['durum']) == 'acik' ? 'Açık' : (metinOku(h['durum']) == 'odendi' ? 'Ödendi' : metinOku(h['durum'])),
                        renk: metinOku(h['durum']) == 'acik' ? t.amber : (metinOku(h['durum']) == 'odendi' ? t.yesil : t.sub)),
                  ]),
                ),
          ]);
        });
  }

  // ───────── PERFORMANS RAPORU ─────────
  List<Widget> _rapor(TemaProvider t, Map<String, dynamic> gy) {
    final perf = liste(gy['performans']);
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('Skor, dönemin en iyi garsonuna göre hesaplanır: ciro %50, ürün sayısı %30, adisyon sayısı %20.', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
      _donemSec(_perf, (x) {
        setState(() => _perf = x);
        _yukle();
      }),
      if (perf.isEmpty)
        const KBos(ikon: Icons.query_stats, baslik: 'Bu dönemde veri yok', aciklama: 'Seçilen dönemde garson adına açılmış/kapatılmış adisyon yok. Dönemi "Bu Ay" yaparak deneyin.')
      else if (genisMi(context))
        KKart(
          child: KTablo(
            basliklar: const ['#', 'Garson', 'Skor', 'Adisyon', 'Ciro', 'Ürün', 'Ort. Adisyon', 'Ort. Masa Süresi', 'Adım'],
            sagaYasla: const {2, 3, 4, 5, 6, 7, 8},
            satirlar: [
              for (var i = 0; i < perf.length; i++)
                [
                  '${i + 1}', metinOku(perf[i]['ad']), '${tamOku(perf[i]['skor'])}', '${tamOku(perf[i]['adisyon'])}', tl(perf[i]['ciro']), '${tamOku(perf[i]['kalem'])}',
                  tl(perf[i]['ort_adisyon']), perf[i]['masa_dk'] == null ? '—' : '${tamOku(perf[i]['masa_dk'])} dk', sayiYaz(perf[i]['adim']),
                ],
            ],
          ),
        )
      else
        for (var i = 0; i < perf.length; i++)
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${i + 1}. ${metinOku(perf[i]['ad'])}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                KRozet('Skor ${tamOku(perf[i]['skor'])}', renk: t.mor1),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: (sayiOku(perf[i]['skor']) / 100).clamp(0.0, 1.0), color: t.mor1, backgroundColor: t.mor1.withValues(alpha: .12), minHeight: 6),
              const SizedBox(height: 8),
              Text(
                '${tamOku(perf[i]['adisyon'])} adisyon · ${tl(perf[i]['ciro'])} · ${tamOku(perf[i]['kalem'])} ürün\n'
                'Ort. adisyon ${tl(perf[i]['ort_adisyon'])} · Ort. masa ${perf[i]['masa_dk'] == null ? '—' : '${tamOku(perf[i]['masa_dk'])} dk'} · ${sayiYaz(perf[i]['adim'])} adım',
                style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4),
              ),
            ]),
          ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => _ac('/garson-performans', 'Garson Performansı'), icon: const Icon(Icons.arrow_forward), label: const Text('Detaylı Garson Karnesi')),
      ),
    ];
  }

  // ───────── AYARLAR ─────────
  List<Widget> _ayarlar(TemaProvider t) {
    const l = [
      ('/personel', Icons.badge_outlined, 'Personel & Maaş', 'Kişi bilgileri, PIN, aktif/pasif'),
      ('/ik-vardiya', Icons.calendar_month_outlined, 'Vardiya Planlama', 'Haftalık garson vardiyaları'),
      ('/puantaj', Icons.schedule, 'Puantaj', 'Mesai giriş ve çıkışları'),
      ('/garson-cagrilari', Icons.notifications_active_outlined, 'Garson Çağrıları', 'Masadan gelen çağrılar'),
      ('/garson-performans', Icons.emoji_events_outlined, 'Garson Karnesi', 'Saatlik dağılım ve adım'),
    ];
    return [
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          for (final (u, ik, b, a) in l)
            KSatir(baslik: b, alt: a, solIkon: KIkon(ik, renk: t.mor1), sag: Icon(Icons.chevron_right, color: t.sub), onTap: () => _ac(u, b)),
        ]),
      ),
    ];
  }

  void _ac(String yol, String ad) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(yol, ad)));
}
