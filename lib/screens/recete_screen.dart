import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';

/// Reçete Yönetimi — ürün listesi (food-cost + reçeteli rozet) → reçete editörü
/// (malzeme + miktar + birim; canlı maliyet & food-cost). Kaydet = sahip.
class ReceteScreen extends StatefulWidget {
  const ReceteScreen({super.key});
  @override
  State<ReceteScreen> createState() => _ReceteScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _sari = Color(0xFFF59E0B);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';
String _mik(num v) => v == v.roundToDouble() ? _fmt.format(v.round()) : v.toStringAsFixed(2);
Color _fcRenk(num fc) => fc >= 38 ? _kirmizi : (fc >= 30 ? _sari : _yesil);

InputDecoration _dec(String label) => InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: _gri), isDense: true,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
    );

class _ReceteScreenState extends State<ReceteScreen> {
  List urunler = [];
  bool loading = true;
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
      final res = await Api.receteUrunler(auth.token!);
      if (!mounted) return;
      setState(() {
        urunler = (res['urunler'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final filtre = _ara.trim().toLowerCase();
    final liste = filtre.isEmpty ? urunler : urunler.where((u) => (u as Map)['ad'].toString().toLowerCase().contains(filtre)).toList();
    final recetesiz = urunler.where((u) => (u as Map)['receteli'] != true).length;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Reçete Yönetimi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              if (recetesiz > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(14, 10, 14, 0), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _sari.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _sari.withValues(alpha: 0.4))),
                  child: Row(children: [const Icon(Icons.info_outline, color: _sari, size: 18), const SizedBox(width: 8), Expanded(child: Text('$recetesiz ürünün reçetesi yok — food-cost hesaplanamıyor.', style: const TextStyle(color: _sari, fontSize: 12)))]),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: TextField(onChanged: (v) => setState(() => _ara = v), style: const TextStyle(color: Colors.white), decoration: _dec('Ürün ara').copyWith(prefixIcon: const Icon(Icons.search, color: _gri))),
              ),
              Expanded(child: RefreshIndicator(onRefresh: _yukle, color: _mor1, backgroundColor: _card, child: ListView(padding: const EdgeInsets.all(14), children: [
                for (final u in liste) _kart(u as Map),
                const SizedBox(height: 30),
              ]))),
            ]),
    );
  }

  // ==========================================================================
  // MASAÜSTÜ (PC/tablet) — kategori tarzı bölümler + ürün reçete kart ızgarası
  // ==========================================================================
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final filtre = _ara.trim().toLowerCase();
    final liste = (filtre.isEmpty
            ? urunler
            : urunler.where((u) => (u as Map)['ad'].toString().toLowerCase().contains(filtre)).toList())
        .cast<Map>();
    final receteliler = liste.where((u) => u['receteli'] == true).toList();
    final recetesizler = liste.where((u) => u['receteli'] != true).toList();
    final recetesizToplam = urunler.where((u) => (u as Map)['receteli'] != true).length;

    return MasaustuSayfa(
      baslik: 'Reçeteler',
      ikon: Icons.menu_book_outlined,
      altBaslik: '${urunler.length} ürün · $recetesizToplam reçetesiz',
      araclar: [
        SizedBox(
          width: 240,
          child: TextField(
            onChanged: (v) => setState(() => _ara = v),
            style: TextStyle(color: t.ink, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Ürün ara',
              hintStyle: TextStyle(color: t.sub),
              isDense: true,
              prefixIcon: Icon(Icons.search, color: t.sub, size: 18),
              filled: true,
              fillColor: t.card2,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        MButon('Yenile', t.mor1, _yukle, dolu: false, ikon: Icons.refresh),
        const SizedBox(width: 4),
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : liste.isEmpty
              ? Center(child: Text(filtre.isEmpty ? 'Ürün yok.' : 'Eşleşen ürün yok.', style: TextStyle(color: t.sub, fontSize: 14)))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (recetesizToplam > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: MKart(
                          kenar: t.amber.withValues(alpha: 0.5),
                          padding: const EdgeInsets.all(14),
                          child: Row(children: [
                            Icon(Icons.info_outline, color: t.amber, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text('$recetesizToplam ürünün reçetesi yok — food-cost hesaplanamıyor.', style: TextStyle(color: t.amber, fontSize: 13, fontWeight: FontWeight.w600))),
                          ]),
                        ),
                      ),
                    if (receteliler.isNotEmpty) ...[
                      MBolumBaslik('Reçeteli Ürünler', renk: t.yesil, sayi: receteliler.length),
                      _izgara(receteliler),
                      const SizedBox(height: 18),
                    ],
                    if (recetesizler.isNotEmpty) ...[
                      MBolumBaslik('Reçetesiz Ürünler', renk: t.amber, sayi: recetesizler.length),
                      _izgara(recetesizler),
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
    );
  }

  Widget _izgara(List<Map> urunListe) {
    return LayoutBuilder(builder: (ctx, c) {
      final sutun = c.maxWidth >= 1500 ? 4 : (c.maxWidth >= 1150 ? 3 : 2);
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: urunListe.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: sutun,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 116,
        ),
        itemBuilder: (ctx, i) => _masaustuKart(ctx, urunListe[i]),
      );
    });
  }

  Widget _masaustuKart(BuildContext context, Map u) {
    final t = context.watch<TemaProvider>();
    final receteli = u['receteli'] == true;
    final fc = _n(u['food_cost']);
    return MKart(
      onTap: () => _editor(u),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Expanded(child: Text(u['ad'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
            const SizedBox(width: 6),
            if (receteli && fc > 0)
              MRozet('%${fc.toStringAsFixed(0)}', _fcRenk(fc))
            else
              MRozet('reçetesiz', t.amber),
          ]),
          Row(children: [
            Text('Fiyat ${_tl(u['fiyat'])}', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (receteli) ...[
              const SizedBox(width: 12),
              Text('Maliyet ${_tl(u['maliyet'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
            ],
            const Spacer(),
            Icon(Icons.chevron_right, color: t.sub, size: 20),
          ]),
        ],
      ),
    );
  }

  Widget _kart(Map u) {
    final receteli = u['receteli'] == true;
    final fc = _n(u['food_cost']);
    return GestureDetector(
      onTap: () => _editor(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF232B42))),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(u['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              if (!receteli)
                Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _sari.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)), child: const Text('reçetesiz', style: TextStyle(color: _sari, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 3),
            Text('Fiyat ${_tl(u['fiyat'])}${receteli ? ' · Maliyet ${_tl(u['maliyet'])}' : ''}', style: const TextStyle(color: _gri, fontSize: 12)),
          ])),
          if (receteli && fc > 0)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: _fcRenk(fc).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Text('%${fc.toStringAsFixed(0)}', style: TextStyle(color: _fcRenk(fc), fontWeight: FontWeight.bold, fontSize: 15))),
          const Icon(Icons.chevron_right, color: _gri, size: 20),
        ]),
      ),
    );
  }

  Future<void> _editor(Map u) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => ReceteEditorScreen(urunId: _n(u['id']).toInt(), urunAd: u['ad'].toString())));
    if (degisti == true) _yukle();
  }
}

// ============================================================================
// REÇETE EDİTÖRÜ
// ============================================================================
class ReceteEditorScreen extends StatefulWidget {
  final int urunId;
  final String urunAd;
  const ReceteEditorScreen({super.key, required this.urunId, required this.urunAd});
  @override
  State<ReceteEditorScreen> createState() => _ReceteEditorScreenState();
}

class _ReceteEditorScreenState extends State<ReceteEditorScreen> {
  final List<Map<String, dynamic>> kalemler = []; // {malzeme_id, malzeme, miktar, birim_id, birim, satir_maliyet}
  List malzemeler = [];
  List birimler = [];
  double fiyat = 0;
  bool loading = true;
  bool duzenleyebilir = false;
  bool kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.urunRecete(auth.token!, widget.urunId);
      final m = await Api.stokMeta(auth.token!);
      final mal = await Api.malzemeler(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          kalemler.clear();
          for (final k in (res['kalemler'] as List?) ?? []) {
            kalemler.add({'malzeme_id': _n((k as Map)['malzeme_id']).toInt(), 'malzeme': k['malzeme'], 'miktar': _n(k['miktar']).toDouble(), 'birim_id': _n(k['birim_id']).toInt(), 'birim': k['birim'], 'satir_maliyet': _n(k['satir_maliyet']).toDouble()});
          }
          fiyat = _n(res['fiyat']).toDouble();
          duzenleyebilir = res['duzenleyebilir'] == true;
          birimler = (m['birimler'] as List?) ?? [];
          malzemeler = (mal['malzemeler'] as List?) ?? [];
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  // Malzeme birim maliyetini (temel birim başına) bul — canlı hesap için
  double _malzemeMaliyet(int malzemeId) {
    final m = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == malzemeId, orElse: () => null);
    return m == null ? 0 : _n((m as Map)['guncel_maliyet']).toDouble();
  }

  // Basit çevrim (kg->g, lt->ml) — sunucudakiyle uyumlu tahmini canlı maliyet
  double _cevrim(int malzemeId, int birimId) {
    final m = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == malzemeId, orElse: () => null);
    if (m == null) return 1;
    final temel = _n((m as Map)['temel_birim_id']).toInt();
    if (birimId == temel) return 1;
    final b = birimler.firstWhere((x) => _n((x as Map)['id']).toInt() == birimId, orElse: () => null);
    final t = birimler.firstWhere((x) => _n((x as Map)['id']).toInt() == temel, orElse: () => null);
    if (b == null || t == null) return 1;
    final bk = (b as Map)['kisaltma'].toString();
    final tk = (t as Map)['kisaltma'].toString();
    const genel = {'kg': {'g': 1000.0}, 'lt': {'ml': 1000.0}, 'g': {'kg': 0.001}, 'ml': {'lt': 0.001}};
    return (genel[bk]?[tk]) ?? 1.0;
  }

  double get _maliyet {
    double t = 0;
    for (final k in kalemler) {
      t += _n(k['miktar']) * _cevrim(k['malzeme_id'], k['birim_id']) * _malzemeMaliyet(k['malzeme_id']);
    }
    return t;
  }

  double get _fc => fiyat > 0 && _maliyet > 0 ? _maliyet / fiyat * 100 : 0;

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: Text(widget.urunAd, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
                _ozet(),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Malzemeler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  if (duzenleyebilir) TextButton.icon(onPressed: _kalemEkle, icon: const Icon(Icons.add, color: _mavi, size: 18), label: const Text('Malzeme Ekle', style: TextStyle(color: _mavi))),
                ]),
                if (kalemler.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Bu ürünün reçetesi boş. Malzeme ekleyin.', style: TextStyle(color: _gri, fontSize: 13)))
                else
                  for (int i = 0; i < kalemler.length; i++) _kalemKart(i),
                const SizedBox(height: 80),
              ])),
              if (duzenleyebilir) _altBar(),
            ]),
    );
  }

  // ==========================================================================
  // MASAÜSTÜ EDİTÖR — tema-duyarlı özet + malzeme kartları + kaydet
  // ==========================================================================
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: widget.urunAd,
      ikon: Icons.menu_book_outlined,
      altBaslik: 'Reçete editörü',
      araclar: [
        if (duzenleyebilir) ...[
          MButon('Malzeme Ekle', t.mavi, _kalemEkle, dolu: false, ikon: Icons.add),
          const SizedBox(width: 8),
          MButon(kaydediliyor ? 'Kaydediliyor…' : 'Reçeteyi Kaydet', t.mor1, kaydediliyor ? () {} : _kaydet, ikon: Icons.save_outlined),
          const SizedBox(width: 4),
        ],
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _ozetMasaustu(t),
                const SizedBox(height: 18),
                MBolumBaslik('Malzemeler', renk: t.mor1, sayi: kalemler.length),
                if (kalemler.isEmpty)
                  MKart(child: Text('Bu ürünün reçetesi boş. Malzeme ekleyin.', style: TextStyle(color: t.sub, fontSize: 13)))
                else
                  for (int i = 0; i < kalemler.length; i++)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: _kalemKartMasaustu(t, i)),
                const SizedBox(height: 30),
              ],
            ),
    );
  }

  Widget _ozetMasaustu(TemaProvider t) {
    final fc = _fc;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi]), borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tahmini Maliyet', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 2),
          Text(_tl(_maliyet), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          Text('Satış ${_tl(fiyat)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(fc > 0 ? '%${fc.toStringAsFixed(0)}' : '—', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            const Text('food-cost', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }

  Widget _kalemKartMasaustu(TemaProvider t, int i) {
    final k = kalemler[i];
    final satir = _n(k['miktar']) * _cevrim(k['malzeme_id'], k['birim_id']) * _malzemeMaliyet(k['malzeme_id']);
    return MKart(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k['malzeme'].toString(), style: TextStyle(color: t.ink, fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${_mik(_n(k['miktar']))} ${k['birim']}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ])),
        Text(_tl(satir), style: TextStyle(color: t.sub2, fontWeight: FontWeight.bold)),
        if (duzenleyebilir)
          IconButton(padding: const EdgeInsets.only(left: 10), constraints: const BoxConstraints(minWidth: 36), onPressed: () => setState(() => kalemler.removeAt(i)), icon: Icon(Icons.close, color: t.sub, size: 18)),
      ]),
    );
  }

  Widget _ozet() {
    final fc = _fc;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tahmini Maliyet', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(_tl(_maliyet), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('Satış ${_tl(fiyat)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(fc > 0 ? '%${fc.toStringAsFixed(0)}' : '—', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text('food-cost', style: TextStyle(color: Colors.white70, fontSize: 10)),
          ]),
        ),
      ]),
    );
  }

  Widget _kalemKart(int i) {
    final k = kalemler[i];
    final satir = _n(k['miktar']) * _cevrim(k['malzeme_id'], k['birim_id']) * _malzemeMaliyet(k['malzeme_id']);
    return Container(
      margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF232B42))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k['malzeme'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${_mik(_n(k['miktar']))} ${k['birim']}', style: const TextStyle(color: _gri, fontSize: 12)),
        ])),
        Text(_tl(satir), style: const TextStyle(color: _gri, fontWeight: FontWeight.bold)),
        if (duzenleyebilir)
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36), onPressed: () => setState(() => kalemler.removeAt(i)), icon: const Icon(Icons.close, color: _gri, size: 18)),
      ]),
    );
  }

  Widget _altBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(color: _card, border: Border(top: BorderSide(color: Color(0xFF232B42)))),
        child: SizedBox(width: double.infinity, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: kaydediliyor ? null : _kaydet,
          child: kaydediliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Reçeteyi Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
        )),
      );

  Future<void> _kalemEkle() async {
    if (malzemeler.isEmpty) { _uyar('Önce Stok ekranından malzeme ekleyin'); return; }
    int malzemeId = _n((malzemeler.first as Map)['id']).toInt();
    int birimId = _n((malzemeler.first as Map)['temel_birim_id']).toInt();
    final miktarC = TextEditingController();
    final eklendi = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
          const Text('Malzeme Ekle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _drop('Malzeme', malzemeId, {for (final m in malzemeler) _n((m as Map)['id']).toInt(): m['ad'].toString()}, (v) {
            final m = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == v);
            setS(() { malzemeId = v; birimId = _n((m as Map)['temel_birim_id']).toInt(); });
          }),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: miktarC, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Miktar (1 porsiyon)'))),
            const SizedBox(width: 10),
            Expanded(child: _drop('Birim', birimId, {for (final b in birimler) _n((b as Map)['id']).toInt(): b['kisaltma'].toString()}, (v) => setS(() => birimId = v))),
          ]),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      )),
    );
    if (eklendi != true) return;
    final miktar = double.tryParse(miktarC.text.replaceAll(',', '.')) ?? 0;
    if (miktar <= 0) { _uyar('Geçerli miktar girin'); return; }
    final malzeme = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == malzemeId) as Map;
    final birim = birimler.firstWhere((x) => _n((x as Map)['id']).toInt() == birimId) as Map;
    setState(() => kalemler.add({'malzeme_id': malzemeId, 'malzeme': malzeme['ad'], 'miktar': miktar, 'birim_id': birimId, 'birim': birim['kisaltma']}));
  }

  Future<void> _kaydet() async {
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final gonder = kalemler.map((k) => {'malzeme_id': k['malzeme_id'], 'miktar': k['miktar'], 'birim_id': k['birim_id']}).toList();
      final res = await Api.receteKaydet(auth.token!, widget.urunId, gonder);
      if (!mounted) return;
      if (res['ok'] == 1) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => kaydediliyor = false);
        _uyar(res['hata']?.toString() ?? 'Kaydedilemedi');
      }
    } catch (_) {
      if (mounted) { setState(() => kaydediliyor = false); _uyar('Bağlantı hatası'); }
    }
  }

  Widget _drop(String label, int? value, Map<int, String> items, ValueChanged<int> onChanged) => InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          value: items.containsKey(value) ? value : null, isDense: true, isExpanded: true, dropdownColor: _card, style: const TextStyle(color: Colors.white),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      );
}
