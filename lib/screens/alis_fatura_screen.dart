import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Alış Faturaları — liste (aylık, fiyat uyarısı renkli) + yeni fatura girişi.
/// Kaydedince: stok girişi + ağırlıklı ort. maliyet güncelleme + otomatik gider.
class AlisFaturaScreen extends StatefulWidget {
  const AlisFaturaScreen({super.key});
  @override
  State<AlisFaturaScreen> createState() => _AlisFaturaScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _sari = Color(0xFFF59E0B);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
Color _uyariRenk(String u) => {'kirmizi': _kirmizi, 'sari': _sari}[u] ?? _yesil;

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';
String _mik(num v) => v == v.roundToDouble() ? _fmt.format(v.round()) : v.toStringAsFixed(2);

InputDecoration _dec(String label) => InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: _gri), isDense: true,
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
    );

class _AlisFaturaScreenState extends State<AlisFaturaScreen> {
  List faturalar = [];
  double toplam = 0;
  bool loading = true;
  bool duzenleyebilir = false;
  DateTime _ay = DateTime.now();

  String get _ayParam => '${_ay.year}-${_ay.month.toString().padLeft(2, '0')}';
  String get _ayMetin => '${_aylar[_ay.month]} ${_ay.year}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.alisFaturalari(auth.token!, ay: _ayParam);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          faturalar = (res['faturalar'] as List?) ?? [];
          toplam = _n(res['toplam']).toDouble();
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }
  void _ayDegis(int d) {
    final y = DateTime(_ay.year, _ay.month + d);
    if (y.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) return;
    setState(() => _ay = y);
    _yukle();
  }

  Future<void> _yeniFatura() async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const AlisFaturaEkleScreen()));
    if (degisti == true) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Alış Faturaları', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      floatingActionButton: duzenleyebilir ? FloatingActionButton.extended(backgroundColor: _mor1, onPressed: _yeniFatura, icon: const Icon(Icons.note_add_outlined, color: Colors.white), label: const Text('Yeni Fatura', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () => _ayDegis(-1), icon: const Icon(Icons.chevron_left, color: _mor1)),
                Text(_ayMetin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(onPressed: () => _ayDegis(1), icon: const Icon(Icons.chevron_right, color: _mor1)),
              ]),
              Expanded(child: RefreshIndicator(onRefresh: _yukle, color: _mor1, backgroundColor: _card, child: ListView(padding: const EdgeInsets.all(14), children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Bu Ay Alış Toplamı', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(_tl(toplam), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 12),
                if (faturalar.isEmpty)
                  const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: Text('Bu ay fatura yok.', style: TextStyle(color: _gri))))
                else
                  for (final f in faturalar) _kart(f as Map),
                const SizedBox(height: 80),
              ]))),
            ]),
    );
  }

  Widget _kart(Map f) {
    final u = f['uyari'].toString();
    return GestureDetector(
      onTap: () => _detay(f),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF232B42))),
        child: Row(children: [
          Container(width: 4, height: 40, decoration: BoxDecoration(color: _uyariRenk(u), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f['tedarikci'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('${f['tarih']}${(f['fatura_no']?.toString() ?? '').isNotEmpty ? ' · No: ${f['fatura_no']}' : ''}', style: const TextStyle(color: _gri, fontSize: 12)),
          ])),
          Text(_tl(f['toplam']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const Icon(Icons.chevron_right, color: _gri, size: 20),
        ]),
      ),
    );
  }

  Future<void> _detay(Map f) async {
    final auth = context.read<AuthProvider>();
    Map? d;
    try {
      final res = await Api.alisFaturaDetay(auth.token!, _n(f['id']).toInt());
      if (res['ok'] == 1) d = res;
    } catch (_) {}
    if (!mounted || d == null) { _uyar('Detay alınamadı'); return; }
    final Map dd = d;
    final kalemler = (dd['kalemler'] as List?) ?? [];
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(expand: false, initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.4, builder: (ctx, scroll) => ListView(controller: scroll, padding: const EdgeInsets.all(16), children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
        Text(dd['tedarikci']?.toString() ?? 'Fatura', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text('${dd['tarih']}${(dd['fatura_no']?.toString() ?? '').isNotEmpty ? ' · No: ${dd['fatura_no']}' : ''}', style: const TextStyle(color: _gri, fontSize: 12)),
        const SizedBox(height: 12),
        for (final k in kalemler) _kalemSatir(k as Map),
        const Divider(color: Color(0xFF232B42), height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOPLAM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(_tl(dd['toplam']), style: const TextStyle(color: _yesil, fontWeight: FontWeight.bold, fontSize: 18)),
        ]),
        const SizedBox(height: 16),
        if (duzenleyebilir)
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: _kirmizi, side: const BorderSide(color: _kirmizi)),
            onPressed: () { Navigator.pop(ctx); _faturaSil(_n(f['id']).toInt()); },
            icon: const Icon(Icons.delete_outline), label: const Text('Faturayı Sil (stok geri alınır)'),
          )),
      ])),
    );
  }

  Widget _kalemSatir(Map k) {
    final u = k['uyari'].toString();
    final fark = _n(k['fiyat_farki_yuzde']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k['malzeme'].toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          Row(children: [
            Text('${_mik(_n(k['miktar']))} ${k['birim']} × ${_tl(k['birim_fiyat'])}', style: const TextStyle(color: _gri, fontSize: 12)),
            if (u != 'yesil' && fark != 0) ...[
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: _uyariRenk(u).withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
                child: Text('${fark > 0 ? '+' : ''}${fark.toStringAsFixed(0)}%', style: TextStyle(color: _uyariRenk(u), fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ]),
        ])),
        Text(_tl(k['satir_toplam']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Future<void> _faturaSil(int id) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.alisFaturaSil(auth.token!, id);
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Silinemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }
}

// ============================================================================
// YENİ FATURA GİRİŞİ
// ============================================================================
class AlisFaturaEkleScreen extends StatefulWidget {
  const AlisFaturaEkleScreen({super.key});
  @override
  State<AlisFaturaEkleScreen> createState() => _AlisFaturaEkleScreenState();
}

class _AlisFaturaEkleScreenState extends State<AlisFaturaEkleScreen> {
  List tedarikciler = [];
  List malzemeler = [];
  List birimler = [];
  int? tedarikciId;
  final _faturaNoC = TextEditingController();
  final List<Map<String, dynamic>> kalemler = []; // {malzeme_id, malzeme_ad, birim_id, birim_ad, miktar, birim_fiyat}
  bool loading = true;
  bool kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    _meta();
  }

  Future<void> _meta() async {
    final auth = context.read<AuthProvider>();
    try {
      final m = await Api.stokMeta(auth.token!);
      final mal = await Api.malzemeler(auth.token!);
      if (!mounted) return;
      setState(() {
        tedarikciler = (m['tedarikciler'] as List?) ?? [];
        birimler = (m['birimler'] as List?) ?? [];
        malzemeler = (mal['malzemeler'] as List?) ?? [];
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  double get _toplam => kalemler.fold(0.0, (s, k) => s + _n(k['miktar']) * _n(k['birim_fiyat']));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Yeni Alış Faturası', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Expanded(child: ListView(padding: const EdgeInsets.all(14), children: [
                _drop('Tedarikçi', tedarikciId, {for (final t in tedarikciler) _n((t as Map)['id']).toInt(): t['ad'].toString()}, (v) => setState(() => tedarikciId = v), bosMetin: 'Seçiniz (opsiyonel)'),
                const SizedBox(height: 10),
                TextField(controller: _faturaNoC, style: const TextStyle(color: Colors.white), decoration: _dec('Fatura No (opsiyonel)')),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Kalemler', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  TextButton.icon(onPressed: _kalemEkle, icon: const Icon(Icons.add, color: _mavi, size: 18), label: const Text('Kalem Ekle', style: TextStyle(color: _mavi))),
                ]),
                if (kalemler.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('Henüz kalem yok. "Kalem Ekle" ile malzeme girin.', style: TextStyle(color: _gri, fontSize: 13)))
                else
                  for (int i = 0; i < kalemler.length; i++) _kalemKart(i),
                const SizedBox(height: 80),
              ])),
              _altBar(),
            ]),
    );
  }

  Widget _kalemKart(int i) {
    final k = kalemler[i];
    final satir = _n(k['miktar']) * _n(k['birim_fiyat']);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF232B42))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k['malzeme_ad'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          Text('${_mik(_n(k['miktar']))} ${k['birim_ad']} × ${_tl(k['birim_fiyat'])}', style: const TextStyle(color: _gri, fontSize: 12)),
        ])),
        Text(_tl(satir), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36), onPressed: () => setState(() => kalemler.removeAt(i)), icon: const Icon(Icons.close, color: _gri, size: 18)),
      ]),
    );
  }

  Widget _altBar() => Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(color: _card, border: Border(top: BorderSide(color: Color(0xFF232B42)))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Toplam', style: TextStyle(color: _gri, fontSize: 12)),
            Text(_tl(_toplam), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ]),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
            onPressed: kaydediliyor || kalemler.isEmpty ? null : _kaydet,
            child: kaydediliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kaydet & Stoğa Al', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      );

  Future<void> _kalemEkle() async {
    if (malzemeler.isEmpty) { _uyar('Önce Stok ekranından malzeme ekleyin'); return; }
    int malzemeId = _n((malzemeler.first as Map)['id']).toInt();
    int birimId = _n((malzemeler.first as Map)['temel_birim_id']).toInt();
    final miktarC = TextEditingController();
    final fiyatC = TextEditingController();
    final eklendi = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
          const Text('Kalem Ekle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _drop('Malzeme', malzemeId, {for (final m in malzemeler) _n((m as Map)['id']).toInt(): m['ad'].toString()}, (v) {
            final m = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == v);
            setS(() { malzemeId = v; birimId = _n((m as Map)['temel_birim_id']).toInt(); });
          }),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: miktarC, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Miktar'))),
            const SizedBox(width: 10),
            Expanded(child: _drop('Birim', birimId, {for (final b in birimler) _n((b as Map)['id']).toInt(): b['kisaltma'].toString()}, (v) => setS(() => birimId = v))),
          ]),
          const SizedBox(height: 10),
          TextField(controller: fiyatC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Birim Fiyat (₺ / birim)')),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle', style: TextStyle(fontWeight: FontWeight.bold)))),
        ])),
      )),
    );
    if (eklendi != true) return;
    final miktar = double.tryParse(miktarC.text.replaceAll(',', '.')) ?? 0;
    final fiyat = double.tryParse(fiyatC.text.replaceAll(',', '.')) ?? 0;
    if (miktar <= 0 || fiyat < 0) { _uyar('Geçerli miktar ve fiyat girin'); return; }
    final malzeme = malzemeler.firstWhere((x) => _n((x as Map)['id']).toInt() == malzemeId) as Map;
    final birim = birimler.firstWhere((x) => _n((x as Map)['id']).toInt() == birimId) as Map;
    setState(() => kalemler.add({'malzeme_id': malzemeId, 'malzeme_ad': malzeme['ad'], 'birim_id': birimId, 'birim_ad': birim['kisaltma'], 'miktar': miktar, 'birim_fiyat': fiyat}));
  }

  Future<void> _kaydet() async {
    if (kalemler.isEmpty) return;
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final gonder = kalemler.map((k) => {'malzeme_id': k['malzeme_id'], 'birim_id': k['birim_id'], 'miktar': k['miktar'], 'birim_fiyat': k['birim_fiyat']}).toList();
      final res = await Api.alisFaturaKaydet(auth.token!, tedarikciId: tedarikciId, faturaNo: _faturaNoC.text.trim(), kalemler: gonder);
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

  Widget _drop(String label, int? value, Map<int, String> items, ValueChanged<int> onChanged, {String? bosMetin}) => InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(child: DropdownButton<int>(
          value: items.containsKey(value) ? value : null,
          isDense: true, isExpanded: true, dropdownColor: _card, style: const TextStyle(color: Colors.white),
          hint: bosMetin != null ? Text(bosMetin, style: const TextStyle(color: _gri)) : null,
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        )),
      );
}
