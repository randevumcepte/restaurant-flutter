import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const Map<String, (String, Color, IconData)> kSiparisDurum = {
  'taslak': ('Taslak', Color(0xFF64748B), Icons.edit_note),
  'gonderildi': ('Gönderildi', Color(0xFF4F46E5), Icons.send),
  'onaylandi': ('Onaylandı', Color(0xFF06B6D4), Icons.verified_outlined),
  'kismi': ('Kısmi Teslim', Color(0xFFF59E0B), Icons.inventory_outlined),
  'tamamlandi': ('Tamamlandı', Color(0xFF10B981), Icons.check_circle_outline),
  'iptal': ('İptal', Color(0xFFF43F5E), Icons.cancel_outlined),
  'siparis': ('Sipariş Verildi', Color(0xFF4F46E5), Icons.shopping_cart_checkout),
};

KRozet siparisDurumRozet(String d) {
  final x = kSiparisDurum[d];
  return KRozet(x?.$1 ?? d, renk: x?.$2 ?? const Color(0xFF64748B), ikon: x?.$3);
}

/// Web /satinalma-siparis — satın alma siparişleri (PO): liste, durum filtreleri, hızlı filtre (geciken / yakın / onay bekleyen), yeni sipariş.
class SatinalmaSiparisScreen extends StatefulWidget {
  const SatinalmaSiparisScreen({super.key});
  @override
  State<SatinalmaSiparisScreen> createState() => _SatinalmaSiparisScreenState();
}

class _SatinalmaSiparisScreenState extends State<SatinalmaSiparisScreen> {
  String _durum = 'hepsi';
  String _hizli = '';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/satinalma-siparis',
      baslik: 'Satın Alma Siparişleri',
      ikon: Icons.shopping_cart_checkout,
      govde: _govde,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        heroTag: 'sas_yeni',
        onPressed: () async {
          final id = await kAltSayfa<int>(context, baslik: 'Yeni Satın Alma Siparişi', icerik: (c) => _YeniSiparisForm(veri: v));
          if (id != null && context.mounted) {
            if (id > 0) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiparisDetayScreen(id: id)));
            yenile();
          }
        },
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Yeni Sipariş', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  int _gunFark(dynamic tarih) {
    final d = DateTime.tryParse(metinOku(tarih));
    if (d == null) return 9999;
    final b = DateTime.now();
    return DateTime(d.year, d.month, d.day).difference(DateTime(b.year, b.month, b.day)).inDays;
  }

  String _hizliEtiket(Map<String, dynamic> s) {
    var h = '';
    if (metinOku(s['beklenen_teslim']).isNotEmpty && !['tamamlandi', 'iptal'].contains(s['durum'])) {
      final f = _gunFark(s['beklenen_teslim']);
      if (f < 0) {
        h = 'geciken';
      } else if (f <= 2) {
        h = 'yakin';
      }
    }
    if (s['onay_durum'] == 'bekliyor') h += ' onay';
    return h;
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final l = liste(v['siparisler']);
    final simdi = DateTime.now();
    final buAy = l.where((s) {
      final d = DateTime.tryParse(metinOku(s['tarih']));
      return d != null && d.year == simdi.year && d.month == simdi.month && s['durum'] != 'iptal';
    }).fold<double>(0, (a, s) => a + sayiOku(s['genel_toplam']));
    final say = {for (final k in kSiparisDurum.keys) k: l.where((s) => s['durum'] == k).length};
    final geciken = l.where((s) => _hizliEtiket(s).contains('geciken')).length;
    final yakin = l.where((s) => _hizliEtiket(s).contains('yakin')).length;
    final onay = l.where((s) => s['onay_durum'] == 'bekliyor').length;
    final tedSay = l.map((s) => s['tedarikci_id']).where((x) => x != null).toSet().length;
    final gorunen = l.where((s) {
      if (_durum != 'hepsi' && s['durum'] != _durum) return false;
      if (_hizli.isNotEmpty && !_hizliEtiket(s).contains(_hizli)) return false;
      return saIcerir('${s['siparis_no']} ${s['tedarikci']}', _ara);
    }).toList();
    final gorunenTop = gorunen.fold<double>(0, (a, s) => a + sayiOku(s['genel_toplam']));
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Bu ay satın alma', deger: tl(buAy, kisa: true), alt: '${l.length} sipariş · $tedSay tedarikçi', ikon: Icons.shopping_cart_checkout, renk: t.mor1),
        KKpi(etiket: 'Gönderildi', deger: '${say['gonderildi']}', ikon: Icons.send, renk: kSiparisDurum['gonderildi']!.$2, onTap: () => setState(() => _durum = 'gonderildi')),
        KKpi(etiket: 'Onaylandı', deger: '${say['onaylandi']}', ikon: Icons.verified_outlined, renk: kSiparisDurum['onaylandi']!.$2, onTap: () => setState(() => _durum = 'onaylandi')),
        KKpi(etiket: 'Kısmi', deger: '${say['kismi']}', ikon: Icons.inventory_outlined, renk: kSiparisDurum['kismi']!.$2, onTap: () => setState(() => _durum = 'kismi')),
        KKpi(etiket: 'Tamamlanan', deger: '${say['tamamlandi']}', ikon: Icons.check_circle_outline, renk: kSiparisDurum['tamamlandi']!.$2, onTap: () => setState(() => _durum = 'tamamlandi')),
      ]),
      KCipler(secenekler: [
        ('hepsi', 'Tümü ${l.length}'),
        for (final k in ['taslak', 'gonderildi', 'onaylandi', 'kismi', 'tamamlandi', 'iptal']) (k, '${kSiparisDurum[k]!.$1} ${say[k]}'),
      ], secili: _durum, onSec: (k) => setState(() => _durum = k)),
      if (geciken + yakin + onay > 0)
        KCipler(secenekler: [
          ('', 'Hızlı filtre yok'),
          if (geciken > 0) ('geciken', 'Geciken ($geciken)'),
          if (yakin > 0) ('yakin', '2 gün içinde ($yakin)'),
          if (onay > 0) ('onay', 'Onay bekliyor ($onay)'),
        ], secili: _hizli, onSec: (k) => setState(() => _hizli = k)),
      KAra(ipucu: 'Sipariş no veya tedarikçi ara…', onDegis: (s) => setState(() => _ara = s)),
      if (_durum != 'hepsi' || _hizli.isNotEmpty || _ara.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text('${gorunen.length} sipariş görünüyor · Toplam: ${tl(gorunenTop)}', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      if (l.isEmpty)
        const KBos(baslik: 'Henüz satın alma siparişi yok', aciklama: '"Yeni Sipariş" ile başlayın ya da Satın Alma Talepleri / Sipariş Önerisi ekranından sipariş oluşturun.', ikon: Icons.shopping_cart_outlined)
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtreye uygun sipariş yok', aciklama: 'Filtreyi "Tümü" yapıp tekrar deneyin.', ikon: Icons.filter_alt_off_outlined)
      else
        SaIzgara([for (final s in gorunen) _kart(s, t, yenile)], minGenislik: 440),
    ]);
  }

  Widget _kart(Map<String, dynamic> s, TemaProvider t, Future<void> Function() yenile) {
    final d = metinOku(s['durum']);
    final ai = metinOku(s['siparis_no']).startsWith('AI-') || metinOku(s['notlar']).contains('AI');
    final tedYok = s['tedarikci_id'] == null;
    final eksik = d == 'taslak' && (tedYok || sayiOku(s['genel_toplam']) <= 0);
    String teslim = '';
    Color teslimRenk = t.sub;
    if (metinOku(s['beklenen_teslim']).isNotEmpty) {
      if (!['tamamlandi', 'iptal'].contains(d)) {
        final f = _gunFark(s['beklenen_teslim']);
        if (f < 0) {
          teslim = '${-f} gün geciken';
          teslimRenk = t.kirmizi;
        } else if (f == 0) {
          teslim = 'Bugün teslim';
          teslimRenk = t.amber;
        } else if (f == 1) {
          teslim = 'Yarın teslim';
          teslimRenk = t.amber;
        } else if (f <= 7) {
          teslim = '$f gün sonra teslim';
        } else {
          teslim = '${tarihYaz(s['beklenen_teslim'], saat: false)} teslim';
        }
      } else {
        teslim = '${tarihYaz(s['beklenen_teslim'], saat: false)} teslim';
      }
    }
    final od = metinOku(s['onay_durum']);
    return KKart(
      renk: kSiparisDurum[d]?.$2,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SiparisDetayScreen(id: tamOku(s['id']))));
        yenile();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(metinOku(s['siparis_no']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
          if (ai) ...[const SizedBox(width: 6), KRozet('AI', renk: t.mor1, ikon: Icons.auto_awesome_outlined)],
          const Spacer(),
          siparisDurumRozet(d),
        ]),
        const SizedBox(height: 4),
        Text(tedYok ? 'Tedarikçi seçilmedi' : metinOku(s['tedarikci'], '—'), style: TextStyle(color: tedYok ? t.sub : t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
        if (eksik)
          Text(tedYok && sayiOku(s['genel_toplam']) <= 0 ? 'Tedarikçi + fiyat eksik' : (tedYok ? 'Tedarikçi eksik' : 'Fiyat eksik'), style: TextStyle(color: t.amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 4, children: [
          if (teslim.isNotEmpty) KRozet(teslim, renk: teslimRenk, ikon: Icons.event_outlined),
          if (od == 'onaylandi') KRozet('Tedarikçi onayladı', renk: t.yesil, ikon: Icons.verified_outlined),
          if (od == 'bekliyor') KRozet('Onay bekliyor', renk: t.amber, ikon: Icons.hourglass_bottom),
          if (od == 'degisiklik') KRozet('Değişiklik istendi', renk: t.kirmizi, ikon: Icons.edit_outlined),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(tarihYaz(s['created_at'] ?? s['tarih']), style: TextStyle(color: t.sub, fontSize: 12.5))),
          Text(tl(s['genel_toplam']), style: TextStyle(color: sayiOku(s['genel_toplam']) <= 0 ? t.sub : t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Yeni sipariş formu ─────────────────────────
class _Satir {
  int? mid;
  int? birim;
  final mik = TextEditingController();
  final fiyat = TextEditingController();
  final isk = TextEditingController();
  final kdv = TextEditingController(text: '10');
}

class _YeniSiparisForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  const _YeniSiparisForm({required this.veri});
  @override
  State<_YeniSiparisForm> createState() => _YeniSiparisFormState();
}

class _YeniSiparisFormState extends State<_YeniSiparisForm> {
  int? _ted;
  String _tarih = bugunStr();
  String _teslim = '';
  final _not = TextEditingController();
  final List<_Satir> _s = [_Satir()];
  bool _gonderiyor = false;

  late final _malz = liste(widget.veri['malzemeler']);
  late final _birim = liste(widget.veri['birimler']);

  (double, double) _hesap() {
    double ara = 0, kdv = 0;
    for (final r in _s) {
      final brut = sayiOku(r.mik.text) * sayiOku(r.fiyat.text);
      final net = brut - brut * sayiOku(r.isk.text) / 100;
      ara += net;
      kdv += net * sayiOku(r.kdv.text) / 100;
    }
    return (ara, kdv);
  }

  Future<void> _kaydet(bool gonder) async {
    final kal = <Map<String, dynamic>>[];
    for (final r in _s) {
      if (r.mid == null || sayiOku(r.mik.text) <= 0) continue;
      kal.add({'malzeme_id': r.mid, 'miktar': sayiOku(r.mik.text), 'alis_birim_id': r.birim ?? 0, 'birim_fiyat': sayiOku(r.fiyat.text), 'iskonto_yuzde': sayiOku(r.isk.text), 'kdv_yuzde': sayiOku(r.kdv.text)});
    }
    if (kal.isEmpty) return kToast(context, 'En az bir kalem ekleyin (malzeme + miktar).', hata: true);
    setState(() => _gonderiyor = true);
    final c = await saGonder(context, '/satinalma-siparis/ekle', {
      'tedarikci_id': _ted ?? '', 'tarih': _tarih, 'beklenen_teslim': _teslim, 'notlar': _not.text.trim(), 'gonder': gonder ? '1' : '', 'kalemler': jsonEncode(kal),
    }, json: false, sessiz: true);
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c == null || !c.ok) return;
    final y = metinOku(c.j['yonlendir']);
    if (!y.startsWith('/satinalma-siparis-detay')) {
      kToast(context, metinOku(c.j['hata'], 'Sipariş oluşturulamadı.'), hata: true);
      return;
    }
    kToast(context, gonder ? 'Sipariş oluşturuldu ve gönderildi olarak işaretlendi.' : 'Sipariş taslağı kaydedildi.');
    Navigator.pop(context, 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final (ara, kdv) = _hesap();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KSecim<int>('Tedarikçi', deger: _ted, secenekler: [for (final x in liste(widget.veri['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (v) => setState(() => _ted = v)),
      Row(children: [
        Expanded(child: KSatir(baslik: 'Sipariş tarihi', alt: tarihYaz(_tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
          final s = await saTarihSec(context, ilk: _tarih);
          if (s != null) setState(() => _tarih = s);
        })),
        const SizedBox(width: 8),
        Expanded(child: KSatir(baslik: 'Beklenen teslim', alt: _teslim.isEmpty ? 'Seçilmedi' : tarihYaz(_teslim, saat: false), sag: const Icon(Icons.event_available_outlined), onTap: () async {
          final s = await saTarihSec(context, ilk: _teslim);
          if (s != null) setState(() => _teslim = s);
        })),
      ]),
      const SizedBox(height: 10),
      Text('Kalemler', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      for (var i = 0; i < _s.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: KSecim<int>('Malzeme', deger: _s[i].mid, secenekler: [for (final m in _malz) (tamOku(m['id']), metinOku(m['ad']))], onSec: (v) {
                  setState(() {
                    _s[i].mid = v;
                    final m = _malz.firstWhere((x) => tamOku(x['id']) == v, orElse: () => const {});
                    final b = tamOku(m['temel_birim_id']);
                    if (b > 0) _s[i].birim = b;
                  });
                }),
              ),
              IconButton(onPressed: _s.length == 1 ? null : () => setState(() => _s.removeAt(i)), icon: Icon(Icons.close, color: t.sub)),
            ]),
            Row(children: [
              Expanded(child: KAlan('Miktar', _s[i].mik, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KSecim<int>('Birim', deger: _s[i].birim, secenekler: [for (final b in _birim) (tamOku(b['id']), metinOku(b['kisaltma'], metinOku(b['ad'])))], onSec: (v) => setState(() => _s[i].birim = v))),
            ]),
            Row(children: [
              Expanded(child: KAlan('Birim fiyat', _s[i].fiyat, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('İsk. %', _s[i].isk, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('KDV %', _s[i].kdv, klavye: const TextInputType.numberWithOptions(decimal: true))),
            ]),
          ]),
        ),
      KButon('Kalem Ekle', ikon: Icons.add, ikincil: true, onTap: () => setState(() => _s.add(_Satir()))),
      const SizedBox(height: 10),
      SaDeger('Ara toplam', tl(ara)),
      SaDeger('KDV', tl(kdv)),
      SaDeger('Genel', tl(ara + kdv), kalin: true),
      TextButton(onPressed: () => setState(() {}), child: const Text('Toplamı yeniden hesapla')),
      KAlan('Not (opsiyonel)', _not, ipucu: 'Sipariş notu…'),
      Row(children: [
        Expanded(child: KButon('Taslak Kaydet', ikon: Icons.save_outlined, ikincil: true, yukleniyor: _gonderiyor, onTap: () => _kaydet(false))),
        const SizedBox(width: 8),
        Expanded(child: KButon('Oluştur & Gönder', ikon: Icons.send, yukleniyor: _gonderiyor, onTap: () => _kaydet(true))),
      ]),
    ]);
  }
}

// ───────────────────────── Sipariş detayı (/satinalma-siparis-detay) ─────────────────────────
class SiparisDetayScreen extends StatefulWidget {
  final int id;
  const SiparisDetayScreen({super.key, required this.id});
  @override
  State<SiparisDetayScreen> createState() => _SiparisDetayScreenState();
}

class _DSatir {
  int? mid;
  int birim = 0;
  final mik = TextEditingController();
  final fiyat = TextEditingController();
  Map<String, dynamic> bilgi = const {};
}

class _SiparisDetayScreenState extends State<SiparisDetayScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  int? _ted;
  String _teslim = '';
  final _not = TextEditingController();
  List<_DSatir>? _satirlar;
  bool _mesgul = false;

  void _hazirla(Map<String, dynamic> v) {
    if (_satirlar != null) return;
    final s = harita(v['s']);
    _ted = s['tedarikci_id'] == null ? null : tamOku(s['tedarikci_id']);
    _teslim = metinOku(s['beklenen_teslim']).length >= 10 ? metinOku(s['beklenen_teslim']).substring(0, 10) : '';
    _not.text = metinOku(s['notlar']);
    _satirlar = [
      for (final k in liste(v['kalemler']))
        _DSatir()
          ..mid = tamOku(k['malzeme_id'])
          ..birim = tamOku(k['alis_birim_id'])
          ..mik.text = sayiYaz(k['miktar']).replaceAll('.', '')
          ..fiyat.text = '${sayiOku(k['birim_fiyat'])}'
          ..bilgi = k,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _ekran,
      yol: '/satinalma-siparis-detay',
      q: {'id': '${widget.id}'},
      baslik: 'Sipariş Detayı',
      ikon: Icons.receipt_long_outlined,
      govde: _govde,
    );
  }

  Future<void> _yenile() async {
    _satirlar = null;
    await _ekran.currentState?.yukle();
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final s = harita(v['s']);
    if (s.isEmpty) return const KBos(baslik: 'Sipariş bulunamadı', aciklama: 'Sipariş silinmiş ya da başka şubeye ait olabilir.');
    _hazirla(v);
    final d = metinOku(s['durum']);
    final duzen = d == 'taslak';
    final tarihDegisir = ['gonderildi', 'onaylandi', 'siparis', 'kismi'].contains(d);
    final ted = harita(v['tedarikci']);
    final ist = harita(v['tedarikciIstat']);
    final od = metinOku(s['onay_durum']);
    final onayLink = metinOku(s['onay_token']).isNotEmpty ? '${AppConfig.baseUrl}/siparis/onay/${s['onay_token']}' : '';
    final malz = liste(v['malzemeler']);
    double gt = 0;
    for (final r in _satirlar!) {
      gt += sayiOku(r.mik.text) * sayiOku(r.fiyat.text);
    }
    return KGovde(yenile: _yenile, maxGenislik: 960, children: [
      Row(children: [
        Expanded(child: Text(metinOku(s['siparis_no']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 18))),
        siparisDurumRozet(d),
      ]),
      const SizedBox(height: 10),
      KKpiIzgara([
        KKpi(etiket: 'Genel toplam', deger: tl(duzen ? gt : s['genel_toplam']), alt: '${_satirlar!.length} kalem', ikon: Icons.payments_outlined, renk: t.mor1),
        KKpi(etiket: 'Beklenen teslim', deger: metinOku(s['beklenen_teslim']).isEmpty ? 'Belirtilmemiş' : tarihYaz(s['beklenen_teslim'], saat: false), alt: 'Oluşturma: ${tarihYaz(s['tarih'], saat: false)}', ikon: Icons.event_outlined, renk: t.mavi),
        if (ist.isNotEmpty) KKpi(etiket: 'Tedarikçi son 30 gün', deger: '${ist['siparis_say']} sipariş', alt: 'Harcama: ${tl(ist['toplam_tutar'], kisa: true)}', ikon: Icons.storefront_outlined, renk: t.yesil),
      ]),
      // Aksiyonlar
      if (duzen)
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('Kaydet', ikon: Icons.save_outlined, yukleniyor: _mesgul, onTap: () => _kaydet()),
          KButon('Tedarikçiye Gönder (WA + Mail)', ikon: Icons.send, renk: t.yesil, yukleniyor: _mesgul, onTap: () => _gonder(false)),
          KButon('İptal Et', ikon: Icons.cancel_outlined, renk: t.kirmizi, ikincil: true, onTap: () => _durum('iptal')),
        ])
      else if (tarihDegisir)
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('Tamamlandı İşaretle', ikon: Icons.check_circle_outline, ikincil: true, onTap: () => _durum('tamamlandi')),
          KButon('Mal Kabul Oluştur', ikon: Icons.inventory_outlined, onTap: () async {
            await saAc(context, '/mal-kabul?siparis_id=${s['id']}', 'Mal Kabul');
            _yenile();
          }),
        ]),
      const SizedBox(height: 12),
      if (!duzen) SaBilgi('Bu sipariş ${(kSiparisDurum[d]?.$1 ?? d).toLowerCase()} durumunda — kalemler artık düzenlenemez${tarihDegisir ? '; teslim tarihi değiştirilebilir' : ''}.', ikon: Icons.lock_outline),
      if (!duzen && d != 'iptal')
        KKart(
          renk: od == 'onaylandi' ? t.yesil : (od == 'degisiklik' ? t.kirmizi : t.amber),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                od == 'onaylandi'
                    ? 'Tedarikçi siparişi ve teslim tarihini onayladı${metinOku(s['onay_at']).isNotEmpty ? ' · ${tarihYaz(s['onay_at'])}' : ''}'
                    : (od == 'degisiklik' ? 'Tedarikçi değişiklik istedi' : (od == 'bekliyor' ? 'Tedarikçi onayı bekleniyor' : 'Tedarikçiye onay bağlantısı gönderilmedi')),
                style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
            if (od == 'degisiklik' && metinOku(s['tedarikci_teslim']).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Önerdiği teslim tarihi: ${tarihYaz(s['tedarikci_teslim'], saat: false)}', style: TextStyle(color: t.ink, fontSize: 13.5)),
              if (tarihDegisir)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: KButon('Bu tarihi kabul et', ikon: Icons.event_available_outlined, onTap: () => _tarihKaydet(metinOku(s['tedarikci_teslim']).substring(0, 10))),
                ),
            ],
            if (od == 'degisiklik' && metinOku(s['onay_not']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Notu: ${s['onay_not']}', style: TextStyle(color: t.sub2, fontSize: 13))),
            if (tarihDegisir) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (onayLink.isNotEmpty) KButon('Onay bağlantısını kopyala', ikon: Icons.content_copy, ikincil: true, onTap: () => saKopyala(context, onayLink, 'Onay bağlantısı kopyalandı — tedarikçiye iletin.')),
                KButon(s['onay_token'] != null ? 'Bağlantıyı yeniden gönder' : 'Onay bağlantısı gönder', ikon: Icons.send, ikincil: true, onTap: () => _gonder(true)),
                KButon('Teslim tarihini değiştir', ikon: Icons.event_outlined, ikincil: true, onTap: () async {
                  final yeni = await saTarihSec(context, ilk: _teslim, enErken: DateTime.now());
                  if (yeni != null) _tarihKaydet(yeni);
                }),
              ]),
            ],
          ]),
        ),
      // Tedarikçi
      KBaslik('Tedarikçi', ikon: Icons.storefront_outlined),
      if (duzen)
        KSecim<int>('Tedarikçi', deger: _ted, secenekler: [for (final x in liste(v['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (x) => setState(() => _ted = x))
      else
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metinOku(ted['ad'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
            if (metinOku(ted['telefon']).isNotEmpty) Text('Telefon: ${ted['telefon']}', style: TextStyle(color: t.sub, fontSize: 13)),
            if (metinOku(ted['email']).isNotEmpty) Text('E-posta: ${ted['email']}', style: TextStyle(color: t.sub, fontSize: 13)),
          ]),
        ),
      if (duzen) ...[
        KSatir(
          baslik: 'Beklenen teslim',
          alt: _teslim.isEmpty ? 'Seçilmedi' : tarihYaz(_teslim, saat: false),
          sag: const Icon(Icons.event_outlined),
          onTap: () async {
            final x = await saTarihSec(context, ilk: _teslim);
            if (x != null) setState(() => _teslim = x);
          },
        ),
        const SizedBox(height: 8),
        KAlan('Not', _not, satir: 2),
      ] else if (metinOku(s['notlar']).isNotEmpty)
        SaBilgi('Not: ${s['notlar']}', ikon: Icons.sticky_note_2_outlined),
      // Kalemler
      KBaslik('Kalemler (${_satirlar!.length})', ikon: Icons.inventory_2_outlined, sag: duzen ? TextButton.icon(onPressed: () => setState(() => _satirlar!.add(_DSatir())), icon: const Icon(Icons.add), label: const Text('Kalem Ekle')) : null),
      if (_satirlar!.isEmpty) const KBos(baslik: 'Kalem yok', aciklama: 'Taslak siparişe "Kalem Ekle" ile malzeme ekleyin.'),
      for (var i = 0; i < _satirlar!.length; i++) _kalem(i, duzen, malz, t),
      if (duzen) Padding(padding: const EdgeInsets.only(top: 4), child: SaDeger('Genel toplam', tl(gt), kalin: true)),
    ]);
  }

  Widget _kalem(int i, bool duzen, List<Map<String, dynamic>> malz, TemaProvider t) {
    final r = _satirlar![i];
    final k = r.bilgi;
    final sa = harita(k['son_alis']);
    final mevcut = sayiOku(k['mevcut_stok']);
    final kritik = sayiOku(k['kritik_stok']);
    final bilgi = Wrap(spacing: 10, runSpacing: 4, children: [
      if (k.isNotEmpty) Text('Stok: ${sayiYaz(mevcut)}${kritik > 0 ? ' (kritik ${sayiYaz(kritik)})' : ''}', style: TextStyle(color: kritik > 0 && mevcut <= kritik ? t.kirmizi : t.sub, fontSize: 12.5)),
      if (sa.isNotEmpty) Text('Son alış: ${tl(sa['fiyat'])} · ${metinOku(sa['tedarikci'])} · ${tarihYaz(sa['tarih'], saat: false)}', style: TextStyle(color: t.sub, fontSize: 12.5)),
      if (sayiOku(k['teslim_edilen']) > 0) Text('Teslim alınan: ${sayiYaz(k['teslim_edilen'])}', style: TextStyle(color: t.yesil, fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]);
    if (!duzen) {
      return KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(metinOku(k['malzeme'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            Text('${sayiYaz(k['miktar'])} ${metinOku(k['birim'])} × ${tl(k['birim_fiyat'])}', style: TextStyle(color: t.sub2, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          bilgi,
          Align(alignment: Alignment.centerRight, child: Text(tl(sayiOku(k['miktar']) * sayiOku(k['birim_fiyat'])), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
        ]),
      );
    }
    return KKart(
      child: Column(children: [
        Row(children: [
          Expanded(
            child: KSecim<int>('Malzeme', deger: r.mid, secenekler: [for (final m in malz) (tamOku(m['id']), metinOku(m['ad']))], onSec: (x) {
              setState(() {
                r.mid = x;
                final m = malz.firstWhere((y) => tamOku(y['id']) == x, orElse: () => const {});
                r.birim = tamOku(m['temel_birim_id']);
                if (sayiOku(r.fiyat.text) <= 0 && sayiOku(m['guncel_maliyet']) > 0) r.fiyat.text = '${m['guncel_maliyet']}';
              });
            }),
          ),
          IconButton(tooltip: 'Sil', onPressed: () => setState(() => _satirlar!.removeAt(i)), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
        ]),
        Row(children: [
          Expanded(child: KAlan('Miktar', r.mik, klavye: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(child: KAlan('Birim fiyat', r.fiyat, klavye: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        bilgi,
      ]),
    );
  }

  Future<bool> _kaydet({bool sessiz = false}) async {
    final kal = <Map<String, dynamic>>[];
    for (final r in _satirlar ?? <_DSatir>[]) {
      if (r.mid == null || sayiOku(r.mik.text) <= 0) continue;
      kal.add({'malzeme_id': r.mid, 'alis_birim_id': r.birim, 'miktar': sayiOku(r.mik.text), 'birim_fiyat': sayiOku(r.fiyat.text)});
    }
    setState(() => _mesgul = true);
    final c = await saGonder(context, '/api/satinalma-siparis/kaydet',
        {'id': widget.id, 'tedarikci_id': _ted ?? 0, 'beklenen_teslim': _teslim.isEmpty ? null : _teslim, 'notlar': _not.text, 'kalemler': kal}, sessiz: sessiz);
    if (mounted) setState(() => _mesgul = false);
    return c?.ok == true;
  }

  Future<void> _gonder(bool gonderilmis) async {
    final ok = await kOnay(context, gonderilmis ? 'Onay bağlantısı yeniden gönderilsin mi?' : 'Sipariş tedarikçiye gönderilsin mi?',
        aciklama: gonderilmis ? null : 'Sipariş, onay bağlantısıyla tedarikçiye (e-posta + WhatsApp) gönderilecek.', evet: 'Gönder');
    if (!ok || !mounted) return;
    if (!gonderilmis && !await _kaydet(sessiz: true)) return;
    if (!mounted) return;
    final c = await saGonder(context, '/api/satinalma-siparis/gonder', {'id': widget.id}, sessiz: true);
    if (c?.ok != true || !mounted) return;
    final iletildi = c!.j['iletildi'] == true;
    kToast(context, metinOku(c.j['mesaj']), hata: !iletildi);
    if (!iletildi && metinOku(c.j['link']).isNotEmpty) await saKopyala(context, metinOku(c.j['link']), 'Onay bağlantısı kopyalandı — tedarikçiye iletin.');
    _yenile();
  }

  Future<void> _tarihKaydet(String tarih) async {
    final c = await saGonder(context, '/api/satinalma-siparis/kaydet', {'id': widget.id, 'beklenen_teslim': tarih});
    if (c?.ok != true || !mounted) return;
    if (metinOku(c!.j['link']).isNotEmpty) await saKopyala(context, metinOku(c.j['link']), 'Onay bağlantısı kopyalandı — tedarikçiye iletin.');
    _yenile();
  }

  Future<void> _durum(String d) async {
    const ad = {'iptal': 'iptal edilsin', 'tamamlandi': 'tamamlandı işaretlensin'};
    if (!await kOnay(context, 'Sipariş ${ad[d] ?? d} mi?', tehlikeli: d == 'iptal', evet: 'Evet')) return;
    if (!mounted) return;
    final c = await saGonder(context, '/api/satinalma-siparis/durum', {'id': widget.id, 'durum': d}, basari: 'Durum güncellendi.');
    if (c?.ok == true) _yenile();
  }
}
