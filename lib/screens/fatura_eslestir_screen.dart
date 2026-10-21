import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Fatura Eşleştir (3-way) — faturası bekleyen mal kabuller → sipariş↔irsaliye↔fatura eşleştir.
/// Veri /api/patron/fatura-bekleyen(+kaydet).
class FaturaEslestirScreen extends StatefulWidget {
  const FaturaEslestirScreen({super.key});
  @override
  State<FaturaEslestirScreen> createState() => _FaturaEslestirScreenState();
}

const _amber = Color(0xFFF59E0B);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);

num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tarih(dynamic v) {
  if (v == null || '$v'.isEmpty) return '—';
  try {
    return DateFormat('dd.MM.yyyy').format(DateTime.parse('$v'));
  } catch (_) {
    return '$v';
  }
}

class _FaturaEslestirScreenState extends State<FaturaEslestirScreen> {
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
      final res = await Api.faturaBekleyen(auth.token!);
      if (!mounted) return;
      setState(() {
        kabuller = res['ok'] == 1 ? ((res['kabuller'] as List?) ?? []) : [];
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
      baslik: 'Fatura Eşleştir',
      ikon: Icons.fact_check,
      geri: true,
      altBaslik: 'Sipariş ↔ irsaliye ↔ fatura (3-way)',
      araclar: [MButon('Yenile', _amber, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: kabuller.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 90),
                      Icon(Icons.fact_check_outlined, size: 54, color: t.line),
                      const SizedBox(height: 10),
                      Center(child: Text('Faturası bekleyen mal kabul yok.', style: TextStyle(color: t.sub))),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        MBolumBaslik('Faturası Bekleyen Mal Kabuller', renk: _amber, sayi: kabuller.length),
                        const SizedBox(height: 8),
                        for (final m in kabuller)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                            child: ListTile(
                              title: Text('${m['tedarikci']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('İrsaliye ${m['irsaliye_no'] ?? '—'} · ${_tarih(m['tarih'])} · ${(m['kalemler'] as List?)?.length ?? 0} kalem', style: TextStyle(color: t.sub2, fontSize: 12)),
                              trailing: const Icon(Icons.fact_check, color: _amber),
                              onTap: () async {
                                final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => _EslestirForm(kabul: m)));
                                if (ok == true) _yukle();
                              },
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
            ),
    );
  }
}

// ======================= EŞLEŞTİRME FORMU =======================
class _Satir {
  final Map k;
  final mik = TextEditingController();
  final fiyat = TextEditingController();
  final kdv = TextEditingController(text: '10');
  _Satir(this.k) {
    mik.text = NumberFormat('#,##0.###', 'tr').format(_n(k['kabul']));
    fiyat.text = '${_n(k['birim_fiyat'])}';
  }
}

class _EslestirForm extends StatefulWidget {
  final Map kabul;
  const _EslestirForm({required this.kabul});
  @override
  State<_EslestirForm> createState() => _EslestirFormState();
}

class _EslestirFormState extends State<_EslestirForm> {
  late final List<_Satir> satirlar;
  final _faturaNo = TextEditingController();
  final _iskonto = TextEditingController(text: '0');
  DateTime _tarih = DateTime.now();
  DateTime? _vade;
  bool kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    satirlar = [for (final k in (widget.kabul['kalemler'] as List? ?? [])) _Satir(k as Map)];
  }

  final _fmtP = NumberFormat('#,##0.00', 'tr');
  String _p(num v) => '${_fmtP.format(v)}TL';

  double get _genel {
    double ara = 0, kdv = 0;
    for (final s in satirlar) {
      final m = double.tryParse(s.mik.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(s.fiyat.text.replaceAll(',', '.')) ?? 0;
      final ky = double.tryParse(s.kdv.text.replaceAll(',', '.')) ?? 0;
      ara += m * f;
      kdv += m * f * ky / 100;
    }
    final isk = double.tryParse(_iskonto.text.replaceAll(',', '.')) ?? 0;
    return (ara - isk) + kdv;
  }

  Future<void> _kaydet() async {
    final liste = <Map<String, dynamic>>[];
    for (final s in satirlar) {
      final m = double.tryParse(s.mik.text.replaceAll(',', '.')) ?? 0;
      if (m <= 0) continue;
      liste.add({
        'malzeme_id': _n(s.k['malzeme_id']).toInt(),
        'alis_birim_id': _n(s.k['alis_birim_id']).toInt(),
        'kabul_miktar': _n(s.k['kabul']).toDouble(),
        'po_fiyat': _n(s.k['po_fiyat']).toDouble(),
        'miktar': m,
        'birim_fiyat': double.tryParse(s.fiyat.text.replaceAll(',', '.')) ?? 0,
        'kdv_yuzde': double.tryParse(s.kdv.text.replaceAll(',', '.')) ?? 0,
      });
    }
    if (liste.isEmpty) return;
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.faturaEslestirKaydet(auth.token!, {
        'mal_kabul_id': '${_n(widget.kabul['id']).toInt()}',
        if (_faturaNo.text.trim().isNotEmpty) 'fatura_no': _faturaNo.text.trim(),
        'tarih': DateFormat('yyyy-MM-dd').format(_tarih),
        if (_vade != null) 'vade_tarihi': DateFormat('yyyy-MM-dd').format(_vade!),
        'iskonto': _iskonto.text.trim().isEmpty ? '0' : _iskonto.text.trim(),
        'kalemler': jsonEncode(liste),
      });
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        final es = res['eslesme'] == 'eslesti';
        final farklar = (res['farklar'] as List?) ?? [];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: es ? _yesil : _kirmizi,
          content: Text(es ? '✓ Fatura eşleşti — tutuyor.' : '⚠ FARK VAR: ${farklar.join(' · ')}'),
        ));
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

  Future<void> _tarihSec(bool vade) async {
    final d = await showDatePicker(context: context, initialDate: vade ? (_vade ?? DateTime.now()) : _tarih, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => vade ? _vade = d : _tarih = d);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Fatura Eşleştir',
      ikon: Icons.fact_check,
      geri: true,
      altBaslik: '${widget.kabul['tedarikci']} · İrsaliye ${widget.kabul['irsaliye_no'] ?? '—'}',
      govde: Column(children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(14), children: [
            Row(children: [
              Expanded(child: _txt(t, _faturaNo, 'Fatura No')),
              const SizedBox(width: 8),
              Expanded(child: _tarihBtn(t, 'Tarih', _tarih, false)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _tarihBtn(t, 'Vade', _vade, true)),
              const SizedBox(width: 8),
              Expanded(child: _txt(t, _iskonto, 'İskonto (₺)', sayi: true)),
            ]),
            const SizedBox(height: 14),
            MBolumBaslik('Kalemler', renk: _amber, sayi: satirlar.length),
            const SizedBox(height: 6),
            for (final s in satirlar) _satirKart(t, s),
            const SizedBox(height: 70),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
          child: Row(children: [
            Expanded(child: Text('Genel: ${_p(_genel)}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold))),
            if (kaydediliyor) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) else MButon('Eşleştir & Kaydet', _amber, _kaydet, ikon: Icons.fact_check),
          ]),
        ),
      ]),
    );
  }

  Widget _satirKart(TemaProvider t, _Satir s) {
    final po = _n(s.k['po_fiyat']).toDouble();
    final fatF = double.tryParse(s.fiyat.text.replaceAll(',', '.')) ?? 0;
    final pahali = po > 0 && fatF > po + 0.0001;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pahali ? _kirmizi.withValues(alpha: 0.06) : t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pahali ? _kirmizi.withValues(alpha: 0.3) : t.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${s.k['malzeme']}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          Text('irsaliye ${NumberFormat('#,##0.###', 'tr').format(_n(s.k['kabul']))}', style: TextStyle(color: t.sub2, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _num(t, s.mik, 'Fatura Mik.')),
          const SizedBox(width: 6),
          Expanded(child: _num(t, s.fiyat, 'Fatura Fiyat')),
          const SizedBox(width: 6),
          SizedBox(width: 60, child: _num(t, s.kdv, 'KDV%')),
        ]),
        if (po > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Sipariş fiyatı: ${_p(po)}${pahali ? '  ⚠ fatura yüksek' : ''}', style: TextStyle(color: pahali ? _kirmizi : t.sub2, fontSize: 11, fontWeight: pahali ? FontWeight.bold : FontWeight.normal))),
      ]),
    );
  }

  Widget _txt(TemaProvider t, TextEditingController c, String h, {bool sayi = false}) => TextField(
        controller: c,
        keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: t.ink, fontSize: 13),
        decoration: InputDecoration(labelText: h, labelStyle: TextStyle(color: t.sub2, fontSize: 12), isDense: true, filled: true, fillColor: t.card,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _amber))),
      );

  Widget _num(TemaProvider t, TextEditingController c, String h) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: t.ink, fontSize: 13),
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: h, labelStyle: TextStyle(color: t.sub2, fontSize: 11), isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _amber))),
      );

  Widget _tarihBtn(TemaProvider t, String label, DateTime? d, bool vade) => InkWell(
        onTap: () => _tarihSec(vade),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: t.sub2, fontSize: 12), isDense: true, filled: true, fillColor: t.card,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line))),
          child: Text(d == null ? '—' : DateFormat('dd.MM.yyyy').format(d), style: TextStyle(color: t.ink, fontSize: 13)),
        ),
      );

  @override
  void dispose() {
    _faturaNo.dispose();
    _iskonto.dispose();
    for (final s in satirlar) {
      s.mik.dispose();
      s.fiyat.dispose();
      s.kdv.dispose();
    }
    super.dispose();
  }
}
