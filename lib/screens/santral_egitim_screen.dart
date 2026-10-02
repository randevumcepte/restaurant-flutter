import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — Eğitim: Kalıp (SSS) + Öğrenilen önbellek + Çözülemeyen + PDF→Kalıp.
class SantralEgitimScreen extends StatefulWidget {
  const SantralEgitimScreen({super.key});
  @override
  State<SantralEgitimScreen> createState() => _SantralEgitimScreenState();
}

class _SantralEgitimScreenState extends State<SantralEgitimScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final int _subeId = 1;

  List<Map<String, dynamic>> _kalip = [];
  List<Map<String, dynamic>> _ogren = [];
  List<Map<String, dynamic>> _coz = [];
  bool _y1 = true, _y2 = true, _y3 = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _kalipYukle();
    _ogrenYukle();
    _cozYukle();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _kalipYukle() async {
    setState(() => _y1 = true);
    try { final r = await SantralApi.kalipListe(_subeId); _kalip = _lst(r); } catch (_) {}
    if (mounted) setState(() => _y1 = false);
  }
  Future<void> _ogrenYukle() async {
    setState(() => _y2 = true);
    try { final r = await SantralApi.ogrenilenListe(_subeId); _ogren = _lst(r); } catch (_) {}
    if (mounted) setState(() => _y2 = false);
  }
  Future<void> _cozYukle() async {
    setState(() => _y3 = true);
    try { final r = await SantralApi.cozulemeyenListe(_subeId); _coz = _lst(r); } catch (_) {}
    if (mounted) setState(() => _y3 = false);
  }

  List<Map<String, dynamic>> _lst(Map<String, dynamic> r) =>
      ((r['liste'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Santral AI Eğitimi',
      altBaslik: 'Sabit cevaplar (kalıp), öğrenilen önbellek, çözülemeyenler ve PDF import',
      ikon: Icons.school_outlined,
      govde: Column(children: [
        Container(
          color: t.card,
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            labelColor: const Color(0xFF7C3AED),
            unselectedLabelColor: t.sub,
            indicatorColor: const Color(0xFF7C3AED),
            tabs: [
              Tab(text: 'Kalıp / SSS (${_kalip.length})'),
              Tab(text: 'Öğrenilen (${_ogren.length})'),
              Tab(text: 'Çözülemeyen (${_coz.length})'),
              const Tab(text: 'PDF → Kalıp'),
            ],
          ),
        ),
        Divider(height: 1, color: t.line),
        Expanded(child: TabBarView(controller: _tab, children: [
          _kalipTab(t), _ogrenTab(t), _cozTab(t), _pdfTab(t),
        ])),
      ]),
    );
  }

  // ---------- TAB 1: KALIP ----------
  Widget _kalipTab(TemaProvider t) {
    if (_y1) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Belirli sorulara SABİT cevap (bedava, LLM\'e gitmez).', style: TextStyle(color: t.sub, fontSize: 12.5))),
          MButon('Yeni Kalıp', const Color(0xFF22C55E), _kalipEkleDialog, ikon: Icons.add),
        ]),
        const SizedBox(height: 12),
        Expanded(child: _kalip.isEmpty
            ? Center(child: Text('Kalıp yok', style: TextStyle(color: t.sub)))
            : ListView.separated(
                itemCount: _kalip.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = _kalip[i];
                  final aktif = (x['aktif'] ?? 1) == 1;
                  return MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${x['tetikleyiciler']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 13.5))),
                      if (!aktif) const MRozet('pasif', Color(0xFF94A3B8)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${x['cevap']}', style: TextStyle(color: t.sub2, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      MButon(aktif ? 'Pasifle' : 'Aktifle', const Color(0xFFF59E0B), () async {
                        await SantralApi.kalipGuncelle(x['id'] as int, aktif: !aktif);
                        _kalipYukle();
                      }, dolu: false),
                      const SizedBox(width: 6),
                      MButon('Sil', const Color(0xFFF43F5E), () async {
                        await SantralApi.kalipSil(x['id'] as int);
                        _kalipYukle();
                      }, dolu: false, ikon: Icons.delete_outline),
                    ]),
                  ]));
                },
              )),
      ]),
    );
  }

  Future<void> _kalipEkleDialog() async {
    final tet = TextEditingController();
    final cev = TextEditingController();
    final kat = TextEditingController(text: 'genel');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Yeni Kalıp'),
      content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
        _dlg(tet, 'Tetikleyiciler (virgülle: çalışma saati, kaça kadar)'),
        const SizedBox(height: 10),
        _dlg(cev, 'Cevap', satir: 3),
        const SizedBox(height: 10),
        _dlg(kat, 'Kategori'),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), onPressed: () => Navigator.pop(c, true), child: const Text('Ekle')),
      ],
    ));
    if (ok != true) return;
    final r = await SantralApi.kalipEkle(_subeId, tet.text.trim(), cev.text.trim(), kat.text.trim());
    _uyar(r['ok'] == 1 ? 'Eklendi ✓' : 'Hata: ${r['hata'] ?? ''}');
    _kalipYukle();
  }

  // ---------- TAB 2: OGRENILEN ----------
  Widget _ogrenTab(TemaProvider t) {
    if (_y2) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('AI\'nın Haiku ile bir kez öğrenip önbelleğe aldığı cevaplar (sonraki sorularda bedava).', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 12),
        Expanded(child: _ogren.isEmpty
            ? Center(child: Text('Henüz öğrenilen yok', style: TextStyle(color: t.sub)))
            : ListView.separated(
                itemCount: _ogren.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = _ogren[i];
                  return MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('${x['soru_key'] ?? ''}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 13))),
                      MRozet('${x['kullanim'] ?? 0} kullanım', const Color(0xFF0EA5E9)),
                    ]),
                    const SizedBox(height: 6),
                    Text('${x['cevap']}', style: TextStyle(color: t.sub2, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      MButon('Düzelt', const Color(0xFF4F46E5), () => _ogrenDuzelt(x), dolu: false, ikon: Icons.edit),
                      const SizedBox(width: 6),
                      MButon('Sil', const Color(0xFFF43F5E), () async { await SantralApi.ogrenilenSil(x['id'] as int); _ogrenYukle(); }, dolu: false, ikon: Icons.delete_outline),
                    ]),
                  ]));
                },
              )),
      ]),
    );
  }

  Future<void> _ogrenDuzelt(Map<String, dynamic> x) async {
    final cev = TextEditingController(text: '${x['cevap'] ?? ''}');
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Cevabı Düzelt'),
      content: SizedBox(width: 460, child: _dlg(cev, 'Cevap', satir: 4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet')),
      ],
    ));
    if (ok != true) return;
    await SantralApi.ogrenilenGuncelle(x['id'] as int, cev.text.trim());
    _ogrenYukle();
  }

  // ---------- TAB 3: COZULEMEYEN ----------
  Widget _cozTab(TemaProvider t) {
    if (_y3) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('AI\'nın cevaplayamadığı sorular (en çok sorulan üstte). Cevap ekleyerek kalıba çevir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 12),
        Expanded(child: _coz.isEmpty
            ? Center(child: Text('Çözülemeyen soru yok 🎉', style: TextStyle(color: t.sub)))
            : ListView.separated(
                itemCount: _coz.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final x = _coz[i];
                  return MKart(child: Row(children: [
                    Expanded(child: Text('${x['ham'] ?? x['soru_norm'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 13.5))),
                    const SizedBox(width: 8),
                    MRozet('${x['adet'] ?? 0}×', const Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    MButon('Cevap ekle', const Color(0xFF22C55E), () => _cozKalip(x), ikon: Icons.add_comment),
                    const SizedBox(width: 6),
                    MButon('Sil', const Color(0xFFF43F5E), () async { await SantralApi.cozulemeyenSil(x['id'] as int); _cozYukle(); }, dolu: false),
                  ]));
                },
              )),
      ]),
    );
  }

  Future<void> _cozKalip(Map<String, dynamic> x) async {
    final cev = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('"${x['ham'] ?? x['soru_norm'] ?? ''}" için cevap'),
      content: SizedBox(width: 460, child: _dlg(cev, 'Bu soruya sabit cevap', satir: 3)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), onPressed: () => Navigator.pop(c, true), child: const Text('Kalıba çevir')),
      ],
    ));
    if (ok != true) return;
    final r = await SantralApi.cozulemeyenKalipla(x['id'] as int, cev.text.trim());
    _uyar(r['ok'] == 1 ? 'Kalıba eklendi ✓' : 'Hata: ${r['hata'] ?? ''}');
    _cozYukle();
    _kalipYukle();
  }

  // ---------- TAB 4: PDF ----------
  List<Map<String, dynamic>> _oneriler = [];
  bool _pdfIsliyor = false;
  String? _pdfDurum;

  Widget _pdfTab(TemaProvider t) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(children: [
        MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MBolumBaslik('Menü/SSS PDF\'inden kalıp çıkar', renk: Color(0xFF7C3AED)),
          Text('Bir PDF seçin; AI içindeki soru-cevapları çıkarsın. Onayladıklarınız kalıp olarak eklenir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _pdfIsliyor ? null : _pdfSec,
            icon: _pdfIsliyor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_file),
            label: Text(_pdfIsliyor ? 'İşleniyor...' : 'PDF Seç'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
          ),
          if (_pdfDurum != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_pdfDurum!, style: TextStyle(color: t.sub2, fontSize: 12.5))),
        ])),
        if (_oneriler.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: MBolumBaslik('Önerilen kalıplar', renk: const Color(0xFF22C55E), sayi: _oneriler.length)),
            MButon('Hepsini ekle', const Color(0xFF22C55E), _oneriOnayla, ikon: Icons.check),
          ]),
          const SizedBox(height: 8),
          for (final k in _oneriler) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${k['tetikleyiciler']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text('${k['cevap']}', style: TextStyle(color: t.sub2, fontSize: 12.5)),
            ])),
          ),
        ],
      ]),
    );
  }

  Future<void> _pdfSec() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) { _uyar('Dosya okunamadı'); return; }
    setState(() { _pdfIsliyor = true; _pdfDurum = 'AI PDF\'i okuyor...'; _oneriler = []; });
    try {
      final b64 = base64Encode(bytes);
      final r = await SantralApi.pdfCikar(_subeId, b64);
      if (r['ok'] == 1) {
        _oneriler = ((r['kaliplar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _pdfDurum = '${_oneriler.length} kalıp önerildi. İncele ve ekle.';
      } else {
        _pdfDurum = 'Hata: ${r['hata'] ?? ''}';
      }
    } catch (e) {
      _pdfDurum = 'Hata: $e';
    }
    if (mounted) setState(() => _pdfIsliyor = false);
  }

  Future<void> _oneriOnayla() async {
    final r = await SantralApi.pdfOnayla(_subeId, _oneriler);
    _uyar(r['ok'] == 1 ? '${r['eklendi'] ?? 0} kalıp eklendi ✓' : 'Hata');
    setState(() { _oneriler = []; _pdfDurum = null; });
    _kalipYukle();
  }

  Widget _dlg(TextEditingController c, String label, {int satir = 1}) => TextField(
        controller: c,
        maxLines: satir,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      );
}
