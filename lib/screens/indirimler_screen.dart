import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// İndirimler (Sahip/Müdür) — yönetilebilir çok-türlü indirim kuralları, her biri ayrı aç/kapa.
/// tip: online_odeme|kupon|uygulama|ilk_siparis|tutar_ustu|happy_hour|gun|dogum_gunu|urun
class IndirimlerScreen extends StatefulWidget {
  const IndirimlerScreen({super.key});
  @override
  State<IndirimlerScreen> createState() => _IndirimlerScreenState();
}

// [ikon, ad, ipucu]
const Map<String, List<String>> kTipler = {
  'online_odeme': ['💳', 'Online Ödeme', 'Müşteri kartla online öderken otomatik. Kasa/nakitte uygulanmaz.'],
  'kupon': ['🎫', 'Kupon Kodu', 'Müşteri ödeme ekranında kodu girer. Kupon kodu zorunlu.'],
  'uygulama': ['📱', 'Uygulama Siparişi', 'Uygulamadan gelen siparişte. (QR-web’de pasif.)'],
  'ilk_siparis': ['🥇', 'İlk Sipariş', 'Müşterinin ilk siparişinde. (Müşteri tanınıyorsa.)'],
  'tutar_ustu': ['💰', 'Tutar Üstü', 'Sepet, min. tutarın üstündeyse. Min. tutarı gir.'],
  'happy_hour': ['🕐', 'Happy Hour', 'Belirlenen saat aralığında.'],
  'gun': ['📅', 'Haftanın Günü', 'Seçili günlerde.'],
  'dogum_gunu': ['🎂', 'Doğum Günü', 'Müşterinin doğum gününde. (Müşteri tanınıyorsa.)'],
  'urun': ['🍽️', 'Seçili Ürünler', 'İndirim yalnızca seçtiğin ürünlere (online ödemede).'],
};

class _IndirimlerScreenState extends State<IndirimlerScreen> {
  List kurallar = [];
  List urunler = [];
  bool loading = true;

  TemaProvider get _t => context.watch<TemaProvider>();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.indirimler(auth.token!);
      if (!mounted) return;
      setState(() {
        kurallar = (res['kurallar'] as List?) ?? [];
        urunler = (res['urunler'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _duzenle([Map? kural]) async {
    final kaydedildi = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _IndirimForm(kural: kural, urunler: urunler),
    ));
    if (kaydedildi == true) _yukle();
  }

  Future<void> _toggle(Map k) async {
    final auth = context.read<AuthProvider>();
    final yeni = (k['aktif'] == 1 || k['aktif'] == true) ? 0 : 1;
    setState(() => k['aktif'] = yeni); // iyimser
    try {
      await Api.indirimToggle(auth.token!, (k['id'] as num).toInt());
    } catch (_) {
      if (mounted) setState(() => k['aktif'] = yeni == 1 ? 0 : 1);
    }
  }

  Future<void> _sil(Map k) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: _t.card,
        title: Text('Silinsin mi?', style: TextStyle(color: _t.ink)),
        content: Text('“${k['ad']}” indirimi silinecek.', style: TextStyle(color: _t.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil', style: TextStyle(color: Color(0xFFF43F5E)))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      await Api.indirimSil(auth.token!, (k['id'] as num).toInt());
      _yukle();
    } catch (_) {}
  }

  String _degerYazi(Map k) {
    final d = (k['deger'] as num?)?.toDouble() ?? 0;
    final ds = d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    return k['deger_tipi'] == 'yuzde' ? '%$ds' : '$ds ₺';
  }

  List<String> _kosullar(Map k) {
    final out = <String>[];
    if (k['kupon_kodu'] != null && '${k['kupon_kodu']}'.isNotEmpty) out.add('${k['kupon_kodu']}');
    if ((k['min_tutar'] as num?) != null && (k['min_tutar'] as num) > 0) out.add('min ${(k['min_tutar'] as num).toInt()}₺');
    if ((k['max_indirim'] as num?) != null && (k['max_indirim'] as num) > 0) out.add('tavan ${(k['max_indirim'] as num).toInt()}₺');
    if (k['saat_bas'] != null && k['saat_bit'] != null) out.add('${k['saat_bas']}–${k['saat_bit']}');
    if (k['gun_maskesi'] != null && '${k['gun_maskesi']}'.isNotEmpty) {
      const g = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
      out.add('${k['gun_maskesi']}'.split(',').where((s) => s.isNotEmpty).map((n) => g[int.tryParse(n) ?? 0]).join(', '));
    }
    if (k['tip'] == 'urun') {
      int n = 0;
      try { n = (jsonDecode('${k['urun_ids'] ?? '[]'}') as List).length; } catch (_) {}
      out.add('$n ürün');
    }
    if ((k['kullanim_limiti'] as num?) != null) out.add('kullanım ${(k['kullanim_sayisi'] ?? 0)}/${k['kullanim_limiti']}');
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0.5,
        title: Text('İndirimler', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.ink),
        actions: const [MenuHamburger()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _duzenle(),
        backgroundColor: const Color(0xFF4F46E5),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni İndirim', style: TextStyle(color: Colors.white)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                    child: Text(
                      'Her indirim türü ayrı bir kuraldır, tek tek açıp kapatabilirsin. Ödeme anında uygun olan en yüksek indirim otomatik uygulanır (kuponsa müşteri kodu girer). Online ödeme indirimi müşteriyi karta teşvik eder.',
                      style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (kurallar.isEmpty)
                    Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Henüz indirim yok. “Yeni İndirim” ile ekle.', style: TextStyle(color: t.sub)))),
                  for (final raw in kurallar) _kart(raw as Map, t),
                ],
              ),
            ),
    );
  }

  Widget _kart(Map k, TemaProvider t) {
    final meta = kTipler[k['tip']] ?? ['🏷️', '${k['tip']}', ''];
    final aktif = k['aktif'] == 1 || k['aktif'] == true;
    final kos = _kosullar(k);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: aktif ? const Color(0xFF22C55E).withOpacity(.55) : t.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(meta[0], style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(meta[1], style: TextStyle(color: t.sub2, fontSize: 11.5)),
            ]),
          ),
          Switch(value: aktif, activeColor: const Color(0xFF22C55E), onChanged: (_) => _toggle(k)),
        ]),
        const SizedBox(height: 4),
        Text(_degerYazi(k), style: const TextStyle(color: Color(0xFF7C6CF0), fontSize: 22, fontWeight: FontWeight.w800)),
        if (kos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in kos)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
                  child: Text(c, style: TextStyle(color: t.sub2, fontSize: 11.5)),
                ),
            ]),
          ),
        const SizedBox(height: 6),
        Row(children: [
          TextButton.icon(onPressed: () => _duzenle(k), icon: Icon(Icons.edit_outlined, size: 18, color: t.sub), label: Text('Düzenle', style: TextStyle(color: t.sub))),
          const Spacer(),
          IconButton(onPressed: () => _sil(k), icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 20)),
        ]),
      ]),
    );
  }
}

/// Yeni/düzenle formu (tam ekran).
class _IndirimForm extends StatefulWidget {
  final Map? kural;
  final List urunler;
  const _IndirimForm({this.kural, required this.urunler});
  @override
  State<_IndirimForm> createState() => _IndirimFormState();
}

class _IndirimFormState extends State<_IndirimForm> {
  late String tip;
  late String degerTipi;
  final adC = TextEditingController();
  final degerC = TextEditingController();
  final kuponC = TextEditingController();
  final minC = TextEditingController();
  final maxC = TextEditingController();
  final limitC = TextEditingController();
  String? saatBas, saatBit;
  final Set<int> gunler = {};
  final Set<int> urunIds = {};
  bool aktif = true;
  bool kaydediyor = false;
  String urunAra = '';

  TemaProvider get _t => context.watch<TemaProvider>();

  @override
  void initState() {
    super.initState();
    final k = widget.kural;
    tip = k?['tip'] ?? 'online_odeme';
    degerTipi = k?['deger_tipi'] ?? 'yuzde';
    adC.text = k?['ad']?.toString() ?? '';
    final d = (k?['deger'] as num?)?.toDouble();
    if (d != null) degerC.text = d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    kuponC.text = k?['kupon_kodu']?.toString() ?? '';
    if ((k?['min_tutar'] as num?) != null) minC.text = (k!['min_tutar'] as num).toString();
    if ((k?['max_indirim'] as num?) != null) maxC.text = (k!['max_indirim'] as num).toString();
    if ((k?['kullanim_limiti'] as num?) != null) limitC.text = (k!['kullanim_limiti'] as num).toInt().toString();
    saatBas = k?['saat_bas'];
    saatBit = k?['saat_bit'];
    if (k?['gun_maskesi'] != null) {
      for (final s in '${k!['gun_maskesi']}'.split(',')) { final n = int.tryParse(s.trim()); if (n != null) gunler.add(n); }
    }
    if (k?['urun_ids'] != null) {
      try { for (final x in (jsonDecode('${k!['urun_ids']}') as List)) urunIds.add((x as num).toInt()); } catch (_) {}
    }
    aktif = k == null ? true : (k['aktif'] == 1 || k['aktif'] == true);
  }

  @override
  void dispose() {
    for (final c in [adC, degerC, kuponC, minC, maxC, limitC]) c.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (degerC.text.trim().isEmpty) { _uyar('Bir indirim değeri gir'); return; }
    if (tip == 'kupon' && kuponC.text.trim().isEmpty) { _uyar('Kupon kodu gir'); return; }
    if (tip == 'urun' && urunIds.isEmpty) { _uyar('En az bir ürün seç'); return; }
    if (tip == 'happy_hour' && (saatBas == null || saatBit == null)) { _uyar('Saat aralığını gir'); return; }
    if (tip == 'gun' && gunler.isEmpty) { _uyar('En az bir gün seç'); return; }

    final auth = context.read<AuthProvider>();
    final data = <String, String>{
      'tip': tip,
      'ad': adC.text.trim().isEmpty ? (kTipler[tip]?[1] ?? 'İndirim') : adC.text.trim(),
      'deger_tipi': degerTipi,
      'deger': degerC.text.trim(),
      'aktif': aktif ? '1' : '0',
    };
    if (widget.kural != null) data['id'] = '${widget.kural!['id']}';
    if (kuponC.text.trim().isNotEmpty) data['kupon_kodu'] = kuponC.text.trim();
    if (minC.text.trim().isNotEmpty) data['min_tutar'] = minC.text.trim();
    if (maxC.text.trim().isNotEmpty) data['max_indirim'] = maxC.text.trim();
    if (limitC.text.trim().isNotEmpty) data['kullanim_limiti'] = limitC.text.trim();
    if (tip == 'happy_hour' && saatBas != null && saatBit != null) { data['saat_bas'] = saatBas!; data['saat_bit'] = saatBit!; }
    if (tip == 'gun' && gunler.isNotEmpty) data['gun_maskesi'] = (gunler.toList()..sort()).join(',');
    if (tip == 'urun' && urunIds.isNotEmpty) data['urun_ids'] = jsonEncode(urunIds.toList());

    setState(() => kaydediyor = true);
    try {
      final res = await Api.indirimKaydet(auth.token!, data);
      if (!mounted) return;
      if (res['ok'] == 1) { Navigator.pop(context, true); return; }
      _uyar(res['hata']?.toString() ?? 'Kaydedilemedi');
    } catch (_) {
      _uyar('Kaydedilemedi, tekrar dene');
    } finally {
      if (mounted) setState(() => kaydediyor = false);
    }
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _saatSec(bool bas) async {
    final s = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 14, minute: 0));
    if (s == null) return;
    final str = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
    setState(() { if (bas) saatBas = str; else saatBit = str; });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final meta = kTipler[tip]!;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0.5,
        iconTheme: IconThemeData(color: t.ink),
        title: Text(widget.kural == null ? 'Yeni İndirim' : 'İndirimi Düzenle', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
        _etiket(t, 'Tür'),
        Container(
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: tip,
              isExpanded: true,
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontSize: 15),
              items: [for (final e in kTipler.entries) DropdownMenuItem(value: e.key, child: Text('${e.value[0]}  ${e.value[1]}'))],
              onChanged: (v) => setState(() => tip = v ?? tip),
            ),
          ),
        ),
        Padding(padding: const EdgeInsets.only(top: 6), child: Text(meta[2], style: TextStyle(color: t.sub2, fontSize: 12))),

        _etiket(t, 'Ad'),
        _kutu(t, TextField(controller: adC, style: TextStyle(color: t.ink), decoration: _dec(t, kTipler[tip]![1]))),

        _etiket(t, 'İndirim'),
        Row(children: [
          _segment(t, 'yuzde', 'Yüzde %'),
          const SizedBox(width: 8),
          _segment(t, 'tutar', 'Tutar ₺'),
        ]),
        const SizedBox(height: 8),
        _kutu(t, TextField(controller: degerC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: t.ink), decoration: _dec(t, degerTipi == 'yuzde' ? 'Örn: 10' : 'Örn: 50'))),

        if (tip == 'kupon') ...[
          _etiket(t, 'Kupon Kodu'),
          _kutu(t, TextField(controller: kuponC, textCapitalization: TextCapitalization.characters, style: TextStyle(color: t.ink, letterSpacing: 1), decoration: _dec(t, 'HOSGELDIN'))),
        ],

        if (tip == 'happy_hour') ...[
          _etiket(t, 'Saat Aralığı'),
          Row(children: [
            Expanded(child: _saatBtn(t, saatBas ?? 'Başlangıç', () => _saatSec(true))),
            const SizedBox(width: 10),
            Expanded(child: _saatBtn(t, saatBit ?? 'Bitiş', () => _saatSec(false))),
          ]),
        ],

        if (tip == 'gun') ...[
          _etiket(t, 'Günler'),
          Row(children: [
            for (var i = 1; i <= 7; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => gunler.contains(i) ? gunler.remove(i) : gunler.add(i)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: gunler.contains(i) ? const Color(0xFF4F46E5) : t.card,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: gunler.contains(i) ? const Color(0xFF4F46E5) : t.line),
                      ),
                      child: Text(const ['', 'Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'][i], style: TextStyle(color: gunler.contains(i) ? Colors.white : t.sub2, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
          ]),
        ],

        if (tip == 'urun') ...[
          _etiket(t, 'İndirim uygulanacak ürünler (${urunIds.length} seçili)'),
          _kutu(t, TextField(onChanged: (v) => setState(() => urunAra = v), style: TextStyle(color: t.ink), decoration: _dec(t, 'Ürün ara…'))),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
            child: _urunListesi(t),
          ),
        ],

        _etiket(t, 'Koşullar (opsiyonel)'),
        Row(children: [
          Expanded(child: _kutu(t, TextField(controller: minC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _dec(t, 'Min. tutar ₺')))),
          const SizedBox(width: 10),
          Expanded(child: _kutu(t, TextField(controller: maxC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _dec(t, 'Maks. indirim ₺')))),
        ]),
        const SizedBox(height: 10),
        _kutu(t, TextField(controller: limitC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _dec(t, 'Toplam kullanım limiti (boş = sınırsız)'))),

        const SizedBox(height: 8),
        SwitchListTile(
          value: aktif,
          activeColor: const Color(0xFF22C55E),
          contentPadding: EdgeInsets.zero,
          title: Text('Aktif', style: TextStyle(color: t.ink, fontSize: 15)),
          subtitle: Text('Kapalıyken uygulanmaz', style: TextStyle(color: t.sub2, fontSize: 12)),
          onChanged: (v) => setState(() => aktif = v),
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: kaydediyor ? null : _kaydet,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: kaydediyor
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }

  Widget _urunListesi(TemaProvider t) {
    final q = urunAra.toLowerCase();
    final list = widget.urunler.where((u) => q.isEmpty || '${(u as Map)['ad']}'.toLowerCase().contains(q)).toList();
    if (list.isEmpty) return Padding(padding: const EdgeInsets.all(14), child: Text('Ürün bulunamadı.', style: TextStyle(color: t.sub)));
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        for (final u in list)
          CheckboxListTile(
            dense: true,
            activeColor: const Color(0xFF4F46E5),
            controlAffinity: ListTileControlAffinity.leading,
            value: urunIds.contains(((u as Map)['id'] as num).toInt()),
            title: Text('${u['ad']}', style: TextStyle(color: t.ink, fontSize: 14)),
            onChanged: (_) => setState(() {
              final id = (u['id'] as num).toInt();
              urunIds.contains(id) ? urunIds.remove(id) : urunIds.add(id);
            }),
          ),
      ],
    );
  }

  Widget _etiket(TemaProvider t, String s) => Padding(padding: const EdgeInsets.fromLTRB(2, 16, 0, 6), child: Text(s, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)));

  Widget _kutu(TemaProvider t, Widget child) => Container(
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: child,
      );

  InputDecoration _dec(TemaProvider t, String hint) => InputDecoration(border: InputBorder.none, hintText: hint, hintStyle: TextStyle(color: t.sub2));

  Widget _segment(TemaProvider t, String v, String label) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => degerTipi = v),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: degerTipi == v ? const Color(0xFF4F46E5) : t.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: degerTipi == v ? const Color(0xFF4F46E5) : t.line),
            ),
            child: Text(label, style: TextStyle(color: degerTipi == v ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ),
      );

  Widget _saatBtn(TemaProvider t, String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Text(label, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      );
}
