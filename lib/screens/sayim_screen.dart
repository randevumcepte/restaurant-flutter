import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

final _f = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _mik(num v) => v == v.roundToDouble() ? _f.format(v.round()) : v.toStringAsFixed(2);
String _tl(num v) => '${_f.format(v.round())}TL';

/// Sayım (fiziksel envanter) — teorik (defter) otomatik dolu, sayılanı gir, canlı fark.
/// Kaydedince defter fiiliye eşitlenir + teorik-gerçek fark (kayıp radarı) raporu.
class SayimScreen extends StatefulWidget {
  const SayimScreen({super.key});
  @override
  State<SayimScreen> createState() => _SayimScreenState();
}

class _SayimScreenState extends State<SayimScreen> {
  List malzemeler = [];
  final Map<int, TextEditingController> _ctrl = {};
  bool loading = true;
  bool duzenleyebilir = false;
  bool kaydediliyor = false;
  String _ara = '';

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { for (final c in _ctrl.values) { c.dispose(); } super.dispose(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.sayimYeni(auth.token!);
      if (!mounted) return;
      setState(() {
        malzemeler = (res['malzemeler'] as List?) ?? [];
        duzenleyebilir = res['duzenleyebilir'] == true;
        for (final m in malzemeler) {
          final id = _n((m as Map)['malzeme_id']).toInt();
          _ctrl.putIfAbsent(id, () => TextEditingController());
        }
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  double? _sayilan(int id) {
    final t = _ctrl[id]?.text.trim().replaceAll(',', '.') ?? '';
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int get _girilenSayi => malzemeler.where((m) => _sayilan(_n((m as Map)['malzeme_id']).toInt()) != null).length;

  Future<void> _kaydet() async {
    final kalemler = <Map<String, dynamic>>[];
    for (final m in malzemeler) {
      final id = _n((m as Map)['malzeme_id']).toInt();
      final s = _sayilan(id);
      if (s != null) kalemler.add({'malzeme_id': id, 'sayilan': s});
    }
    if (kalemler.isEmpty) { _uyar('En az bir malzeme sayın (miktar girin)'); return; }
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.sayimKaydet(auth.token!, kalemler);
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        await _sonucGoster(res);
        if (mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => SayimDetayScreen(id: _n(res['sayim_id']).toInt())));
      } else {
        _uyar(res['hata']?.toString() ?? 'Kaydedilemedi');
      }
    } catch (_) {
      if (mounted) { setState(() => kaydediliyor = false); _uyar('Bağlantı hatası'); }
    }
  }

  Future<void> _sonucGoster(Map res) async {
    final t = context.read<TemaProvider>();
    final fm = _n(res['toplam_fark_maliyet']).toDouble();
    await showDialog(context: context, builder: (c) => AlertDialog(
      backgroundColor: t.card,
      title: Text('Sayım kaydedildi', style: TextStyle(color: t.ink)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${res['sayilan_kalem']} kalem sayıldı · ${res['eksik']} eksik · ${res['fazla']} fazla', style: TextStyle(color: t.sub, fontSize: 13)),
        const SizedBox(height: 8),
        Text(fm < 0 ? 'Toplam açık: ${_tl(fm.abs())} (kayıp)' : (fm > 0 ? 'Toplam fazla: ${_tl(fm)}' : 'Fark yok — tertemiz.'),
            style: TextStyle(color: fm < 0 ? const Color(0xFFF43F5E) : (fm > 0 ? const Color(0xFFF59E0B) : t.yesil), fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tamam'))],
    ));
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final filtre = _ara.trim().toLowerCase();
    final liste = filtre.isEmpty ? malzemeler : malzemeler.where((m) => (m as Map)['ad'].toString().toLowerCase().contains(filtre)).toList();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Sayım', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SayimGecmisScreen())),
            icon: Icon(Icons.history, color: t.mavi, size: 18), label: Text('Geçmiş', style: TextStyle(color: t.mavi, fontSize: 13))), const MenuHamburger()],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : Column(children: [
              Container(
                margin: const EdgeInsets.fromLTRB(14, 10, 14, 0), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.mavi.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mavi.withValues(alpha: 0.35))),
                child: Row(children: [
                  Icon(Icons.info_outline, color: t.mavi, size: 18), const SizedBox(width: 8),
                  Expanded(child: Text('Fiili sayımı girin. Sistem, "olması gereken" ile karşılaştırıp farkı (kayıp/fazla) çıkarır. Sadece saydıklarınızı girin.', style: TextStyle(color: t.sub2, fontSize: 12, height: 1.3))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                child: TextField(onChanged: (v) => setState(() => _ara = v), style: TextStyle(color: t.ink),
                    decoration: InputDecoration(hintText: 'Malzeme ara', hintStyle: TextStyle(color: t.sub), isDense: true, prefixIcon: Icon(Icons.search, color: t.sub, size: 18),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)))),
              ),
              Expanded(child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                itemCount: liste.length,
                itemBuilder: (ctx, i) => _satir(t, liste[i] as Map),
              )),
            ]),
      bottomSheet: (!loading && duzenleyebilir)
          ? Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
              child: SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: t.mor1, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: kaydediliyor ? null : _kaydet,
                child: kaydediliyor
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Sayımı Kaydet ($_girilenSayi kalem)', style: const TextStyle(fontWeight: FontWeight.bold)),
              )),
            )
          : null,
    );
  }

  Widget _satir(TemaProvider t, Map m) {
    final id = _n(m['malzeme_id']).toInt();
    final teorik = _n(m['teorik']).toDouble();
    final s = _sayilan(id);
    final fark = s == null ? null : (s - teorik);
    final renk = fark == null ? t.sub : (fark < -0.0001 ? const Color(0xFFF43F5E) : (fark > 0.0001 ? const Color(0xFFF59E0B) : t.yesil));
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m['ad'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Sistemde: ${_mik(teorik)} ${m['birim']}', style: TextStyle(color: t.sub, fontSize: 12)),
        ])),
        SizedBox(
          width: 88,
          child: TextField(
            controller: _ctrl[id], enabled: duzenleyebilir,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 14),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(hintText: 'Say', hintStyle: TextStyle(color: t.sub), isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.mor1))),
          ),
        ),
        SizedBox(
          width: 62,
          child: Text(fark == null ? '—' : (fark > 0 ? '+${_mik(fark)}' : _mik(fark)),
              textAlign: TextAlign.right, style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

// ============================================================================
// SAYIM GEÇMİŞİ
// ============================================================================
class SayimGecmisScreen extends StatefulWidget {
  const SayimGecmisScreen({super.key});
  @override
  State<SayimGecmisScreen> createState() => _SayimGecmisScreenState();
}

class _SayimGecmisScreenState extends State<SayimGecmisScreen> {
  List liste = [];
  bool loading = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.sayimGecmis(auth.token!);
      if (!mounted) return;
      setState(() { liste = (res['sayimlar'] as List?) ?? []; loading = false; });
    } on ApiYetkiHatasi { if (mounted) context.read<AuthProvider>().cikis(); }
    catch (_) { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
          title: Text('Sayım Geçmişi', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : liste.isEmpty
              ? Center(child: Text('Henüz sayım yapılmadı.', style: TextStyle(color: t.sub, fontSize: 14)))
              : RefreshIndicator(onRefresh: _yukle, color: t.mor1, backgroundColor: t.card, child: ListView(padding: const EdgeInsets.all(14), children: [
                  for (final s in liste) _kart(t, s as Map),
                  const SizedBox(height: 30),
                ])),
    );
  }

  Widget _kart(TemaProvider t, Map s) {
    final fm = _n(s['fark_maliyet']).toDouble();
    final renk = fm < 0 ? const Color(0xFFF43F5E) : (fm > 0 ? const Color(0xFFF59E0B) : t.yesil);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SayimDetayScreen(id: _n(s['id']).toInt()))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['tarih'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
            Text('${s['kalem']} kalem · ${s['eksik']} eksik', style: TextStyle(color: t.sub, fontSize: 12)),
          ])),
          Text(fm < 0 ? '-${_tl(fm.abs())}' : (fm > 0 ? '+${_tl(fm)}' : '0'), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: t.sub, size: 20),
        ]),
      ),
    );
  }
}

// ============================================================================
// SAYIM DETAYI (teorik-gerçek fark raporu + AI)
// ============================================================================
class SayimDetayScreen extends StatefulWidget {
  final int id;
  const SayimDetayScreen({super.key, required this.id});
  @override
  State<SayimDetayScreen> createState() => _SayimDetayScreenState();
}

class _SayimDetayScreenState extends State<SayimDetayScreen> {
  Map? d;
  bool loading = true;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.sayimDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() { d = res['ok'] == 1 ? res : null; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kalemler = (d?['kalemler'] as List?) ?? [];
    final ai = (d?['ai'] as List?) ?? [];
    final fm = _n(d?['toplam_fark_maliyet']).toDouble();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
          title: Text('Sayım — ${d?['tarih'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : d == null
              ? Center(child: Text('Sayım bulunamadı', style: TextStyle(color: t.sub)))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  // Özet
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: fm < 0 ? [const Color(0xFFF43F5E), const Color(0xFFF59E0B)] : (fm > 0 ? [const Color(0xFFF59E0B), t.mavi] : [t.yesil, t.mavi])),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(fm < 0 ? 'Toplam Açık (Kayıp)' : (fm > 0 ? 'Toplam Fazla' : 'Fark Yok'), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(fm == 0 ? 'Tertemiz' : _tl(fm.abs()), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  // AI yorum
                  for (final a in ai)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mor2.withValues(alpha: 0.4))),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('✨', style: TextStyle(fontSize: 14)), const SizedBox(width: 8),
                        Expanded(child: Text((a as Map)['mesaj'].toString(), style: TextStyle(color: t.ink, fontSize: 13, height: 1.35))),
                      ]),
                    ),
                  const SizedBox(height: 8),
                  Text('Kalem Bazında Fark', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  for (final k in kalemler) _kalemSatir(t, k as Map),
                  const SizedBox(height: 30),
                ]),
    );
  }

  Widget _kalemSatir(TemaProvider t, Map k) {
    final fark = _n(k['fark']).toDouble();
    final fmk = _n(k['fark_maliyet']).toDouble();
    final renk = fark < -0.0001 ? const Color(0xFFF43F5E) : (fark > 0.0001 ? const Color(0xFFF59E0B) : t.yesil);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k['malzeme'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('Sistem ${_mik(_n(k['teorik']))} · Sayılan ${_mik(_n(k['sayilan']))} ${k['birim']}', style: TextStyle(color: t.sub, fontSize: 11.5)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fark > 0 ? '+${_mik(fark)}' : _mik(fark), style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.bold)),
          if (fmk.abs() >= 1) Text(fmk < 0 ? '-${_tl(fmk.abs())}' : '+${_tl(fmk)}', style: TextStyle(color: renk, fontSize: 11)),
        ]),
      ]),
    );
  }
}
