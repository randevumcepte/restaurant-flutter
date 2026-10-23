import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// Satın Alma Talebi — requisition → RFQ → ⭐öneri → patron onay → PO.
/// Veri: /api/patron/talep-liste ; aksiyonlar /satinalma-talep/* (Bearer).
class SatinalmaTalepScreen extends StatefulWidget {
  const SatinalmaTalepScreen({super.key});
  @override
  State<SatinalmaTalepScreen> createState() => _SatinalmaTalepScreenState();
}

bool _ok(dynamic v) => v == true || v == 1 || v == '1';
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _mik(dynamic v) {
  final n = _n(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

const _durumMetin = {
  'yeni': 'Yeni', 'teklif': 'Teklif Bekleniyor', 'onayda': 'Onayda',
  'onaylandi': 'Onaylandı', 'siparis': 'Siparişte', 'tamamlandi': 'Tamamlandı',
};
const _durumRenk = {
  'yeni': Color(0xFF4F46E5), 'teklif': Color(0xFFF59E0B), 'onayda': Color(0xFFF59E0B),
  'onaylandi': Color(0xFF10B981), 'siparis': Color(0xFF0EA5E9), 'tamamlandi': Color(0xFF10B981),
};

class _SatinalmaTalepScreenState extends State<SatinalmaTalepScreen> {
  bool loading = true;
  List talepler = [];
  Map ozet = {'yeni': 0, 'onayda': 0, 'tamamlanan': 0};
  List kritikler = [];
  List malzemeler = [];
  List birimler = [];
  List tedarikciler = [];
  bool patron = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.talepListe(auth.token!);
      if (!mounted) return;
      if (_ok(res['ok'])) {
        setState(() {
          talepler = (res['talepler'] as List?) ?? [];
          ozet = (res['ozet'] as Map?) ?? ozet;
          kritikler = (res['kritikler'] as List?) ?? [];
          malzemeler = (res['malzemeler'] as List?) ?? [];
          birimler = (res['birimler'] as List?) ?? [];
          tedarikciler = (res['tedarikciler'] as List?) ?? [];
          patron = _ok(res['patron']);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String m, {Color? renk}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m), backgroundColor: renk, behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _yeniTalepAc({List? onDolu}) async {
    final t = context.read<TemaProvider>();
    final sonuc = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => _YeniTalepSheet(
        t: t, malzemeler: malzemeler, birimler: birimler, onDolu: onDolu,
      ),
    );
    if (sonuc == true) { _toast('Talep oluşturuldu', renk: const Color(0xFF10B981)); _yukle(); }
  }

  Future<void> _detayAc(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TalepDetayScreen(id: id, tedarikciler: tedarikciler, patron: patron),
    ));
    _yukle(); // detaydan dönünce listeyi tazele
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.mor1, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Satın Alma Talepleri', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: t.mor1,
        onPressed: () => _yeniTalepAc(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni Talep', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  _ozetRow(t),
                  if (kritikler.isNotEmpty) ...[const SizedBox(height: 12), _kritikBanner(t)],
                  const SizedBox(height: 14),
                  if (talepler.isEmpty)
                    _bos(t)
                  else
                    ...talepler.map((e) => _talepKart(t, e)),
                ],
              ),
            ),
    );
  }

  Widget _ozetRow(TemaProvider t) => Row(children: [
        _ozetKart(t, '${ozet['yeni'] ?? 0}', 'Yeni', Icons.inbox_outlined, t.mavi),
        _ozetKart(t, '${ozet['onayda'] ?? 0}', 'Onayda', Icons.pending_actions_outlined, t.amber),
        _ozetKart(t, '${ozet['tamamlanan'] ?? 0}', 'Tamamlanan', Icons.task_alt, t.yesil),
      ]);

  Widget _ozetKart(TemaProvider t, String say, String alt, IconData ik, Color c) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(ik, color: c, size: 19),
            ),
            const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(say, style: TextStyle(color: t.ink, fontSize: 19, fontWeight: FontWeight.w900, height: 1)),
              Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
      );

  Widget _kritikBanner(TemaProvider t) {
    final adlar = kritikler.take(6).map((e) => '${e['ad']}').join(', ');
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: t.kirmizi.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.kirmizi.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: t.kirmizi, size: 24),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${kritikler.length} malzeme kritik seviyede', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(adlar, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: t.kirmizi, foregroundColor: Colors.white, elevation: 0),
            onPressed: () => _yeniTalepAc(onDolu: kritikler),
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Kritikten Talep Oluştur', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _talepKart(TemaProvider t, dynamic e) {
    final durum = '${e['durum']}';
    final acil = '${e['aciliyet']}' == 'acil';
    final renk = _durumRenk[durum] ?? t.sub;
    final serit = acil ? t.kirmizi : t.mavi;
    return GestureDetector(
      onTap: () => _detayAc(_n(e['id']).toInt()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(15), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(width: 4, height: 42, decoration: BoxDecoration(color: serit, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(acil ? Icons.priority_high : Icons.storefront_outlined, size: 16, color: serit),
              const SizedBox(width: 5),
              Flexible(child: Text('${e['departman']}', overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800))),
              if (acil) ...[
                const SizedBox(width: 6),
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1), decoration: BoxDecoration(color: t.kirmizi, borderRadius: BorderRadius.circular(20)), child: const Text('ACİL', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
              ],
            ]),
            const SizedBox(height: 3),
            Text('${e['isteyen_ad'] ?? ''} · ${_n(e['kalem_sayisi']).toInt()} kalem', style: TextStyle(color: t.sub, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(20)), child: Text(_durumMetin[durum] ?? durum, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700))),
          ]),
          Icon(Icons.chevron_right, color: t.sub2, size: 20),
        ]),
      ),
    );
  }

  Widget _bos(TemaProvider t) => Container(
        padding: const EdgeInsets.symmetric(vertical: 56),
        alignment: Alignment.center,
        child: Column(children: [
          Icon(Icons.assignment_outlined, size: 48, color: t.sub.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text('Henüz talep yok.', style: TextStyle(color: t.sub, fontSize: 14)),
        ]),
      );
}

// ══════════════════════ YENİ TALEP SHEET ══════════════════════
class _YeniTalepSheet extends StatefulWidget {
  final TemaProvider t;
  final List malzemeler, birimler;
  final List? onDolu;
  const _YeniTalepSheet({required this.t, required this.malzemeler, required this.birimler, this.onDolu});
  @override
  State<_YeniTalepSheet> createState() => _YeniTalepSheetState();
}

class _YeniTalepSheetState extends State<_YeniTalepSheet> {
  String departman = 'Mutfak';
  String aciliyet = 'normal';
  final _not = TextEditingController();
  final List<Map<String, dynamic>> kalemler = [];
  bool kaydediyor = false;

  @override
  void initState() {
    super.initState();
    if (widget.onDolu != null && widget.onDolu!.isNotEmpty) {
      aciliyet = 'acil';
      _not.text = 'Kritik stok — otomatik oluşturuldu.';
      for (final k in widget.onDolu!) {
        kalemler.add({'malzeme_id': _n(k['id']).toInt(), 'miktar': _mik(k['oneri']), 'birim': '${k['birim'] ?? ''}'});
      }
    }
    if (kalemler.isEmpty) kalemler.add({'malzeme_id': null, 'miktar': '', 'birim': ''});
  }

  @override
  void dispose() { _not.dispose(); super.dispose(); }

  String _malzemeBirim(int? id) {
    if (id == null) return '';
    final m = widget.malzemeler.firstWhere((e) => _n(e['id']).toInt() == id, orElse: () => null);
    return m == null ? '' : '${m['birim_kisaltma'] ?? ''}';
  }

  Future<void> _kaydet() async {
    final auth = context.read<AuthProvider>();
    final gecerli = kalemler.where((k) => k['malzeme_id'] != null && _n(k['miktar']) > 0).toList();
    if (gecerli.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir kalem (malzeme + miktar) girin.'), backgroundColor: Color(0xFFF43F5E), behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => kaydediyor = true);
    final payload = gecerli.map((k) => {'malzeme_id': k['malzeme_id'], 'miktar': _n(k['miktar']), 'birim': k['birim'] ?? ''}).toList();
    try {
      final res = await Api.talepOlustur(auth.token!, departman, aciliyet, _not.text.trim(), jsonEncode(payload));
      if (!mounted) return;
      if (_ok(res['ok'])) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => kaydediyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['mesaj'] ?? 'Hata'}'), backgroundColor: const Color(0xFFF43F5E), behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) setState(() => kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(color: t.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Icon(Icons.add_shopping_cart, color: t.mor1),
              const SizedBox(width: 8),
              Text('Yeni Satın Alma Talebi', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                Row(children: [
                  Expanded(child: _alan(t, 'Departman', DropdownButtonFormField<String>(
                    initialValue: departman,
                    decoration: _dec(t),
                    dropdownColor: t.card,
                    style: TextStyle(color: t.ink, fontSize: 14),
                    items: const ['Mutfak', 'Bar', 'İK', 'Temizlik', 'Diğer'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setState(() => departman = v ?? 'Mutfak'),
                  ))),
                  const SizedBox(width: 10),
                  _acilToggle(t),
                ]),
                const SizedBox(height: 10),
                _alan(t, 'Not (opsiyonel)', TextField(controller: _not, style: TextStyle(color: t.ink), decoration: _dec(t, ipucu: 'Ör. bu hafta gerekli'))),
                const SizedBox(height: 14),
                Text('MALZEME KALEMLERİ', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
                const SizedBox(height: 8),
                ...kalemler.asMap().entries.map((en) => _kalemSatiri(t, en.key)),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: t.line), foregroundColor: t.mor1, minimumSize: const Size.fromHeight(44)),
                  onPressed: () => setState(() => kalemler.add({'malzeme_id': null, 'miktar': '', 'birim': ''})),
                  icon: const Icon(Icons.add, size: 18), label: const Text('Satır Ekle'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: t.mor1, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                  onPressed: kaydediyor ? null : _kaydet,
                  child: kaydediyor ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)) : const Text('Talebi Gönder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _acilToggle(TemaProvider t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Aciliyet', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        ToggleButtons(
          borderRadius: BorderRadius.circular(10),
          isSelected: [aciliyet == 'normal', aciliyet == 'acil'],
          onPressed: (i) => setState(() => aciliyet = i == 0 ? 'normal' : 'acil'),
          selectedColor: Colors.white,
          fillColor: aciliyet == 'acil' ? t.kirmizi : t.mavi,
          color: t.sub, constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          children: const [Text('Normal'), Text('Acil')],
        ),
      ]);

  Widget _kalemSatiri(TemaProvider t, int i) {
    final k = kalemler[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(flex: 4, child: DropdownButtonFormField<int>(
          initialValue: k['malzeme_id'],
          isExpanded: true,
          decoration: _dec(t, ipucu: 'Malzeme'),
          dropdownColor: t.card,
          style: TextStyle(color: t.ink, fontSize: 13.5),
          items: widget.malzemeler.map<DropdownMenuItem<int>>((m) => DropdownMenuItem(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) => setState(() { k['malzeme_id'] = v; k['birim'] = _malzemeBirim(v); }),
        )),
        const SizedBox(width: 5),
        Expanded(flex: 2, child: TextFormField(
          initialValue: '${k['miktar']}',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(color: t.ink, fontSize: 13.5),
          decoration: _dec(t, ipucu: 'Miktar'),
          onChanged: (v) => k['miktar'] = v,
        )),
        const SizedBox(width: 5),
        Expanded(flex: 2, child: _birimAlan(t, k, i)),
        const SizedBox(width: 2),
        SizedBox(width: 34, child: IconButton(
          icon: Icon(Icons.close, size: 18, color: t.sub2),
          onPressed: kalemler.length == 1 ? null : () => setState(() => kalemler.removeAt(i)),
        )),
      ]),
    );
  }

  // Birim dropdown'u (kg/koli/adet...) — malzeme seçilince baz birim otomatik gelir, kullanıcı değiştirebilir
  Widget _birimAlan(TemaProvider t, Map<String, dynamic> k, int i) {
    final set = <String>{};
    for (final b in widget.birimler) {
      final ks = '${b['kisaltma'] ?? b['ad'] ?? ''}'.trim();
      if (ks.isNotEmpty) set.add(ks);
    }
    final cur = '${k['birim'] ?? ''}'.trim();
    if (cur.isNotEmpty) set.add(cur); // otomatik gelen baz birim her zaman listede olsun (dropdown çökmesin)
    final liste = set.toList();
    return DropdownButtonFormField<String>(
      key: ValueKey('birim_${i}_$cur'), // malzeme seçilince birim otomatik yansısın
      initialValue: cur.isEmpty ? null : cur,
      isExpanded: true,
      decoration: _dec(t, ipucu: 'Birim'),
      dropdownColor: t.card,
      style: TextStyle(color: t.ink, fontSize: 13.5),
      items: liste.map<DropdownMenuItem<String>>((ks) => DropdownMenuItem(value: ks, child: Text(ks, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (v) => setState(() => k['birim'] = v ?? ''),
    );
  }

  Widget _alan(TemaProvider t, String etiket, Widget alan) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5), alan,
      ]);

  InputDecoration _dec(TemaProvider t, {String? ipucu}) => InputDecoration(
        hintText: ipucu, hintStyle: TextStyle(color: t.sub2, fontSize: 13),
        isDense: true, filled: true, fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      );
}

// ══════════════════════ TALEP DETAY ══════════════════════
class TalepDetayScreen extends StatefulWidget {
  final int id;
  final List tedarikciler;
  final bool patron;
  const TalepDetayScreen({super.key, required this.id, required this.tedarikciler, required this.patron});
  @override
  State<TalepDetayScreen> createState() => _TalepDetayScreenState();
}

class _TalepDetayScreenState extends State<TalepDetayScreen> {
  bool loading = true, islemde = false;
  Map? talep;
  List kalemler = [];

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.talepDetay(auth.token!, widget.id);
      if (!mounted) return;
      if (_ok(res['ok'])) {
        setState(() { talep = res['talep'] as Map?; kalemler = (res['kalemler'] as List?) ?? []; loading = false; });
      } else { setState(() => loading = false); }
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  void _toast(String m, {Color? renk}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: renk, behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));
  }

  Future<void> _calistir(Future<Map<String, dynamic>> Function(String token) f, {String? basari}) async {
    final auth = context.read<AuthProvider>();
    setState(() => islemde = true);
    try {
      final res = await f(auth.token!);
      if (!mounted) return;
      if (_ok(res['ok'])) {
        if (basari != null) _toast(basari, renk: const Color(0xFF10B981));
        await _yukle();
      } else {
        _toast('${res['mesaj'] ?? 'Hata'}', renk: const Color(0xFFF43F5E));
      }
    } catch (_) {
      _toast('Bağlantı hatası', renk: const Color(0xFFF43F5E));
    } finally {
      if (mounted) setState(() => islemde = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final durum = talep == null ? '' : '${talep!['durum']}';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.mor1, elevation: 0, iconTheme: const IconThemeData(color: Colors.white),
        title: Text(talep == null ? 'Talep' : '${talep!['departman']} Talebi', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : talep == null
              ? Center(child: Text('Talep bulunamadı', style: TextStyle(color: t.sub)))
              : Stack(children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      _durumSerit(t, durum),
                      const SizedBox(height: 12),
                      if ('${talep!['not'] ?? ''}'.isNotEmpty) ...[_notKutu(t), const SizedBox(height: 12)],
                      Text('KALEMLER · TEKLİFLER', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .3)),
                      const SizedBox(height: 8),
                      ...kalemler.map((k) => _kalemKart(t, k, durum)),
                      const SizedBox(height: 14),
                      _aksiyon(t, durum),
                    ],
                  ),
                  if (islemde) Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
                ]),
    );
  }

  Widget _durumSerit(TemaProvider t, String durum) {
    final renk = _durumRenk[durum] ?? t.sub;
    final acil = '${talep!['aciliyet']}' == 'acil';
    return Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(20)), child: Text(_durumMetin[durum] ?? durum, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      if (acil) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: t.kirmizi, borderRadius: BorderRadius.circular(20)), child: const Text('ACİL', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
      const Spacer(),
      Flexible(child: Text('${talep!['isteyen_ad'] ?? ''}', textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5))),
    ]);
  }

  Widget _notKutu(TemaProvider t) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: t.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.amber.withValues(alpha: 0.4))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.sticky_note_2_outlined, color: t.amber, size: 17),
          const SizedBox(width: 8),
          Expanded(child: Text('${talep!['not']}', style: TextStyle(color: t.ink, fontSize: 13))),
        ]),
      );

  Widget _kalemKart(TemaProvider t, dynamic k, String durum) {
    final teklifler = (k['teklifler'] as List?) ?? [];
    final duzenle = ['yeni', 'teklif', 'onayda'].contains(durum);
    final patronSecebilir = widget.patron && durum == 'onayda';
    final onerilen = k['onerilen_tedarikci_id'] == null ? null : _n(k['onerilen_tedarikci_id']).toInt();
    final secilen = k['secilen_tedarikci_id'] == null ? null : _n(k['secilen_tedarikci_id']).toInt();
    double? enUcuz;
    for (final tk in teklifler) { final f = _n(tk['fiyat']).toDouble(); if (enUcuz == null || f < enUcuz) enUcuz = f; }
    final kid = _n(k['id']).toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.inventory_2_outlined, color: t.mor1, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800))),
          Text('${_mik(k['miktar'])} ${k['birim'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        if (teklifler.isEmpty && !duzenle) Text('Teklif girilmedi.', style: TextStyle(color: t.sub, fontSize: 12)),
        ...teklifler.map((tk) {
          final tid = _n(tk['tedarikci_id']).toInt();
          final isOneri = onerilen == tid, isSecili = secilen == tid;
          final ucuz = enUcuz != null && _n(tk['fiyat']).toDouble() == enUcuz;
          Color kenar = t.line; Color? dolgu;
          if (isSecili) { kenar = t.yesil; dolgu = t.yesil.withValues(alpha: 0.1); }
          else if (isOneri) { kenar = t.amber; dolgu = t.amber.withValues(alpha: 0.09); }
          return GestureDetector(
            onTap: patronSecebilir ? () => _calistir((tok) => Api.talepPatronSec(tok, kid, tid, ''), basari: 'Seçildi') : null,
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: dolgu ?? t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: kenar, width: 1.4)),
              child: Row(children: [
                if (duzenle)
                  GestureDetector(
                    onTap: () => _calistir((tok) => Api.talepOneriKaydet(tok, kid, tid, '${k['oneri_gerekce'] ?? ''}'), basari: '⭐ Öneri kaydedildi'),
                    child: Icon(isOneri ? Icons.star : Icons.star_border, color: isOneri ? t.amber : t.sub2, size: 20),
                  )
                else if (isOneri)
                  Icon(Icons.star, color: t.amber, size: 20),
                if (duzenle || isOneri) const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text('${tk['tedarikci_ad']}', overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700))),
                    if (ucuz) ...[const SizedBox(width: 5), _etiket(t, 'EN UCUZ', t.yesil)],
                    if (isSecili) ...[const SizedBox(width: 5), _etiket(t, 'SEÇİLDİ', t.yesil)],
                  ]),
                  if ('${tk['vade'] ?? ''}'.isNotEmpty || tk['teslim_gun'] != null)
                    Text([if ('${tk['vade'] ?? ''}'.isNotEmpty) 'Vade: ${tk['vade']}', if (tk['teslim_gun'] != null) '${_n(tk['teslim_gun']).toInt()} gün'].join(' · '), style: TextStyle(color: t.sub, fontSize: 11)),
                ])),
                const SizedBox(width: 6),
                Text('${_mik(tk['fiyat'])} ₺', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800)),
                if (duzenle) ...[
                  const SizedBox(width: 4),
                  GestureDetector(onTap: () => _calistir((tok) => Api.talepTeklifSil(tok, _n(tk['id']).toInt())), child: Icon(Icons.close, size: 16, color: t.sub2)),
                ],
              ]),
            ),
          );
        }),
        if (duzenle) _teklifEkleForm(t, kid),
        if (duzenle) _gerekceAlan(t, k, kid),
        if (!duzenle && '${k['oneri_gerekce'] ?? ''}'.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: _gerekceGoster(t, 'Satın almacı', '${k['oneri_gerekce']}', t.amber)),
        if ('${k['patron_not'] ?? ''}'.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: _gerekceGoster(t, 'Yönetici', '${k['patron_not']}', t.yesil)),
      ]),
    );
  }

  Widget _etiket(TemaProvider t, String s, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)), child: Text(s, style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.w800)));

  Widget _teklifEkleForm(TemaProvider t, int kid) {
    int? tedId; final fiyat = TextEditingController(); final gun = TextEditingController();
    return StatefulBuilder(builder: (ctx, setLocal) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 4, child: DropdownButtonFormField<int>(
            initialValue: tedId, isExpanded: true,
            decoration: _miniDec(t, 'Tedarikçi'), dropdownColor: t.card, style: TextStyle(color: t.ink, fontSize: 12.5),
            items: widget.tedarikciler.map<DropdownMenuItem<int>>((m) => DropdownMenuItem(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (v) => setLocal(() => tedId = v),
          )),
          const SizedBox(width: 5),
          Expanded(flex: 2, child: TextField(controller: fiyat, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: t.ink, fontSize: 12.5), decoration: _miniDec(t, 'Fiyat'))),
          const SizedBox(width: 5),
          Expanded(flex: 2, child: TextField(controller: gun, keyboardType: TextInputType.number, style: TextStyle(color: t.ink, fontSize: 12.5), decoration: _miniDec(t, 'gün'))),
          const SizedBox(width: 5),
          IconButton(
            icon: Icon(Icons.add_circle, color: t.mor1),
            onPressed: () {
              if (tedId == null) { _toast('Tedarikçi seç', renk: const Color(0xFFF43F5E)); return; }
              if (_n(fiyat.text) <= 0) { _toast('Fiyat gir', renk: const Color(0xFFF43F5E)); return; }
              _calistir((tok) => Api.talepTeklifEkle(tok, {'talep_kalem_id': '$kid', 'tedarikci_id': '$tedId', 'fiyat': fiyat.text, if (gun.text.isNotEmpty) 'teslim_gun': gun.text}), basari: 'Teklif eklendi');
            },
          ),
        ]),
      );
    });
  }

  Widget _gerekceAlan(TemaProvider t, dynamic k, int kid) {
    final c = TextEditingController(text: '${k['oneri_gerekce'] ?? ''}');
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextField(
        controller: c, style: TextStyle(color: t.ink, fontSize: 12.5),
        decoration: _miniDec(t, 'Öneri gerekçesi (neden bu tedarikçi?)'),
        onSubmitted: (v) {
          final onerilen = k['onerilen_tedarikci_id'] == null ? null : _n(k['onerilen_tedarikci_id']).toInt();
          _calistir((tok) => Api.talepOneriKaydet(tok, kid, onerilen, v), basari: 'Gerekçe kaydedildi');
        },
      ),
    );
  }

  Widget _gerekceGoster(TemaProvider t, String kim, String metin, Color c) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(9)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.tips_and_updates_outlined, color: c, size: 15),
          const SizedBox(width: 6),
          Expanded(child: RichText(text: TextSpan(style: TextStyle(color: t.ink, fontSize: 12), children: [TextSpan(text: '$kim: ', style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: metin)]))),
        ]),
      );

  Widget _aksiyon(TemaProvider t, String durum) {
    final List<Widget> w = [];
    void bilgi(String s) => w.add(Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5))));
    Widget btn(String ad, IconData ik, Color c, VoidCallback onp) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SizedBox(width: double.infinity, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), elevation: 0),
            onPressed: islemde ? null : onp, icon: Icon(ik, size: 19), label: Text(ad, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          )),
        );

    if (['yeni', 'teklif'].contains(durum)) {
      bilgi('Her kaleme teklif girip ⭐ ile birini öner, sonra patrona gönder.');
      w.add(btn('Patrona Gönder (Onaya)', Icons.send, t.amber, () => _calistir((tok) => Api.talepPatronaGonder(tok, widget.id), basari: 'Patrona gönderildi')));
      w.add(btn('Anlaşmalıdan Direkt Sipariş', Icons.bolt, const Color(0xFF0EA5E9), () => _calistir((tok) => Api.talepAnlasmaliDirekt(tok, widget.id), basari: 'Direkt sipariş oluşturuldu')));
      bilgi('⚡ Anlaşmalı tedarikçiye ⭐ önerip fiyat girdiğin kalemler patron onayı olmadan direkt siparişe döner, tedarikçiye WhatsApp gider.');
    }
    if (durum == 'onayda') {
      if (widget.patron) {
        bilgi('Önerileri incele. Bir teklife dokunup değiştir, sonra onayla.');
        w.add(btn('Onayla (seçimleri kesinleştir)', Icons.check_circle, t.yesil, () => _calistir((tok) => Api.talepOnayla(tok, widget.id), basari: 'Onaylandı')));
      } else {
        bilgi('Patron onayı bekleniyor. Teklif/öneri hâlâ düzenlenebilir.');
      }
      w.add(btn('Anlaşmalıdan Direkt Sipariş', Icons.bolt, const Color(0xFF0EA5E9), () => _calistir((tok) => Api.talepAnlasmaliDirekt(tok, widget.id), basari: 'Direkt sipariş oluşturuldu')));
      bilgi('⚡ Anlaşmalı tedarikçiye ⭐ önerip fiyat girdiğin kalemler patron onayı olmadan direkt siparişe döner, tedarikçiye WhatsApp gider.');
    }
    if (durum == 'onaylandi') {
      bilgi('Onaylandı. Tedarikçiye-gruplu sipariş oluşturabilirsin.');
      w.add(btn('Sipariş Oluştur (PO)', Icons.shopping_cart_checkout, const Color(0xFF0EA5E9), () => _calistir((tok) => Api.talepPoOlustur(tok, widget.id), basari: 'Sipariş oluşturuldu')));
    }
    if (durum == 'siparis') {
      bilgi('✓ Sipariş oluşturuldu. Mal gelince Mal Kabul ekranından karşılaştır.');
      w.add(btn('Tamamlandı İşaretle', Icons.task_alt, t.yesil, () => _calistir((tok) => Api.talepDurumGuncelle(tok, widget.id, 'tamamlandi'), basari: 'Tamamlandı')));
    }
    return Column(children: w);
  }

  InputDecoration _miniDec(TemaProvider t, String ipucu) => InputDecoration(
        hintText: ipucu, hintStyle: TextStyle(color: t.sub2, fontSize: 12),
        isDense: true, filled: true, fillColor: t.card2,
        contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.mor1)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.line)),
      );
}
