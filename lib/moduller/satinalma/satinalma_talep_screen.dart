import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /satinalma-talep — Satın Alma Talepleri (talep aç, departman onayı, teklif, patrona gönder, sipariş).
/// Sunucu rol/yetkiye göre süzer; ekran web'in bayraklarını (patronMu, satinalmaci, onaylayabilir) aynen kullanır.
class SatinalmaTalepScreen extends StatefulWidget {
  final String url;
  const SatinalmaTalepScreen({super.key, this.url = '/satinalma-talep'});
  @override
  State<SatinalmaTalepScreen> createState() => _SatinalmaTalepScreenState();
}

class _SatinalmaTalepScreenState extends State<SatinalmaTalepScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  String _filtre = '';
  String _ara = '';
  bool _kopyaAcildi = false;
  bool _acAcildi = false;
  late final Map<String, String> _uq;

  @override
  void initState() {
    super.initState();
    _uq = Uri.parse(widget.url).queryParameters;
    _filtre = _uq['durum'] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _ekran,
      yol: '/satinalma-talep',
      q: _uq['kopya'] != null ? {'kopya': _uq['kopya']!} : null,
      baslik: 'Satın Alma Talepleri',
      ikon: Icons.assignment_outlined,
      govde: _govde,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        heroTag: 'sta_yeni',
        onPressed: () => _yeniTalep(v, yenile),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Yeni Talep', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final talepler = liste(v['talepler']);
    final ozet = harita(v['ozet']);
    final kritikler = liste(v['kritikler']);
    _sonSurec = harita(v['surec']);
    final patronMu = v['patronMu'] == true;
    final satinalmaci = v['satinalmaci'] == true;
    // ?kopya=ID → reddedilen talep forma dolu yüklenir (web ile aynı)
    if (!_kopyaAcildi && v['kopya'] is Map) {
      _kopyaAcildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _yeniTalep(v, yenile, kopya: harita(v['kopya'])));
    }
    // ?ac=ID → detay açılır
    final ac = int.tryParse(_uq['ac'] ?? '');
    if (!_acAcildi && ac != null && ac > 0) {
      _acAcildi = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _detay(ac, patronMu, satinalmaci, yenile));
    }
    final onayBek = talepler.where((x) => x['onaylayabilir'] == true).toList();
    final ozelSay = talepler.where((x) => metinOku(x['etkinlik_tarih']).isNotEmpty).length;
    final cipler = <(String, String)>[('', 'Tümü ${talepler.length}')];
    if (ozelSay > 0) cipler.add(('ozel', 'Özel gün $ozelSay'));
    for (final d in ['departman_onay', 'yeni', 'teklif', 'onayda', 'onaylandi', 'siparis', 'tamamlandi', 'reddedildi']) {
      final c = talepler.where((x) => x['durum'] == d).length;
      if (c > 0 || d == 'departman_onay' || d == 'reddedildi') {
        cipler.add((d, '${d == 'departman_onay' ? 'Onay Bekliyor' : kTalepDurum[d]!.$1} $c'));
      }
    }
    final gorunen = talepler.where((x) {
      final okD = _filtre.isEmpty || (_filtre == 'ozel' ? metinOku(x['etkinlik_tarih']).isNotEmpty : x['durum'] == _filtre);
      return okD && saIcerir('${x['departman']} ${x['isteyen_ad']} ${x['kalem_ozet']} ${x['etkinlik_ad'] ?? ''}', _ara);
    }).toList();

    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam Talep', deger: sayiYaz(ozet['toplam']), ikon: Icons.description_outlined, renk: t.mor1),
        KKpi(etiket: 'Beklemede', deger: sayiYaz(ozet['beklemede']), ikon: Icons.hourglass_top, renk: t.amber),
        KKpi(etiket: 'Onaylandı / Sipariş', deger: sayiYaz(ozet['onaylandi']), ikon: Icons.check_circle_outline, renk: t.yesil),
        KKpi(etiket: 'Tamamlandı', deger: sayiYaz(ozet['tamamlanan']), ikon: Icons.task_alt, renk: t.mavi),
      ]),
      if (onayBek.isNotEmpty) ...[
        KBaslik('${onayBek.length} talep onayınızı bekliyor', ikon: Icons.fact_check_outlined, renk: const Color(0xFF8B5CF6), alt: 'Ekibinizden gelen talepler — onaylayınca satın almaya gider.'),
        SaIzgara([for (final o in onayBek) _onayKart(o, yenile)], minGenislik: 360),
      ],
      if (kritikler.isNotEmpty)
        SaBilgi(
          '${kritikler.length} malzeme kritik seviyede: ${kritikler.take(6).map((k) => metinOku(k['ad'])).join(', ')}${kritikler.length > 6 ? '…' : ''}',
          renk: t.amber,
          ikon: Icons.warning_amber_outlined,
          sag: TextButton.icon(onPressed: () => _yeniTalep(v, yenile, kritik: true), icon: const Icon(Icons.playlist_add, size: 18), label: const Text('Kritikten Talep')),
        ),
      KCipler(secenekler: cipler, secili: _filtre, onSec: (k) => setState(() => _filtre = k)),
      KAra(ipucu: 'Departman / kişi / ürün ara…', onDegis: (s) => setState(() => _ara = s)),
      if (talepler.isEmpty)
        const KBos(baslik: 'Henüz talep yok', aciklama: 'Malzeme ihtiyacını "Yeni Talep" ile açın. Talep departman sorumlusu onayından sonra satın almaya düşer.', ikon: Icons.assignment_outlined)
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtreye uygun talep yok', aciklama: '"Tümü" çipine dönüp tekrar deneyin.', ikon: Icons.filter_alt_off_outlined)
      else
        SaIzgara([for (final x in gorunen) _talepKart(x, patronMu, satinalmaci, yenile)], minGenislik: 480),
    ]);
  }

  Widget _onayKart(Map<String, dynamic> o, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final acil = o['aciliyet'] == 'acil';
    return KKart(
      renk: acil ? t.kirmizi : const Color(0xFF8B5CF6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(o['departman'], 'Talep'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
          if (acil) KRozet('ACİL', renk: t.kirmizi),
          const SizedBox(width: 6),
          Text(gecenZaman(o['created_at']), style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 4),
        Text('${metinOku(o['isteyen_ad'], '—')} · #${o['id']} · ${o['kalem_sayisi']} kalem', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
          child: Text(metinOku(o['kalem_ozet'], '—'), style: TextStyle(color: t.ink, fontSize: 13)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: KButon('Onayla', ikon: Icons.check_circle_outline, renk: t.yesil, onTap: () => _deptKarar(o, true, yenile))),
          const SizedBox(width: 8),
          Expanded(child: KButon('Reddet', ikon: Icons.block, renk: t.kirmizi, ikincil: true, onTap: () => _deptKarar(o, false, yenile))),
        ]),
      ]),
    );
  }

  Future<void> _deptKarar(Map<String, dynamic> o, bool onay, Future<void> Function() yenile) async {
    final ozet = '${metinOku(o['departman'], 'Talep')}${metinOku(o['kalem_ozet']).isNotEmpty ? ' · ${o['kalem_ozet']}' : ''}';
    if (onay) {
      if (!await kOnay(context, 'Talep onaylansın mı?', aciklama: '$ozet — satın almaya iletilecek.', evet: 'Onayla')) return;
      if (!mounted) return;
      final c = await saGonder(context, '/satinalma-talep/dept-onayla', {'id': o['id']}, basari: 'Onaylandı — satın almaya iletildi.');
      if (c?.ok == true) yenile();
    } else {
      final sebep = await saMetinSor(context, 'Talep reddedilsin mi?',
          aciklama: ozet,
          ipucu: 'Red sebebi (zorunlu) — talebi açan bu sebebi görecek',
          hazirlar: const ['Stokta yeterli var', 'Miktar fazla, düzeltip tekrar gönder', 'Bütçe uygun değil', 'Başka tedarikçiden alınacak'],
          enAz: 3,
          evet: 'Reddet',
          tehlikeli: true);
      if (sebep == null || !mounted) return;
      final c = await saGonder(context, '/satinalma-talep/dept-reddet', {'id': o['id'], 'sebep': sebep}, basari: 'Talep reddedildi.');
      if (c?.ok == true) yenile();
    }
  }

  Widget _talepKart(Map<String, dynamic> x, bool patronMu, bool satinalmaci, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final durum = metinOku(x['durum']);
    final dedo = durum == 'departman_onay';
    final acil = x['aciliyet'] == 'acil';
    final renk = kTalepDurum[durum]?.$2 ?? t.sub;
    final sr = harita(_sonSurec[metinOku(x['id'])]);
    final etk = metinOku(x['etkinlik_tarih']);
    return KKart(
      renk: renk,
      onTap: dedo ? null : () => _detay(tamOku(x['id']), patronMu, satinalmaci, yenile),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('#${x['id']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
          if (acil) ...[const SizedBox(width: 6), KRozet('ACİL', renk: t.kirmizi)],
          const Spacer(),
          talepDurumRozet(durum),
        ]),
        const SizedBox(height: 6),
        Text(metinOku(x['departman'], 'Diğer'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
        if (etk.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: KRozet('${metinOku(x['etkinlik_ad'], 'Özel gün')} · ${tarihYaz(etk, saat: false)}', renk: const Color(0xFFEC4899), ikon: Icons.celebration_outlined),
          ),
        const SizedBox(height: 2),
        Text(metinOku(x['kalem_ozet']).isNotEmpty ? metinOku(x['kalem_ozet']) : '${x['kalem_sayisi'] ?? 0} kalem', style: TextStyle(color: t.sub, fontSize: 13)),
        if (durum == 'reddedildi' && metinOku(x['red_sebep']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('⛔ ${x['red_sebep']}${metinOku(x['karar_veren_ad']).isNotEmpty ? ' · ${x['karar_veren_ad']}' : ''}', style: TextStyle(color: t.kirmizi, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        if (sr.isNotEmpty) ...[
          const SizedBox(height: 8),
          _surecNoktalar(liste(sr['adimlar'])),
          const SizedBox(height: 3),
          Text('${metinOku(sr['etiket'])}${metinOku(sr['alt']).isNotEmpty ? ' · ${sr['alt']}' : ''}', style: TextStyle(color: sr['red'] == true ? t.kirmizi : t.sub2, fontSize: 12)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.person_outline, size: 15, color: t.sub),
          const SizedBox(width: 4),
          Expanded(child: Text('${metinOku(x['isteyen_ad'], '—')} · ${tarihYaz(x['created_at'])}', style: TextStyle(color: t.sub, fontSize: 12.5))),
          Text(x['tutar'] != null && sayiOku(x['tutar']) > 0 ? tl(x['tutar'], kisa: true) : 'teklif bekleniyor',
              style: TextStyle(color: x['tutar'] != null ? t.ink : t.sub, fontWeight: FontWeight.w700, fontSize: 13.5)),
        ]),
        if (dedo) ...[
          const SizedBox(height: 10),
          if (x['onaylayabilir'] == true)
            Row(children: [
              Expanded(child: KButon('Onayla', renk: t.yesil, onTap: () => _deptKarar(x, true, yenile))),
              const SizedBox(width: 8),
              Expanded(child: KButon('Reddet', renk: t.kirmizi, ikincil: true, onTap: () => _deptKarar(x, false, yenile))),
            ])
          else
            Text('Şef / sorumlu onayında', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ]),
    );
  }

  Map<String, dynamic> _sonSurec = const {};

  Widget _surecNoktalar(List<Map<String, dynamic>> adimlar) {
    final t = context.watch<TemaProvider>();
    return Row(children: [
      for (final a in adimlar)
        Expanded(
          child: Container(
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: switch (metinOku(a['durum'])) { 'tamam' => t.yesil, 'aktif' => t.amber, 'red' => t.kirmizi, _ => t.line },
            ),
          ),
        ),
    ]);
  }

  Future<void> _detay(int id, bool patronMu, bool satinalmaci, Future<void> Function() yenile) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TalepDetayScreen(id: id, patronMu: patronMu, satinalmaci: satinalmaci)));
    yenile();
  }

  Future<void> _yeniTalep(Map<String, dynamic> v, Future<void> Function() yenile, {Map<String, dynamic>? kopya, bool kritik = false}) async {
    final ok = await kAltSayfa<bool>(context, baslik: 'Yeni Satın Alma Talebi', icerik: (c) => _YeniTalepForm(veri: v, kopya: kopya, kritik: kritik));
    if (ok == true) yenile();
  }
}


// ───────────────────────── Yeni talep formu ─────────────────────────
class _YeniTalepForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Map<String, dynamic>? kopya;
  final bool kritik;
  const _YeniTalepForm({required this.veri, this.kopya, this.kritik = false});
  @override
  State<_YeniTalepForm> createState() => _YeniTalepFormState();
}

class _Kalem {
  int? mid;
  String ad = '';
  String birim = '';
  final TextEditingController mik = TextEditingController();
}

class _YeniTalepFormState extends State<_YeniTalepForm> {
  String _dept = 'Mutfak';
  String _acil = 'normal';
  final _not = TextEditingController();
  final List<_Kalem> _kalemler = [];
  bool _gonderiyor = false;
  late final List<Map<String, dynamic>> _malzemeler = liste(widget.veri['malzemeler']);
  late final List<String> _birimler = [for (final b in liste(widget.veri['birimler'])) metinOku(b['kisaltma'])].where((s) => s.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    if (widget.kopya != null) {
      final k = widget.kopya!;
      _acil = k['aciliyet'] == 'acil' ? 'acil' : 'normal';
      _not.text = metinOku(k['not']);
      for (final x in liste(k['kalemler'])) {
        _ekle(mid: tamOku(x['malzeme_id']), miktar: metinOku(x['miktar']), birim: metinOku(x['birim']));
      }
    } else if (widget.kritik) {
      _acil = 'acil';
      _not.text = 'Kritik stok — otomatik oluşturuldu.';
      for (final x in liste(widget.veri['kritikler'])) {
        _ekle(mid: tamOku(x['id']), miktar: metinOku(x['oneri']), birim: metinOku(x['birim']));
      }
    }
    if (_kalemler.isEmpty) _ekle();
  }

  void _ekle({int? mid, String miktar = '', String birim = ''}) {
    final k = _Kalem();
    if (mid != null && mid > 0) _malzemeSec(k, mid);
    if (birim.isNotEmpty) k.birim = birim;
    k.mik.text = miktar == '0' ? '' : miktar;
    _kalemler.add(k);
  }

  void _malzemeSec(_Kalem k, int? mid) {
    k.mid = mid;
    final m = _malzemeler.firstWhere((x) => tamOku(x['id']) == mid, orElse: () => const {});
    k.ad = metinOku(m['ad']);
    final b = metinOku(m['birim_kisaltma']);
    if (b.isNotEmpty) k.birim = b;
  }

  Future<void> _gonder() async {
    final kalemler = <Map<String, dynamic>>[];
    for (var i = 0; i < _kalemler.length; i++) {
      final k = _kalemler[i];
      if (k.mid == null) return kToast(context, '${i + 1}. satırda malzeme seçilmedi.', hata: true);
      final m = sayiOku(k.mik.text);
      if (m <= 0) return kToast(context, '${i + 1}. satırda geçerli miktar girin.', hata: true);
      kalemler.add({'malzeme_id': k.mid, 'ad': k.ad, 'miktar': m, 'birim': k.birim});
    }
    if (kalemler.isEmpty) return kToast(context, 'En az bir kalem ekleyin.', hata: true);
    setState(() => _gonderiyor = true);
    final c = await saGonder(context, '/satinalma-talep/olustur',
        {'departman': _dept, 'aciliyet': _acil, 'not': _not.text.trim().isEmpty ? null : _not.text.trim(), 'kalemler': kalemler},
        basari: 'Talep oluşturuldu.');
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c?.ok == true) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final birimSec = <(String, String)>[for (final b in _birimler) (b, b)];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.kopya != null) SaBilgi('Talep #${widget.kopya!['id']} forma yüklendi — düzeltip gönderin.', renk: t.mor1),
      if (widget.kritik) SaBilgi('${_kalemler.length} kritik kalem forma eklendi.', renk: t.amber, ikon: Icons.warning_amber_outlined),
      KSecim<String>('Departman', deger: _dept, secenekler: const [('Mutfak', 'Mutfak'), ('Bar', 'Bar'), ('İK', 'İK'), ('Temizlik', 'Temizlik'), ('Diğer', 'Diğer')], onSec: (s) => setState(() => _dept = s ?? 'Mutfak')),
      Text('Aciliyet', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      KCipler(secenekler: const [('normal', 'Normal'), ('acil', 'Acil')], secili: _acil, onSec: (s) => setState(() => _acil = s)),
      KAlan('Not / Açıklama (opsiyonel)', _not, ipucu: 'Ör. Bu hafta içinde gerekli, stok kritik…', satir: 2),
      Text('Malzeme Kalemleri (en az 1)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      for (var i = 0; i < _kalemler.length; i++)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(children: [
                _MalzemeSecici(
                  malzemeler: _malzemeler,
                  secili: _kalemler[i].mid,
                  onSec: (mid) => setState(() => _malzemeSec(_kalemler[i], mid)),
                ),
                Row(children: [
                  Expanded(child: KAlan('Miktar', _kalemler[i].mik, klavye: const TextInputType.numberWithOptions(decimal: true), ipucu: '0')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: KSecim<String>('Birim', deger: _kalemler[i].birim, secenekler: [
                      ...birimSec,
                      if (_kalemler[i].birim.isNotEmpty && !_birimler.contains(_kalemler[i].birim)) (_kalemler[i].birim, _kalemler[i].birim),
                    ], onSec: (s) => setState(() => _kalemler[i].birim = s ?? '')),
                  ),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'Satırı sil',
              onPressed: _kalemler.length == 1 ? null : () => setState(() => _kalemler.removeAt(i)),
              icon: Icon(Icons.close, color: t.sub),
            ),
          ]),
        ),
      KButon('Satır Ekle', ikon: Icons.add, ikincil: true, onTap: () => setState(() => _ekle())),
      const SizedBox(height: 14),
      KButon('Talebi Gönder', ikon: Icons.send, genis: true, yukleniyor: _gonderiyor, onTap: _gonder),
    ]);
  }
}

/// Aranabilir malzeme seçici
class _MalzemeSecici extends StatelessWidget {
  final List<Map<String, dynamic>> malzemeler;
  final int? secili;
  final ValueChanged<int> onSec;
  const _MalzemeSecici({required this.malzemeler, required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final m = malzemeler.firstWhere((x) => tamOku(x['id']) == secili, orElse: () => const {});
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final s = await kAltSayfa<int>(context, baslik: 'Malzeme seç', icerik: (c) => _MalzemeListe(malzemeler: malzemeler));
          if (s != null) onSec(s);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Row(children: [
            Icon(Icons.inventory_2_outlined, size: 18, color: t.sub),
            const SizedBox(width: 8),
            Expanded(child: Text(m.isEmpty ? '— Malzeme seç —' : metinOku(m['ad']), style: TextStyle(color: m.isEmpty ? t.sub : t.ink, fontSize: 14.5))),
            Icon(Icons.arrow_drop_down, color: t.sub),
          ]),
        ),
      ),
    );
  }
}

class _MalzemeListe extends StatefulWidget {
  final List<Map<String, dynamic>> malzemeler;
  const _MalzemeListe({required this.malzemeler});
  @override
  State<_MalzemeListe> createState() => _MalzemeListeState();
}

class _MalzemeListeState extends State<_MalzemeListe> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = widget.malzemeler.where((m) => saIcerir(metinOku(m['ad']), _q)).take(120).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KAra(ipucu: 'Malzeme ara…', onDegis: (s) => setState(() => _q = s)),
      if (widget.malzemeler.isEmpty) const KBos(baslik: 'Malzeme tanımlı değil', aciklama: 'Malzemeler Stok > Malzemeler ekranından eklenir.'),
      for (final m in l) KSatir(baslik: metinOku(m['ad']), alt: metinOku(m['birim_kisaltma']), onTap: () => Navigator.pop(context, tamOku(m['id']))),
    ]);
  }
}

// ───────────────────────── Talep detayı ─────────────────────────
class TalepDetayScreen extends StatefulWidget {
  final int id;
  final bool patronMu;
  final bool satinalmaci;
  const TalepDetayScreen({super.key, required this.id, required this.patronMu, required this.satinalmaci});
  @override
  State<TalepDetayScreen> createState() => _TalepDetayScreenState();
}

class _TalepDetayScreenState extends State<TalepDetayScreen> {
  Map<String, dynamic>? _d;
  Map<String, dynamic>? _trf;
  Map<String, dynamic>? _limit;
  String? _hata;
  bool _mesgul = false;
  late int _id = widget.id;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final c = await saAl(context, '/api/patron/talep-detay', q: {'id': '$_id'});
    if (!mounted) return;
    if (c == null) return;
    if (!c.ok || c.j['talep'] == null) {
      setState(() => _hata = saHata(c));
      return;
    }
    setState(() {
      _d = c.j;
      _hata = null;
    });
    _transferYukle();
    final durum = metinOku(harita(c.j['talep'])['durum']);
    if (widget.satinalmaci && (durum == 'yeni' || durum == 'teklif')) _limitYukle();
  }

  Future<void> _transferYukle() async {
    final c = await saAl(context, '/api/sube-transfer/talep', q: {'id': '$_id'});
    if (!mounted || c == null) return;
    setState(() => _trf = c.ok ? c.j : null);
  }

  Future<void> _limitYukle() async {
    final c = await saAl(context, '/satinalma-talep/limit-bilgi', q: {'id': '$_id'});
    if (!mounted || c == null) return;
    setState(() => _limit = c.ok ? c.j : null);
  }

  Map<String, dynamic> get _talep => harita(_d?['talep']);
  List<Map<String, dynamic>> get _kalemler => liste(_d?['kalemler']);
  List<Map<String, dynamic>> get _tedarikciler => liste(_d?['tedarikciler']);
  String get _durum => metinOku(_talep['durum']);

  String _tedAd(dynamic id) => metinOku(_tedarikciler.firstWhere((t) => '${t['id']}' == '$id', orElse: () => const {})['ad'], 'Tedarikçi #$id');

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    if (_d == null && _hata == null) {
      govde = const KYukleniyor();
    } else if (_d == null) {
      govde = KHata(_hata!, tekrar: _yukle);
    } else {
      govde = _icerik(t);
    }
    return KSayfa(
      baslik: _d == null ? 'Talep #$_id' : '#$_id · ${metinOku(_talep['departman'])} Talebi',
      ikon: Icons.assignment_outlined,
      araclar: [IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh))],
      govde: govde,
    );
  }

  Widget _icerik(TemaProvider t) {
    final talep = _talep;
    final satTaraf = widget.satinalmaci || widget.patronMu;
    final duzenle = widget.satinalmaci && ['yeni', 'teklif', 'onayda'].contains(_durum);
    final patronSecebilir = widget.patronMu && _durum == 'onayda';
    final surec = harita(_d?['surec']);
    final ayrilan = liste(_d?['ayrilan']);
    return KGovde(yenile: _yukle, maxGenislik: 900, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        KRozet(talep['aciliyet'] == 'acil' ? 'ACİL' : 'Normal', renk: talep['aciliyet'] == 'acil' ? t.kirmizi : t.sub),
        talepDurumRozet(_durum),
        Text('${metinOku(talep['isteyen_ad'])} · ${gecenZaman(talep['created_at'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ]),
      const SizedBox(height: 10),
      if (metinOku(talep['not']).isNotEmpty) SaBilgi(metinOku(talep['not']), ikon: Icons.sticky_note_2_outlined, renk: t.amber),
      if (liste(surec['adimlar']).isNotEmpty) KKart(child: _zamanCizelgesi(liste(surec['adimlar']), t)),
      KBaslik(satTaraf ? 'Kalemler · Teklifler' : 'İstenen malzemeler', ikon: Icons.inventory_2_outlined),
      if (duzenle && _durum != 'onayda')
        SaBilgi('Fiyatı "Fiyat Araştır" ile tedarikçiler girer; telefonda konuştuysanız kalemdeki "Teklif" ile kendiniz ekleyin.', ikon: Icons.lightbulb_outline),
      if (_kalemler.isEmpty) const KBos(baslik: 'Kalem yok', aciklama: 'Bu talepte malzeme kalemi bulunmuyor.'),
      for (final k in _kalemler) _kalemKart(k, t, satTaraf, duzenle, patronSecebilir),
      if (ayrilan.isNotEmpty)
        KKart(
          renk: t.yesil,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bu talepten onaya gidenler', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Bunlar bu talepten çıktı, tekrar gönderilmez.', style: TextStyle(color: t.sub, fontSize: 12)),
            for (final a in ayrilan)
              KSatir(
                baslik: dizi(a['urunler']).join(', '),
                alt: 'Talep #${a['talep_id']} · ${kTalepDurum[metinOku(a['durum'])]?.$1 ?? a['durum']}',
                sag: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _id = tamOku(a['talep_id']);
                    _d = null;
                    _trf = null;
                    _limit = null;
                  });
                  _yukle();
                },
              ),
          ]),
        ),
      ..._transferBolum(t),
      const SizedBox(height: 4),
      ..._aksiyonlar(t),
    ]);
  }

  Widget _zamanCizelgesi(List<Map<String, dynamic>> adimlar, TemaProvider t) {
    return Column(children: [
      for (var i = 0; i < adimlar.length; i++)
        Builder(builder: (_) {
          final a = adimlar[i];
          final d = metinOku(a['durum']);
          final r = switch (d) { 'tamam' => t.yesil, 'aktif' => t.amber, 'red' => t.kirmizi, _ => t.line };
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Column(children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: d == 'bekliyor' ? t.card2 : r, shape: BoxShape.circle, border: Border.all(color: r)),
                child: Icon(switch (d) { 'tamam' => Icons.check, 'aktif' => Icons.more_horiz, 'red' => Icons.close, _ => null }, size: 14, color: Colors.white),
              ),
              if (i < adimlar.length - 1) Container(width: 2, height: 26, color: t.line),
            ]),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(metinOku(a['ad']), style: TextStyle(color: d == 'bekliyor' ? t.sub : t.ink, fontWeight: FontWeight.w700, fontSize: 13.5))),
                    Text(metinOku(a['zaman']), style: TextStyle(color: t.sub, fontSize: 12)),
                  ]),
                  if (metinOku(a['detay']).isNotEmpty) Text(metinOku(a['detay']), style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
            ),
          ]);
        }),
    ]);
  }

  Widget _kalemKart(Map<String, dynamic> k, TemaProvider t, bool satTaraf, bool duzenle, bool patronSecebilir) {
    final teklifler = liste(k['teklifler']);
    final fiyatlar = teklifler.map((x) => sayiOku(x['fiyat'])).where((f) => f > 0).toList();
    final enUcuz = fiyatlar.isEmpty ? null : fiyatlar.reduce((a, b) => a < b ? a : b);
    final gerekce = metinOku(k['oneri_gerekce']);
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(k['ad'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
          Text('${sayiYaz(k['miktar'])} ${metinOku(k['birim'])}', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700, fontSize: 13.5)),
          if (satTaraf && teklifler.isNotEmpty) ...[const SizedBox(width: 8), KRozet('${teklifler.length} teklif', renk: t.mavi)],
        ]),
        if (satTaraf)
          for (final tk in teklifler)
            Builder(builder: (_) {
              final oneri = '${k['onerilen_tedarikci_id']}' == '${tk['tedarikci_id']}' && k['onerilen_tedarikci_id'] != null;
              final secili = '${k['secilen_tedarikci_id']}' == '${tk['tedarikci_id']}' && k['secilen_tedarikci_id'] != null;
              final ucuz = enUcuz != null && sayiOku(tk['fiyat']) == enUcuz;
              final alt = [if (metinOku(tk['vade']).isNotEmpty) 'Vade: ${tk['vade']}', if (metinOku(tk['teslim_gun']).isNotEmpty) '${tk['teslim_gun']} gün'].join(' · ');
              return Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: secili ? t.yesil.withValues(alpha: .1) : (oneri ? t.amber.withValues(alpha: .1) : t.card2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: secili ? t.yesil : (oneri ? t.amber : t.line)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: patronSecebilir ? () => _patronSec(k, tk['tedarikci_id']) : (duzenle ? () => _oneriSec(k, tk['tedarikci_id']) : null),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(children: [
                      if (duzenle || oneri)
                        IconButton(
                          tooltip: 'Önerim',
                          onPressed: duzenle ? () => _oneriSec(k, tk['tedarikci_id']) : null,
                          icon: Icon(oneri ? Icons.star : Icons.star_border, color: t.amber),
                        ),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(metinOku(tk['tedarikci_ad'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w600, fontSize: 13.5)),
                            if (ucuz) KRozet('EN UCUZ', renk: t.yesil),
                            if (secili) KRozet('SEÇİLDİ', renk: t.yesil, ikon: Icons.check),
                          ]),
                          if (alt.isNotEmpty) Text(alt, style: TextStyle(color: t.sub, fontSize: 12)),
                        ]),
                      ),
                      Text(tl(tk['fiyat']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
                      if (duzenle)
                        IconButton(tooltip: 'Teklifi sil', onPressed: () => _teklifSil(tk), icon: Icon(Icons.close, color: t.kirmizi, size: 20)),
                    ]),
                  ),
                ),
              );
            }),
        if (satTaraf && gerekce.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Satın almacı: $gerekce', style: TextStyle(color: t.sub2, fontSize: 12.5))),
        if (satTaraf && metinOku(k['patron_not']).isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: Text('Yönetici: ${k['patron_not']}', style: TextStyle(color: t.yesil, fontSize: 12.5, fontWeight: FontWeight.w600))),
        if (duzenle)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              KButon('Teklif', ikon: Icons.add, ikincil: true, onTap: () => _teklifEkle(k)),
              KButon(gerekce.isEmpty ? 'Gerekçe' : 'Gerekçeyi düzenle', ikon: Icons.tips_and_updates_outlined, ikincil: true, renk: t.amber, onTap: () => _gerekce(k)),
            ]),
          ),
      ]),
    );
  }

  Future<void> _teklifEkle(Map<String, dynamic> k) async {
    int? ted;
    final fiyat = TextEditingController(), gun = TextEditingController(), vade = TextEditingController();
    final ok = await kAltSayfa<bool>(context, baslik: 'Elle teklif — ${metinOku(k['ad'])}', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Tedarikçi', deger: ted, secenekler: [for (final x in _tedarikciler) (tamOku(x['id']), metinOku(x['ad']))], onSec: (v) => ss(() => ted = v)),
            KAlan('Fiyat (₺)', fiyat, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
            Row(children: [
              Expanded(child: KAlan('Teslim (gün)', gun, klavye: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Vade', vade, ipucu: 'ör. 30 gün')),
            ]),
            KButon('+ Teklif Ekle', genis: true, onTap: () {
              if (ted == null) return kToast(c, 'Tedarikçi seçin.', hata: true);
              if (sayiOku(fiyat.text) <= 0) return kToast(c, 'Fiyat girin.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    final c = await saGonder(context, '/satinalma-talep/teklif-ekle', {
      'talep_kalem_id': k['id'], 'tedarikci_id': ted, 'fiyat': sayiOku(fiyat.text),
      'teslim_gun': gun.text.trim().isEmpty ? null : gun.text.trim(), 'vade': vade.text.trim().isEmpty ? null : vade.text.trim(),
    }, basari: 'Teklif eklendi.');
    if (c?.ok == true) _yukle();
  }

  Future<void> _teklifSil(Map<String, dynamic> tk) async {
    if (!await kOnay(context, 'Teklif silinsin mi?', tehlikeli: true, evet: 'Sil')) return;
    if (!mounted) return;
    final c = await saGonder(context, '/satinalma-talep/teklif-sil', {'teklif_id': tk['id']}, basari: 'Teklif silindi.');
    if (c?.ok == true) _yukle();
  }

  Future<void> _oneriSec(Map<String, dynamic> k, dynamic tedId) async {
    final yeni = '${k['onerilen_tedarikci_id']}' == '$tedId' ? null : tedId;
    setState(() => k['onerilen_tedarikci_id'] = yeni);
    final c = await saGonder(context, '/satinalma-talep/oneri-kaydet', {'talep_kalem_id': k['id'], 'onerilen_tedarikci_id': yeni},
        basari: yeni != null ? 'Öneriniz kaydedildi.' : 'Öneri kaldırıldı.');
    if (c?.ok != true) {
      _yukle();
    } else if (_limit != null) {
      _limitYukle();
    }
  }

  Future<void> _gerekce(Map<String, dynamic> k) async {
    final s = await saMetinSor(context, 'Öneri gerekçesi', ipucu: 'Neden bu tedarikçi?', baslangic: metinOku(k['oneri_gerekce']), evet: 'Kaydet');
    if (s == null || !mounted) return;
    final c = await saGonder(context, '/satinalma-talep/oneri-kaydet',
        {'talep_kalem_id': k['id'], 'onerilen_tedarikci_id': k['onerilen_tedarikci_id'], 'oneri_gerekce': s}, basari: 'Gerekçe kaydedildi.');
    if (c?.ok == true) _yukle();
  }

  Future<void> _patronSec(Map<String, dynamic> k, dynamic tedId) async {
    final yeni = '${k['secilen_tedarikci_id']}' == '$tedId' ? null : tedId;
    setState(() => k['secilen_tedarikci_id'] = yeni);
    final c = await saGonder(context, '/satinalma-talep/patron-sec', {'talep_kalem_id': k['id'], 'secilen_tedarikci_id': yeni},
        basari: yeni != null ? 'Seçim kaydedildi.' : 'Seçim kaldırıldı.');
    if (c?.ok != true) _yukle();
  }

  List<Widget> _transferBolum(TemaProvider t) {
    final j = _trf;
    if (j == null) return const [];
    final out = <Widget>[];
    final trDur = {'oneri': 'Kabul bekliyor', 'istendi': 'Gönderen onayında', 'hazirlaniyor': 'Hazırlanıyor', 'yolda': 'Yolda', 'teslim': 'Teslim alındı', 'reddedildi': 'Reddedildi', 'iptal': 'İptal'};
    final trf = liste(j['transferler']);
    if (trf.isNotEmpty) {
      out.add(KKart(
        renk: const Color(0xFF0891B2),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Şubeler arası transfer', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
          Text('Bu ürünler yeni sipariş yerine kardeş şubeden geliyor.', style: TextStyle(color: t.sub, fontSize: 12)),
          for (final x in trf)
            KSatir(baslik: '${dizi(x['urunler']).join(', ')} ← ${metinOku(x['gonderen'])}', alt: '${metinOku(x['no'])} · ${trDur[metinOku(x['durum'])] ?? metinOku(x['durum_ad'])}'),
        ]),
      ));
    }
    final kal = liste(j['kalemler']);
    if (j['grup'] == true && kal.isNotEmpty && ['yeni', 'teklif'].contains(metinOku(j['durum'])) && j['yetkili'] == true) {
      out.add(KKart(
        renk: t.mor1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Diğer şubelerde var — yeni sipariş gerekmeyebilir', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
          Text('Fazla stoğu olan ya da son kullanma tarihi yaklaşan şubeden isteyin; transferle karşılanan miktar bu talepten ayrılır, kalan için fiyat araştırması devam eder.',
              style: TextStyle(color: t.sub, fontSize: 12)),
          for (final k in kal)
            for (final s in liste(k['kaynaklar']))
              KSatir(
                baslik: '${metinOku(k['ad'])} (talep: ${sayiYaz(k['miktar'])} ${metinOku(k['birim'])}) → ${metinOku(s['sube_ad'])}',
                alt: '${sayiYaz(s['verilebilir'])} ${metinOku(k['temel_birim'])} verebilir${sayiOku(s['skt_risk']) > 0 ? ' · SKT ${metinOku(s['en_yakin_skt'])}' : ''}',
                sag: KButon('Transferle karşıla', onTap: () => _transferIste(k, s)),
              ),
        ]),
      ));
    }
    return out;
  }

  Future<void> _transferIste(Map<String, dynamic> k, Map<String, dynamic> s) async {
    final oneri = k['ihtiyac_temel'] != null ? [sayiOku(k['ihtiyac_temel']), sayiOku(s['verilebilir'])].reduce((a, b) => a < b ? a : b) : sayiOku(s['verilebilir']);
    final m = await saMetinSor(context, 'Transfer miktarı (${metinOku(k['temel_birim'])})',
        aciklama: '${metinOku(k['ad'])} → ${metinOku(s['sube_ad'])} şubesinden istenecek.', baslangic: sayiYaz(oneri).replaceAll('.', ''), satir: 1, klavye: const TextInputType.numberWithOptions(decimal: true), evet: 'İste');
    if (m == null || !mounted) return;
    final mik = sayiOku(m);
    if (mik <= 0) return kToast(context, 'Miktar girin.', hata: true);
    final c = await saGonder(context, '/sube-transfer/iste', {
      'gonderen_sube_id': s['sube_id'], 'talep_id': _id,
      'kalemler': [{'malzeme_id': k['malzeme_id'], 'miktar': mik, 'talep_kalem_id': k['kalem_id']}],
    });
    if (c?.ok == true) _yukle();
  }

  List<Widget> _aksiyonlar(TemaProvider t) {
    final d = _durum;
    final w = <Widget>[];
    Widget btn(String m, IconData i, Color r, VoidCallback? f) => Padding(padding: const EdgeInsets.only(bottom: 8), child: KButon(m, ikon: i, renk: r, genis: true, yukleniyor: _mesgul, onTap: f));
    if (d == 'departman_onay') return [const SaBilgi('Departman sorumlusunun (şefin) onayı bekleniyor. Onaylanınca satın almaya düşer.', ikon: Icons.hourglass_top)];
    if (d == 'reddedildi') {
      return [
        SaBilgi('Bu talep reddedildi.${metinOku(_talep['red_sebep']).isNotEmpty ? ' Sebep: ${_talep['red_sebep']}' : ''}', renk: t.kirmizi, ikon: Icons.block),
        btn('Düzenle ve tekrar gönder', Icons.edit_outlined, t.mor1, () {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => SatinalmaTalepScreen(url: '/satinalma-talep?kopya=$_id')));
        }),
      ];
    }
    if (!widget.satinalmaci) {
      const nerede = {
        'yeni': 'Satın almaya iletildi, fiyat araştırılacak.', 'teklif': 'Satın alma tedarikçilerden fiyat topluyor.', 'onayda': 'Teklifler yönetimin onayında.',
        'onaylandi': 'Yönetim onayladı, sipariş geçilecek.', 'siparis': 'Sipariş tedarikçiye geçildi, teslimat bekleniyor.', 'tamamlandi': 'Ürünler teslim alındı.',
      };
      if (nerede[d] != null) w.add(SaBilgi(nerede[d]!));
      if (d == 'onayda' && widget.patronMu) {
        w.add(const SaBilgi('Önerileri inceleyin. İsterseniz bir teklife dokunup değiştirin, sonra onaylayın.'));
        w.add(btn('Onayla (seçimleri kesinleştir)', Icons.check_circle_outline, t.yesil, _onayla));
      }
      return w;
    }
    final teklifSay = _kalemler.fold<int>(0, (s, k) => s + liste(k['teklifler']).length);
    final rfq = liste(_d?['rfq']);
    if (rfq.isNotEmpty && ['teklif', 'onayda'].contains(d)) {
      w.add(KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Teklif istenen tedarikçiler', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          for (final g in rfq)
            KSatir(
              baslik: metinOku(g['tedarikci'], '—'),
              alt: g['durum'] == 'teklif_geldi' ? 'teklif verdi' : ((g['iletildi'] == true || g['iletildi'] == 1) ? (g['durum'] == 'gonderildi' ? 'teklif bekleniyor' : metinOku(g['kanal'])) : 'ulaşılamadı'),
              sag: g['durum'] != 'teklif_geldi' && metinOku(g['link']).isNotEmpty
                  ? IconButton(tooltip: 'Bağlantıyı kopyala', onPressed: () => saKopyala(context, metinOku(g['link']), 'Bağlantı kopyalandı — tedarikçiye iletin.'), icon: const Icon(Icons.content_copy))
                  : null,
            ),
        ]),
      ));
    }
    if (['yeni', 'teklif', 'onayda'].contains(d)) {
      w.add(SaBilgi(d == 'onayda'
          ? 'Patron onayı bekleniyor. Teklif/öneri hâlâ düzenlenebilir.'
          : 'Fiyat Araştır ile tüm tedarikçilere teklif isteyin → tedarikçi bağlantıdan fiyat+teslim girer → teklifler buraya düşer → yıldız ile önerin → Patrona Gönder.'));
      if (d != 'onayda') {
        final j = _limit;
        if (j != null && j['goster'] == true) {
          final ay = sayiOku(j['aylik']) > 0 ? ' · bu ay ${tl(j['kullanilan'])} / ${tl(j['aylik'])}' : '';
          if (j['uygun'] == true) {
            w.add(btn('Limitimle Onayla ve Sipariş Geç · ${tl(j['tutar'])}', Icons.verified_outlined, t.yesil, _limitOnay));
            w.add(SaBilgi('Bu sipariş limitinizin içinde (limitiniz ${tl(j['limit'])}$ay). Patron onayı beklenmez, patrona bilgi gider.${sayiOku(j['kalan_kalem']) > 0 ? ' Fiyatı gelmeyen ${j['kalan_kalem']} kalem talepte kalır.' : ''}', renk: t.yesil));
          } else {
            w.add(SaBilgi('Kendi limitinizle onaylanamaz: ${metinOku(j['neden'])} (limitiniz ${tl(j['limit'])}$ay)', renk: t.amber, ikon: Icons.lock_outline));
          }
        }
        w.add(btn('Fiyat Araştır (tüm tedarikçilere)', Icons.request_quote_outlined, t.mor1, _fiyatArastir));
        if (teklifSay > 0) {
          w.add(btn('Patrona Gönder (Onaya) · $teklifSay teklif', Icons.send, t.amber, () => _patronaGonder(false, false)));
        } else {
          w.add(btn('Patrona Gönder — teklif bekleniyor', Icons.hourglass_empty, t.sub, null));
          w.add(const SaBilgi('Henüz teklif gelmedi. Tedarikçiler fiyatı girince (veya elle teklif eklerseniz) "Patrona Gönder" aktifleşir.'));
        }
      }
      w.add(btn('Anlaşmalıdan Direkt Sipariş', Icons.bolt, const Color(0xFF0EA5E9), _anlasmaliDirekt));
      w.add(const SaBilgi('Anlaşmalı tedarikçiye yıldızla önerdiğiniz + fiyatını girdiğiniz kalemler, patron onayı beklemeden direkt siparişe döner ve tedarikçiye WhatsApp sipariş gider.'));
    }
    if (d == 'onayda' && widget.patronMu) {
      w.add(const SaBilgi('Önerileri inceleyin. İsterseniz bir teklife dokunup değiştirin, sonra onaylayın.'));
      w.add(btn('Onayla (seçimleri kesinleştir)', Icons.check_circle_outline, t.yesil, _onayla));
    }
    if (d == 'onaylandi') {
      w.add(const SaBilgi('Onaylandı. Satın almacı tedarikçiye-gruplu sipariş oluşturabilir.'));
      w.add(btn('Sipariş Oluştur (PO)', Icons.shopping_cart_checkout, const Color(0xFF0EA5E9), _poOlustur));
    }
    if (d == 'siparis') {
      if (_talep['sa_onay_tipi'] == 'limit_ici') w.add(SaBilgi('Satın almacı bu siparişi kendi onay limiti içinde onayladı; patrona bilgi gitti.', renk: t.yesil));
      w.add(const SaBilgi('Sipariş tedarikçiye geçildi. Tedarikçi bağlantıdan siparişi ve teslim tarihini onaylar; mal gelince Mal Kabul yapılınca talep kendiliğinden tamamlanır.'));
      w.add(btn('Tamamlandı İşaretle', Icons.task_alt, t.yesil, () => _durumGuncelle('tamamlandi')));
    }
    return w;
  }

  Future<void> _calis(Future<void> Function() f) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    try {
      await f();
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _fiyatArastir() async {
    if (!await kOnay(context, 'Fiyat isteği gönderilsin mi?', aciklama: 'Bu talepteki ürünleri sağlayan TÜM tedarikçilere fiyat isteği (e-posta + WhatsApp) gönderilecek.', evet: 'Evet, gönder')) return;
    await _calis(() => _fiyatGit(false));
  }

  Future<void> _fiyatGit(bool sadeceBagsiz) async {
    if (!mounted) return;
    final c = await saGonder(context, '/satinalma-talep/fiyat-arastir', {'id': _id, if (sadeceBagsiz) 'sadece_bagsiz': 1}, sessiz: true, hataSessiz: true);
    if (c == null || !mounted) return;
    final r = c.j;
    if (!c.ok && dizi(r['bagsiz']).isNotEmpty) {
      await _bagsizSor(r);
      return;
    }
    if (!c.ok) return kToast(context, saHata(c), hata: true);
    final ulas = liste(r['ulasilamayan']);
    final giden = tamOku(r['gonderilen']) - ulas.length;
    kToast(context, giden > 0
        ? '$giden tedarikçiye fiyat isteği gitti (e-posta ${r['mail']}, WhatsApp ${r['wa']}).${ulas.isNotEmpty ? ' ${ulas.length} tedarikçiye ulaşılamadı.' : ''}'
        : 'Hiçbir tedarikçiye otomatik ulaşılamadı — bağlantıları elle iletin.', hata: giden <= 0);
    if (ulas.isNotEmpty) await _baglantiPenceresi('Teklif bağlantıları — ulaşılamayan tedarikçiler', ulas.map((u) => (metinOku(u['tedarikci']), metinOku(u['link']))).toList());
    if (metinOku(r['wa_hata']).isNotEmpty && mounted) {
      await kOnay(context, 'WhatsApp mesajı gitmedi', aciklama: '${r['wa_hata']}\nWhatsApp hattını web panelde "WhatsApp Hatları" ekranından bağlayın.', evet: 'Tamam', hayir: 'Kapat');
    } else {
      await _bagsizSor(r);
    }
    _yukle();
  }

  Future<void> _bagsizSor(Map<String, dynamic> r) async {
    final b = dizi(r['bagsiz']).map((e) => '$e').toList();
    final aday = dizi(r['tum_tedarikci']).map((e) => '$e').toList();
    if (b.isEmpty || !mounted) return;
    if (aday.isEmpty) {
      kToast(context, '${b.length} kalemin tedarikçisi yok ve telefonu/e-postası kayıtlı tedarikçi de yok: ${b.join(', ')}', hata: true);
      return;
    }
    final ok = await kOnay(context, '${b.length} kalem kimseye sorulmadı',
        aciklama: 'Bu kalemler tedarikçi kataloğunda hiçbir tedarikçiye bağlı değil:\n${b.join(', ')}\n\nKayıtlı ${aday.length} tedarikçinin hepsine soralım mı?\n(${aday.join(', ')})\nVeremedikleri ürünü boş bırakırlar.',
        evet: 'Evet, hepsine sor');
    if (ok) await _fiyatGit(true);
  }

  Future<void> _baglantiPenceresi(String baslik, List<(String, String)> satirlar) async {
    if (satirlar.isEmpty || !mounted) return;
    await kAltSayfa(context, baslik: baslik, icerik: (c) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('E-postası/telefonu olmayan tedarikçiye bağlantıyı siz iletin (WhatsApp, telefon vb.).', style: TextStyle(color: t.sub, fontSize: 13)),
        for (final (ad, link) in satirlar)
          KSatir(
            baslik: ad.isEmpty ? '—' : ad,
            alt: 'ulaşılamadı',
            sag: link.isEmpty ? null : IconButton(tooltip: 'Bağlantıyı kopyala', onPressed: () => saKopyala(c, link, 'Bağlantı kopyalandı — tedarikçiye iletin.'), icon: const Icon(Icons.content_copy)),
          ),
      ]);
    });
  }

  Future<void> _patronaGonder(bool kismi, bool ciftHaric) async {
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/patrona-gonder', {'id': _id, 'kismi': kismi ? 1 : 0, 'cift_haric': ciftHaric ? 1 : 0}, sessiz: true, hataSessiz: true);
      if (c == null || !mounted) return;
      final r = c.j;
      if (c.ok) {
        kToast(context, metinOku(r['mesaj'], 'Patrona gönderildi.'));
        _yukle();
        return;
      }
      if (r['cift'] is List) {
        final l = liste(r['cift']).map((x) => '• ${x['ad']} → Talep #${x['talep_id']} (${x['durum']})').join('\n');
        if (tamOku(r['gidecek']) > 0) {
          final ok = await kOnay(context, 'Bu ürünler zaten onay sürecinde', aciklama: 'TEKRAR GÖNDERİLMEYECEK:\n$l\n\nKalan ${r['gidecek']} ürün patrona gönderilsin mi?', evet: 'Kalanları Gönder');
          if (ok) {
            setState(() => _mesgul = false);
            await _patronaGonder(kismi, true);
          }
        } else {
          await kOnay(context, 'Tekrar gönderilmedi', aciklama: 'Fiyatı gelen ürünlerin hepsi zaten onay sürecinde:\n$l', evet: 'Tamam', hayir: 'Kapat');
        }
        return;
      }
      if (r['kismi_teklif'] == true || r['kismi_teklif'] == 1) {
        if (r['oto_oner'] == true || r['oto_oner'] == 1) _yukle();
        final ok = await kOnay(context, 'Fiyatı gelen ${r['onerili']} ürün şimdi patron onayına gitsin mi?',
            aciklama: '${(r['oto_oner'] == true || r['oto_oner'] == 1) ? 'Bu ürünlerde en ucuz teklif otomatik yıldızlandı; isterseniz önce değiştirebilirsiniz.\n\n' : ''}Kalan ${r['bekleyen']} ürün bu talepte bekler. Gönderdiğiniz ürünler bu talepten çıkar ve "Onaya gidenler" kutusunda görünür — bir daha gönderilemez.',
            evet: 'Gelenleri Gönder');
        if (ok) {
          setState(() => _mesgul = false);
          await _patronaGonder(true, ciftHaric);
        }
        return;
      }
      kToast(context, saHata(c), hata: true);
    });
  }

  Future<void> _onayla() async {
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/onayla', {'id': _id}, basari: 'Onaylandı.');
      if (c?.ok == true) _yukle();
    });
  }

  Future<void> _durumGuncelle(String durum) async {
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/durum-guncelle', {'id': _id, 'durum': durum}, basari: 'Durum güncellendi.');
      if (c?.ok == true) _yukle();
    });
  }

  /// Sipariş penceresi: tedarikçi başına teslim tarihi (teklifteki tarih hazır gelir)
  Future<Map<String, String>?> _teslimSor(String baslik, String aciklama, List<String> tedIdler) async {
    final oneri = harita(_d?['teslim_oneri']);
    final tarih = <String, String>{for (final id in tedIdler) id: metinOku(oneri[id])};
    return kAltSayfa<Map<String, String>>(context, baslik: baslik, icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(aciklama, style: TextStyle(color: t.sub, fontSize: 13, height: 1.4)),
            const SizedBox(height: 10),
            for (final id in tedIdler)
              KSatir(
                baslik: _tedAd(id),
                alt: tarih[id]!.isEmpty ? 'Teslim tarihi seçin' : 'Teslim: ${tarihYaz(tarih[id], saat: false)}',
                sag: const Icon(Icons.event_outlined),
                onTap: () async {
                  final s = await saTarihSec(c, ilk: tarih[id], enErken: DateTime.now());
                  if (s != null) ss(() => tarih[id] = s);
                },
              ),
            const SizedBox(height: 12),
            KButon('Siparişi Geç', ikon: Icons.shopping_cart_checkout, genis: true, onTap: () {
              final bugun = bugunStr();
              if (tarih.values.any((v) => v.isEmpty || v.compareTo(bugun) < 0)) {
                return kToast(c, 'Her tedarikçi için bugün veya sonrası bir teslim tarihi seçin.', hata: true);
              }
              Navigator.pop(c, tarih);
            }),
          ]);
        }));
  }

  Future<void> _siparisSonucu(Map<String, dynamic> r) async {
    final gon = liste(r['gonderim']);
    final iletilen = gon.where((g) => g['iletildi'] == true || g['iletildi'] == 1).length;
    kToast(context, 'Sipariş geçildi: ${dizi(r['siparisler']).join(', ')}${iletilen > 0 ? ' · $iletilen tedarikçiye onay bağlantısı gitti' : ''}');
    await _baglantiPenceresi('Sipariş onay bağlantıları — ulaşılamayan tedarikçiler',
        gon.where((g) => !(g['iletildi'] == true || g['iletildi'] == 1)).map((g) => (metinOku(g['tedarikci']), metinOku(g['link']))).toList());
  }

  Future<void> _limitOnay() async {
    final j = _limit;
    if (j == null || j['uygun'] != true || dizi(j['tedarikciler']).isEmpty) {
      kToast(context, 'Limit bilgisi güncel değil, tekrar deneyin.', hata: true);
      _limitYukle();
      return;
    }
    final teslim = await _teslimSor('Limitimle Onayla ve Sipariş Geç',
        'Toplam ${tl(j['tutar'])} — onay limitiniz içinde, patron onayı beklenmeden sipariş geçilecek (patrona bilgi gider). Yıldız seçilmeyen kalemde en ucuz teklif kullanılır. Her tedarikçi için teslim tarihini girin.',
        dizi(j['tedarikciler']).map((e) => '$e').toList());
    if (teslim == null || !mounted) return;
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/limit-onay', {'id': _id, 'teslim': teslim}, sessiz: true);
      if (c?.ok == true) {
        await _siparisSonucu(c!.j);
        if (mounted && tamOku(c.j['kalan']) > 0) kToast(context, '${c.j['kalan']} kalem talepte kaldı (fiyat bekliyor).');
        _yukle();
      } else {
        _limitYukle();
      }
    });
  }

  Future<void> _poOlustur() async {
    final ids = _kalemler.where((k) => k['secilen_tedarikci_id'] != null && k['malzeme_id'] != null).map((k) => '${k['secilen_tedarikci_id']}').toSet().toList();
    if (ids.isEmpty) return kToast(context, 'Tedarikçi seçili kalem yok.', hata: true);
    final teslim = await _teslimSor('Sipariş Oluştur', 'Her tedarikçi için teslim tarihini girin. Tedarikçi siparişi ve bu tarihi gelen bağlantıdan onaylayacak.', ids);
    if (teslim == null || !mounted) return;
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/po-olustur', {'id': _id, 'teslim': teslim}, sessiz: true);
      if (c?.ok == true) {
        await _siparisSonucu(c!.j);
        _yukle();
      }
    });
  }

  Future<void> _anlasmaliDirekt() async {
    final ids = _kalemler
        .where((k) =>
            k['onerilen_tedarikci_id'] != null &&
            k['malzeme_id'] != null &&
            liste(k['teklifler']).any((x) => '${x['tedarikci_id']}' == '${k['onerilen_tedarikci_id']}') &&
            '${_tedarikciler.firstWhere((x) => '${x['id']}' == '${k['onerilen_tedarikci_id']}', orElse: () => const {})['anlasmali']}' == '1')
        .map((k) => '${k['onerilen_tedarikci_id']}')
        .toSet()
        .toList();
    if (ids.isEmpty) return kToast(context, 'Anlaşmalı tedarikçiye yıldızla önerilmiş ve fiyatı girili kalem yok.', hata: true);
    final teslim = await _teslimSor('Anlaşmalıdan Direkt Sipariş', 'Patron onayı beklenmeden sipariş geçilecek. Her tedarikçi için teslim tarihini girin.', ids);
    if (teslim == null || !mounted) return;
    await _calis(() async {
      final c = await saGonder(context, '/satinalma-talep/anlasmali-direkt', {'id': _id, 'teslim': teslim}, sessiz: true);
      if (c?.ok == true) {
        await _siparisSonucu(c!.j);
        if (mounted && tamOku(c.j['kalan']) > 0) kToast(context, '${c.j['kalan']} kalem onaya kaldı.');
        _yukle();
      }
    });
  }
}
