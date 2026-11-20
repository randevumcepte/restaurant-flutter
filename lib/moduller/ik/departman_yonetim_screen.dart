import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// /departman-yonetim — Departman & Yetki (web departman_yonetim.blade.php ile aynı):
/// gruplu departman kartları, yeni/düzenle (hazır şablon, ad, kod, renk, ikon, grup, ünvanlar, AI erişimi,
/// üye sayfaları, sorumluya ek sayfalar, menü kategorisi eşlemesi, aktif), sil, hazır departmanları kur,
/// mutfak departmanlarını kur, bağlantılar.
class IkDepartmanYonetimScreen extends StatefulWidget {
  const IkDepartmanYonetimScreen({super.key});
  @override
  State<IkDepartmanYonetimScreen> createState() => _IkDepartmanYonetimScreenState();
}

/// Web ikon seçicisindeki ikonlar (aynı sıra)
const Map<String, IconData> kDepIkonlar = {
  'inventory_2': Icons.inventory_2_outlined, 'shopping_cart': Icons.shopping_cart_outlined, 'local_shipping': Icons.local_shipping_outlined,
  'warehouse': Icons.warehouse_outlined, 'receipt_long': Icons.receipt_long_outlined, 'fact_check': Icons.fact_check_outlined, 'inventory': Icons.inventory_outlined,
  'restaurant': Icons.restaurant, 'soup_kitchen': Icons.soup_kitchen_outlined, 'kitchen': Icons.kitchen_outlined, 'outdoor_grill': Icons.outdoor_grill_outlined,
  'set_meal': Icons.set_meal_outlined, 'bakery_dining': Icons.bakery_dining_outlined, 'lunch_dining': Icons.lunch_dining_outlined, 'dinner_dining': Icons.dinner_dining_outlined,
  'icecream': Icons.icecream_outlined, 'blender': Icons.blender_outlined, 'ac_unit': Icons.ac_unit, 'local_bar': Icons.local_bar_outlined, 'liquor': Icons.liquor_outlined,
  'local_cafe': Icons.local_cafe_outlined, 'emoji_food_beverage': Icons.emoji_food_beverage_outlined, 'room_service': Icons.room_service_outlined,
  'table_restaurant': Icons.table_restaurant_outlined, 'restaurant_menu': Icons.restaurant_menu, 'point_of_sale': Icons.point_of_sale, 'payments': Icons.payments_outlined,
  'account_balance': Icons.account_balance_outlined, 'request_quote': Icons.request_quote_outlined, 'account_balance_wallet': Icons.account_balance_wallet_outlined,
  'groups': Icons.groups_outlined, 'badge': Icons.badge_outlined, 'person': Icons.person_outline, 'support_agent': Icons.support_agent, 'handshake': Icons.handshake_outlined,
  'campaign': Icons.campaign_outlined, 'verified': Icons.verified_outlined, 'cleaning_services': Icons.cleaning_services_outlined, 'security': Icons.security_outlined,
  'engineering': Icons.engineering_outlined, 'build': Icons.build_outlined, 'plumbing': Icons.plumbing, 'computer': Icons.computer, 'wifi': Icons.wifi,
  'delivery_dining': Icons.delivery_dining_outlined, 'two_wheeler': Icons.two_wheeler, 'store': Icons.store_outlined, 'apartment': Icons.apartment,
  'menu_book': Icons.menu_book_outlined, 'local_dining': Icons.local_dining_outlined, 'egg': Icons.egg_outlined, 'spa': Icons.spa_outlined,
  'health_and_safety': Icons.health_and_safety_outlined, 'admin_panel_settings': Icons.admin_panel_settings_outlined, 'manage_accounts': Icons.manage_accounts_outlined,
};
IconData depIkon(dynamic ad) => kDepIkonlar['$ad'] ?? ikonAdi('$ad', Icons.badge_outlined);

const _renkPalet = ['#7C3AED', '#4F46E5', '#2563EB', '#0EA5E9', '#06B6D4', '#0D9488', '#10B981', '#84CC16', '#F59E0B', '#F97316', '#EF4444', '#EC4899', '#8B5CF6', '#475569'];

List<String> _jsonListe(dynamic v) {
  if (v is List) return v.map((e) => '$e').toList();
  final s = metinOku(v);
  if (s.isEmpty) return [];
  try {
    final d = jsonDecode(s);
    if (d is List) return d.map((e) => '$e').toList();
    if (d is Map) return [for (final e in d.entries) if (e.value == true || e.value == 1) '${e.key}'];
  } catch (_) {}
  return [];
}

class _IkDepartmanYonetimScreenState extends State<IkDepartmanYonetimScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _ara = '';

  Future<void> _yenile() async => _k.currentState?.yukle();

  Future<void> _formAc(Map<String, dynamic> v, Map<String, dynamic>? d) async {
    final r = await kAltSayfa<bool>(context, baslik: d == null ? 'Yeni Departman' : 'Düzenle — ${metinOku(d['ad'])}', icerik: (c) => _DepartmanForm(veri: v, d: d));
    if (r == true) _yenile();
  }

  Future<void> _sil(Map<String, dynamic> d) async {
    if (!await kOnay(context, '${metinOku(d['ad'])} departmanı silinsin mi?',
        evet: 'Evet, sil', tehlikeli: true, aciklama: 'Bağlı personelin erişimi mevcut yetkileriyle devam eder. Bu işlemi yalnız işletme sahibi yapabilir.')) {
      return;
    }
    if (!mounted) return;
    if (await kopruGonder(context, '/departman-sil', {'id': d['id']}, basariMesaji: 'Departman silindi.')) _yenile();
  }

  Future<void> _sablonKur() async {
    if (!await kOnay(context, 'Hazır departmanlar oluşturulsun mu?', evet: 'Oluştur', aciklama: 'Mutfak, Servis, Bar, Kasa, Satın Alma… gibi hazır departmanlar sayfa yetkileri ve ünvanlarıyla kurulur. Var olanlar atlanır.')) return;
    if (!mounted) return;
    if (await kopruGonder(context, '/departman-sablon-kur', {})) _yenile();
  }

  Future<void> _mutfakKur() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/mutfak-altdep-kur');
      if (!mounted) return;
      kToast(context, c.ok ? (c.mesaj ?? 'Mutfak departmanları kuruldu.') : (c.hata ?? 'Kurulamadı.'), hata: !c.ok);
      if (c.ok) _yenile();
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/departman-yonetim',
      baslik: 'Departman & Yetki',
      ikon: Icons.groups_outlined,
      fab: (ctx, v, y) => v['duzenleyebilir'] == true
          ? FloatingActionButton.extended(
              heroTag: 'ik_dep_ekle',
              onPressed: () => _formAc(v, null),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Departman', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
      govde: (ctx, v, y) => _govde(ctx, v),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v) {
    final t = context.watch<TemaProvider>();
    final duz = v['duzenleyebilir'] == true;
    final deps = liste(v['departmanlar']);
    final kategoriler = liste(v['kategoriler']);
    final mutfakVar = deps.any((d) => d['kod'] == 'mutfak' && tamOku(d['aktif'] ?? 1) == 1);
    final suz = deps.where((d) => _ara.isEmpty || '${metinOku(d['ad'])} ${metinOku(d['grup'])} ${metinOku(d['kod'])}'.toLowerCase().contains(_ara)).toList();
    final gruplu = <String, List<Map<String, dynamic>>>{};
    for (final d in suz) {
      gruplu.putIfAbsent(metinOku(d['grup'], 'Diğer'), () => []).add(d);
    }
    final aktif = deps.where((d) => tamOku(d['aktif']) == 1).length;

    return KGovde(yenile: _yenile, children: [
      KKart(
        renk: t.mor1,
        child: Text(
            'Departman = sayfa yetkilerinin yeniden kullanılabilir şablonu. Personel ekranında bir kişiye departman atayınca o departmanın sayfaları otomatik açılır. '
            'İki departman aynı sayfayı paylaşabilir (örn. Stok hem Mutfak hem Satın Alma\'da).',
            style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
      ),
      KKpiIzgara([
        KKpi(etiket: 'Departman', deger: '${deps.length}', alt: '$aktif aktif', ikon: Icons.groups_outlined, renk: t.mor1),
        KKpi(etiket: 'Grup', deger: '${deps.map((d) => metinOku(d['grup'], 'Diğer')).toSet().length}', ikon: Icons.account_tree_outlined, renk: t.mavi),
        KKpi(etiket: 'AI açık', deger: '${deps.where((d) => d['ai_erisim'] == 'tam' || d['ai_erisim'] == 'kisitli').length}', ikon: Icons.smart_toy_outlined, renk: t.yesil),
      ]),
      if (duz)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Personel yetkileri', ikon: Icons.badge_outlined, ikincil: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/personel', 'Personel & Maaş')))),
            if (!mutfakVar) KButon('Mutfak departmanlarını kur', ikon: Icons.soup_kitchen_outlined, ikincil: true, renk: t.amber, onTap: _mutfakKur),
            if (deps.isEmpty) KButon('Hazır departmanları oluştur', ikon: Icons.auto_awesome_outlined, ikincil: true, renk: t.yesil, onTap: _sablonKur),
          ]),
        ),
      if (deps.length > 6) KAra(ipucu: 'Departman ara…', onDegis: (s) => setState(() => _ara = s.toLowerCase().trim())),
      if (deps.isEmpty)
        KBos(
          ikon: Icons.groups_outlined,
          baslik: 'Henüz departman yok',
          aciklama: duz
              ? '"Hazır departmanları oluştur" ile tek dokunuşta başlayabilir ya da "Yeni Departman" ile elle ekleyebilirsiniz.'
              : 'Departmanları işletme sahibi ya da müdür oluşturur.',
        ),
      for (final g in gruplu.entries) ...[
        KBaslik(g.key, ikon: Icons.folder_outlined, renk: t.mavi, sag: KRozet('${g.value.length}', renk: t.sub2)),
        LayoutBuilder(builder: (ctx, c) {
          final n = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 620 ? 2 : 1);
          final w = (c.maxWidth - (n - 1) * 12) / n;
          return Wrap(spacing: 12, children: [
            for (final d in g.value) SizedBox(width: w, child: _kart(t, d, v, duz, kategoriler)),
          ]);
        }),
      ],
    ]);
  }

  Widget _kart(TemaProvider t, Map<String, dynamic> d, Map<String, dynamic> v, bool duz, List<Map<String, dynamic>> kategoriler) {
    final renk = renkOku(d['renk'], t.mavi);
    final sayfa = _jsonListe(d['sayfa_yetki']);
    final unvan = _jsonListe(d['unvanlar']);
    final ai = metinOku(d['ai_erisim'], 'kapali');
    final aiR = {'tam': t.yesil, 'kisitli': t.amber}[ai] ?? t.sub;
    final aiE = {'tam': 'AI: Tam', 'kisitli': 'AI: Kısıtlı'}[ai] ?? 'AI: Kapalı';
    final katSay = kategoriler.where((k) => tamOku(k['departman_id']) == tamOku(d['id'])).length;
    return KKart(
      renk: renk,
      onTap: duz ? () => _formAc(v, d) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          KIkon(depIkon(d['ikon']), renk: renk),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(d['ad']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(unvan.isNotEmpty ? '↑ ${unvan.first}' : metinOku(d['kod']), style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
          if (tamOku(d['aktif']) != 1) KRozet('Pasif', renk: t.kirmizi),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 4, children: [
          KRozet(aiE, renk: aiR, ikon: Icons.smart_toy_outlined),
          KRozet('${sayfa.length} sayfa', renk: t.sub2),
          if (unvan.isNotEmpty) KRozet('${unvan.length} ünvan', renk: t.sub2),
          if (katSay > 0) KRozet('$katSay kategori', renk: t.yesil),
        ]),
        if (duz) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _formAc(v, d))),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Bağlantılar (Gmail/Outlook/SMTP/WhatsApp)',
              icon: Icon(Icons.hub_outlined, color: t.mor1),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/departman-baglanti?dep=${d['id']}', '${metinOku(d['ad'])} — Bağlantılar'))),
            ),
            IconButton(tooltip: 'Sil', icon: Icon(Icons.delete_outline, color: t.kirmizi), onPressed: () => _sil(d)),
          ]),
        ],
      ]),
    );
  }
}

// ═════════════════════════════ FORM ═════════════════════════════
class _DepartmanForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Map<String, dynamic>? d;
  const _DepartmanForm({required this.veri, this.d});
  @override
  State<_DepartmanForm> createState() => _DepartmanFormState();
}

class _DepartmanFormState extends State<_DepartmanForm> {
  final _ad = TextEditingController();
  final _kod = TextEditingController();
  final _grup = TextEditingController();
  final _unvan = TextEditingController();
  final _aiLimit = TextEditingController();
  String _renk = '#4F46E5';
  String _ikon = 'inventory_2';
  String _ai = 'kapali';
  bool _aktif = true;
  String _sablon = '';
  final Set<String> _sayfa = {};
  final Set<String> _ek = {};
  final Set<int> _kat = {};
  bool _kaydediliyor = false;

  Map<String, dynamic> get _sablonlar => harita(widget.veri['sablonlar']);
  Map<String, dynamic> get _sayfaKategori => harita(widget.veri['sayfaKategori']);
  List<Map<String, dynamic>> get _kategoriler => liste(widget.veri['kategoriler']);

  @override
  void initState() {
    super.initState();
    final d = widget.d;
    if (d != null) {
      _ad.text = metinOku(d['ad']);
      _kod.text = metinOku(d['kod']);
      _grup.text = metinOku(d['grup']);
      _renk = metinOku(d['renk'], '#4F46E5');
      _ikon = metinOku(d['ikon'], 'inventory_2');
      _ai = metinOku(d['ai_erisim'], 'kapali');
      _aiLimit.text = '${tamOku(d['ai_gunluk_limit'])}';
      _aktif = tamOku(d['aktif']) == 1;
      _unvan.text = _jsonListe(d['unvanlar']).join('\n');
      _sayfa.addAll(_jsonListe(d['sayfa_yetki']));
      _ek.addAll(_jsonListe(d['sorumlu_ek']));
      for (final k in _kategoriler) {
        if (tamOku(k['departman_id']) == tamOku(d['id'])) _kat.add(tamOku(k['id']));
      }
      if (_sablonlar.containsKey(_kod.text)) _sablon = _kod.text;
    } else {
      _aiLimit.text = '30';
    }
  }

  @override
  void dispose() {
    for (final c in [_ad, _kod, _grup, _unvan, _aiLimit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _sablonUygula(String kod) {
    setState(() {
      _sablon = kod;
      if (kod.isEmpty) return;
      if (kod == '__yeni') {
        _ad.clear();
        _kod.clear();
        _grup.clear();
        return;
      }
      final s = harita(_sablonlar[kod]);
      _ad.text = metinOku(s['ad']);
      _kod.text = kod;
      if (metinOku(s['renk']).isNotEmpty) _renk = metinOku(s['renk']);
      _ikon = metinOku(s['ikon'], 'inventory_2');
      _grup.text = metinOku(s['grup']);
      _unvan.text = dizi(s['unvan']).map((e) => '$e').join('\n');
      _ai = metinOku(s['ai'], 'kapali');
      _aiLimit.text = _ai == 'kisitli' ? '30' : '0';
      _sayfa
        ..clear()
        ..addAll(dizi(s['sayfa']).map((e) => '$e'));
      _ek
        ..clear()
        ..addAll(dizi(s['sorumlu_ek']).map((e) => '$e'));
    });
  }

  Future<void> _kaydet() async {
    if (_ad.text.trim().isEmpty) return kToast(context, 'Departman adı boş olamaz.', hata: true);
    setState(() => _kaydediliyor = true);
    final g = <String, dynamic>{
      if (widget.d != null) 'id': widget.d!['id'],
      'ad': _ad.text.trim(),
      'kod': _kod.text.trim(),
      'grup': _grup.text.trim(),
      'renk': _renk,
      'ikon': _ikon,
      'unvanlar': _unvan.text,
      'ai_erisim': _ai,
      'ai_gunluk_limit': '${tamOku(_aiLimit.text)}',
      'aktif': _aktif ? '1' : '0',
    };
    for (final k in _sayfa) {
      g['sayfa_$k'] = '1';
    }
    for (final k in _ek) {
      g['sorumlu_$k'] = '1';
    }
    for (final k in _kat) {
      g['kat_$k'] = '1';
    }
    final ok = await kopruGonder(context, '/departman-kaydet', g);
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final gruplar = <String>{
      for (final s in _sablonlar.values) metinOku(harita(s)['grup']),
      for (final d in liste(widget.veri['departmanlar'])) metinOku(d['grup']),
    }..remove('');
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KSecim<String>('Hazır departman seç — ikon, grup, ünvan, yetkiler otomatik dolar',
          deger: _sablon,
          secenekler: [
            ('', '— Hazır departman seç —'),
            for (final e in _sablonlar.entries) (e.key, '${metinOku(harita(e.value)['ad'])} · ${metinOku(harita(e.value)['grup'])}'),
            ('__yeni', '➕ Diğer / Yeni departman (elle gir)'),
          ],
          onSec: (v) => _sablonUygula(v ?? '')),
      KAlan('Departman Adı', _ad, zorunlu: true, ipucu: 'örn. Satın Alma'),
      KAlan('Kısa Kod', _kod, ipucu: 'satinalma'),
      // Grup
      Text('Üst Grup (ağaç)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final g in gruplar)
          ChoiceChip(
            label: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _grup.text == g ? Colors.white : t.sub2)),
            selected: _grup.text == g,
            selectedColor: t.mavi,
            backgroundColor: t.card2,
            showCheckmark: false,
            onSelected: (_) => setState(() => _grup.text = g),
          ),
      ]),
      const SizedBox(height: 8),
      KAlan('Grup adı (listede yoksa yazın)', _grup, ipucu: 'örn. Mutfak (BOH)'),
      // Renk
      Text('Renk', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in {..._renkPalet, _renk.toUpperCase()})
          InkWell(
            onTap: () => setState(() => _renk = r),
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: renkOku(r),
                shape: BoxShape.circle,
                border: Border.all(color: _renk.toUpperCase() == r.toUpperCase() ? t.ink : Colors.transparent, width: 3),
              ),
              child: _renk.toUpperCase() == r.toUpperCase() ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
            ),
          ),
      ]),
      const SizedBox(height: 14),
      // İkon
      Text('İkon — dokunup seçin', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
        child: Wrap(spacing: 4, runSpacing: 4, children: [
          for (final e in {...kDepIkonlar.keys, _ikon})
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _ikon = e),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _ikon == e ? renkOku(_renk).withValues(alpha: .18) : t.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _ikon == e ? renkOku(_renk) : Colors.transparent, width: 1.6),
                ),
                child: Icon(depIkon(e), size: 22, color: _ikon == e ? renkOku(_renk) : t.sub2),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      KAlan('Ünvanlar (en üst SORUMLU en başta; her satıra bir ünvan)', _unvan, satir: 4, ipucu: 'Mutfak Şefi\nSous Chef\nAşçı\nKomi'),
      // AI
      KSecim<String>('AI Erişimi',
          deger: _ai,
          secenekler: const [('kapali', 'Kapalı — bu departman AI kullanamaz'), ('kisitli', 'Kısıtlı — günlük soru sınırı'), ('tam', 'Tam — sınırsız (üst yönetim)')],
          onSec: (v) => setState(() => _ai = v ?? 'kapali')),
      if (_ai == 'kisitli') KAlan('Kişi başı günlük soru tavanı', _aiLimit, klavye: TextInputType.number),
      // Sayfalar
      _sayfaBolum(t, 'Görebileceği Sayfalar', Icons.visibility_outlined, t.mavi, _sayfa, null),
      _sayfaBolum(t, 'Sorumlu\'ya (en üst kademe) Ek Sayfalar', Icons.workspace_premium_outlined, t.amber, _ek,
          'Bu departmanın sorumlusu, üyelere ek olarak bu sayfaları da görür (örn. Raporlar, Puantaj).'),
      if (_kategoriler.isNotEmpty) ...[
        const SizedBox(height: 6),
        KBaslik('Menü Kategorileri (istasyon ayrımı)', ikon: Icons.restaurant_menu, renk: t.yesil,
            alt: 'Bu departmanın hazırladığı kategorileri seçin (örn. Pastane → Tatlılar).'),
        Container(
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            for (final k in _kategoriler)
              CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                value: _kat.contains(tamOku(k['id'])),
                activeColor: t.yesil,
                onChanged: (v) => setState(() => v == true ? _kat.add(tamOku(k['id'])) : _kat.remove(tamOku(k['id']))),
                title: Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontSize: 14)),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _aktif,
        activeThumbColor: t.yesil,
        onChanged: (v) => setState(() => _aktif = v),
        title: Text('Aktif', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 6),
      KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediliyor, onTap: _kaydet),
    ]);
  }

  Widget _sayfaBolum(TemaProvider t, String baslik, IconData ikon, Color renk, Set<String> secili, String? alt) {
    final tum = [for (final g in _sayfaKategori.values) ...harita(g).keys];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      KBaslik(baslik,
          ikon: ikon,
          renk: renk,
          alt: alt ?? '${secili.length} / ${tum.length} açık',
          sag: TextButton(
            onPressed: () => setState(() => secili.length == tum.length ? secili.clear() : secili.addAll(tum)),
            child: Text(secili.length == tum.length ? 'Hepsini kapat' : 'Hepsini aç', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          )),
      for (final e in _sayfaKategori.entries)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: genisMi(context),
              title: Text(e.key, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text('${harita(e.value).keys.where(secili.contains).length} / ${harita(e.value).length}', style: TextStyle(color: t.sub, fontSize: 12.5)),
              children: [
                for (final s in harita(e.value).entries)
                  CheckboxListTile(
                    controlAffinity: ListTileControlAffinity.leading,
                    value: secili.contains(s.key),
                    activeColor: renk,
                    onChanged: (v) => setState(() => v == true ? secili.add(s.key) : secili.remove(s.key)),
                    title: Text(metinOku(s.value, s.key), style: TextStyle(color: t.ink, fontSize: 13.5)),
                  ),
              ],
            ),
          ),
        ),
    ]);
  }
}
