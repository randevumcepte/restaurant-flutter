import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /stok/malzeme — malzeme listesi (stok · kritik · az · negatif · takipsiz), malzeme detayı (hareketler,
/// dönem, Excel/PDF), stok girişi / fire / sayım düzeltme, malzeme kartı ekle/düzenle (gor_malzeme_kart).
class StokMalzemeScreen extends StatefulWidget {
  const StokMalzemeScreen({super.key});

  @override
  State<StokMalzemeScreen> createState() => _StokMalzemeScreenState();
}

const List<String> kFireSebepleri = [
  'Bozulma / SKT geçti', 'Pişirme / hazırlama hatası', 'Düşme / döküm', 'Hazırlık artığı (ayıklama)',
  'Fazla hazırlık (satılmadı)', 'Müşteri iadesi', 'Diğer',
];

class _StokMalzemeScreenState extends State<StokMalzemeScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _filtre = 'tumu';
  String _ara = '';
  List<Map<String, dynamic>> _kategoriler = [];
  bool _metaYuklendi = false;
  Map<String, dynamic> _sonVeri = const {};

  Future<void> _yenile() async => _k.currentState?.yukle();

  // web stok/index @php hesabının aynısı
  List<Map<String, dynamic>> _satirlar(Map<String, dynamic> v) {
    final birim = harita(v['birimler']);
    final simdi = DateTime.now();
    return [
      for (final m in liste(v['malzemeler']))
        () {
          final stok = sayiOku(m['stok']);
          final esik = sayiOku(m['kritik_stok']);
          final takipli = m['stok_takipli'] == null ? 1 : tamOku(m['stok_takipli']);
          String durum;
          if (stok < 0) {
            durum = 'negatif';
          } else if (esik > 0 && stok <= esik) {
            durum = 'kirmizi';
          } else if (esik > 0 && stok <= esik * 1.5) {
            durum = 'turuncu';
          } else {
            durum = 'yesil';
          }
          final hedef = esik > 0 ? esik * 2 : (stok > 1 ? stok : 1);
          final yuzde = hedef > 0 ? (stok / hedef).clamp(0.0, 1.0) : 0.0;
          String sonMetin = 'Hareket yok';
          int? sonGun;
          final sh = DateTime.tryParse(metinOku(m['son_hareket']).replaceFirst(' ', 'T'));
          if (sh != null) {
            sonGun = simdi.difference(sh).inDays;
            sonMetin = sonGun <= 0 ? 'Bugün' : (sonGun == 1 ? 'Dün' : '$sonGun gün önce');
          }
          return {
            ...m,
            'mevcut': stok,
            'deger': (stok > 0 ? stok : 0) * sayiOku(m['guncel_maliyet']),
            'birim': metinOku(birim['${m['temel_birim_id']}']),
            'kategori_ad': metinOku(m['kategori'], 'Diğer'),
            'durum': durum,
            'durum_metin': const {'negatif': 'Veri Hatası', 'kirmizi': 'Kritik', 'turuncu': 'Az', 'yesil': 'Yeterli'}[durum],
            'yuzde': yuzde,
            'takipli': takipli,
            'son_metin': sonMetin,
            'son_gun': sonGun,
          };
        }(),
    ];
  }

  Future<void> _metaYukle(List<Map<String, dynamic>> rows) async {
    if (_metaYuklendi) return;
    _metaYuklendi = true;
    // tam kategori listesi yalnız patron/müdüre açık uçtan gelir; değilse listeden çıkarılır
    final kat = <int, String>{};
    for (final r in rows) {
      final id = tamOku(r['kategori_id']);
      if (id > 0) kat[id] = metinOku(r['kategori'], '—');
    }
    if (stPatron(context)) {
      final c = await stAl(context, '/api/patron/stok-meta');
      if (c.ok) {
        for (final k in liste(c.veri['kategoriler'])) {
          kat[tamOku(k['id'])] = metinOku(k['ad']);
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _kategoriler = [for (final e in kat.entries) {'id': e.key, 'ad': e.value}]..sort((a, b) => '${a['ad']}'.compareTo('${b['ad']}'));
    });
  }

  @override
  Widget build(BuildContext context) {
    final kart = stKartYetki(context);
    return KopruEkran(
      key: _k,
      yol: '/stok/malzeme',
      baslik: 'Stok / Malzeme',
      ikon: Icons.inventory_2_outlined,
      araclar: (ctx, v, y) => stIndirAraclari(ctx, '/stok/malzeme/indir', 'Stok-Malzemeler'),
      fab: kart
          ? (ctx, v, y) => FloatingActionButton.extended(
                heroTag: 'stkFab',
                onPressed: () => _malzemeForm(ctx, v, null),
                icon: const Icon(Icons.add),
                label: const Text('Malzeme', style: TextStyle(fontWeight: FontWeight.w700)),
              )
          : null,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    _sonVeri = v;
    final rows = _satirlar(v);
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _metaYukle(rows); });
    final toplam = rows.fold<double>(0, (s, r) => s + sayiOku(r['deger']));
    int say(String d) => rows.where((r) => r['durum'] == d).length;
    final takipsiz = rows.where((r) => r['takipli'] == 0).length;
    final q = _ara.toLowerCase();
    final gorunen = rows.where((r) {
      if (q.isNotEmpty && !'${r['ad']}'.toLowerCase().contains(q)) return false;
      return switch (_filtre) {
        'tumu' => true,
        'takipsiz' => r['takipli'] == 0,
        _ => r['durum'] == _filtre,
      };
    }).toList();
    final genis = genisMi(context);
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam Stok Değeri', deger: tl(toplam, kisa: true), ikon: Icons.payments_outlined, renk: t.mor1),
        KKpi(etiket: 'Malzeme Sayısı', deger: '${rows.length}', ikon: Icons.inventory_2_outlined, renk: t.mavi, onTap: () => setState(() => _filtre = 'tumu')),
        KKpi(etiket: 'Kritik Stok', deger: '${say('kirmizi')}', ikon: Icons.warning_amber_outlined, renk: t.kirmizi, onTap: () => setState(() => _filtre = 'kirmizi')),
        KKpi(etiket: 'Veri Hatası (Negatif)', deger: '${say('negatif')}', ikon: Icons.error_outline, renk: const Color(0xFF991B1B), onTap: () => setState(() => _filtre = 'negatif')),
      ]),
      const SizedBox(height: 10),
      KAra(ipucu: 'Malzeme ara', onDegis: (s) => setState(() => _ara = s)),
      const SizedBox(height: 8),
      KCipler(
        secenekler: [
          ('tumu', 'Tümü ${rows.length}'),
          ('negatif', 'Veri Hatası ${say('negatif')}'),
          ('kirmizi', 'Kritik ${say('kirmizi')}'),
          ('turuncu', 'Az ${say('turuncu')}'),
          ('takipsiz', 'Takipsiz $takipsiz'),
        ],
        secili: _filtre,
        onSec: (s) => setState(() => _filtre = s),
      ),
      const SizedBox(height: 8),
      if (rows.isEmpty)
        KBos(
          baslik: 'Malzeme yok',
          ikon: Icons.inventory_2_outlined,
          aciklama: stKartYetki(context)
              ? 'Henüz malzeme kartı açılmamış. Sağ alttaki "Malzeme" düğmesiyle ekleyin; alış faturası girildikçe stok kendiliğinden artar.'
              : 'Henüz malzeme kartı açılmamış. Malzeme kartını işletme sahibi ya da "Malzeme Kartı" yetkisi olan kişi ekler.',
        )
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtrede malzeme yok', ikon: Icons.filter_alt_off_outlined, aciklama: 'Aramayı temizleyin ya da "Tümü" çipine dokunun.')
      else if (genis)
        ..._masaustu(context, gorunen)
      else
        for (final m in gorunen) _mobilKart(context, m, v),
    ]);
  }

  List<Widget> _masaustu(BuildContext context, List<Map<String, dynamic>> rows) {
    final t = context.read<TemaProvider>();
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      (gruplar[r['kategori_ad'] as String] ??= []).add(r);
    }
    final adlar = gruplar.keys.toList()..sort();
    return [
      for (final ad in adlar) ...[
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(children: [
            Icon(Icons.category_outlined, size: 18, color: t.mor1),
            const SizedBox(width: 6),
            Text(ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            KRozet('${gruplar[ad]!.length}', renk: t.sub),
            const Spacer(),
            if (gruplar[ad]!.any((r) => r['durum'] == 'kirmizi' || r['durum'] == 'negatif'))
              Padding(padding: const EdgeInsets.only(right: 8), child: KRozet('${gruplar[ad]!.where((r) => r['durum'] == 'kirmizi' || r['durum'] == 'negatif').length} kritik', renk: t.kirmizi)),
            Text(tl(gruplar[ad]!.fold<double>(0, (s, r) => s + sayiOku(r['deger'])), kisa: true), style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        LayoutBuilder(builder: (c, s) {
          final sutun = s.maxWidth > 1050 ? 4 : 3;
          final w = (s.maxWidth - (sutun - 1) * 12) / sutun;
          return Wrap(spacing: 12, children: [for (final m in gruplar[ad]!) SizedBox(width: w, child: _izgaraKart(context, m))]);
        }),
      ],
    ];
  }

  Widget _izgaraKart(BuildContext context, Map<String, dynamic> m) {
    final t = context.read<TemaProvider>();
    final renk = stDurumRenk(t, '${m['durum']}');
    final kritikMi = const ['kirmizi', 'negatif', 'turuncu'].contains(m['durum']);
    return KKart(
      renk: renk,
      onTap: () => _detay(context, m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${m['ad']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold))),
          KRozet('${m['durum_metin']}', renk: renk),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: sayiOku(m['yuzde']), minHeight: 7, backgroundColor: t.card2, color: renk),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text('${mik(m['mevcut'])} ${m['birim']}', style: TextStyle(color: kritikMi ? renk : t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('Kritik: ${mik(m['kritik_stok'])}', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.payments_outlined, size: 14, color: t.sub),
          const SizedBox(width: 3),
          Text(tl(m['deger'], kisa: true), style: TextStyle(color: t.sub2, fontSize: 12)),
          const Spacer(),
          Icon(Icons.schedule, size: 14, color: (m['son_gun'] as int? ?? 0) >= 7 ? t.amber : t.sub),
          const SizedBox(width: 3),
          Text('${m['son_metin']}', style: TextStyle(color: (m['son_gun'] as int? ?? 0) >= 7 ? t.amber : t.sub2, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _mobilKart(BuildContext context, Map<String, dynamic> m, Map<String, dynamic> v) {
    final t = context.read<TemaProvider>();
    final renk = stDurumRenk(t, '${m['durum']}');
    final kritik = m['durum'] == 'kirmizi' || m['durum'] == 'negatif';
    return KKart(
      renk: kritik ? renk : null,
      onTap: () => _detay(context, m),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${m['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
              if (kritik) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(m['durum'] == 'negatif' ? Icons.error_outline : Icons.warning_amber_outlined, size: 16, color: renk)),
            ]),
            const SizedBox(height: 3),
            Text('${m['kategori_ad']} · ${tl(m['guncel_maliyet'])}/${m['birim']} · ${m['son_metin']}', style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${mik(m['mevcut'])} ${m['birim']}', style: TextStyle(color: kritik ? renk : t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(tl(m['deger'], kisa: true), style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        Icon(Icons.chevron_right, color: t.sub),
      ]),
    );
  }

  // ───────── detay ─────────
  Future<void> _detay(BuildContext context, Map<String, dynamic> m) async {
    final id = tamOku(m['id']);
    final degisti = await kAltSayfa<bool>(context, baslik: '${m['ad']}', icerik: (c) => _MalzemeDetay(id: id, satir: m, onDuzenle: () {
          Navigator.pop(c);
          _malzemeForm(context, _sonVeri, m);
        }));
    if (degisti == true) _yenile();
  }

  // ───────── malzeme kartı formu ─────────
  Future<void> _malzemeForm(BuildContext context, Map<String, dynamic> v, Map<String, dynamic>? m) async {
    final birimler = <(int, String)>[];
    for (final e in harita(_sonVeri['birimler']).entries) {
      final id = int.tryParse(e.key) ?? 0;
      if (id > 0) birimler.add((id, '${e.value}'));
    }
    if (birimler.isEmpty && m != null) birimler.add((tamOku(m['temel_birim_id']), '${m['birim']}'));
    final sonuc = await kAltSayfa<bool>(context, baslik: m == null ? 'Yeni Malzeme' : 'Malzeme Düzenle', icerik: (c) => _MalzemeForm(
          m: m,
          kategoriler: _kategoriler,
          birimler: birimler,
          onKategoriEklendi: (id, ad) => setState(() {
            if (!_kategoriler.any((k) => k['id'] == id)) _kategoriler = [..._kategoriler, {'id': id, 'ad': ad}];
          }),
        ));
    if (sonuc == true) _yenile();
  }
}

// ═════════════════════ detay alt sayfası ═════════════════════
class _MalzemeDetay extends StatefulWidget {
  final int id;
  final Map<String, dynamic> satir;
  final VoidCallback onDuzenle;
  const _MalzemeDetay({required this.id, required this.satir, required this.onDuzenle});

  @override
  State<_MalzemeDetay> createState() => _MalzemeDetayState();
}

class _MalzemeDetayState extends State<_MalzemeDetay> {
  int _gun = 90;
  Map<String, dynamic>? _d;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    if (_hata != null || _d != null) setState(() { _hata = null; _d = null; });
    final c = await stAl(context, '/api/patron/malzeme-detay', q: {'id': '${widget.id}', 'gun': '$_gun'});
    if (!mounted) return;
    setState(() {
      if (c.ok) {
        _d = c.veri;
      } else {
        _hata = c.yetkisiz ? 'Hareket geçmişini yalnız işletme sahibi, müdür ve satın alma görebilir.' : (c.hata ?? 'Detay alınamadı.');
      }
    });
  }

  Future<void> _hareket(String tip) async {
    final baslik = const {'giris': 'Stok Girişi', 'fire': 'Fire / Zayi', 'duzeltme': 'Sayım Düzeltme (±)'}[tip]!;
    final miktarK = TextEditingController();
    final aciklamaK = TextEditingController();
    String sebep = kFireSebepleri.first;
    final birim = metinOku(_d?['birim'] ?? widget.satir['birim']);
    final ok = await kAltSayfa<bool>(context, baslik: baslik, icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tip == 'duzeltme' ? 'Fazla için pozitif, eksik için negatif yazın (temel birim: $birim).' : 'Miktar temel birimde ($birim).',
                style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 10),
            KAlan('Miktar', miktarK, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true), zorunlu: true),
            if (tip == 'fire') KSecim<String>('Fire sebebi', deger: sebep, secenekler: [for (final s in kFireSebepleri) (s, s)], onSec: (s) => ss(() => sebep = s ?? sebep)),
            KAlan('Açıklama', aciklamaK, ipucu: 'İsteğe bağlı'),
            KButon('Kaydet', ikon: Icons.check, genis: true, onTap: () async {
              final mk = double.tryParse(miktarK.text.trim().replaceAll(',', '.')) ?? 0;
              if (mk == 0) {
                kToast(c, 'Geçerli miktar girin', hata: true);
                return;
              }
              final r = await stGonder(c, '/api/patron/stok-hareket', {
                'malzeme_id': widget.id, 'tip': tip, 'miktar': mk, 'aciklama': aciklamaK.text.trim(),
                'fire_sebep': tip == 'fire' ? sebep : '',
              }, basari: 'Hareket kaydedildi');
              if (r.ok && c.mounted) Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final patron = stPatron(context);
    final kart = stKartYetki(context);
    final d = _d;
    final birim = metinOku(d?['birim'] ?? widget.satir['birim']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        KRozet('Mevcut: ${mik(d?['mevcut'] ?? widget.satir['mevcut'])} $birim', renk: t.mor1),
        KRozet('Maliyet ${tl(d?['guncel_maliyet'] ?? widget.satir['guncel_maliyet'])}/$birim', renk: t.mavi),
        KRozet('Değer ${tl(d?['deger'] ?? widget.satir['deger'], kisa: true)}', renk: t.yesil),
      ]),
      const SizedBox(height: 12),
      if (patron)
        Row(children: [
          Expanded(child: KButon('Giriş', ikon: Icons.add, renk: t.yesil, onTap: () => _hareket('giris'))),
          const SizedBox(width: 8),
          Expanded(child: KButon('Fire', ikon: Icons.delete_outline, renk: t.kirmizi, onTap: () => _hareket('fire'))),
          const SizedBox(width: 8),
          Expanded(child: KButon('Düzelt', ikon: Icons.tune, renk: t.mavi, onTap: () => _hareket('duzeltme'))),
        ]),
      if (kart) ...[
        const SizedBox(height: 8),
        KButon('Malzemeyi Düzenle', ikon: Icons.edit_outlined, ikincil: true, genis: true, onTap: widget.onDuzenle),
      ],
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: Text('Hareketler', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
        IconButton(
          tooltip: 'Bu dönemin hareketleri · Excel',
          icon: Icon(Icons.table_view_outlined, color: t.yesil),
          onPressed: () => stDosyaIndir(context, '/stok/malzeme/hareket-indir', 'Hareketler-${widget.id}.xlsx', q: {'format': 'xlsx', 'id': '${widget.id}', 'gun': '$_gun'}),
        ),
        IconButton(
          tooltip: 'Bu dönemin hareketleri · PDF',
          icon: Icon(Icons.picture_as_pdf_outlined, color: t.kirmizi),
          onPressed: () => stDosyaIndir(context, '/stok/malzeme/hareket-indir', 'Hareketler-${widget.id}.pdf', q: {'format': 'pdf', 'id': '${widget.id}', 'gun': '$_gun'}),
        ),
      ]),
      KCipler(
        secenekler: const [('30', '30 gün'), ('90', '90 gün'), ('180', '6 ay'), ('365', '1 yıl'), ('0', 'Tümü')],
        secili: '$_gun',
        onSec: (s) {
          _gun = int.parse(s);
          _yukle();
        },
      ),
      const SizedBox(height: 6),
      if (_hata != null)
        KBos(baslik: 'Hareketler gösterilemiyor', aciklama: _hata, ikon: Icons.lock_outline)
      else if (d == null)
        const Padding(padding: EdgeInsets.all(20), child: KYukleniyor())
      else ...[
        if (harita(d['ozet']).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              KRozet('Giriş +${mik(d['ozet']['giris'])} $birim', renk: t.yesil),
              KRozet('Çıkış −${mik(d['ozet']['cikis'])} $birim', renk: t.kirmizi),
              if (sayiOku(d['ozet']['fire']) > 0) KRozet('Fire ${mik(d['ozet']['fire'])} $birim', renk: t.amber),
              KRozet('${d['ozet']['adet']} hareket', renk: t.sub),
            ]),
          ),
        if (liste(d['hareketler']).isEmpty)
          KBos(baslik: 'Bu dönemde hareket yok', aciklama: _gun > 0 ? 'Daha uzun bir dönem seçin.' : 'Bu malzemeye hiç giriş/çıkış yapılmamış.', ikon: Icons.swap_vert)
        else
          for (final h in liste(d['hareketler']))
            KSatir(
              solIkon: Icon(sayiOku(h['miktar']) >= 0 ? Icons.arrow_downward : Icons.arrow_upward, color: sayiOku(h['miktar']) >= 0 ? t.yesil : t.kirmizi),
              baslik: const {'alis': 'Alış', 'tuketim': 'Satış tüketimi', 'fire': 'Fire', 'sayim': 'Sayım', 'iade': 'Giriş', 'transfer': 'Transfer', 'transfer_giris': 'Şubeden transfer', 'transfer_cikis': 'Şubeye transfer'}[h['tip']] ?? '${h['tip']}',
              alt: '${tarihYaz(h['tarih'])}${metinOku(h['aciklama']).isNotEmpty ? ' · ${h['aciklama']}' : ''}',
              sag: Text('${sayiOku(h['miktar']) >= 0 ? '+' : ''}${mik(h['miktar'])}',
                  style: TextStyle(color: sayiOku(h['miktar']) >= 0 ? t.yesil : t.kirmizi, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
      ],
    ]);
  }
}

// ═════════════════════ malzeme kartı formu ═════════════════════
class _MalzemeForm extends StatefulWidget {
  final Map<String, dynamic>? m;
  final List<Map<String, dynamic>> kategoriler;
  final List<(int, String)> birimler;
  final void Function(int id, String ad) onKategoriEklendi;
  const _MalzemeForm({required this.m, required this.kategoriler, required this.birimler, required this.onKategoriEklendi});

  @override
  State<_MalzemeForm> createState() => _MalzemeFormState();
}

class _MalzemeFormState extends State<_MalzemeForm> {
  late final TextEditingController _ad, _kritik, _maliyet, _baslangic, _barkod;
  int? _kat;
  int? _birim;
  bool _takip = true;
  bool _gonderiliyor = false;
  late List<Map<String, dynamic>> _katlar;

  bool get _yeni => widget.m == null;

  @override
  void initState() {
    super.initState();
    final m = widget.m;
    _ad = TextEditingController(text: m == null ? '' : '${m['ad']}');
    _kritik = TextEditingController(text: m != null && sayiOku(m['kritik_stok']) > 0 ? mik(m['kritik_stok']).replaceAll('.', '') : '');
    _maliyet = TextEditingController();
    _baslangic = TextEditingController();
    _barkod = TextEditingController();
    _kat = m == null ? null : (tamOku(m['kategori_id']) > 0 ? tamOku(m['kategori_id']) : null);
    _birim = m == null ? (widget.birimler.isEmpty ? null : widget.birimler.first.$1) : tamOku(m['temel_birim_id']);
    _takip = m == null ? true : tamOku(m['stok_takipli'] ?? 1) == 1;
    _katlar = [...widget.kategoriler];
  }

  @override
  void dispose() {
    for (final c in [_ad, _kritik, _maliyet, _baslangic, _barkod]) {
      c.dispose();
    }
    super.dispose();
  }

  double _s(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  Future<void> _kaydet({bool onay = false, bool onayKategori = false}) async {
    final ad = _ad.text.trim();
    if (ad.isEmpty) {
      kToast(context, 'Ad boş olamaz', hata: true);
      return;
    }
    if (_yeni && _kat == null) {
      kToast(context, 'Kategori seçin', hata: true);
      return;
    }
    setState(() => _gonderiliyor = true);
    final veri = <String, dynamic>{
      'ad': ad, 'id': _yeni ? 0 : tamOku(widget.m!['id']), 'kategori_id': _kat ?? 0, 'temel_birim_id': _birim ?? 0,
      'kritik_stok': _s(_kritik), 'stok_takipli': _takip ? 1 : 0, 'guncel_maliyet': _s(_maliyet),
      if (_yeni) 'baslangic_stok': _s(_baslangic),
      if (_yeni) 'barkod': _barkod.text.trim(),
      if (onay) 'onay': 1,
      if (onayKategori) 'onay_kategori': 1,
    };
    final r = await stGonder(context, '/api/patron/malzeme-kaydet', veri, sessiz: true, hataSessiz: true);
    if (!mounted) return;
    setState(() => _gonderiliyor = false);
    if (r.ok) {
      kToast(context, _yeni ? 'Malzeme eklendi' : 'Güncellendi');
      Navigator.pop(context, true);
      return;
    }
    final ku = harita(r.j['kategori_uyari']);
    if (ku.isNotEmpty) {
      final evet = await kOnay(context, 'Kategori doğru mu?',
          aciklama: '"$ad" genelde "${ku['beklenen']}" kategorisindedir (${ku['kaynak']}). '
              '${metinOku(ku['secilen']).isNotEmpty ? 'Seçtiğiniz: "${ku['secilen']}".' : 'Kategori seçmediniz.'}\n\n'
              'Evet: "${ku['beklenen']}" kategorisine kaydet.',
          evet: 'Önerilene kaydet', hayir: 'Seçimimle devam');
      if (!mounted) return;
      if (evet) {
        setState(() => _kat = tamOku(ku['beklenen_id']));
        return _kaydet(onay: onay, onayKategori: true);
      }
      if (metinOku(ku['secilen']).isNotEmpty && await kOnay(context, '"$ad" yine de "${ku['secilen']}" kategorisine kaydedilsin mi?')) {
        return _kaydet(onay: onay, onayKategori: true);
      }
      return;
    }
    final bz = dizi(r.j['benzer']);
    if (bz.isNotEmpty) {
      final evet = await kOnay(context, 'Çok benzer malzeme var',
          aciklama: '• ${bz.join('\n• ')}\n\nYazım hatası olabilir; mevcut kartı kullanmak için Vazgeç deyin. "$ad" yine de ayrı malzeme olarak eklensin mi?',
          evet: 'Yine de ekle');
      if (evet && mounted) return _kaydet(onay: true, onayKategori: onayKategori);
      return;
    }
    kToast(context, r.hata ?? 'Kaydedilemedi', hata: true);
  }

  Future<void> _kategoriEkle({String? hazir, bool onay = false}) async {
    String? ad = hazir;
    if (ad == null) {
      final k = TextEditingController();
      ad = await kAltSayfa<String>(context, baslik: 'Yeni Kategori', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Kategori adı', k, ipucu: 'Örn: Et & Tavuk'),
            KButon('Ekle', genis: true, onTap: () => Navigator.pop(c, k.text.trim())),
          ]));
    }
    if (ad == null || ad.isEmpty || !mounted) return;
    final r = await stGonder(context, '/api/patron/malzeme-kategori-ekle', {'ad': ad, if (onay) 'onay': 1}, sessiz: true, hataSessiz: true);
    if (!mounted) return;
    if (r.ok) {
      final id = tamOku(r.j['id']);
      final kad = metinOku(r.j['ad'], ad);
      setState(() {
        if (!_katlar.any((k) => k['id'] == id)) _katlar.add({'id': id, 'ad': kad});
        _kat = id;
      });
      widget.onKategoriEklendi(id, kad);
      kToast(context, r.j['mevcut'] == 1 ? 'Bu kategori zaten vardı, o seçildi.' : 'Kategori eklendi');
      return;
    }
    final bz = dizi(r.j['benzer']);
    if (bz.isNotEmpty && await kOnay(context, 'Çok benzer kategori var', aciklama: '• ${bz.join('\n• ')}\n\n"$ad" yine de eklensin mi?', evet: 'Yine de ekle')) {
      return _kategoriEkle(hazir: ad, onay: true);
    }
    if (bz.isEmpty && mounted) kToast(context, r.hata ?? 'Eklenemedi', hata: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KAlan('Malzeme adı', _ad, zorunlu: true, ipucu: 'Örn: Dana kıyma'),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: KSecim<int>('Kategori', deger: _kat, secenekler: [for (final k in _katlar) (tamOku(k['id']), '${k['ad']}')], onSec: (v) => setState(() => _kat = v)),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 4),
          child: IconButton(tooltip: 'Kategori ekle', onPressed: () => _kategoriEkle(), icon: Icon(Icons.add_circle_outline, color: t.mavi)),
        ),
      ]),
      if (_katlar.isEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Kategori listesi boş — "+" ile ekleyin.', style: TextStyle(color: t.sub, fontSize: 12.5))),
      Row(children: [
        Expanded(child: KSecim<int>('Temel birim', deger: _birim, secenekler: widget.birimler, onSec: (v) => setState(() => _birim = v))),
        const SizedBox(width: 10),
        Expanded(child: KAlan('Kritik stok', _kritik, klavye: const TextInputType.numberWithOptions(decimal: true), ipucu: '0 = uyarı yok')),
      ]),
      if (_yeni) ...[
        Row(children: [
          Expanded(child: KAlan('Başlangıç maliyeti (₺/birim)', _maliyet, klavye: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 10),
          Expanded(child: KAlan('Başlangıç stok', _baslangic, klavye: const TextInputType.numberWithOptions(decimal: true), ipucu: 'İsteğe bağlı')),
        ]),
        KAlan('Barkod', _barkod, ipucu: 'İsteğe bağlı (okutulursa bu malzemeye bağlanır)'),
      ],
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _takip,
        onChanged: (v) => setState(() => _takip = v),
        title: Text('Stok takipli', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text('Kapalıysa satışta stoktan düşülmez ve sayım listesine girmez.', style: TextStyle(color: t.sub, fontSize: 12)),
      ),
      const SizedBox(height: 8),
      KButon(_yeni ? 'Malzemeyi Ekle' : 'Kaydet', ikon: Icons.check, genis: true, yukleniyor: _gonderiliyor, onTap: _gonderiliyor ? null : () => _kaydet()),
    ]);
  }
}
