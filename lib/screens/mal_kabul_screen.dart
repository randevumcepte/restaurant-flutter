import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';
import 'barkod_tarayici.dart';

/// Mal Kabul (GRN) — açık sipariş veya serbest; gelen/kabul/red + lot/SKT + barkod.
/// Kabul edilen miktar anında stoğa + partiye (FEFO) işlenir. Veri /api/patron/mal-kabul-*.
class MalKabulScreen extends StatefulWidget {
  const MalKabulScreen({super.key});
  @override
  State<MalKabulScreen> createState() => _MalKabulScreenState();
}

const _mavi = Color(0xFF0EA5E9);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _turuncu = Color(0xFFF59E0B);
const _mor = Color(0xFF7C3AED);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';
String _mik(dynamic v) => NumberFormat('#,##0.###', 'tr').format(_n(v));

class _MalKabulScreenState extends State<MalKabulScreen> {
  bool loading = true;
  List kabuller = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.malKabulListe(auth.token!);
      if (!mounted) return;
      setState(() {
        kabuller = res['ok'] == 1 ? ((res['kabuller'] as List?) ?? []) : [];
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _yeni() async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _YeniMalKabulScreen()));
    if (degisti == true) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Mal Kabul',
      ikon: Icons.inventory_outlined,
      geri: true,
      altBaslik: 'İrsaliye · gelen/kabul/red',
      araclar: [MButon('Yeni', _mavi, _yeni, ikon: Icons.add)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : kabuller.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  const Icon(Icons.inventory_outlined, size: 54, color: _mavi),
                  const SizedBox(height: 10),
                  Center(child: Text('Henüz mal kabul yok', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 6),
                  Center(child: Text('Gelen irsaliyeyi “Yeni Mal Kabul” ile kaydet.', style: TextStyle(color: t.sub))),
                ])
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(padding: const EdgeInsets.all(14), children: [for (final m in kabuller) _kart(t, m)]),
                ),
    );
  }

  Widget _kart(TemaProvider t, dynamic m) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MalKabulDetayScreen(id: _n(m['id']).toInt()))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _mavi.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_outlined, color: _mavi, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['tedarikci']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text('${m['tarih']}${(m['irsaliye_no']?.toString().isNotEmpty ?? false) ? ' · İrs. ${m['irsaliye_no']}' : ''}', style: TextStyle(color: t.sub2, fontSize: 11.5)),
            ]),
          ),
          if (m['genel_toplam'] != null)
            Text(_p(m['genel_toplam']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ======================= DETAY =======================
class _MalKabulDetayScreen extends StatefulWidget {
  final int id;
  const _MalKabulDetayScreen({required this.id});
  @override
  State<_MalKabulDetayScreen> createState() => _MalKabulDetayScreenState();
}

class _MalKabulDetayScreenState extends State<_MalKabulDetayScreen> {
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malKabulDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        data = res['ok'] == 1 ? res : null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final mk = (data?['mk'] as Map?) ?? {};
    final kalemler = (data?['kalemler'] as List?) ?? [];
    return MasaustuSayfa(
      baslik: 'Mal Kabul #${widget.id}',
      ikon: Icons.inventory_outlined,
      geri: true,
      altBaslik: loading ? '' : '${mk['tedarikci']} · ${mk['tarih']}',
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? Center(child: Text('Yüklenemedi', style: TextStyle(color: t.sub)))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _satir(t, 'Tedarikçi', '${mk['tedarikci']}'),
                      if ((mk['irsaliye_no']?.toString().isNotEmpty ?? false)) _satir(t, 'İrsaliye No', '${mk['irsaliye_no']}'),
                      _satir(t, 'Tarih', '${mk['tarih']}'),
                      if (mk['genel_toplam'] != null) _satir(t, 'Genel Toplam', _p(mk['genel_toplam'])),
                      if ((mk['notlar']?.toString().isNotEmpty ?? false)) _satir(t, 'Not', '${mk['notlar']}'),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text('Kalemler (${kalemler.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final k in kalemler) _kalemKart(t, k),
                  const SizedBox(height: 24),
                ]),
    );
  }

  Widget _satir(TemaProvider t, String b, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(b, style: TextStyle(color: t.sub2, fontSize: 12.5))),
          Expanded(child: Text(v, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _kalemKart(TemaProvider t, dynamic k) {
    final red = _n(k['red']).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: red > 0 ? _kirmizi.withValues(alpha: 0.3) : t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${k['malzeme']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
          Text('${_p(k['birim_fiyat'])}/${k['birim']}', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          MRozet('Gelen ${_mik(k['gelen'])}', _mavi),
          MRozet('Kabul ${_mik(k['kabul'])}', _yesil),
          if (red > 0) MRozet('Red ${_mik(k['red'])}', _kirmizi),
          if ((k['lot_no']?.toString().isNotEmpty ?? false)) MRozet('Lot ${k['lot_no']}', _mor),
          if ((k['skt']?.toString().isNotEmpty ?? false)) MRozet('SKT ${k['skt']}', _turuncu),
        ]),
        if ((k['red_sebep']?.toString().isNotEmpty ?? false)) ...[
          const SizedBox(height: 4),
          Text('Red: ${k['red_sebep']}', style: const TextStyle(color: _kirmizi, fontSize: 11)),
        ],
      ]),
    );
  }
}

// ======================= YENİ MAL KABUL =======================
class _YeniMalKabulScreen extends StatefulWidget {
  const _YeniMalKabulScreen();
  @override
  State<_YeniMalKabulScreen> createState() => _YeniMalKabulScreenState();
}

class _Kalem {
  int malzemeId;
  int birimId;
  final gelen = TextEditingController();
  final kabul = TextEditingController();
  final red = TextEditingController();
  final fiyat = TextEditingController();
  final lot = TextEditingController();
  final redSebep = TextEditingController();
  String? skt;
  int? siparisKalemId;
  double? siparisMiktar;
  _Kalem(this.malzemeId, this.birimId);
  void dispose() {
    gelen.dispose();
    kabul.dispose();
    red.dispose();
    fiyat.dispose();
    lot.dispose();
    redSebep.dispose();
  }
}

class _YeniMalKabulScreenState extends State<_YeniMalKabulScreen> {
  bool loading = true, kaydediliyor = false;
  List acikSiparisler = [], malzemeler = [], birimler = [], tedarikciler = [];
  int? siparisId, tedarikciId;
  final _irsaliye = TextEditingController();
  final _notlar = TextEditingController();
  String _tarih = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final List<_Kalem> kalemler = [];

  @override
  void initState() {
    super.initState();
    _meta();
  }

  Future<void> _meta({int? spid}) async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.malKabulListe(auth.token!, siparisId: spid);
      if (!mounted) return;
      if (res['ok'] == 1) {
        acikSiparisler = (res['acik_siparisler'] as List?) ?? [];
        malzemeler = (res['malzemeler'] as List?) ?? [];
        birimler = (res['birimler'] as List?) ?? [];
        tedarikciler = (res['tedarikciler'] as List?) ?? [];
        if (spid != null) {
          final sk = (res['siparis_kalem'] as List?) ?? [];
          for (final c in kalemler) {
            c.dispose();
          }
          kalemler.clear();
          for (final k in sk) {
            final kalem = _Kalem(_n(k['malzeme_id']).toInt(), _n(k['alis_birim_id']).toInt());
            kalem.siparisKalemId = _n(k['siparis_kalem_id']).toInt();
            kalem.siparisMiktar = _n(k['siparis_miktar']).toDouble();
            kalem.gelen.text = _mik(k['kalan']);
            kalem.kabul.text = _mik(k['kalan']);
            kalem.fiyat.text = '${_n(k['birim_fiyat'])}';
            kalemler.add(kalem);
          }
        }
      }
      setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _birimKis(int id) {
    final b = birimler.cast<Map>().where((x) => _n(x['id']).toInt() == id);
    return b.isEmpty ? '' : '${b.first['ad']}';
  }

  void _kalemEkle({int? malzemeId}) {
    if (malzemeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce Stok ekranından malzeme ekleyin.')));
      return;
    }
    final id = malzemeId ?? _n((malzemeler.first as Map)['id']).toInt();
    final bid = _n((malzemeler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == id, orElse: () => malzemeler.first as Map))['birim_id']).toInt();
    setState(() => kalemler.add(_Kalem(id, bid)));
  }

  Future<void> _barkod() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Mal Kabul — Barkod Okut');
    if (kod == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final r = await Api.malKabulBarkod(auth.token!, kod);
    if (!mounted) return;
    if (r['ok'] == 1) {
      final id = _n(r['id']).toInt();
      if (!malzemeler.any((m) => _n((m as Map)['id']).toInt() == id)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['ad']} malzeme listesinde yok — Stok\'tan ekleyin')));
        return;
      }
      _kalemEkle(malzemeId: id);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['hata'] ?? 'Barkod tanımlı değil'}')));
    }
  }

  double get _toplam {
    double t = 0;
    for (final k in kalemler) {
      final kabul = double.tryParse(k.kabul.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0;
      t += kabul * f;
    }
    return t;
  }

  Future<void> _kaydet() async {
    if (kalemler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir kalem ekleyin.')));
      return;
    }
    final liste = <Map<String, dynamic>>[];
    for (final k in kalemler) {
      final gelen = double.tryParse(k.gelen.text.replaceAll(',', '.')) ?? 0;
      final kabul = double.tryParse(k.kabul.text.replaceAll(',', '.')) ?? gelen;
      final red = double.tryParse(k.red.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0;
      if (gelen <= 0 && kabul <= 0) continue;
      liste.add({
        'malzeme_id': k.malzemeId,
        'alis_birim_id': k.birimId,
        'gelen': gelen,
        'kabul': kabul,
        'red': red,
        'red_sebep': k.redSebep.text.trim(),
        'birim_fiyat': f,
        'lot_no': k.lot.text.trim(),
        'skt': k.skt ?? '',
        'siparis_kalem_id': k.siparisKalemId ?? 0,
        'siparis_miktar': k.siparisMiktar ?? 0,
      });
    }
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli miktar girin.')));
      return;
    }
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malKabulOlustur(auth.token!, {
        'tedarikci_id': '${tedarikciId ?? ''}',
        'siparis_id': '${siparisId ?? ''}',
        'irsaliye_no': _irsaliye.text.trim(),
        'tarih': _tarih,
        'notlar': _notlar.text.trim(),
        'kalemler': jsonEncode(liste),
      });
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mal kabul kaydedildi, stok güncellendi.')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['hata'] ?? 'Hata'}')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => kaydediliyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası.')));
      }
    }
  }

  @override
  void dispose() {
    for (final c in kalemler) {
      c.dispose();
    }
    _irsaliye.dispose();
    _notlar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Yeni Mal Kabul',
      ikon: Icons.add_box_outlined,
      geri: true,
      altBaslik: 'İrsaliye gir · gelen/kabul/red',
      araclar: [MButon('Barkod', _mor, _barkod, dolu: false, ikon: Icons.qr_code_scanner)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(14), children: [
                  // Açık sipariş seç
                  if (acikSiparisler.isNotEmpty) ...[
                    _etiket(t, 'Açık Siparişten Doldur (opsiyonel)'),
                    _kutu(t, DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: siparisId,
                        isExpanded: true,
                        dropdownColor: t.card,
                        hint: Text('Sipariş seçin', style: TextStyle(color: t.sub)),
                        style: TextStyle(color: t.ink, fontSize: 13.5),
                        items: [
                          DropdownMenuItem(value: null, child: Text('— Serbest (siparişsiz) —', style: TextStyle(color: t.sub))),
                          for (final s in acikSiparisler)
                            DropdownMenuItem(value: _n(s['id']).toInt(), child: Text('${s['siparis_no'] ?? s['id']} · ${s['tedarikci']}', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() {
                            siparisId = v;
                            if (v != null) {
                              final s = acikSiparisler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == v);
                              tedarikciId = _n(s['tedarikci_id']).toInt();
                            }
                          });
                          if (v != null) _meta(spid: v);
                        },
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],
                  // Tedarikçi (sipariş yoksa)
                  if (siparisId == null) ...[
                    _etiket(t, 'Tedarikçi'),
                    _kutu(t, DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: tedarikciId,
                        isExpanded: true,
                        dropdownColor: t.card,
                        hint: Text('Tedarikçi seçin (opsiyonel)', style: TextStyle(color: t.sub)),
                        style: TextStyle(color: t.ink, fontSize: 13.5),
                        items: [
                          DropdownMenuItem(value: null, child: Text('— Seçilmedi —', style: TextStyle(color: t.sub))),
                          for (final s in tedarikciler) DropdownMenuItem(value: _n(s['id']).toInt(), child: Text('${s['ad']}', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => tedarikciId = v),
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(child: _alan(t, _irsaliye, 'İrsaliye No')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(_tarih) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (d != null) setState(() => _tarih = DateFormat('yyyy-MM-dd').format(d));
                        },
                        child: _kutu(t, Row(children: [
                          Icon(Icons.calendar_today, size: 16, color: t.sub),
                          const SizedBox(width: 8),
                          Text(_tarih, style: TextStyle(color: t.ink, fontSize: 13.5)),
                        ])),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('Kalemler (${kalemler.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(onPressed: () => _kalemEkle(), icon: const Icon(Icons.add, size: 18, color: _mavi), label: const Text('Kalem', style: TextStyle(color: _mavi))),
                  ]),
                  const SizedBox(height: 4),
                  for (int i = 0; i < kalemler.length; i++) _kalemKart(t, i),
                  const SizedBox(height: 10),
                  _alan(t, _notlar, 'Not (opsiyonel)', satir: 2),
                  const SizedBox(height: 70),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
                child: Row(children: [
                  Expanded(child: Text('Kabul tutarı: ${_p(_toplam)}', style: const TextStyle(color: _mavi, fontSize: 15, fontWeight: FontWeight.bold))),
                  if (kaydediliyor)
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    MButon('Kaydet & Stoğa Al', _yesil, _kaydet, ikon: Icons.check),
                ]),
              ),
            ]),
    );
  }

  Widget _etiket(TemaProvider t, String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600)));

  Widget _kutu(TemaProvider t, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
        child: child,
      );

  Widget _alan(TemaProvider t, TextEditingController c, String label, {int satir = 1}) => TextField(
        controller: c,
        maxLines: satir,
        style: TextStyle(color: t.ink, fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.sub, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mavi)),
        ),
      );

  Widget _kalemKart(TemaProvider t, int i) {
    final k = kalemler[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: k.malzemeId,
                isExpanded: true,
                dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600),
                items: [for (final m in malzemeler) DropdownMenuItem(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))],
                onChanged: k.siparisKalemId != null ? null : (v) {
                  if (v == null) return;
                  setState(() {
                    k.malzemeId = v;
                    k.birimId = _n((malzemeler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == v))['birim_id']).toInt();
                  });
                },
              ),
            ),
          ),
          Text(_birimKis(k.birimId), style: TextStyle(color: t.sub, fontSize: 12)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: _kirmizi), onPressed: () => setState(() => kalemler.removeAt(i))),
        ]),
        if (k.siparisMiktar != null && k.siparisMiktar! > 0)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Sipariş: ${_mik(k.siparisMiktar)} ${_birimKis(k.birimId)}', style: TextStyle(color: t.sub2, fontSize: 11))),
        Row(children: [
          Expanded(child: _mini(t, k.gelen, 'Gelen', onChanged: () {
            if (k.kabul.text.isEmpty) k.kabul.text = k.gelen.text;
          })),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.kabul, 'Kabul', onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.red, 'Red')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _mini(t, k.fiyat, 'Birim Fiyat', onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.lot, 'Lot No', sayi: false)),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(k.skt ?? '') ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime(2040));
                if (d != null) setState(() => k.skt = DateFormat('yyyy-MM-dd').format(d));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                child: Row(children: [
                  Icon(Icons.event_busy, size: 14, color: k.skt != null ? _turuncu : t.sub2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(k.skt ?? 'SKT', style: TextStyle(color: k.skt != null ? t.ink : t.sub2, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
        ]),
        if ((double.tryParse(k.red.text.replaceAll(',', '.')) ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _mini(t, k.redSebep, 'Red sebebi', sayi: false),
        ],
      ]),
    );
  }

  Widget _mini(TemaProvider t, TextEditingController c, String label, {bool sayi = true, VoidCallback? onChanged}) => TextField(
        controller: c,
        keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: t.ink, fontSize: 13),
        onChanged: onChanged == null ? null : (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.sub2, fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mavi)),
        ),
      );
}
