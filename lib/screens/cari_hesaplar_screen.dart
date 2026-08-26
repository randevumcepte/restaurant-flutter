import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Cari / Açık Hesap ("bana yazın") — hesaplar, bakiye, hareketler, tahsilat.
/// secmeMod=true ise: açık hesapla masa kapatırken cari SEÇİCİ olarak kullanılır (dokununca pop).
class CariHesaplarScreen extends StatefulWidget {
  final bool secmeMod;
  const CariHesaplarScreen({super.key, this.secmeMod = false});

  @override
  State<CariHesaplarScreen> createState() => _CariHesaplarScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
final _f = NumberFormat.decimalPattern('tr');
String _tl(num v) => '${_f.format(v.round())}TL';
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

Color _tipRenk(String t) => {'patron': _mor1, 'firma': _mavi, 'musteri': _yesil, 'personel': const Color(0xFFD97706)}[t] ?? const Color(0xFF64748B);
String _tipAd(String t) => {'patron': 'Patron', 'firma': 'Firma', 'musteri': 'Müşteri', 'personel': 'Personel'}[t] ?? t;

class _CariHesaplarScreenState extends State<CariHesaplarScreen> {
  List cariler = [];
  num toplamAlacak = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.cariler(auth.token!);
      if (!mounted) return;
      setState(() {
        cariler = (res['cariler'] as List?) ?? [];
        toplamAlacak = _n(res['toplam_alacak']);
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _yeniCari() async {
    final adC = TextEditingController();
    final telC = TextEditingController();
    String tip = 'musteri';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Yeni Cari Hesap', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: adC, autofocus: true, style: const TextStyle(color: Colors.white), decoration: _inp('İsim / Ünvan')),
          const SizedBox(height: 10),
          TextField(controller: telC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _inp('Telefon (opsiyonel)')),
          const SizedBox(height: 12),
          Row(children: [
            for (final t in ['musteri', 'firma', 'personel'])
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setD(() => tip = t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: tip == t ? _tipRenk(t).withValues(alpha: 0.25) : const Color(0xFF1E263B), borderRadius: BorderRadius.circular(8), border: Border.all(color: tip == t ? _tipRenk(t) : Colors.transparent)),
                    child: Text(_tipAd(t), textAlign: TextAlign.center, style: TextStyle(color: tip == t ? _tipRenk(t) : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8)))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _mor1), child: const Text('Ekle')),
        ],
      )),
    );
    if (ok == true && adC.text.trim().isNotEmpty) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final res = await Api.cariEkle(auth.token!, adC.text.trim(), tip, telC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) {
        if (widget.secmeMod) {
          Navigator.of(context).pop({'id': res['id'], 'ad': res['ad']});
        } else {
          _yukle();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.secmeMod ? 'Cari Seç (Açık Hesap)' : 'Cari Hesaplar', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _yeniCari,
        backgroundColor: _mor1,
        icon: const Icon(Icons.person_add_alt, color: Colors.white),
        label: const Text('Yeni Cari', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: _mor1,
              backgroundColor: _card,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                if (!widget.secmeMod)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Toplam Açık Alacak', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(_tl(toplamAlacak), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                      Text('${cariler.length} cari hesap', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ]),
                  ),
                for (final c in cariler) _cariKart(c as Map),
                const SizedBox(height: 80),
              ]),
            ),
    );
  }

  Widget _cariKart(Map c) {
    final renk = _tipRenk(c['tip'].toString());
    final bakiye = _n(c['bakiye']);
    return GestureDetector(
      onTap: () async {
        if (widget.secmeMod) {
          Navigator.of(context).pop({'id': c['id'], 'ad': c['ad']});
        } else {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CariDetayScreen(cariId: _n(c['id']).toInt(), ad: c['ad'].toString())));
          _yukle();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: renk.withValues(alpha: 0.25), child: Text(c['ad'].toString().substring(0, 1).toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(_tipAd(c['tip'].toString()), style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_tl(bakiye), style: TextStyle(color: bakiye > 0 ? _kirmizi : _yesil, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(bakiye > 0 ? 'borç' : 'temiz', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
          ]),
          if (widget.secmeMod) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, color: Color(0xFF64748B))),
        ]),
      ),
    );
  }
}

InputDecoration _inp(String hint) => InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: Color(0xFF64748B)),
      filled: true, fillColor: const Color(0xFF0F1526),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );

class _CariDetayScreen extends StatefulWidget {
  final int cariId;
  final String ad;
  const _CariDetayScreen({required this.cariId, required this.ad});

  @override
  State<_CariDetayScreen> createState() => _CariDetayScreenState();
}

class _CariDetayScreenState extends State<_CariDetayScreen> {
  Map<String, dynamic>? d;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.cariDetay(auth.token!, widget.cariId);
      if (!mounted) return;
      setState(() {
        d = res['ok'] == 1 ? res : null;
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _tahsilat() async {
    final tutarC = TextEditingController(text: (_n(d?['bakiye']) > 0 ? _n(d!['bakiye']).round().toString() : ''));
    String sekil = 'nakit';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Tahsilat', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: tutarC, keyboardType: TextInputType.number, autofocus: true, style: const TextStyle(color: Colors.white), decoration: _inp('Tutar (TL)')),
          const SizedBox(height: 12),
          Row(children: [
            for (final s in ['nakit', 'havale', 'kredi'])
              Expanded(child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => setD(() => sekil = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(color: sekil == s ? _yesil.withValues(alpha: 0.25) : const Color(0xFF1E263B), borderRadius: BorderRadius.circular(8), border: Border.all(color: sekil == s ? _yesil : Colors.transparent)),
                    child: Text(s[0].toUpperCase() + s.substring(1), textAlign: TextAlign.center, style: TextStyle(color: sekil == s ? _yesil : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
              )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8)))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _yesil), child: const Text('Tahsil Et')),
        ],
      )),
    );
    if (ok == true) {
      final tutar = double.tryParse(tutarC.text.replaceAll(',', '.')) ?? 0;
      if (tutar > 0) {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        final res = await Api.cariTahsilat(auth.token!, widget.cariId, tutar, sekil);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['mesaj']?.toString() ?? 'Tahsil edildi'), backgroundColor: _yesil));
        _yukle();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bakiye = _n(d?['bakiye']);
    final hareketler = (d?['hareketler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.ad, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : d == null
              ? const Center(child: Text('Cari alınamadı', style: TextStyle(color: _kirmizi)))
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: _mor1,
                  backgroundColor: _card,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: bakiye > 0 ? [const Color(0xFF7F1D1D), const Color(0xFF9F1239)] : [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Güncel Bakiye (Borç)', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(_tl(bakiye), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text('Toplam satış ${_tl(_n(d!['toplam_borc']))} · Tahsilat ${_tl(_n(d!['toplam_tahsilat']))}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _tahsilat,
                        icon: const Icon(Icons.payments_outlined, size: 20),
                        label: const Text('Tahsil Et', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('Hesap Hareketleri', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
                    for (final h in hareketler) _hareketSatir(h as Map),
                  ]),
                ),
    );
  }

  Widget _hareketSatir(Map h) {
    final borc = h['tip'] == 'borc';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(borc ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: borc ? _kirmizi : _yesil),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(borc ? 'Satış (Borç)' : 'Tahsilat${h['odeme_sekli'] != null ? ' · ${h['odeme_sekli']}' : ''}', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w600)),
            Text(h['zaman'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ]),
        ),
        Text('${borc ? '+' : '-'}${_tl(_n(h['tutar']))}', style: TextStyle(color: borc ? _kirmizi : _yesil, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
