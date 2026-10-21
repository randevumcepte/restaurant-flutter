import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Tedarikçi Detay — kart bilgileri + aldığın malzeme kataloğu (son/ort/trend)
/// + cari ekstre (borç/ödeme/bakiye) + ödeme girişi. Veri /api/patron/tedarikci-detay.
class TedarikciDetayScreen extends StatefulWidget {
  final int id;
  final String ad;
  const TedarikciDetayScreen({super.key, required this.id, this.ad = 'Tedarikçi'});
  @override
  State<TedarikciDetayScreen> createState() => _TedarikciDetayScreenState();
}

const _mavi = Color(0xFF0EA5E9);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _turuncu = Color(0xFFF59E0B);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';

class _TedarikciDetayScreenState extends State<TedarikciDetayScreen> {
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.tedarikciDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        data = res['ok'] == 1 ? res : null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _odemeAl() async {
    final t = context.read<TemaProvider>();
    final ctrl = TextEditingController();
    String sekil = 'nakit';
    final sonuc = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: t.card,
          title: Text('Ödeme Al', style: TextStyle(color: t.ink)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: t.ink),
              decoration: InputDecoration(labelText: 'Tutar (TL)', labelStyle: TextStyle(color: t.sub)),
            ),
            const SizedBox(height: 12),
            Row(children: [
              for (final s in const ['nakit', 'havale', 'kart'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: sekil == s,
                    onSelected: (_) => setD(() => sekil = s),
                  ),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (sonuc != true || !mounted) return;
    final tutar = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
    if (tutar <= 0) return;
    final auth = context.read<AuthProvider>();
    final res = await Api.tedarikciOdeme(auth.token!, tedarikciId: widget.id, tutar: tutar, odemeSekli: sekil);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['ok'] == 1 ? 'Ödeme kaydedildi.' : '${res['hata'] ?? 'Hata'}')));
    if (res['ok'] == 1) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ted = (data?['ted'] as Map?) ?? {};
    final katalog = (data?['katalog'] as List?) ?? [];
    final ekstre = (data?['ekstre'] as List?) ?? [];
    return MasaustuSayfa(
      baslik: (ted['ad'] ?? widget.ad).toString(),
      ikon: Icons.local_shipping_outlined,
      geri: true,
      altBaslik: 'Cari · katalog · ekstre',
      araclar: [
        MButon('Ödeme Al', _yesil, _odemeAl, ikon: Icons.payments_outlined),
        MButon('Yenile', _mavi, _yukle, dolu: false, ikon: Icons.refresh),
      ],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? Center(child: Text('Tedarikçi yüklenemedi', style: TextStyle(color: t.sub)))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  _cariSerit(t),
                  const SizedBox(height: 14),
                  if ((ted['telefon'] ?? ted['yetkili'] ?? ted['unvan'] ?? ted['iban'] ?? ted['adres']) != null) ...[
                    _bilgiKart(t, ted),
                    const SizedBox(height: 14),
                  ],
                  Text('Aldığın Malzemeler (${katalog.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (katalog.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Bu tedarikçiden faturalanmış malzeme yok.', style: TextStyle(color: t.sub)))
                  else
                    for (final k in katalog) _katalogKart(t, k),
                  const SizedBox(height: 18),
                  Text('Cari Ekstre (${ekstre.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (ekstre.isEmpty)
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text('Hareket yok.', style: TextStyle(color: t.sub)))
                  else
                    for (final e in ekstre) _ekstreSatir(t, e),
                  const SizedBox(height: 30),
                ]),
    );
  }

  Widget _cariSerit(TemaProvider t) {
    final bakiye = _n(data?['bakiye']);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Row(children: [
        Expanded(child: _ozet(t, 'Toplam Alış', _p(data?['borc']), _turuncu)),
        Container(width: 1, height: 38, color: t.line),
        Expanded(child: _ozet(t, 'Ödenen', _p(data?['odeme']), _yesil)),
        Container(width: 1, height: 38, color: t.line),
        Expanded(child: _ozet(t, 'Bakiye (Borç)', _p(bakiye), bakiye > 0 ? _kirmizi : _yesil)),
      ]),
    );
  }

  Widget _ozet(TemaProvider t, String b, String v, Color c) => Column(children: [
        Text(b, style: TextStyle(color: t.sub2, fontSize: 11)),
        const SizedBox(height: 4),
        FittedBox(child: Text(v, style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.bold))),
      ]);

  Widget _bilgiKart(TemaProvider t, Map ted) {
    final satir = <Widget>[];
    void ekle(IconData i, String? v) {
      if (v == null || v.toString().trim().isEmpty) return;
      satir.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(i, size: 15, color: t.sub2),
          const SizedBox(width: 8),
          Expanded(child: Text(v.toString(), style: TextStyle(color: t.ink, fontSize: 12.5))),
        ]),
      ));
    }

    ekle(Icons.badge_outlined, ted['unvan']?.toString());
    ekle(Icons.person_outline, ted['yetkili']?.toString());
    ekle(Icons.phone_outlined, ted['telefon']?.toString());
    ekle(Icons.email_outlined, ted['email']?.toString());
    ekle(Icons.account_balance_outlined, ted['iban']?.toString());
    ekle(Icons.numbers, ted['vkn_tckn']?.toString());
    final vade = _n(ted['odeme_vade_gun']);
    if (vade > 0) ekle(Icons.schedule, 'Ödeme vadesi: ${vade.toInt()} gün');
    ekle(Icons.location_on_outlined, ted['adres']?.toString());
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: satir),
    );
  }

  Widget _katalogKart(TemaProvider t, dynamic k) {
    final trend = _n(k['trend']).toDouble();
    final trendC = trend > 1 ? _kirmizi : (trend < -1 ? _yesil : t.sub2);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('Ort ${_p(k['ort'])} · ${_p(k['mn'])}–${_p(k['mx'])} · ${_n(k['adet']).toInt()} alış', style: TextStyle(color: t.sub2, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_p(k['son_fiyat'])}/${k['birim']}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(trend > 1 ? Icons.trending_up : (trend < -1 ? Icons.trending_down : Icons.trending_flat), size: 14, color: trendC),
            const SizedBox(width: 3),
            Text('${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}%', style: TextStyle(color: trendC, fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ]),
    );
  }

  Widget _ekstreSatir(TemaProvider t, dynamic e) {
    final tahsilat = e['tip'] == 'tahsilat';
    final c = tahsilat ? _yesil : _turuncu;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Row(children: [
        Icon(tahsilat ? Icons.south_west : Icons.north_east, size: 16, color: c),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${e['aciklama']}', style: TextStyle(color: t.ink, fontSize: 12.5), overflow: TextOverflow.ellipsis),
            Text('${e['tarih']}', style: TextStyle(color: t.sub2, fontSize: 10.5)),
          ]),
        ),
        Text('${tahsilat ? '-' : '+'}${_p(e['tutar'])}', style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
