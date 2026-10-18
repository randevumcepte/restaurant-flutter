import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'barkod_tarayici.dart';

/// Kasa + Garson: müşterinin ödül QR kodunu okut/gir → doğrula → onayla.
/// Backend: /api/patron/odul-dogrula (bilgi) + /api/patron/odul-onayla (puan düş + açık hesaba işle).
class OdulDogrulaScreen extends StatefulWidget {
  const OdulDogrulaScreen({super.key});
  @override
  State<OdulDogrulaScreen> createState() => _OdulDogrulaScreenState();
}

class _OdulDogrulaScreenState extends State<OdulDogrulaScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();
  final _kodC = TextEditingController();
  Map<String, dynamic>? _bilgi; // doğrula sonucu
  bool _loading = false;
  bool _onaylaniyor = false;

  @override
  void dispose() { _kodC.dispose(); super.dispose(); }

  String _temizle(String raw) {
    var k = raw.trim();
    if (k.contains('/')) k = k.split('/').last; // URL ise son parça
    return k.trim().toUpperCase();
  }

  Future<void> _qrOkut() async {
    final v = await BarkodTarayici.oku(context, baslik: 'Ödül Kodu Okut');
    if (v != null && v.trim().isNotEmpty && mounted) { _kodC.text = _temizle(v); _dogrula(); }
  }

  Future<void> _dogrula() async {
    final kod = _temizle(_kodC.text);
    if (kod.isEmpty) { _uyar('Kod gir veya QR okut'); return; }
    setState(() { _loading = true; _bilgi = null; });
    try {
      final token = context.read<AuthProvider>().token;
      final r = await Api.odulDogrula(token!, kod);
      if (!mounted) return;
      if (r['ok'] == 1) { setState(() => _bilgi = Map<String, dynamic>.from(r)); }
      else { _uyar(r['hata']?.toString() ?? 'Kod doğrulanamadı'); }
    } catch (_) { if (mounted) _uyar('Bağlantı hatası'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _onayla() async {
    final b = _bilgi; if (b == null) return;
    if (b['yeterli'] != true) { _uyar('Müşterinin puanı yetersiz'); return; }
    setState(() => _onaylaniyor = true);
    try {
      final token = context.read<AuthProvider>().token;
      final adId = (b['adisyon'] is Map) ? (b['adisyon']['id'] as num?)?.toInt() : null;
      final r = await Api.odulOnayla(token!, b['kod'].toString(), adisyonId: adId);
      if (!mounted) return;
      if (r['ok'] == 1) {
        _basari(r['mesaj']?.toString() ?? 'Ödül uygulandı');
        setState(() { _bilgi = null; _kodC.clear(); });
      } else { _uyar(r['hata']?.toString() ?? 'Onaylanamadı'); }
    } catch (_) { if (mounted) _uyar('Bağlantı hatası'); }
    finally { if (mounted) setState(() => _onaylaniyor = false); }
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: _t.kirmizi, behavior: SnackBarBehavior.floating));
  void _basari(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: _t.yesil, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 4)));

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.card, foregroundColor: t.ink, elevation: 0,
          title: const Text('Ödül Doğrula', style: TextStyle(fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _bilgi == null ? _girisKart(t) : _bilgiKart(t),
      ),
    );
  }

  Widget _girisKart(TemaProvider t) => Column(children: [
        GestureDetector(
          onTap: _loading ? null : _qrOkut,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 34),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [t.mor1, t.mavi]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: t.mor1.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Column(children: [
              Icon(Icons.qr_code_scanner, color: Colors.white, size: 54),
              SizedBox(height: 10),
              Text('Ödül Kodunu Okut', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Padding(padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Müşterinin ekranındaki QR kodu kameraya göster',
                      style: TextStyle(color: Colors.white70, fontSize: 12.5), textAlign: TextAlign.center)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: t.line)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('veya kodu elle gir', style: TextStyle(color: t.sub, fontSize: 12))),
          Expanded(child: Divider(color: t.line)),
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _kodC,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: t.ink, fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'ÖRN: ZXLAGE', hintStyle: TextStyle(color: t.sub, letterSpacing: 2),
            filled: true, fillColor: t.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
          ),
          onSubmitted: (_) => _dogrula(),
        ),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, height: 52, child: FilledButton(
          style: FilledButton.styleFrom(backgroundColor: t.mavi, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: _loading ? null : _dogrula,
          child: _loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Doğrula', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        )),
      ]);

  Widget _bilgiKart(TemaProvider t) {
    final b = _bilgi!;
    final yeterli = b['yeterli'] == true;
    final adisyon = b['adisyon'] is Map ? b['adisyon'] as Map : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.line)),
        child: Column(children: [
          Icon(Icons.card_giftcard, color: t.gold, size: 44),
          const SizedBox(height: 10),
          Text(b['odul_ad']?.toString() ?? 'Ödül', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text('${b['puan']} puan', style: TextStyle(color: t.sub, fontSize: 14)),
          if ((b['aciklama']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(b['aciklama'].toString(), style: TextStyle(color: t.sub2, fontSize: 13), textAlign: TextAlign.center),
          ],
          Divider(height: 28, color: t.line),
          _satir(t, Icons.person_outline, 'Müşteri', b['musteri']?.toString() ?? '-'),
          _satir(t, Icons.stars_rounded, 'Mevcut Puanı', '${b['musteri_puan']} puan', renk: yeterli ? t.yesil : t.kirmizi),
          if (adisyon != null) _satir(t, Icons.receipt_long, 'Açık Hesap', '#${adisyon['id']} · ${(adisyon['toplam'] as num).toStringAsFixed(0)}₺'),
          if (!yeterli) Padding(padding: const EdgeInsets.only(top: 10),
              child: Text('Müşterinin puanı yetersiz, onaylanamaz.', style: TextStyle(color: t.kirmizi, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: (adisyon != null ? t.yesil : t.amber).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(Icons.info_outline, color: adisyon != null ? t.yesil : t.amber, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(
            adisyon != null
                ? 'Onaylayınca ödül bu açık hesaba indirim/ikram olarak işlenir + puan düşülür.'
                : 'Açık hesap yok. Onaylayınca sadece puan düşülür (ödülü elle verin).',
            style: TextStyle(color: t.sub2, fontSize: 12.5))),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: SizedBox(height: 52, child: OutlinedButton(
          onPressed: _onaylaniyor ? null : () => setState(() { _bilgi = null; _kodC.clear(); }),
          style: OutlinedButton.styleFrom(side: BorderSide(color: t.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Vazgeç', style: TextStyle(color: t.sub, fontSize: 15)),
        ))),
        const SizedBox(width: 12),
        Expanded(flex: 2, child: SizedBox(height: 52, child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: yeterli ? t.yesil : t.sub, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: (_onaylaniyor || !yeterli) ? null : _onayla,
          icon: _onaylaniyor
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle, color: Colors.white),
          label: const Text('Onayla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        ))),
      ]),
    ]);
  }

  Widget _satir(TemaProvider t, IconData i, String k, String v, {Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(i, color: t.sub, size: 18), const SizedBox(width: 10),
          Text(k, style: TextStyle(color: t.sub, fontSize: 13.5)),
          const Spacer(),
          Text(v, style: TextStyle(color: renk ?? t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      );
}
