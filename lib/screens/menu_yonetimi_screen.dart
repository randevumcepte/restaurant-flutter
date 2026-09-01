import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';

/// Menü Yönetimi — kategori bazlı: yeni yemek ekle, tüm detayları düzenle, fotoğraf yükle.
/// Sadece Sahip/Müdür (backend ayrıca doğrular).
class MenuYonetimiScreen extends StatefulWidget {
  const MenuYonetimiScreen({super.key});

  @override
  State<MenuYonetimiScreen> createState() => _MenuYonetimiScreenState();
}

class _MenuYonetimiScreenState extends State<MenuYonetimiScreen> {
  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _kirmizi = Color(0xFFF43F5E);
  final _f = NumberFormat.decimalPattern('tr');

  bool loading = true;
  String? hata;
  List<Map<String, dynamic>> kategoriler = [];
  List<Map<String, dynamic>> urunler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() { loading = true; hata = null; });
    try {
      final res = await Api.menuYonetim(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          kategoriler = ((res['kategoriler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          urunler = ((res['urunler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
        });
      } else {
        setState(() { hata = res['hata']?.toString() ?? 'Alınamadı'; loading = false; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  String _tl(dynamic v) => '${_f.format((v is num ? v : num.tryParse('$v') ?? 0).round())} TL';

  List<Map<String, dynamic>> _katUrunleri(int katId) =>
      urunler.where((u) => (u['kategori_id'] ?? 0) == katId).toList()
        ..sort((a, b) => '${a['ad']}'.compareTo('${b['ad']}'));

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final kategorisiz = urunler.where((u) => (u['kategori_id'] ?? 0) == 0).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        title: const Text('Menü Yönetimi', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () => _kategoriDuzenle(null),
            icon: const Icon(Icons.create_new_folder_outlined, color: Color(0xFFC4B5FD), size: 19),
            label: const Text('Kategori', style: TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _mor1,
        onPressed: () => _urunDuzenle(null),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Yeni Ürün', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : hata != null
              ? _hataGorunum()
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: _mor1,
                  backgroundColor: _card,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                    children: [
                      for (final k in kategoriler) _kategoriBolum(k, _katUrunleri(k['id'] as int)),
                      if (kategorisiz.isNotEmpty) _kategoriBolum(null, kategorisiz..sort((a, b) => '${a['ad']}'.compareTo('${b['ad']}'))),
                      if (kategoriler.isEmpty && urunler.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 60),
                          child: Column(children: const [
                            Icon(Icons.restaurant_menu, color: Color(0xFF334155), size: 54),
                            SizedBox(height: 12),
                            Text('Henüz menü yok.\nÖnce kategori, sonra ürün ekleyin.',
                                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
                          ]),
                        ),
                    ],
                  ),
                ),
    );
  }

  // ================== MASAÜSTÜ (gece/gündüz temalı) ==================
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kategorisiz = urunler.where((u) => (u['kategori_id'] ?? 0) == 0).toList()
      ..sort((a, b) => '${a['ad']}'.compareTo('${b['ad']}'));
    final bosMu = kategoriler.isEmpty && urunler.isEmpty;
    return MasaustuSayfa(
      baslik: 'Menü Yönetimi',
      ikon: Icons.restaurant_menu,
      altBaslik: loading || hata != null ? null : '${urunler.length} ürün · ${kategoriler.length} kategori',
      araclar: [
        MButon('Kategori', t.mavi, () => _kategoriDuzenle(null), dolu: false, ikon: Icons.create_new_folder_outlined),
        const SizedBox(width: 10),
        MButon('Yeni Ürün', t.mor1, () => _urunDuzenle(null), ikon: Icons.add),
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : hata != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.wifi_off, color: t.sub, size: 46),
                    const SizedBox(height: 10),
                    Text(hata ?? '', style: TextStyle(color: t.sub, fontSize: 14)),
                    const SizedBox(height: 14),
                    MButon('Tekrar dene', t.mor1, _yukle, ikon: Icons.refresh),
                  ]),
                )
              : bosMu
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.restaurant_menu, color: t.sub, size: 54),
                        const SizedBox(height: 12),
                        Text('Henüz menü yok.\nÖnce kategori, sonra ürün ekleyin.',
                            textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 14)),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _yukle,
                      color: t.mor1,
                      backgroundColor: t.card,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        children: [
                          for (final k in kategoriler)
                            ..._masaustuBolum(t, k, _katUrunleri(k['id'] as int)),
                          if (kategorisiz.isNotEmpty) ..._masaustuBolum(t, null, kategorisiz),
                        ],
                      ),
                    ),
    );
  }

  List<Widget> _masaustuBolum(TemaProvider t, Map<String, dynamic>? kat, List<Map<String, dynamic>> list) {
    final baslik = kat?['ad']?.toString() ?? 'Kategorisiz';
    return [
      MBolumBaslik(
        baslik,
        renk: t.mor1,
        sayi: list.length,
        sag: kat != null
            ? MButon('Düzenle', t.mavi, () => _kategoriDuzenle(kat), dolu: false, ikon: Icons.edit_outlined)
            : null,
      ),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Bu kategoride ürün yok', style: TextStyle(color: t.sub, fontSize: 13)),
        )
      else
        GridView.count(
          crossAxisCount: 4,
          childAspectRatio: 0.86,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final u in list) _masaustuUrunKart(t, u)],
        ),
      const SizedBox(height: 18),
    ];
  }

  Widget _masaustuUrunKart(TemaProvider t, Map<String, dynamic> u) {
    final gorsel = u['gorsel']?.toString();
    final tukendi = u['tukendi'] == true;
    final pasif = u['aktif'] == false;
    return MKart(
      padding: EdgeInsets.zero,
      onTap: () => _urunDuzenle(u),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: gorsel != null
                ? Image.network(gorsel, fit: BoxFit.cover, errorBuilder: (_, _, _) => _masaustuFotoYer(t))
                : _masaustuFotoYer(t),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${u['ad']}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
              if (('${u['aciklama'] ?? ''}').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('${u['aciklama']}',
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: t.sub, fontSize: 11.5)),
              ],
              const Spacer(),
              Row(children: [
                Expanded(
                  child: Text(_tl(u['fiyat']),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: t.gold, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                if (tukendi) MRozet('Tükendi', t.kirmizi),
                if (pasif) ...[if (tukendi) const SizedBox(width: 5), MRozet('Pasif', t.sub)],
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _masaustuFotoYer(TemaProvider t) => Container(
        color: t.card2,
        child: Icon(Icons.image_outlined, color: t.sub, size: 30),
      );

  Widget _hataGorunum() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off, color: Color(0xFF64748B), size: 44),
          const SizedBox(height: 10),
          Text(hata ?? '', style: const TextStyle(color: Color(0xFF94A3B8))),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: _yukle, style: ElevatedButton.styleFrom(backgroundColor: _mor1), child: const Text('Tekrar dene')),
        ]),
      );

  Widget _kategoriBolum(Map<String, dynamic>? kat, List<Map<String, dynamic>> list) {
    final baslik = kat?['ad']?.toString() ?? 'Kategorisiz';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Row(children: [
            Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(20)),
              child: Text('${list.length}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            if (kat != null)
              IconButton(
                onPressed: () => _kategoriDuzenle(kat),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF64748B), size: 19),
                visualDensity: VisualDensity.compact,
              ),
          ]),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text('Bu kategoride ürün yok', style: TextStyle(color: const Color(0xFF64748B), fontSize: 12.5)),
          ),
        for (final u in list) _urunKart(u),
      ],
    );
  }

  Widget _urunKart(Map<String, dynamic> u) {
    final gorsel = u['gorsel']?.toString();
    final tukendi = u['tukendi'] == true;
    final pasif = u['aktif'] == false;
    return GestureDetector(
      onTap: () => _urunDuzenle(u),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF232B42))),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 58, height: 58,
              child: gorsel != null
                  ? Image.network(gorsel, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fotoYer())
                  : _fotoYer(),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${u['ad']}', style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold))),
                if (tukendi) _rozet('Tükendi', _kirmizi),
                if (pasif) _rozet('Pasif', const Color(0xFF64748B)),
              ]),
              if (('${u['aciklama'] ?? ''}').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('${u['aciklama']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF8698B5), fontSize: 11.5)),
                ),
              const SizedBox(height: 3),
              Text(_tl(u['fiyat']), style: const TextStyle(color: Color(0xFFFDE9B5), fontSize: 13.5, fontWeight: FontWeight.bold)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF475569)),
        ]),
      ),
    );
  }

  Widget _rozet(String t, Color c) => Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
      );

  Widget _fotoYer() => Container(
        color: const Color(0xFF0E1428),
        child: const Icon(Icons.image_outlined, color: Color(0xFF334155), size: 24),
      );

  // ---- Kategori ekle/düzenle ----
  Future<void> _kategoriDuzenle(Map<String, dynamic>? kat) async {
    final adCtrl = TextEditingController(text: kat?['ad']?.toString() ?? '');
    final siraCtrl = TextEditingController(text: '${kat?['sira'] ?? kategoriler.length}');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(kat == null ? 'Yeni Kategori' : 'Kategori Düzenle', style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _alan(adCtrl, 'Kategori adı', TextInputType.text),
          const SizedBox(height: 10),
          _alan(siraCtrl, 'Sıra (küçük önce)', TextInputType.number),
        ]),
        actions: [
          if (kat != null)
            TextButton(onPressed: () => Navigator.pop(ctx, 'sil'), child: const Text('Sil', style: TextStyle(color: _kirmizi))),
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, 'kaydet'), style: ElevatedButton.styleFrom(backgroundColor: _mor1), child: const Text('Kaydet')),
        ],
      ),
    );
    if (res == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      if (res == 'sil') {
        final r = await Api.kategoriSil(auth.token!, kat!['id'] as int);
        _sonuc(r, 'Kategori silindi');
      } else {
        if (adCtrl.text.trim().isEmpty) { _uyar('Kategori adı gerekli'); return; }
        final r = await Api.kategoriKaydet(auth.token!, id: kat?['id'] as int?, ad: adCtrl.text.trim(), sira: int.tryParse(siraCtrl.text) ?? 0);
        _sonuc(r, 'Kategori kaydedildi');
      }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  // ---- Ürün ekle/düzenle (tam sayfa) ----
  Future<void> _urunDuzenle(Map<String, dynamic>? urun) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => _UrunDuzenleSayfa(urun: urun, kategoriler: kategoriler),
    ));
    if (degisti == true) _yukle();
  }

  void _sonuc(Map<String, dynamic> r, String basari) {
    if (r['ok'] == 1) { _yukle(); _uyar(basari); }
    else { _uyar(r['hata']?.toString() ?? 'İşlem başarısız'); }
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: _card));
  }

  Widget _alan(TextEditingController c, String etiket, TextInputType tip, {int maxLines = 1}) {
    return TextField(
      controller: c,
      keyboardType: tip,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiket,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFF0E1428),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2D3752))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mor1)),
      ),
    );
  }
}

/// Ürün ekleme/düzenleme tam sayfa (foto yükleme dahil).
class _UrunDuzenleSayfa extends StatefulWidget {
  final Map<String, dynamic>? urun;
  final List<Map<String, dynamic>> kategoriler;
  const _UrunDuzenleSayfa({required this.urun, required this.kategoriler});

  @override
  State<_UrunDuzenleSayfa> createState() => _UrunDuzenleSayfaState();
}

class _UrunDuzenleSayfaState extends State<_UrunDuzenleSayfa> {
  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);

  late TextEditingController adCtrl;
  late TextEditingController fiyatCtrl;
  late TextEditingController aciklamaCtrl;
  int kategoriId = 0;
  bool tukendi = false;
  bool aktif = true;
  int? urunId;
  String? gorsel;
  bool kaydediyor = false;
  bool fotoYukleniyor = false;

  bool get yeni => urunId == null;

  @override
  void initState() {
    super.initState();
    final u = widget.urun;
    urunId = u?['id'] as int?;
    adCtrl = TextEditingController(text: u?['ad']?.toString() ?? '');
    fiyatCtrl = TextEditingController(text: u != null ? '${(u['fiyat'] is num ? u['fiyat'] : num.tryParse('${u['fiyat']}') ?? 0)}' : '');
    aciklamaCtrl = TextEditingController(text: u?['aciklama']?.toString() ?? '');
    kategoriId = (u?['kategori_id'] ?? 0) as int;
    tukendi = u?['tukendi'] == true;
    aktif = u == null ? true : u['aktif'] != false;
    gorsel = u?['gorsel']?.toString();
  }

  @override
  void dispose() {
    adCtrl.dispose(); fiyatCtrl.dispose(); aciklamaCtrl.dispose();
    super.dispose();
  }

  Future<bool> _kaydet({bool kapat = true}) async {
    if (adCtrl.text.trim().isEmpty) { _uyar('Ürün adı gerekli'); return false; }
    final fiyat = double.tryParse(fiyatCtrl.text.replaceAll(',', '.')) ?? 0;
    setState(() => kaydediyor = true);
    try {
      final auth = context.read<AuthProvider>();
      final r = await Api.urunKaydet(auth.token!,
          id: urunId, ad: adCtrl.text.trim(), aciklama: aciklamaCtrl.text.trim(),
          fiyat: fiyat, kategoriId: kategoriId, tukendi: tukendi, aktif: aktif);
      if (!mounted) return false;
      if (r['ok'] == 1) {
        final urn = Map<String, dynamic>.from(r['urun'] ?? {});
        setState(() { urunId = urn['id'] as int? ?? urunId; gorsel = urn['gorsel']?.toString() ?? gorsel; kaydediyor = false; });
        if (kapat) Navigator.of(context).pop(true);
        return true;
      } else {
        setState(() => kaydediyor = false);
        _uyar(r['hata']?.toString() ?? 'Kaydedilemedi');
        return false;
      }
    } catch (_) {
      if (mounted) setState(() => kaydediyor = false);
      _uyar('Bağlantı hatası');
      return false;
    }
  }

  Future<void> _sil() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: const Text('Ürünü sil?', style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text('"${adCtrl.text}" menüden kalkacak.', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF94A3B8)))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _kirmizi), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    try {
      final auth = context.read<AuthProvider>();
      final r = await Api.urunSil(auth.token!, urunId!);
      if (!mounted) return;
      if (r['ok'] == 1) { Navigator.of(context).pop(true); }
      else { _uyar(r['hata']?.toString() ?? 'Silinemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _fotoEkle() async {
    // Yeni üründe önce kaydet (id lazım)
    if (yeni) {
      final ok = await _kaydet(kapat: false);
      if (!ok) return;
    }
    if (!mounted) return;
    final kaynak = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _card,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_camera, color: Colors.white), title: const Text('Kamera', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library, color: Colors.white), title: const Text('Galeri', style: TextStyle(color: Colors.white)), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (kaynak == null) return;
    try {
      final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1400, imageQuality: 82);
      if (x == null || !mounted) return;
      setState(() => fotoYukleniyor = true);
      final auth = context.read<AuthProvider>();
      final r = await Api.urunFotoYukle(auth.token!, urunId!, x.path);
      if (!mounted) return;
      if (r['ok'] == 1) { setState(() { gorsel = r['url']?.toString(); fotoYukleniyor = false; }); _uyar('Fotoğraf yüklendi'); }
      else { setState(() => fotoYukleniyor = false); _uyar(r['hata']?.toString() ?? 'Yüklenemedi'); }
    } catch (_) {
      if (mounted) setState(() => fotoYukleniyor = false);
      _uyar('Fotoğraf yüklenemedi');
    }
  }

  void _uyar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: _card));
  }

  @override
  Widget build(BuildContext context) {
    final kats = widget.kategoriler;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        title: Text(yeni ? 'Yeni Ürün' : 'Ürünü Düzenle', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          if (!yeni) IconButton(onPressed: _sil, icon: const Icon(Icons.delete_outline, color: _kirmizi)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        children: [
          // Fotoğraf
          Center(
            child: GestureDetector(
              onTap: fotoYukleniyor ? null : _fotoEkle,
              child: Container(
                width: double.infinity,
                height: 190,
                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2D3752))),
                clipBehavior: Clip.antiAlias,
                child: fotoYukleniyor
                    ? const Center(child: CircularProgressIndicator(color: _mor1))
                    : gorsel != null
                        ? Stack(fit: StackFit.expand, children: [
                            Image.network(gorsel!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fotoBos()),
                            Positioned(
                              right: 10, bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                                child: const Text('📷 Değiştir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5)),
                              ),
                            ),
                          ])
                        : _fotoBos(),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _alan(adCtrl, 'Ürün adı', TextInputType.text),
          const SizedBox(height: 12),
          _alan(fiyatCtrl, 'Fiyat (TL)', const TextInputType.numberWithOptions(decimal: true)),
          const SizedBox(height: 12),
          // Kategori
          Container(
            decoration: BoxDecoration(color: const Color(0xFF0E1428), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2D3752))),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: kategoriId,
                isExpanded: true,
                dropdownColor: _card,
                iconEnabledColor: const Color(0xFF94A3B8),
                style: const TextStyle(color: Colors.white, fontSize: 14.5),
                hint: const Text('Kategori', style: TextStyle(color: Color(0xFF94A3B8))),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('Kategorisiz')),
                  for (final k in kats) DropdownMenuItem(value: k['id'] as int, child: Text('${k['ad']}')),
                ],
                onChanged: (v) => setState(() => kategoriId = v ?? 0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _alan(aciklamaCtrl, 'Açıklama (müşteriye tanıtım)', TextInputType.multiline, maxLines: 3),
          const SizedBox(height: 14),
          _switch('Tükendi (86)', 'Geçici olarak yok — menüde "tükendi" görünür', tukendi, _kirmizi, (v) => setState(() => tukendi = v)),
          const SizedBox(height: 8),
          _switch('Aktif', 'Kapalıysa menüde hiç görünmez', aktif, _yesil, (v) => setState(() => aktif = v)),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: kaydediyor ? null : () => _kaydet(),
              style: ElevatedButton.styleFrom(backgroundColor: _mor1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: kaydediyor
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          if (yeni)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('İpucu: Fotoğraf eklemek için karta dokunun — ürün otomatik kaydedilip fotoğraf yüklenir.',
                  textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _fotoBos() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_a_photo_outlined, color: Color(0xFF475569), size: 34),
          SizedBox(height: 8),
          Text('Fotoğraf ekle', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        ],
      );

  Widget _switch(String baslik, String alt, bool deger, Color renk, ValueChanged<bool> onc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
            Text(alt, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
          ]),
        ),
        Switch(value: deger, activeThumbColor: renk, onChanged: onc),
      ]),
    );
  }

  Widget _alan(TextEditingController c, String etiket, TextInputType tip, {int maxLines = 1}) {
    return TextField(
      controller: c,
      keyboardType: tip,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: etiket,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFF0E1428),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2D3752))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mor1)),
      ),
    );
  }
}
