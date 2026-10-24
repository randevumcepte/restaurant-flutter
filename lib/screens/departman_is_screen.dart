import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// GENERIC DEPARTMAN İŞ / KONTROL / OLAY ekranı (Grup B):
/// kalite (HACCP kontrol+sıcaklık), temizlik, güvenlik, teknik (arıza/bakım), it, bulaşık, etkinlik.
/// Tek ekran; departman kodu + preset şablonlarla çalışır. Periyodik işler tamamlanınca sunucu bir sonrakini üretir.
class DepartmanIsScreen extends StatefulWidget {
  final String kod;
  final String baslik;
  final Color renk;
  const DepartmanIsScreen({super.key, required this.kod, required this.baslik, this.renk = const Color(0xFF4F46E5)});
  @override
  State<DepartmanIsScreen> createState() => _DepartmanIsScreenState();
}

class _DepartmanIsScreenState extends State<DepartmanIsScreen> {
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _gri = Color(0xFF64748B);
  static const _mor = Color(0xFF7C3AED);

  static const _tip = {
    'gorev': ['Görev', Icons.task_alt, Color(0xFF4F46E5)],
    'kontrol': ['Kontrol', Icons.checklist, _yesil],
    'olay': ['Olay', Icons.report, _kirmizi],
    'ariza': ['Arıza', Icons.report_problem, _kirmizi],
    'bakim': ['Bakım', Icons.handyman, _amber],
    'etkinlik': ['Etkinlik', Icons.celebration, _mor],
    'kayit': ['Kayıt', Icons.description, _gri],
  };
  static const _onc = {'yuksek': ['Yüksek', _kirmizi], 'orta': ['Orta', _amber], 'dusuk': ['Düşük', _gri]};
  static const _tekrarAd = {'gunluk': 'Günlük', 'haftalik': 'Haftalık', 'aylik': 'Aylık'};

  TemaProvider get _t => context.watch<TemaProvider>();
  Map<String, dynamic>? data;
  bool loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() => loading = true);
    try {
      final res = await Api.departmanIsPanel(auth.token!, widget.kod);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { data = Map<String, dynamic>.from(res); loading = false; });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _mesaj(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  Future<void> _presetEkle(Map pr) async {
    final auth = context.read<AuthProvider>();
    try {
      await Api.departmanIsEkle(auth.token!, {'kod': widget.kod, 'tip': '${pr['tip']}', 'baslik': '${pr['baslik']}', 'oncelik': '${pr['oncelik'] ?? 'orta'}', if (pr['tekrar'] != null) 'tekrar': '${pr['tekrar']}'});
    } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<void> _durum(int id, String durum, bool olcumIster) async {
    String deger = '';
    if (durum == 'tamam' && olcumIster) {
      final girilen = await _olcumSor();
      if (girilen == null) return;
      deger = girilen;
    }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try { await Api.departmanIsDurum(auth.token!, id, durum, deger: deger); } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<String?> _olcumSor() async {
    final c = TextEditingController();
    final t = context.read<TemaProvider>();
    return showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: t.card,
      title: Text('Ölçüm / Değer', style: TextStyle(color: t.ink, fontSize: 16)),
      content: TextField(controller: c, autofocus: true, style: TextStyle(color: t.ink), decoration: const InputDecoration(hintText: 'ör. 4 °C')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? '-' : c.text.trim()), style: ElevatedButton.styleFrom(backgroundColor: _yesil), child: const Text('Kaydet')),
      ],
    ));
  }

  Future<void> _sil(int id) async {
    final t = context.read<TemaProvider>();
    final onay = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: t.card,
      title: Text('Silinsin mi?', style: TextStyle(color: t.ink, fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _kirmizi), child: const Text('Sil')),
      ],
    ));
    if (onay != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    try { await Api.departmanIsSil(auth.token!, id); } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<void> _ekleDialog() async {
    final t = context.read<TemaProvider>();
    final baslik = TextEditingController(), aciklama = TextEditingController();
    String tip = 'gorev', oncelik = 'orta', tekrar = '';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
      backgroundColor: t.card,
      title: Text('Yeni İş / Kayıt', style: TextStyle(color: t.ink, fontSize: 17)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dd(t, tip, const {'gorev': 'Görev', 'kontrol': 'Kontrol', 'olay': 'Olay/Tutanak', 'ariza': 'Arıza', 'bakim': 'Bakım', 'etkinlik': 'Etkinlik', 'kayit': 'Kayıt'}, (v) => setD(() => tip = v)),
        const SizedBox(height: 8),
        _tf(t, baslik, 'Başlık *'),
        _tf(t, aciklama, 'Açıklama / not'),
        const SizedBox(height: 4),
        _dd(t, oncelik, const {'orta': 'Orta öncelik', 'yuksek': 'Yüksek öncelik', 'dusuk': 'Düşük öncelik'}, (v) => setD(() => oncelik = v)),
        const SizedBox(height: 8),
        _dd(t, tekrar, const {'': 'Tek seferlik', 'gunluk': 'Günlük tekrar', 'haftalik': 'Haftalık tekrar', 'aylik': 'Aylık tekrar'}, (v) => setD(() => tekrar = v)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: widget.renk), child: const Text('Ekle')),
      ],
    )));
    if (ok != true || !mounted) return;
    if (baslik.text.trim().isEmpty) { _mesaj('Başlık gerekli.'); return; }
    final auth = context.read<AuthProvider>();
    try {
      await Api.departmanIsEkle(auth.token!, {'kod': widget.kod, 'tip': tip, 'baslik': baslik.text.trim(), 'oncelik': oncelik, if (tekrar.isNotEmpty) 'tekrar': tekrar, if (aciklama.text.trim().isNotEmpty) 'aciklama': aciklama.text.trim()});
    } catch (_) {}
    _yukle(sessiz: true);
  }

  Widget _tf(TemaProvider t, TextEditingController c, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, style: TextStyle(color: t.ink), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: t.sub2), filled: true, fillColor: t.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11))),
      );

  Widget _dd(TemaProvider t, String val, Map<String, String> opts, ValueChanged<String> onCh) => Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
        child: DropdownButton<String>(value: val, isExpanded: true, underline: const SizedBox(), dropdownColor: t.card,
          items: [for (final e in opts.entries) DropdownMenuItem(value: e.key, child: Text(e.value, style: TextStyle(color: t.ink)))],
          onChanged: (v) { if (v != null) onCh(v); }),
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final oz = (data?['ozet'] as Map?) ?? {};
    final isler = (data?['isler'] as List?) ?? [];
    final presetler = (data?['presetler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text(widget.baslik, style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub))]),
      floatingActionButton: FloatingActionButton.extended(backgroundColor: widget.renk, onPressed: _ekleDialog, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Yeni', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _yukle, color: widget.renk, backgroundColor: t.card, child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 90),
              children: [
                Row(children: [
                  Expanded(child: _ozetKart(t, Icons.pending_actions, '${_n(oz['acik']).toInt()}', 'Açık', widget.renk)),
                  const SizedBox(width: 9),
                  Expanded(child: _ozetKart(t, Icons.task_alt, '${_n(oz['bugun_tamam']).toInt()}', 'Bugün', _yesil)),
                  const SizedBox(width: 9),
                  Expanded(child: _ozetKart(t, Icons.schedule, '${_n(oz['geciken']).toInt()}', 'Geciken', _kirmizi)),
                  const SizedBox(width: 9),
                  Expanded(child: _ozetKart(t, Icons.priority_high, '${_n(oz['yuksek']).toInt()}', 'Yüksek', _amber)),
                ]),
                if (presetler.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Hızlı ekle', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final pr in presetler) _presetCip(t, pr as Map)]),
                ],
                const SizedBox(height: 16),
                if (isler.isEmpty) _bos(t) else for (final x in isler) _satir(t, x as Map),
              ],
            )),
    );
  }

  Widget _ozetKart(TemaProvider t, IconData ik, String say, String etiket, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Column(children: [
          Icon(ik, color: c, size: 20),
          const SizedBox(height: 6),
          Text(say, style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
          const SizedBox(height: 2),
          Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );

  Widget _presetCip(TemaProvider t, Map pr) => InkWell(
        onTap: () => _presetEkle(pr), borderRadius: BorderRadius.circular(20),
        child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: widget.renk)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.add, color: widget.renk, size: 15), const SizedBox(width: 5), Text('${pr['baslik']}', style: TextStyle(color: widget.renk, fontSize: 12, fontWeight: FontWeight.w700))])),
      );

  Widget _satir(TemaProvider t, Map x) {
    final tip = (_tip['${x['tip']}'] ?? _tip['gorev']!);
    final onc = (_onc['${x['oncelik']}'] ?? _onc['orta']!);
    final tipAd = tip[0] as String, tipIk = tip[1] as IconData, tipRenk = tip[2] as Color;
    final oncAd = onc[0] as String, oncRenk = onc[1] as Color;
    final id = _n(x['id']).toInt();
    final olcumIster = x['tip'] == 'kontrol';
    final yapiliyor = x['durum'] == 'yapiliyor';
    final gecikti = x['gecikti'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      padding: const EdgeInsets.fromLTRB(13, 11, 7, 11),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: tipRenk.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: Icon(tipIk, color: tipRenk, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${x['baslik']}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800))),
            if (x['deger'] != null && '${x['deger']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(left: 6), child: Text('${x['deger']}', style: const TextStyle(color: _yesil, fontSize: 13, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 5),
          Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            _cip(tipAd, tipRenk), _cip(oncAd, oncRenk),
            if (x['tekrar'] != null) Text('🔁 ${_tekrarAd['${x['tekrar']}'] ?? x['tekrar']}', style: TextStyle(color: t.sub, fontSize: 11)),
            if (x['son_tarih'] != null) Text('📅 ${x['son_tarih']}${gecikti ? ' (gecikti)' : ''}', style: TextStyle(color: gecikti ? _kirmizi : t.sub, fontSize: 11, fontWeight: gecikti ? FontWeight.w700 : FontWeight.w400)),
            if (yapiliyor) const Text('● yapılıyor', style: TextStyle(color: _amber, fontSize: 11)),
          ]),
          if (x['aciklama'] != null && '${x['aciklama']}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${x['aciklama']}', style: TextStyle(color: t.sub, fontSize: 11.5))),
        ])),
        Column(children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (!yapiliyor) _ikonBtn(Icons.play_arrow, _gri, () => _durum(id, 'yapiliyor', false)),
            _ikonBtn(Icons.check_circle, _yesil, () => _durum(id, 'tamam', olcumIster)),
            _ikonBtn(Icons.delete_outline, _gri, () => _sil(id)),
          ]),
        ]),
      ]),
    );
  }

  Widget _cip(String metin, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Text(metin, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)));

  Widget _ikonBtn(IconData ik, Color c, VoidCallback onTap) => IconButton(onPressed: onTap, icon: Icon(ik, color: c, size: 22), visualDensity: VisualDensity.compact, padding: const EdgeInsets.all(3), constraints: const BoxConstraints());

  Widget _bos(TemaProvider t) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 15),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Text('Açık iş yok. "Yeni" ile ekle ya da yukarıdaki hazır şablonlardan seç.', style: TextStyle(color: t.sub, fontSize: 13)));
}
