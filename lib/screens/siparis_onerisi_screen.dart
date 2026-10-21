import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Otomatik Sipariş Önerisi — par/kritik altı malzemeler → seç → tedarikçiye gruplu PO taslağı.
/// Veri /api/patron/siparis-onerisi(-olustur).
class SiparisOnerisiScreen extends StatefulWidget {
  const SiparisOnerisiScreen({super.key});
  @override
  State<SiparisOnerisiScreen> createState() => _SiparisOnerisiScreenState();
}

const _mor1 = Color(0xFF7C3AED);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';
String _mik(dynamic v) => NumberFormat('#,##0.###', 'tr').format(_n(v));

class _SiparisOnerisiScreenState extends State<SiparisOnerisiScreen> {
  bool loading = true, kaydediliyor = false;
  List oneriler = [];
  final Set<int> secili = {};
  final Map<int, TextEditingController> mik = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.siparisOnerisi(auth.token!);
      if (!mounted) return;
      final list = res['ok'] == 1 ? ((res['oneriler'] as List?) ?? []) : [];
      secili.clear();
      for (final c in mik.values) {
        c.dispose();
      }
      mik.clear();
      for (final o in list) {
        final id = _n(o['id']).toInt();
        secili.add(id);
        mik[id] = TextEditingController(text: _mik(o['oneri']));
      }
      setState(() {
        oneriler = list;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  double get _toplam {
    double t = 0;
    for (final o in oneriler) {
      final id = _n(o['id']).toInt();
      if (!secili.contains(id)) continue;
      final m = double.tryParse((mik[id]?.text ?? '').replaceAll(',', '.')) ?? 0;
      t += m * _n(o['fiyat']).toDouble();
    }
    return t;
  }

  Future<void> _olustur() async {
    final liste = <Map<String, dynamic>>[];
    for (final o in oneriler) {
      final id = _n(o['id']).toInt();
      if (!secili.contains(id)) continue;
      final m = double.tryParse((mik[id]?.text ?? '').replaceAll(',', '.')) ?? 0;
      if (m <= 0) continue;
      liste.add({'malzeme_id': id, 'tedarikci_id': _n(o['tedarikci_id']).toInt(), 'birim_id': _n(o['birim_id']).toInt(), 'miktar': m, 'fiyat': _n(o['fiyat']).toDouble()});
    }
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir ürün seç.')));
      return;
    }
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.siparisOnerisiOlustur(auth.token!, jsonEncode(liste));
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['olusan']} sipariş taslağı oluşturuldu (tedarikçiye göre).')));
        _yukle();
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
    for (final c in mik.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Sipariş Önerisi',
      ikon: Icons.auto_awesome,
      geri: true,
      altBaslik: 'Neyin azaldı · ne almalısın',
      araclar: [MButon('Yenile', _mor1, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : oneriler.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  const Icon(Icons.check_circle, size: 54, color: _yesil),
                  const SizedBox(height: 10),
                  Center(child: Text('Her şey yeterli 👍', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 6),
                  Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: Text('Par/kritik altına düşen malzeme yok. Malzeme kartından hedef stok belirleyebilirsin.', textAlign: TextAlign.center, style: TextStyle(color: t.sub)))),
                ])
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          for (final o in oneriler) _kart(t, o),
                          const SizedBox(height: 70),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
                      child: Row(children: [
                        Expanded(child: Text('Seçili: ${_p(_toplam)}', style: TextStyle(color: _mor1, fontSize: 15, fontWeight: FontWeight.bold))),
                        if (kaydediliyor)
                          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          MButon('Sipariş Taslağı Oluştur', _mor1, _olustur, ikon: Icons.shopping_cart_checkout),
                      ]),
                    ),
                  ],
                ),
    );
  }

  Widget _kart(TemaProvider t, dynamic o) {
    final id = _n(o['id']).toInt();
    final kritik = o['kritik_mi'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: kritik ? _kirmizi.withValues(alpha: 0.06) : t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kritik ? _kirmizi.withValues(alpha: 0.3) : t.line),
      ),
      child: Row(children: [
        Checkbox(
          value: secili.contains(id),
          activeColor: _mor1,
          onChanged: (v) => setState(() => v == true ? secili.add(id) : secili.remove(id)),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${o['ad']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              if (kritik) ...[const SizedBox(width: 6), const MRozet('kritik', _kirmizi)],
            ]),
            const SizedBox(height: 2),
            Text('Mevcut ${_mik(o['mevcut'])} ${o['birim']} · günlük ${_mik(o['gunluk'])} · ${o['tedarikci']}', style: TextStyle(color: t.sub2, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 84,
          child: TextField(
            controller: mik[id],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.bold),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Öner',
              labelStyle: TextStyle(color: t.sub2, fontSize: 11),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _mor1)),
            ),
          ),
        ),
      ]),
    );
  }
}
