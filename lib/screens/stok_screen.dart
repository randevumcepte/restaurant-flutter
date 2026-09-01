import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';

/// Stok / Malzeme — mevcut stok, değer, kritik uyarı; malzeme ekle/düzenle,
/// manuel giriş/fire/düzeltme hareketi. Düzenleme = sahip.
class StokScreen extends StatefulWidget {
  const StokScreen({super.key});
  @override
  State<StokScreen> createState() => _StokScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';
String _mik(num v) => v == v.roundToDouble() ? _fmt.format(v.round()) : v.toStringAsFixed(2);

InputDecoration _dec(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _gri),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
    );

class _StokScreenState extends State<StokScreen> {
  List malzemeler = [];
  double toplamDeger = 0;
  int kritikSayi = 0;
  bool loading = true;
  bool duzenleyebilir = false;
  List birimler = [];
  List kategoriler = [];
  String _ara = '';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.malzemeler(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          malzemeler = (res['malzemeler'] as List?) ?? [];
          toplamDeger = _n(res['toplam_deger']).toDouble();
          kritikSayi = _n(res['kritik_sayi']).toInt();
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
        if (birimler.isEmpty) _metaYukle();
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _metaYukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.stokMeta(auth.token!);
      if (!mounted || res['ok'] != 1) return;
      setState(() {
        birimler = (res['birimler'] as List?) ?? [];
        kategoriler = (res['kategoriler'] as List?) ?? [];
      });
    } catch (_) {}
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final filtre = _ara.trim().toLowerCase();
    final liste = filtre.isEmpty ? malzemeler : malzemeler.where((m) => (m as Map)['ad'].toString().toLowerCase().contains(filtre)).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Stok / Malzeme', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: duzenleyebilir
          ? FloatingActionButton.extended(backgroundColor: _mor1, onPressed: () => _malzemeForm(null), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Malzeme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: _ozetKart(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: TextField(
                  onChanged: (v) => setState(() => _ara = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: _dec('Malzeme ara').copyWith(prefixIcon: const Icon(Icons.search, color: _gri), isDense: true),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle, color: _mor1, backgroundColor: _card,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    if (liste.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('Malzeme yok. Sağ alttan ekleyin.', style: TextStyle(color: _gri))))
                    else
                      for (final m in liste) _malzemeKart(m as Map),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ]),
    );
  }

  // ===================== MASAÜSTÜ (PC/tablet) — renk kodlu kart ızgarası =====================

  static const _mYesil = Color(0xFF16A34A);
  static const _mTuruncu = Color(0xFFEA580C);
  static const _mKirmizi = Color(0xFFDC2626);

  /// Bir malzemenin durum rengi: kırmızı=kritik, turuncu=kritiğe yakın (az),
  /// yeşil=yeterli. Mobil `kritik` bayrağı bozulmadan; turuncu additive olarak
  /// mevcut ≤ kritik eşiğin 1.5 katı ise türetilir.
  Color _durumRenk(Map m) {
    if (m['kritik'] == true) return _mKirmizi;
    final mevcut = _n(m['mevcut']).toDouble();
    final esik = _n(m['kritik_stok']).toDouble();
    if (esik > 0 && mevcut <= esik * 1.5) return _mTuruncu;
    return _mYesil;
  }

  String _durumMetin(Color c) => c == _mKirmizi ? 'Kritik' : (c == _mTuruncu ? 'Az' : 'Yeterli');

  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final filtre = _ara.trim().toLowerCase();
    final liste = (filtre.isEmpty
            ? malzemeler
            : malzemeler.where((m) => (m as Map)['ad'].toString().toLowerCase().contains(filtre)).toList())
        .cast<Map>();

    // Kategoriye göre grupla (response'taki `kategori` alanı).
    final Map<String, List<Map>> gruplar = {};
    for (final m in liste) {
      final k = (m['kategori']?.toString().trim().isNotEmpty ?? false) ? m['kategori'].toString() : 'Diğer';
      (gruplar[k] ??= []).add(m);
    }
    final kategoriAdlari = gruplar.keys.toList()..sort();

    return MasaustuSayfa(
      baslik: 'Stok / Malzeme',
      ikon: Icons.inventory_2_outlined,
      altBaslik: 'Toplam değer ${_tl(toplamDeger)}'
          '${kritikSayi > 0 ? '  ·  $kritikSayi kritik' : ''}',
      araclar: [
        SizedBox(
          width: 240,
          child: TextField(
            onChanged: (v) => setState(() => _ara = v),
            style: TextStyle(color: t.ink, fontSize: 13),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Malzeme ara',
              hintStyle: TextStyle(color: t.sub),
              prefixIcon: Icon(Icons.search, color: t.sub, size: 18),
              filled: true,
              fillColor: t.card2,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)),
            ),
          ),
        ),
        if (duzenleyebilir) ...[
          const SizedBox(width: 10),
          MButon('Malzeme', t.mor1, () => _malzemeForm(null), ikon: Icons.add),
        ],
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : liste.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.inventory_2_outlined, color: t.sub, size: 48),
                    const SizedBox(height: 10),
                    Text(
                      malzemeler.isEmpty ? 'Malzeme yok. Sağ üstten ekleyin.' : 'Aramaya uygun malzeme yok.',
                      style: TextStyle(color: t.sub, fontSize: 14),
                    ),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: t.mor1,
                  backgroundColor: t.card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    children: [
                      for (final kat in kategoriAdlari) ...[
                        MBolumBaslik(kat, renk: t.mor1, sayi: gruplar[kat]!.length),
                        GridView.count(
                          crossAxisCount: 4,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [for (final m in gruplar[kat]!) _mKart(m, t)],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _mKart(Map m, TemaProvider t) {
    final renk = _durumRenk(m);
    final kritik = m['kritik'] == true;
    final mevcut = _n(m['mevcut']);
    return MKart(
      padding: EdgeInsets.zero,
      onTap: () => _detay(m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // üst renk şerit
        Container(height: 5, decoration: BoxDecoration(color: renk, borderRadius: const BorderRadius.vertical(top: Radius.circular(13)))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    m['ad'].toString(),
                    style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (kritik) ...[const SizedBox(width: 6), Icon(Icons.warning_amber_rounded, color: renk, size: 18)],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(m['kategori']?.toString() ?? '', style: TextStyle(color: t.sub, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                MRozet(_durumMetin(renk), renk),
              ]),
              const Spacer(),
              _mSatir(t, 'Kalan', '${_mik(mevcut)} ${m['birim']}', renk),
              _mSatir(t, 'Kritik', '${_mik(_n(m['kritik_stok']))} ${m['birim']}', t.sub),
              _mSatir(t, 'Değer', _tl(m['deger']), t.sub),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _mSatir(TemaProvider t, String etiket, String deger, Color degerRenk) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(etiket, style: TextStyle(color: t.sub, fontSize: 12)),
          Text(deger, style: TextStyle(color: degerRenk, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _ozetKart() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Toplam Stok Değeri', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(_tl(toplamDeger), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          ])),
          if (kritikSayi > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('$kritikSayi', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const Text('kritik', style: TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
        ]),
      );

  Widget _malzemeKart(Map m) {
    final kritik = m['kritik'] == true;
    final mevcut = _n(m['mevcut']);
    return GestureDetector(
      onTap: () => _detay(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: kritik ? _kirmizi.withValues(alpha: 0.5) : const Color(0xFF232B42))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(m['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              if (kritik) ...[const SizedBox(width: 6), const Icon(Icons.warning_amber_rounded, color: _kirmizi, size: 16)],
            ]),
            const SizedBox(height: 3),
            Text('${m['kategori']} · ${_tl(m['guncel_maliyet'])}/${m['birim']}', style: const TextStyle(color: _gri, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_mik(mevcut)} ${m['birim']}', style: TextStyle(color: kritik ? _kirmizi : Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_tl(m['deger']), style: const TextStyle(color: _gri, fontSize: 11)),
          ]),
          const Icon(Icons.chevron_right, color: _gri, size: 20),
        ]),
      ),
    );
  }

  Future<void> _detay(Map m) async {
    final auth = context.read<AuthProvider>();
    final id = _n(m['id']).toInt();
    Map? d;
    try {
      final res = await Api.malzemeDetay(auth.token!, id);
      if (res['ok'] == 1) d = res;
    } catch (_) {}
    if (!mounted || d == null) { _uyar('Detay alınamadı'); return; }
    final Map dd = d;
    final hareketler = (dd['hareketler'] as List?) ?? [];
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false, initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4,
        builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
          Text(dd['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Mevcut: ${_mik(_n(dd['mevcut']))} ${dd['birim']} · Maliyet ${_tl(dd['guncel_maliyet'])}/${dd['birim']} · Değer ${_tl(dd['deger'])}', style: const TextStyle(color: _gri, fontSize: 13)),
          const SizedBox(height: 12),
          if (duzenleyebilir)
            Row(children: [
              Expanded(child: _kbtn('Giriş', Icons.add, _yesil, () { Navigator.pop(ctx); _hareketDialog(id, 'giris'); })),
              const SizedBox(width: 8),
              Expanded(child: _kbtn('Fire', Icons.delete_outline, _kirmizi, () { Navigator.pop(ctx); _hareketDialog(id, 'fire'); })),
              const SizedBox(width: 8),
              Expanded(child: _kbtn('Düzelt', Icons.tune, _mavi, () { Navigator.pop(ctx); _hareketDialog(id, 'duzeltme'); })),
            ]),
          const SizedBox(height: 14),
          const Text('Son Hareketler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (hareketler.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Hareket yok.', style: TextStyle(color: _gri, fontSize: 13)))
          else
            for (final h in hareketler) _hareketSatir(h as Map),
        ]),
      ),
    );
  }

  Widget _kbtn(String s, IconData ic, Color c, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.4))),
          child: Column(children: [Icon(ic, color: c, size: 20), const SizedBox(height: 2), Text(s, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12))]),
        ),
      );

  Widget _hareketSatir(Map h) {
    final miktar = _n(h['miktar']);
    final poz = miktar >= 0;
    final tipAd = {'alis': 'Alış', 'tuketim': 'Satış tüketimi', 'fire': 'Fire', 'sayim': 'Sayım', 'iade': 'Giriş', 'transfer': 'Transfer'}[h['tip']] ?? h['tip'].toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(poz ? Icons.arrow_downward : Icons.arrow_upward, color: poz ? _yesil : _kirmizi, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tipAd, style: const TextStyle(color: Colors.white, fontSize: 13)),
          Text('${h['tarih']}${(h['aciklama']?.toString() ?? '').isNotEmpty ? ' · ${h['aciklama']}' : ''}', style: const TextStyle(color: _gri, fontSize: 11)),
        ])),
        Text('${poz ? '+' : ''}${_mik(miktar)}', style: TextStyle(color: poz ? _yesil : _kirmizi, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Future<void> _hareketDialog(int malzemeId, String tip) async {
    final miktarC = TextEditingController();
    final aciklamaC = TextEditingController();
    final baslik = {'giris': 'Stok Girişi', 'fire': 'Fire / Zayi', 'duzeltme': 'Sayım Düzeltme (±)'}[tip]!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card, title: Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: miktarC, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), style: const TextStyle(color: Colors.white), decoration: _dec('Miktar (temel birim)')),
          const SizedBox(height: 10),
          TextField(controller: aciklamaC, style: const TextStyle(color: Colors.white), decoration: _dec('Açıklama (opsiyonel)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: _gri))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1), onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;
    final miktar = double.tryParse(miktarC.text.replaceAll(',', '.')) ?? 0;
    if (miktar == 0) { _uyar('Geçerli miktar girin'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.stokHareket(auth.token!, malzemeId, tip, miktar, aciklama: aciklamaC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Kaydedilemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _malzemeForm(Map? m) async {
    if (birimler.isEmpty) await _metaYukle();
    if (!mounted) return;
    final adC = TextEditingController(text: m?['ad']?.toString() ?? '');
    final kritikC = TextEditingController(text: m != null && _n(m['kritik_stok']) > 0 ? _mik(_n(m['kritik_stok'])) : '');
    final maliyetC = TextEditingController(text: m != null && _n(m['guncel_maliyet']) > 0 ? _n(m['guncel_maliyet']).toString() : '');
    int? kategoriId = m != null ? _n(m['kategori_id']).toInt() : (kategoriler.isNotEmpty ? _n((kategoriler.first as Map)['id']).toInt() : null);
    int birimId = m != null ? _n(m['temel_birim_id']).toInt() : (birimler.isNotEmpty ? _n((birimler.first as Map)['id']).toInt() : 0);
    bool takipli = m == null ? true : _n(m['stok_takipli']) == 1;
    final yeni = m == null;

    final kaydet = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
          Text(yeni ? 'Yeni Malzeme' : 'Malzeme Düzenle', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          TextField(controller: adC, style: const TextStyle(color: Colors.white), decoration: _dec('Malzeme adı')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _drop('Kategori', kategoriId, {for (final k in kategoriler) _n((k as Map)['id']).toInt(): k['ad'].toString()}, (v) => setS(() => kategoriId = v))),
            const SizedBox(width: 8),
            IconButton(onPressed: () => _kategoriEkle(setS, (id) => kategoriId = id), icon: const Icon(Icons.add_circle_outline, color: _mavi)),
          ]),
          const SizedBox(height: 10),
          _drop('Temel/Stok Birimi', birimId, {for (final b in birimler) _n((b as Map)['id']).toInt(): '${b['ad']} (${b['kisaltma']})'}, (v) => setS(() => birimId = v)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: kritikC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Kritik stok'))),
            const SizedBox(width: 10),
            if (yeni) Expanded(child: TextField(controller: maliyetC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Başlangıç ₺/birim'))),
          ]),
          SwitchListTile(contentPadding: EdgeInsets.zero, activeThumbColor: _yesil, title: const Text('Stok takibi yapılsın', style: TextStyle(color: Colors.white, fontSize: 14)), value: takipli, onChanged: (v) => setS(() => takipli = v)),
          const SizedBox(height: 4),
          SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)))),
        ])),
      )),
    );
    if (kaydet != true) return;
    if (adC.text.trim().isEmpty) { _uyar('Ad boş olamaz'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malzemeKaydet(auth.token!,
        id: yeni ? null : _n(m['id']).toInt(), ad: adC.text.trim(), kategoriId: kategoriId ?? 0, temelBirimId: birimId,
        kritikStok: double.tryParse(kritikC.text.replaceAll(',', '.')) ?? 0, stokTakipli: takipli,
        guncelMaliyet: double.tryParse(maliyetC.text.replaceAll(',', '.')) ?? 0);
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Kaydedilemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _kategoriEkle(StateSetter setS, void Function(int) onEkle) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _card, title: const Text('Yeni Kategori', style: TextStyle(color: Colors.white, fontSize: 16)),
      content: TextField(controller: c, autofocus: true, style: const TextStyle(color: Colors.white), decoration: _dec('Kategori adı')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: _gri))), FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle'))],
    ));
    if (ok != true || c.text.trim().isEmpty) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malzemeKategoriEkle(auth.token!, c.text.trim());
      if (res['ok'] == 1) {
        await _metaYukle();
        final id = _n(res['id']).toInt();
        setS(() => onEkle(id));
      }
    } catch (_) {}
  }

  Widget _drop(String label, int? value, Map<int, String> items, ValueChanged<int> onChanged) => InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          value: items.containsKey(value) ? value : (items.isNotEmpty ? items.keys.first : null),
          isDense: true, isExpanded: true, dropdownColor: _card, style: const TextStyle(color: Colors.white),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      );
}
