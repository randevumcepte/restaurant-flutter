import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Satınalma Siparişi (PO) — liste + detay + yeni sipariş. Veri /api/patron/satinalma-*.
class SatinalmaSiparisScreen extends StatefulWidget {
  const SatinalmaSiparisScreen({super.key});
  @override
  State<SatinalmaSiparisScreen> createState() => _SatinalmaSiparisScreenState();
}

const _mavi = Color(0xFF4F46E5);
const _mor1 = Color(0xFF7C3AED);
const _yesil = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';
String _mik(dynamic v) => NumberFormat('#,##0.###', 'tr').format(_n(v));
String _tarih(dynamic v) {
  if (v == null || '$v'.isEmpty) return '—';
  try {
    return DateFormat('dd.MM.yyyy').format(DateTime.parse('$v'));
  } catch (_) {
    return '$v';
  }
}

const _durumAd = {'taslak': 'Taslak', 'gonderildi': 'Gönderildi', 'kismi': 'Kısmi', 'tamamlandi': 'Tamamlandı', 'iptal': 'İptal'};
Color _durumRenk(String d) => {'taslak': _gri, 'gonderildi': _mavi, 'kismi': _amber, 'tamamlandi': _yesil, 'iptal': _kirmizi}[d] ?? _gri;

class _SatinalmaSiparisScreenState extends State<SatinalmaSiparisScreen> {
  bool loading = true;
  List siparisler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.satinalmaSiparisleri(auth.token!);
      if (!mounted) return;
      setState(() {
        siparisler = res['ok'] == 1 ? ((res['siparisler'] as List?) ?? []) : [];
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Satınalma Siparişi',
      ikon: Icons.shopping_cart_checkout,
      geri: true,
      altBaslik: 'Sipariş ver · mal kabul · fatura',
      araclar: [
        MButon('Yeni Sipariş', _mor1, () async {
          final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _YeniSiparisScreen()));
          if (ok == true) _yukle();
        }, ikon: Icons.add),
      ],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: siparisler.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      Icon(Icons.shopping_cart_outlined, size: 54, color: t.line),
                      const SizedBox(height: 10),
                      Center(child: Text('Henüz sipariş yok. "Yeni Sipariş" ile başla.', style: TextStyle(color: t.sub))),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        MTablo(
                          sutunlar: const [
                            MSutun('Sipariş No', flex: 22),
                            MSutun('Tedarikçi', flex: 26),
                            MSutun('Durum', flex: 18, hiza: TextAlign.center),
                            MSutun('Tutar', flex: 20, hiza: TextAlign.right),
                            MSutun('', flex: 10, hiza: TextAlign.right),
                          ],
                          satirlar: [
                            for (final s in siparisler)
                              [
                                Text('${s['siparis_no']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                Text('${s['tedarikci']}', style: TextStyle(color: t.ink, fontSize: 12)),
                                Align(alignment: Alignment.center, child: MRozet(_durumAd['${s['durum']}'] ?? '${s['durum']}', _durumRenk('${s['durum']}'))),
                                Text(_p(s['genel_toplam']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.chevron_right, color: t.sub2),
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SiparisDetayScreen(id: _n(s['id']).toInt()))),
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ],
                    ),
            ),
    );
  }
}

// ======================= DETAY =======================
class _SiparisDetayScreen extends StatefulWidget {
  final int id;
  const _SiparisDetayScreen({required this.id});
  @override
  State<_SiparisDetayScreen> createState() => _SiparisDetayScreenState();
}

class _SiparisDetayScreenState extends State<_SiparisDetayScreen> {
  bool loading = true;
  Map s = {};
  List kalemler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.satinalmaSiparisDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        if (res['ok'] == 1) {
          s = (res['siparis'] as Map?) ?? {};
          kalemler = (res['kalemler'] as List?) ?? [];
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: '${s['siparis_no'] ?? 'Sipariş'}',
      ikon: Icons.shopping_cart_checkout,
      geri: true,
      altBaslik: 'Sipariş detayı',
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MKart(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: _sat(t, 'Tedarikçi', '${s['tedarikci'] ?? '—'}')),
                      MRozet(_durumAd['${s['durum']}'] ?? '${s['durum']}', _durumRenk('${s['durum']}')),
                    ]),
                    const SizedBox(height: 8),
                    _sat(t, 'Tarih / Beklenen', '${_tarih(s['tarih'])} → ${_tarih(s['beklenen_teslim'])}'),
                    const SizedBox(height: 8),
                    _sat(t, 'Genel Toplam', _p(s['genel_toplam']), vurgulu: true),
                    Text('Ara ${_p(s['ara_toplam'])} · KDV ${_p(s['kdv_toplam'])}', style: TextStyle(color: t.sub2, fontSize: 11.5)),
                  ]),
                ),
                const SizedBox(height: 16),
                MBolumBaslik('Kalemler', renk: _mor1, sayi: kalemler.length),
                const SizedBox(height: 8),
                MTablo(
                  sutunlar: const [
                    MSutun('Malzeme', flex: 30),
                    MSutun('Miktar', flex: 18, hiza: TextAlign.right),
                    MSutun('Fiyat', flex: 20, hiza: TextAlign.right),
                    MSutun('Satır', flex: 20, hiza: TextAlign.right),
                  ],
                  satirlar: [
                    for (final k in kalemler)
                      [
                        Text('${k['malzeme']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                        Text('${_mik(k['miktar'])} ${k['birim']}', textAlign: TextAlign.right, style: TextStyle(color: t.sub, fontSize: 12)),
                        Text(_p(k['birim_fiyat']), textAlign: TextAlign.right, style: TextStyle(color: t.sub, fontSize: 12)),
                        Text(_p(k['satir_toplam']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                      ],
                  ],
                ),
                if ('${s['notlar'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  MKart(child: _sat(t, 'Not', '${s['notlar']}')),
                ],
                const SizedBox(height: 20),
              ],
            ),
    );
  }

  Widget _sat(TemaProvider t, String e, String d, {bool vurgulu = false}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(e, style: TextStyle(color: t.sub2, fontSize: 11)),
          Text(d, style: TextStyle(color: vurgulu ? _mor1 : t.ink, fontSize: vurgulu ? 20 : 14, fontWeight: vurgulu ? FontWeight.w900 : FontWeight.w600)),
        ],
      );
}

// ======================= YENİ SİPARİŞ =======================
class _Kalem {
  int? malzemeId;
  int? birimId;
  final mik = TextEditingController();
  final fiyat = TextEditingController();
  final kdv = TextEditingController(text: '10');
}

class _YeniSiparisScreen extends StatefulWidget {
  const _YeniSiparisScreen();
  @override
  State<_YeniSiparisScreen> createState() => _YeniSiparisScreenState();
}

class _YeniSiparisScreenState extends State<_YeniSiparisScreen> {
  bool meta = false, kaydediliyor = false;
  List tedarikciler = [], malzemeler = [], birimler = [];
  int? tedarikciId;
  final List<_Kalem> kalemler = [_Kalem()];
  final _not = TextEditingController();

  @override
  void initState() {
    super.initState();
    _meta();
  }

  Future<void> _meta() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.satinalmaMeta(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          tedarikciler = (res['tedarikciler'] as List?) ?? [];
          malzemeler = (res['malzemeler'] as List?) ?? [];
          birimler = (res['birimler'] as List?) ?? [];
          meta = true;
        });
      }
    } catch (_) {}
  }

  double get _toplam {
    double a = 0, kdv = 0;
    for (final k in kalemler) {
      final m = double.tryParse(k.mik.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0;
      final ky = double.tryParse(k.kdv.text.replaceAll(',', '.')) ?? 0;
      final net = m * f;
      a += net;
      kdv += net * ky / 100;
    }
    return a + kdv;
  }

  Future<void> _kaydet(bool gonder) async {
    final liste = <Map<String, dynamic>>[];
    for (final k in kalemler) {
      final mik = double.tryParse(k.mik.text.replaceAll(',', '.')) ?? 0;
      if (k.malzemeId == null || mik <= 0) continue;
      liste.add({
        'malzeme_id': k.malzemeId,
        'alis_birim_id': k.birimId ?? 0,
        'miktar': mik,
        'birim_fiyat': double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0,
        'kdv_yuzde': double.tryParse(k.kdv.text.replaceAll(',', '.')) ?? 0,
      });
    }
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir geçerli kalem ekle.')));
      return;
    }
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.satinalmaSiparisEkle(auth.token!, {
        if (tedarikciId != null) 'tedarikci_id': '$tedarikciId',
        'tarih': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'kalemler': jsonEncode(liste),
        if (gonder) 'gonder': '1',
        if (_not.text.trim().isNotEmpty) 'notlar': _not.text.trim(),
      });
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['siparis_no']} oluşturuldu.')));
        Navigator.of(context).pop(true);
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
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Yeni Sipariş',
      ikon: Icons.add_shopping_cart,
      geri: true,
      govde: !meta
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // tedarikçi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                        child: DropdownButton<int>(
                          value: tedarikciId,
                          isExpanded: true,
                          underline: const SizedBox(),
                          dropdownColor: t.card,
                          hint: Text('Tedarikçi seç', style: TextStyle(color: t.sub2)),
                          style: TextStyle(color: t.ink, fontSize: 14),
                          items: [for (final td in tedarikciler) DropdownMenuItem<int>(value: _n(td['id']).toInt(), child: Text('${td['ad']}'))],
                          onChanged: (v) => setState(() => tedarikciId = v),
                        ),
                      ),
                      const SizedBox(height: 14),
                      MBolumBaslik('Kalemler', renk: _mor1, sayi: kalemler.length, sag: MButon('Kalem', _mor1, () => setState(() => kalemler.add(_Kalem())), dolu: false, ikon: Icons.add)),
                      const SizedBox(height: 6),
                      for (int i = 0; i < kalemler.length; i++) _kalemKart(t, i),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _not,
                        style: TextStyle(color: t.ink),
                        decoration: InputDecoration(hintText: 'Not (opsiyonel)', hintStyle: TextStyle(color: t.sub2), filled: true, fillColor: t.card, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line))),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
                // alt bar
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
                  child: Row(children: [
                    Expanded(child: Text('Tahmini: ${_p(_toplam)}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold))),
                    if (kaydediliyor)
                      const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    else ...[
                      MButon('Taslak', _gri, () => _kaydet(false), dolu: false),
                      const SizedBox(width: 8),
                      MButon('Oluştur', _mor1, () => _kaydet(true), ikon: Icons.check),
                    ],
                  ]),
                ),
              ],
            ),
    );
  }

  Widget _kalemKart(TemaProvider t, int i) {
    final k = kalemler[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: DropdownButton<int>(
              value: k.malzemeId,
              isExpanded: true,
              underline: const SizedBox(),
              dropdownColor: t.card,
              hint: Text('Malzeme…', style: TextStyle(color: t.sub2, fontSize: 13)),
              style: TextStyle(color: t.ink, fontSize: 13),
              items: [for (final m in malzemeler) DropdownMenuItem<int>(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() {
                k.malzemeId = v;
                final m = malzemeler.firstWhere((x) => _n(x['id']).toInt() == v, orElse: () => null);
                if (m != null) k.birimId = _n(m['birim']).toInt();
              }),
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18, color: _kirmizi), onPressed: kalemler.length > 1 ? () => setState(() => kalemler.removeAt(i)) : null),
        ]),
        Row(children: [
          Expanded(child: _num(t, k.mik, 'Miktar')),
          const SizedBox(width: 6),
          Expanded(child: _num(t, k.fiyat, 'Birim Fiyat')),
          const SizedBox(width: 6),
          SizedBox(width: 64, child: _num(t, k.kdv, 'KDV%')),
        ]),
      ]),
    );
  }

  Widget _num(TemaProvider t, TextEditingController c, String h) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: t.ink, fontSize: 13),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(hintText: h, hintStyle: TextStyle(color: t.sub2, fontSize: 12), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _mor1))),
      );

  @override
  void dispose() {
    _not.dispose();
    for (final k in kalemler) {
      k.mik.dispose();
      k.fiyat.dispose();
      k.kdv.dispose();
    }
    super.dispose();
  }
}
