import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /uretim-plani — üretim planı (MRP): reçeteli ürünlere adet gir ya da satış tahminini uygula (dönem + güvenlik payı),
/// özel gün (etkinlik) modu, üretim birimi seç (reçeteye kaydedilir) → malzeme ihtiyacı (stok düşülmüş alınacaklar),
/// reçete detayı, kopyala/yazdır, satın alma talebi oluştur.
class UretimPlaniScreen extends StatefulWidget {
  const UretimPlaniScreen({super.key});

  @override
  State<UretimPlaniScreen> createState() => _UretimPlaniScreenState();
}

class _UretimPlaniScreenState extends State<UretimPlaniScreen> {
  final _k = GlobalKey<KopruEkranState>();
  final Map<int, double> _adet = {};
  final Map<int, int> _birim = {};
  Map<String, dynamic>? _tahmin; // null = view'daki akilli
  Map<String, dynamic> _normal = {}; // özel gün: o günün normal satış tahmini
  String _gun = '7', _pay = '10';
  String _mod = 'rutin';
  bool _normalEkle = false;
  String _etkinlikAd = '';
  String? _etkinlikTarih;
  String _f = 'hepsi', _ara = '';
  Map<String, dynamic>? _sonuc;
  bool _hesapliyor = false;
  Timer? _zaman;
  int _hesapNo = 0;
  String _alKip = 'eksik';
  List<Map<String, dynamic>> _urunler = [];

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _tahminVeri(Map<String, dynamic> v) => _tahmin ?? harita(v['akilli']);

  Future<void> _tahminYukle() async {
    final c = await stAl(context, '/uretim-plani/tahmin', q: {'gun': _gun, 'pay': _pay});
    if (!mounted) return;
    if (c.ok) setState(() => _tahmin = harita(c.veri['tahmin']));
  }

  Future<void> _normalYukle() async {
    if (_etkinlikTarih == null) return;
    final c = await stAl(context, '/uretim-plani/tahmin', q: {'gun': '1', 'pay': '0', 'tarih': _etkinlikTarih!});
    if (!mounted) return;
    setState(() => _normal = c.ok ? harita(c.veri['tahmin']) : {});
    _hesaplaGecikmeli(0);
  }

  List<Map<String, dynamic>> _plan() {
    final plan = <Map<String, dynamic>>[];
    for (final u in _urunler) {
      final id = tamOku(u['id']);
      var a = _adet[id] ?? 0;
      if (_mod == 'ozel' && _normalEkle && a > 0) a += sayiOku(harita(_normal['$id'])['oneri']);
      if (a > 0) plan.add({'urun_id': id, 'recete_id': tamOku(u['recete_id']), 'adet': a, 'birim_id': _birim[id] ?? tamOku(u['verim_birim_id'])});
    }
    return plan;
  }

  void _hesaplaGecikmeli([int ms = 500]) {
    _zaman?.cancel();
    _zaman = Timer(Duration(milliseconds: ms), _hesapla);
  }

  Future<void> _hesapla() async {
    final plan = _plan();
    final no = ++_hesapNo;
    if (plan.isEmpty) {
      setState(() => _sonuc = null);
      return;
    }
    setState(() => _hesapliyor = true);
    final r = await stGonder(context, '/uretim-plani/hesapla', {'plan': plan}, json: true, sessiz: true);
    if (!mounted || no != _hesapNo) return;
    setState(() {
      _hesapliyor = false;
      if (r.ok) _sonuc = r.j;
    });
  }

  void _adetDegis(int id, double a) {
    setState(() => _adet[id] = a < 0 ? 0 : a);
    _hesaplaGecikmeli();
  }

  Future<void> _birimDegis(Map<String, dynamic> u, int birimId) async {
    final id = tamOku(u['id']);
    setState(() => _birim[id] = birimId);
    final r = await stGonder(context, '/uretim-plani/birim-kaydet', {'recete_id': u['recete_id'], 'birim_id': birimId}, json: true, sessiz: true, hataSessiz: true);
    if (!mounted) return;
    kToast(context, r.ok ? '${u['ad']} üretim birimi kaydedildi' : 'Birim kaydedilemedi', hata: !r.ok);
    _hesaplaGecikmeli(0);
  }

  void _tahminUygula(Map<String, dynamic> tahmin) {
    setState(() {
      for (final u in _urunler) {
        final id = tamOku(u['id']);
        final t = harita(tahmin['$id']);
        _adet[id] = t.isEmpty ? 0 : sayiOku(t['oneri']);
      }
    });
    _hesaplaGecikmeli(0);
  }

  String _alinacakMetin() {
    final rows = liste(_sonuc?['rows']).where((r) => _alKip == 'tum' || r['yeterli'] != true).toList();
    final b = StringBuffer(_mod == 'ozel' ? '🎉 ${_etkinlikAd.isEmpty ? 'Özel gün' : _etkinlikAd} — alınacaklar\n' : '🛒 Üretim planı — ${_alKip == 'eksik' ? 'alınacaklar' : 'toplam ihtiyaç'}\n');
    for (final r in rows) {
      b.writeln('• ${r['ad']}: ${_alKip == 'eksik' ? r['net'] : r['lazim']} ${r['birim']}');
    }
    return b.toString();
  }

  Future<void> _yazdir() async {
    final rows = liste(_sonuc?['rows']).where((r) => _alKip == 'tum' || r['yeterli'] != true).toList();
    pw.Font? fr, fb;
    try {
      fr = await PdfGoogleFonts.notoSansRegular();
      fb = await PdfGoogleFonts.notoSansBold();
    } catch (_) {}
    final doc = pw.Document(theme: fr == null ? null : pw.ThemeData.withFont(base: fr, bold: fb));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (_) => [
        pw.Text(_mod == 'ozel' ? (_etkinlikAd.isEmpty ? 'Özel gün alışveriş listesi' : '$_etkinlikAd — alışveriş listesi') : 'Alışveriş listesi',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text('${_alKip == 'eksik' ? 'Stok düşüldü — alınacaklar' : 'Toplam ihtiyaç'} · ${tarihYaz(stBugun(), saat: false)}', style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: ['Malzeme', 'Miktar', 'Birim'],
          data: [for (final r in rows) ['${r['ad']}', '${_alKip == 'eksik' ? r['net'] : r['lazim']}', '${r['birim']}']],
        ),
      ],
    ));
    final bayt = await doc.save();
    await Printing.layoutPdf(name: 'Alisveris-listesi.pdf', onLayout: (_) async => bayt);
  }

  Future<void> _talep() async {
    final alinacak = liste(_sonuc?['alinacak']);
    if (alinacak.isEmpty) {
      kToast(context, 'Satın alınacak malzeme yok (stok yeterli).', hata: true);
      return;
    }
    String? teslim = _mod == 'ozel' && _etkinlikTarih != null ? _etkinlikTarih : stBugun(1);
    final not = TextEditingController();
    final ok = await kAltSayfa<bool>(context, baslik: 'Satın Alma Talebi', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${alinacak.length} kalem (stokta olmayan kısım) satın almaya talep olarak gider.', style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 10),
            StTarihAlan('İstenen teslim tarihi', deger: teslim, temizlenir: true, onSec: (s) => ss(() => teslim = s)),
            KAlan('Not', not, ipucu: 'İsteğe bağlı', satir: 2),
            KButon('Talep Oluştur', ikon: Icons.send_outlined, genis: true, onTap: () async {
              final r = await stGonder(c, '/uretim-plani/talep', {
                'plan_json': jsonEncode(_plan()),
                'teslim_tarihi': teslim ?? '',
                'not': not.text.trim(),
                if (_mod == 'ozel' && _etkinlikTarih != null) 'etkinlik_tarih': _etkinlikTarih,
                if (_mod == 'ozel' && _etkinlikTarih != null) 'etkinlik_ad': _etkinlikAd,
              }, basari: '${alinacak.length} kalemlik talep oluşturuldu.');
              if (r.ok && c.mounted) Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok == true && mounted) {
      setState(() {
        _adet.clear();
        _sonuc = null;
      });
    }
  }

  Future<void> _ozelAyar() async {
    final ad = TextEditingController(text: _etkinlikAd);
    String? tarih = _etkinlikTarih ?? stBugun(1);
    bool normal = _normalEkle;
    final ok = await kAltSayfa<bool>(context, baslik: 'Özel gün (etkinlik)', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Düğün, toplantı, kurumsal yemek… Menüdeki ürünleri seçip kişi sayısını yazın; o günün malzeme listesi çıkar.', style: TextStyle(color: t.sub, fontSize: 13, height: 1.35)),
            const SizedBox(height: 10),
            KAlan('Etkinlik adı', ad, ipucu: 'Örn: Yılmaz düğünü'),
            StTarihAlan('Etkinlik tarihi', deger: tarih, onSec: (s) => ss(() => tarih = s ?? tarih)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: normal,
              onChanged: (b) => ss(() => normal = b == true),
              title: Text('O gün normal servis de var — normal satışı da ekle', style: TextStyle(color: t.ink, fontSize: 14)),
              subtitle: Text('Satış geçmişinden o günün tahmini plana eklenir.', style: TextStyle(color: t.sub, fontSize: 12)),
            ),
            KButon('Özel gün planına geç', ikon: Icons.celebration_outlined, genis: true, onTap: () => Navigator.pop(c, true)),
          ]);
        }));
    if (ok != true || !mounted) return;
    setState(() {
      _mod = 'ozel';
      _etkinlikAd = ad.text.trim();
      _etkinlikTarih = tarih;
      _normalEkle = normal;
      _adet.clear();
      _sonuc = null;
    });
    if (_normalEkle) _normalYukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/uretim-plani',
      baslik: 'Üretim Planı',
      ikon: Icons.event_note_outlined,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    _urunler = liste(v['urunler']);
    final birimAll = liste(v['birimAll']);
    final tahmin = _tahminVeri(v);
    final q = _ara.toLowerCase();
    final gorunen = _urunler.where((u) {
      if (q.isNotEmpty && !'${u['ad']}'.toLowerCase().contains(q)) return false;
      if (_f == 'plan' && (_adet[tamOku(u['id'])] ?? 0) <= 0) return false;
      return true;
    }).toList();
    final planli = _adet.values.where((a) => a > 0).length;
    final porsiyon = _adet.values.fold<double>(0, (s, a) => s + a);
    int veriGun = 0;
    String? guven;
    for (final e in tahmin.values) {
      final m = harita(e);
      if (tamOku(m['veri_gun']) > veriGun) veriGun = tamOku(m['veri_gun']);
      guven = metinOku(m['guven']);
    }
    final sol = <Widget>[
      KCipler(
        secenekler: const [('rutin', 'Rutin üretim'), ('ozel', 'Özel gün (etkinlik)')],
        secili: _mod,
        onSec: (s) {
          if (s == 'ozel') {
            _ozelAyar();
          } else {
            setState(() {
              _mod = 'rutin';
              _adet.clear();
              _sonuc = null;
            });
          }
        },
      ),
      if (_mod == 'rutin') ...[
        const SizedBox(height: 6),
        Row(children: [
          Text('Dönem', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: KCipler(
              secenekler: const [('1', 'Yarın'), ('7', '7 Gün'), ('30', '30 Gün')],
              secili: _gun,
              onSec: (s) {
                setState(() => _gun = s);
                _tahminYukle();
              },
            ),
          ),
        ]),
        Row(children: [
          Text('Güvenlik payı', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Expanded(
            child: KCipler(
              secenekler: const [('0', '%0'), ('10', '%10'), ('20', '%20')],
              secili: _pay,
              onSec: (s) {
                setState(() => _pay = s);
                _tahminYukle();
              },
            ),
          ),
        ]),
        if (veriGun > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Tahmin: son 8 haftada $veriGun satış günü · ${const {'yuksek': 'güven yüksek', 'orta': 'güven orta', 'dusuk': 'güven düşük'}[guven] ?? ''}',
                style: TextStyle(color: t.sub, fontSize: 12.5)),
          ),
        KButon('Tahmini Uygula', ikon: Icons.auto_awesome, genis: true, onTap: tahmin.isEmpty ? null : () => _tahminUygula(tahmin)),
        if (tahmin.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Satış geçmişi yok — tahmin için kapanmış adisyon gerekir. Adetleri elle girin.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          ),
      ] else
        KKart(
          renk: t.mor1,
          onTap: _ozelAyar,
          child: Row(children: [
            Icon(Icons.celebration_outlined, color: t.mor1),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${_etkinlikAd.isEmpty ? 'Özel gün' : _etkinlikAd} · ${tarihYaz(_etkinlikTarih, saat: false)}${_normalEkle ? ' · + normal satış' : ''}',
                  style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            Icon(Icons.edit_outlined, color: t.sub, size: 18),
          ]),
        ),
      const SizedBox(height: 10),
      KAra(ipucu: 'Ürün ara', onDegis: (s) => setState(() => _ara = s)),
      const SizedBox(height: 6),
      KCipler(secenekler: [('hepsi', 'Tümü'), ('plan', 'Planlananlar $planli')], secili: _f, onSec: (s) => setState(() => _f = s)),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(planli > 0 ? '$planli ürün planlandı · ${sayiYaz(porsiyon)} ${_mod == 'ozel' ? 'porsiyon (menüde)' : 'porsiyon'}' : 'Adet gir ya da ✨ öneriye dokun',
            style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
      if (_urunler.isEmpty)
        const KBos(baslik: 'Reçetesi tanımlı aktif ürün yok', ikon: Icons.menu_book_outlined, aciklama: 'Üretim planı reçeteden malzeme hesaplar. Önce Reçeteler ekranından ürünlere reçete tanımlayın.')
      else
        for (final u in gorunen) _urunSatir(context, u, tahmin, birimAll),
    ];
    final sag = _sonucBolum(context);
    if (genisMi(context)) {
      return KGovde(yenile: yenile, maxGenislik: 1400, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sol)),
          const SizedBox(width: 18),
          Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sag)),
        ]),
      ]);
    }
    return KGovde(yenile: yenile, children: [...sol, const SizedBox(height: 12), ...sag]);
  }

  Widget _urunSatir(BuildContext context, Map<String, dynamic> u, Map<String, dynamic> tahmin, List<Map<String, dynamic>> birimAll) {
    final t = context.read<TemaProvider>();
    final id = tamOku(u['id']);
    final a = _adet[id] ?? 0;
    final th = harita(tahmin['$id']);
    final n = harita(_normal['$id']);
    final birimId = _birim[id] ?? tamOku(u['verim_birim_id']);
    return KKart(
      renk: a > 0 ? t.mor1 : null,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('${u['ad']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold))),
          if (_mod == 'rutin')
            th.isEmpty
                ? Text('satış yok', style: TextStyle(color: t.sub, fontSize: 12))
                : Tooltip(
                    message: 'Günde ort. ~${sayiYaz(th['gunluk_ort'])}${metinOku(th['en_yogun']).isNotEmpty ? ' · en yoğun gün ${th['en_yogun']}' : ''}'
                        '${tamOku(th['trend']) != 0 ? ' · son 2 hafta trendi %${th['trend']}' : ''}',
                    child: ActionChip(
                      avatar: Icon(Icons.auto_awesome, size: 16, color: t.mor1),
                      label: Text('${sayiYaz(th['oneri'])}${tamOku(th['trend']) >= 5 ? ' ↑%${th['trend']}' : (tamOku(th['trend']) <= -5 ? ' ↓%${tamOku(th['trend']).abs()}' : '')}',
                          style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                      onPressed: () => _adetDegis(id, sayiOku(th['oneri'])),
                      backgroundColor: t.card2,
                      side: BorderSide(color: t.line),
                    ),
                  )
          else if (n.isNotEmpty && _normalEkle)
            KRozet('+${sayiYaz(n['oneri'])} normal', renk: t.amber),
        ]),
        Row(children: [
          IconButton(onPressed: () => _adetDegis(id, a - 1), icon: Icon(Icons.remove_circle_outline, color: t.sub2), tooltip: 'Azalt'),
          SizedBox(
            width: 80,
            child: _AdetAlan(deger: a, onDegis: (d) => _adetDegis(id, d)),
          ),
          IconButton(onPressed: () => _adetDegis(id, a + 1), icon: Icon(Icons.add_circle_outline, color: t.sub2), tooltip: 'Artır'),
          const Spacer(),
          SizedBox(
            width: 110,
            child: DropdownButton<int>(
              isExpanded: true,
              value: birimAll.any((b) => tamOku(b['id']) == birimId) ? birimId : null,
              hint: const Text('birim'),
              underline: const SizedBox.shrink(),
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontSize: 14),
              items: [for (final b in birimAll) DropdownMenuItem(value: tamOku(b['id']), child: Text('${b['kisaltma']}'))],
              onChanged: (b) {
                if (b != null && b != birimId) _birimDegis(u, b);
              },
            ),
          ),
        ]),
      ]),
    );
  }

  List<Widget> _sonucBolum(BuildContext context) {
    final t = context.read<TemaProvider>();
    final s = _sonuc;
    final rows = liste(s?['rows']);
    final alinacak = liste(s?['alinacak']);
    final gorunen = rows.where((r) => _alKip == 'tum' || r['yeterli'] != true).toList();
    return [
      KBaslik('Alınacaklar', ikon: Icons.shopping_basket_outlined,
          alt: s == null ? null : '${alinacak.length} kalem alınacak · tahmini ${tl(s['toplam'], kisa: true)}',
          sag: _hesapliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : null),
      if (s == null)
        KBos(
          baslik: _mod == 'ozel' ? 'Özel gün menüsü boş' : 'Plan boş',
          ikon: _mod == 'ozel' ? Icons.celebration_outlined : Icons.shopping_basket_outlined,
          aciklama: _mod == 'ozel'
              ? 'Ürünlere kişi sayısını yazın; o günün malzeme listesi burada çıkar.'
              : 'Adet girin ya da "Tahmini Uygula"ya dokunun — reçeteler açılır, stok düşülür, alınacak liste burada çıkar.',
        )
      else ...[
        KCipler(secenekler: [('eksik', 'Alınacaklar ${alinacak.length}'), ('tum', 'Toplam ihtiyaç ${rows.length}')], secili: _alKip, onSec: (k) => setState(() => _alKip = k)),
        Wrap(spacing: 8, runSpacing: 4, children: [
          TextButton.icon(onPressed: () => _detayAc(context), icon: const Icon(Icons.menu_book_outlined, size: 18), label: const Text('Reçete detayı')),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _alinacakMetin()));
              if (context.mounted) kToast(context, 'Liste kopyalandı (WhatsApp\'a yapıştırabilirsiniz).');
            },
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Kopyala'),
          ),
          TextButton.icon(onPressed: _yazdir, icon: const Icon(Icons.print_outlined, size: 18), label: const Text('Yazdır')),
        ]),
        if (gorunen.isEmpty)
          const KBos(baslik: 'Stok yeterli', ikon: Icons.check_circle_outline, aciklama: 'Bu plan için hiçbir malzemeyi satın almanız gerekmiyor.')
        else
          for (final r in gorunen)
            KSatir(
              solIkon: Icon(r['yeterli'] == true ? Icons.check_circle_outline : Icons.shopping_cart_outlined, color: r['yeterli'] == true ? t.yesil : t.amber),
              baslik: '${r['ad']}',
              alt: 'Lazım ${r['lazim']} ${r['birim']} · Stok ${r['mevcut']} ${r['mevcut_birim'] ?? r['birim']}',
              sag: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(r['yeterli'] == true ? 'Yeterli' : '${r['net']} ${r['birim']}',
                    style: TextStyle(color: r['yeterli'] == true ? t.yesil : t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                if (sayiOku(r['tahmini_maliyet']) > 0) Text(tl(r['tahmini_maliyet'], kisa: true), style: TextStyle(color: t.sub, fontSize: 12)),
              ]),
            ),
        const SizedBox(height: 10),
        KButon('Satın Alma Talebi Oluştur', ikon: Icons.send_outlined, genis: true, onTap: alinacak.isEmpty ? null : _talep),
      ],
    ];
  }

  void _detayAc(BuildContext context) {
    final detay = liste(_sonuc?['detay']);
    kAltSayfa(context, baslik: 'Reçete detayı', icerik: (c) {
      final t = c.read<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (detay.isEmpty) const KBos(baslik: 'Detay yok'),
        for (final d in detay) ...[
          KBaslik('${d['urun']} × ${d['adet']}', ikon: Icons.restaurant_menu),
          for (final k in liste(d['kalemler']))
            KSatir(baslik: '${k['ad']}', sag: Text('${k['miktar']} ${k['birim']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700))),
        ],
      ]);
    });
  }
}

class _AdetAlan extends StatefulWidget {
  final double deger;
  final ValueChanged<double> onDegis;
  const _AdetAlan({required this.deger, required this.onDegis});

  @override
  State<_AdetAlan> createState() => _AdetAlanState();
}

class _AdetAlanState extends State<_AdetAlan> {
  late final TextEditingController _k = TextEditingController(text: _yaz(widget.deger));

  String _yaz(double d) => d == 0 ? '' : (d == d.roundToDouble() ? '${d.round()}' : '$d');

  @override
  void didUpdateWidget(covariant _AdetAlan old) {
    super.didUpdateWidget(old);
    final simdiki = double.tryParse(_k.text.replaceAll(',', '.')) ?? 0;
    if (simdiki != widget.deger) _k.text = _yaz(widget.deger);
  }

  @override
  void dispose() {
    _k.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return TextField(
      controller: _k,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (s) => widget.onDegis(double.tryParse(s.replaceAll(',', '.')) ?? 0),
      style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        hintText: '0',
        isDense: true,
        filled: true,
        fillColor: t.card2,
        contentPadding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      ),
    );
  }
}
