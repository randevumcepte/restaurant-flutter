import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Masa & QR Yönetimi — uygulama içi (tarayıcı AÇMAZ).
/// Her masanın KALICI qr_token'ı vardır, asla değişmez. Silme = arşivleme (geri getirilebilir).
/// QR'lar qr_flutter ile cihazda çizilir, printing ile PDF/yazdırılır.
class MasaYonetimScreen extends StatefulWidget {
  const MasaYonetimScreen({super.key});

  @override
  State<MasaYonetimScreen> createState() => _MasaYonetimScreenState();
}

class _MasaYonetimScreenState extends State<MasaYonetimScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  bool loading = true;
  List masalar = [];
  List arsiv = [];
  List bolgeler = [];
  bool yetkiSil = false;
  String subeAd = '';

  TemaProvider get _t => context.read<TemaProvider>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    subeAd = context.read<AuthProvider>().sube ?? 'Restoran';
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.masaYonetim(auth.token!);
      if (!mounted) return;
      if (r['ok'] == 1) {
        setState(() {
          masalar = (r['masalar'] as List?) ?? [];
          arsiv = (r['arsiv'] as List?) ?? [];
          bolgeler = (r['bolgeler'] as List?) ?? [];
          yetkiSil = r['yetki_sil'] == true;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String msg, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: hata ? _t.kirmizi : _t.yesil,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: _t.bg,
      appBar: AppBar(
        backgroundColor: _t.card,
        elevation: 0.5,
        iconTheme: IconThemeData(color: _t.ink),
        title: Text('Masa & QR Yönetimi', style: TextStyle(color: _t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Tüm QR afişlerini yazdır',
            icon: Icon(Icons.print, color: _t.mor1),
            onPressed: masalar.isEmpty ? null : () => _yazdir(masalar.cast<Map>()),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: _t.mor1,
          unselectedLabelColor: _t.sub,
          indicatorColor: _t.mor1,
          tabs: [
            Tab(text: 'Masalar (${masalar.length})'),
            Tab(text: 'Arşiv (${arsiv.length})'),
          ],
        ),
      ),
      floatingActionButton: _tab.index == 0
          ? FloatingActionButton.extended(
              backgroundColor: _t.mor1,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Masa Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: _masaEkleDialog,
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [_aktifListe(), _arsivListe()],
            ),
    );
  }

  Widget _aktifListe() {
    if (masalar.isEmpty) {
      return _bosDurum(Icons.table_restaurant, 'Henüz masa yok', 'Sağ alttan "Masa Ekle" ile başla.\nHer masa için QR kod otomatik oluşur.');
    }
    return RefreshIndicator(
      onRefresh: _yukle,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.82),
        itemCount: masalar.length,
        itemBuilder: (_, i) => _masaKart(masalar[i] as Map),
      ),
    );
  }

  Widget _masaKart(Map m) {
    final url = (m['qr_url'] ?? '').toString();
    final bolge = (m['bolge'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _qrAfisDialog(m),
      child: Container(
        decoration: BoxDecoration(color: _t.card, borderRadius: BorderRadius.circular(16), boxShadow: _t.golge, border: Border.all(color: _t.line)),
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.all(8),
              child: url.isEmpty
                  ? const Center(child: Icon(Icons.qr_code_2, size: 48, color: Colors.black26))
                  : QrImageView(data: url, version: QrVersions.auto, backgroundColor: Colors.white, padding: EdgeInsets.zero),
            ),
          ),
          const SizedBox(height: 8),
          Text(m['ad']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          Text('${m['kapasite'] ?? 0} kişi${bolge.isNotEmpty ? ' · $bolge' : ''}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _t.sub, fontSize: 11)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _miniBtn(Icons.visibility_outlined, 'QR', _t.mor1, () => _qrAfisDialog(m)),
            _miniBtn(Icons.edit_outlined, 'Düzenle', _t.mavi, () => _masaDuzenleDialog(m)),
            if (yetkiSil) _miniBtn(Icons.delete_outline, 'Sil', _t.kirmizi, () => _silOnay(m)),
          ]),
        ]),
      ),
    );
  }

  Widget _miniBtn(IconData ic, String tip, Color renk, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(4), child: Icon(ic, size: 20, color: renk)),
      );

  Widget _arsivListe() {
    if (arsiv.isEmpty) {
      return _bosDurum(Icons.inventory_2_outlined, 'Arşiv boş', 'Silinen masalar buraya düşer.\nQR kodları korunur; tek dokunuşla geri getirilir.');
    }
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: arsiv.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final m = arsiv[i] as Map;
          return Container(
            decoration: BoxDecoration(color: _t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _t.line)),
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.qr_code_2, color: _t.sub2, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(m['ad']?.toString() ?? '-', style: TextStyle(color: _t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('QR korunuyor · kalıcı kod', style: TextStyle(color: _t.sub, fontSize: 11)),
                ]),
              ),
              if (yetkiSil)
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _t.yesil, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  icon: const Icon(Icons.restore, size: 18, color: Colors.white),
                  label: const Text('Geri Getir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _geriGetir(m),
                ),
            ]),
          );
        },
      ),
    );
  }

  Widget _bosDurum(IconData ic, String baslik, String alt) => ListView(children: [
        const SizedBox(height: 120),
        Icon(ic, size: 64, color: _t.sub2),
        const SizedBox(height: 16),
        Center(child: Text(baslik, style: TextStyle(color: _t.ink, fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 8),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(alt, textAlign: TextAlign.center, style: TextStyle(color: _t.sub, fontSize: 13, height: 1.4))),
      ]);

  // ---- QR afiş önizleme (uygulama içi) + yazdır ----
  void _qrAfisDialog(Map m) {
    final url = (m['qr_url'] ?? '').toString();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(subeAd, style: TextStyle(color: _t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('Karekodu telefonunuzla okutun', style: TextStyle(color: _t.sub, fontSize: 12)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: url.isEmpty
                  ? const Icon(Icons.qr_code_2, size: 180, color: Colors.black26)
                  : QrImageView(data: url, version: QrVersions.auto, size: 220, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(m['ad']?.toString() ?? '-', style: TextStyle(color: _t.ink, fontSize: 24, fontWeight: FontWeight.bold)),
            Text('Menü · Sipariş · Garson Çağır · Öde', style: TextStyle(color: _t.sub, fontSize: 11)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _t.mor1),
                  icon: const Icon(Icons.print, size: 18, color: Colors.white),
                  label: const Text('Yazdır', style: TextStyle(color: Colors.white)),
                  onPressed: () => _yazdir([m]),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  // ---- Masa ekle ----
  Future<void> _masaEkleDialog() async {
    final adCtrl = TextEditingController();
    final kapCtrl = TextEditingController(text: '4');
    int? bolgeId;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setD) {
        return AlertDialog(
          backgroundColor: _t.card,
          title: Text('Masa Ekle', style: TextStyle(color: _t.ink)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: adCtrl, style: TextStyle(color: _t.ink),
                decoration: InputDecoration(labelText: 'Masa adı (boş = otomatik)', labelStyle: TextStyle(color: _t.sub))),
            const SizedBox(height: 10),
            TextField(controller: kapCtrl, keyboardType: TextInputType.number, style: TextStyle(color: _t.ink),
                decoration: InputDecoration(labelText: 'Kapasite (kişi)', labelStyle: TextStyle(color: _t.sub))),
            if (bolgeler.isNotEmpty) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: bolgeId,
                dropdownColor: _t.card,
                decoration: InputDecoration(labelText: 'Bölge', labelStyle: TextStyle(color: _t.sub)),
                items: [
                  DropdownMenuItem<int?>(value: null, child: Text('Bölgesiz', style: TextStyle(color: _t.ink))),
                  ...bolgeler.map((b) => DropdownMenuItem<int?>(value: (b['id'] as num).toInt(),
                      child: Text(b['ad']?.toString() ?? '-', style: TextStyle(color: _t.ink)))),
                ],
                onChanged: (v) => setD(() => bolgeId = v),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _t.mor1),
              onPressed: () async {
                Navigator.pop(ctx);
                final r = await Api.masaEkle(context.read<AuthProvider>().token!,
                    ad: adCtrl.text.trim(), kapasite: int.tryParse(kapCtrl.text) ?? 4, bolgeId: bolgeId);
                if (r['ok'] == 1) { _snack(r['mesaj']?.toString() ?? 'Eklendi'); _yukle(); }
                else { _snack(r['hata']?.toString() ?? 'Eklenemedi', hata: true); }
              },
              child: const Text('Ekle'),
            ),
          ],
        );
      }),
    );
  }

  // ---- Masa düzenle ----
  Future<void> _masaDuzenleDialog(Map m) async {
    final adCtrl = TextEditingController(text: m['ad']?.toString() ?? '');
    final kapCtrl = TextEditingController(text: '${m['kapasite'] ?? 4}');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _t.card,
        title: Text('Masa Düzenle', style: TextStyle(color: _t.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: adCtrl, style: TextStyle(color: _t.ink),
              decoration: InputDecoration(labelText: 'Masa adı', labelStyle: TextStyle(color: _t.sub))),
          const SizedBox(height: 10),
          TextField(controller: kapCtrl, keyboardType: TextInputType.number, style: TextStyle(color: _t.ink),
              decoration: InputDecoration(labelText: 'Kapasite', labelStyle: TextStyle(color: _t.sub))),
          const SizedBox(height: 8),
          Text('QR kodu değişmez.', style: TextStyle(color: _t.sub, fontSize: 11)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _t.mavi),
            onPressed: () async {
              Navigator.pop(ctx);
              final r = await Api.masaGuncelle(context.read<AuthProvider>().token!, (m['id'] as num).toInt(),
                  ad: adCtrl.text.trim(), kapasite: int.tryParse(kapCtrl.text));
              if (r['ok'] == 1) { _snack('Güncellendi'); _yukle(); }
              else { _snack(r['hata']?.toString() ?? 'Hata', hata: true); }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  // ---- Sil (arşivle) onayı — QR uyarılı ----
  Future<void> _silOnay(Map m) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _t.card,
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: _t.kirmizi), const SizedBox(width: 8),
          Expanded(child: Text('${m['ad']} arşive taşınsın mı?', style: TextStyle(color: _t.ink, fontSize: 16)))]),
        content: Text(
          'Bu masanın QR kodu metal/ağaç gibi fiziksel bir yere basılmış olabilir.\n\n'
          'Masa SİLİNMEZ, arşive taşınır — QR kodu KORUNUR ve istediğin an aynı kodla geri getirebilirsin. '
          'Böylece yeniden bastırma masrafı olmaz.',
          style: TextStyle(color: _t.sub, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _t.kirmizi),
            onPressed: () async {
              Navigator.pop(ctx);
              final r = await Api.masaSil(context.read<AuthProvider>().token!, (m['id'] as num).toInt());
              if (r['ok'] == 1) { _snack(r['mesaj']?.toString() ?? 'Arşive taşındı'); _yukle(); }
              else { _snack(r['hata']?.toString() ?? 'Hata', hata: true); }
            },
            child: const Text('Arşive Taşı'),
          ),
        ],
      ),
    );
  }

  Future<void> _geriGetir(Map m) async {
    final r = await Api.masaGeri(context.read<AuthProvider>().token!, (m['id'] as num).toInt());
    if (r['ok'] == 1) { _snack(r['mesaj']?.toString() ?? 'Geri getirildi'); _yukle(); }
    else { _snack(r['hata']?.toString() ?? 'Hata', hata: true); }
  }

  // ---- Yazdır (PDF, Türkçe-uyumlu font) — her masa için A6 afiş ----
  Future<void> _yazdir(List<Map> liste) async {
    try {
      final base = await PdfGoogleFonts.nunitoRegular();
      final bold = await PdfGoogleFonts.nunitoExtraBold();
      final doc = pw.Document(theme: pw.ThemeData.withFont(base: base, bold: bold));
      for (final m in liste) {
        final url = (m['qr_url'] ?? '').toString();
        if (url.isEmpty) continue;
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a6,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Center(
            child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Text(subeAd, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text('Karekodu telefonunuzla okutun', style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 12),
              pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: url, width: 150, height: 150),
              pw.SizedBox(height: 12),
              pw.Text(m['ad']?.toString() ?? '-', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text('Menü · Sipariş · Garson Çağır · Öde', style: const pw.TextStyle(fontSize: 9)),
            ]),
          ),
        ));
      }
      await Printing.layoutPdf(onLayout: (f) async => doc.save());
    } catch (e) {
      _snack('Yazdırma hatası: $e', hata: true);
    }
  }
}
