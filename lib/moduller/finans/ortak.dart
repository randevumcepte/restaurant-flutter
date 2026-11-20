import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Finans modülü ortak parçaları: ay seçici, tutar satırı, bilgi notu, dosya indir-kaydet.

/// "2026-11" → "Kasım 2026"
String ayAdi(String ay) {
  final d = DateTime.tryParse('$ay-01');
  if (d == null) return ay;
  final s = DateFormat('MMMM y', 'tr_TR').format(d);
  return s.isEmpty ? ay : '${s[0].toUpperCase()}${s.substring(1)}';
}

String ayKaydir(String ay, int delta) {
  final d = DateTime.tryParse('$ay-01') ?? DateTime.now();
  final y = DateTime(d.year, d.month + delta, 1);
  return '${y.year}-${y.month.toString().padLeft(2, '0')}';
}

String buAy() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

/// Önceki / sonraki ay seçici (web'deki ?ay=YYYY-MM parametresi). Gelecek aya geçilmez.
class AySecici extends StatelessWidget {
  final String ay;
  final ValueChanged<String> onSec;
  final String? ek;
  const AySecici({super.key, required this.ay, required this.onSec, this.ek});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ileri = ay.compareTo(buAy()) < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          IconButton(tooltip: 'Önceki ay', onPressed: () => onSec(ayKaydir(ay, -1)), icon: Icon(Icons.chevron_left, color: t.ink)),
          Expanded(
            child: InkWell(
              onTap: ay == buAy() ? null : () => onSec(buAy()),
              child: Column(children: [
                Text(ayAdi(ay), textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                if (ek != null) Text(ek!, style: TextStyle(color: t.sub, fontSize: 12)),
                if (ay != buAy()) Text('Bu aya dön', style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
          IconButton(tooltip: 'Sonraki ay', onPressed: ileri ? () => onSec(ayKaydir(ay, 1)) : null, icon: Icon(Icons.chevron_right, color: ileri ? t.ink : t.line)),
        ]),
      ),
    );
  }
}

/// Etiket — tutar satırı (P&L, KDV, bilanço tabloları)
class FSatir extends StatelessWidget {
  final String etiket;
  final String deger;
  final Color? renk;
  final bool vurgu;
  final bool girinti;
  final IconData? ikon;
  const FSatir(this.etiket, this.deger, {super.key, this.renk, this.vurgu = false, this.girinti = false, this.ikon});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Container(
      padding: EdgeInsets.fromLTRB(girinti ? 22 : 4, 11, 4, 11),
      decoration: BoxDecoration(
        color: vurgu ? t.card2 : null,
        border: Border(bottom: BorderSide(color: t.line.withValues(alpha: .7))),
      ),
      child: Row(children: [
        if (ikon != null) ...[Icon(ikon, size: 17, color: t.sub), const SizedBox(width: 8)],
        Expanded(
          child: Text(etiket,
              style: TextStyle(color: girinti ? t.sub2 : t.ink, fontSize: vurgu ? 15 : 14, fontWeight: vurgu ? FontWeight.w700 : FontWeight.w500)),
        ),
        const SizedBox(width: 10),
        Text(deger, style: TextStyle(color: renk ?? t.ink, fontSize: vurgu ? 16 : 14, fontWeight: vurgu ? FontWeight.bold : FontWeight.w700)),
      ]),
    );
  }
}

/// Bilgi notu (web sayfalarının altındaki "info" kutusu)
class FNot extends StatelessWidget {
  final String metin;
  final List<Widget> baglantilar;
  const FNot(this.metin, {super.key, this.baglantilar = const []});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.amber.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.amber.withValues(alpha: .3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18, color: t.amber),
          const SizedBox(width: 8),
          Expanded(child: Text(metin, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4))),
        ]),
        if (baglantilar.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 8, runSpacing: 8, children: baglantilar)),
      ]),
    );
  }
}

/// Büyük vurgulu tutar kartı (net kâr, ödenecek KDV, özkaynak…)
class FHero extends StatelessWidget {
  final String etiket;
  final String deger;
  final String? alt;
  final Color renk;
  final IconData ikon;
  final List<Widget> ekler;
  const FHero({super.key, required this.etiket, required this.deger, required this.renk, required this.ikon, this.alt, this.ekler = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(colors: [renk, Color.lerp(renk, Colors.black, .25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ikon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(etiket, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(deger, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))),
        if (alt != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(alt!, style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 13))),
        if (ekler.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 10, runSpacing: 8, children: ekler)),
      ]),
    );
  }
}

/// Hero içindeki küçük gösterge (beyaz)
class FHeroMini extends StatelessWidget {
  final String etiket;
  final String deger;
  final IconData ikon;
  const FHeroMini(this.etiket, this.deger, this.ikon, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text('$etiket ', style: TextStyle(color: Colors.white.withValues(alpha: .85), fontSize: 12.5)),
          Text(deger, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Başka bir web sayfasına (uygulamadaki karşılığına) geçiş düğmesi
class FGecis extends StatelessWidget {
  final String metin;
  final VoidCallback onTap;
  const FGecis(this.metin, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return ActionChip(
      label: Text(metin, style: TextStyle(color: t.mor1, fontSize: 13, fontWeight: FontWeight.w700)),
      avatar: Icon(Icons.arrow_forward, size: 16, color: t.mor1),
      backgroundColor: t.mor1.withValues(alpha: .08),
      side: BorderSide(color: t.mor1.withValues(alpha: .3)),
      onPressed: onTap,
    );
  }
}

/// İki/üç sütunlu duyarlı ızgara (masaüstünde yan yana, telefonda alt alta)
class FIzgara extends StatelessWidget {
  final List<Widget> cocuklar;
  final double minGenislik;
  const FIzgara(this.cocuklar, {super.key, this.minGenislik = 340});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, k) {
      final n = (k.maxWidth / minGenislik).floor().clamp(1, cocuklar.length.clamp(1, 3));
      if (n <= 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cocuklar);
      const ara = 12.0;
      final g = (k.maxWidth - ara * (n - 1)) / n;
      return Wrap(spacing: ara, children: [for (final w in cocuklar) SizedBox(width: g, child: w)]);
    });
  }
}

/// Web'deki indirme bağlantısını (CSV/Excel/PDF) köprüden alır ve kullanıcıya kaydettirir.
/// Telefonda sistem "kaydet" penceresi, masaüstünde "Farklı kaydet" penceresi; olmazsa uygulama belgeler klasörü.
Future<void> dosyaIndirKaydet(BuildContext context, String yol, {Map<String, String>? q, required String dosyaAdi}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return;
  kToast(context, 'Dosya hazırlanıyor…');
  Uint8List? b;
  try {
    b = await KopruApi.dosya(tok, yol, q: q);
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return;
  }
  if (!context.mounted) return;
  if (b == null) {
    kToast(context, 'Dosya alınamadı (yetki ya da bağlantı sorunu).', hata: true);
    return;
  }
  final veri = b;
  String? kayit;
  var iptal = false;
  try {
    final uzanti = dosyaAdi.contains('.') ? dosyaAdi.split('.').last : '';
    if (Platform.isAndroid || Platform.isIOS) {
      kayit = await FilePicker.platform.saveFile(dialogTitle: 'Dosyayı kaydet', fileName: dosyaAdi, bytes: veri);
    } else {
      final p = await FilePicker.platform.saveFile(
        dialogTitle: 'Dosyayı kaydet',
        fileName: dosyaAdi,
        type: uzanti.isEmpty ? FileType.any : FileType.custom,
        allowedExtensions: uzanti.isEmpty ? null : [uzanti],
      );
      if (p != null) {
        await File(p).writeAsBytes(veri);
        kayit = p;
      }
    }
    iptal = kayit == null;
  } catch (_) {
    kayit = null;
  }
  if (kayit == null && !iptal) {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$dosyaAdi');
      await f.writeAsBytes(veri);
      kayit = f.path;
    } catch (_) {}
  }
  if (!context.mounted) return;
  if (iptal) {
    kToast(context, 'Kaydetme iptal edildi.');
  } else if (kayit == null) {
    kToast(context, 'Dosya kaydedilemedi.', hata: true);
  } else {
    kToast(context, 'Kaydedildi: $kayit');
  }
}

/// Web adresinin uygulamadaki ekranını aç (menüdeki gibi)
void sayfaAc(BuildContext context, String url, String ad) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));
}

/// Tarih seç → 'YYYY-MM-DD' (iptalde null)
Future<String?> tarihSec(BuildContext context, {String? baslangic, bool gelecek = true}) async {
  final simdi = DateTime.now();
  final ilk = DateTime.tryParse(baslangic ?? '') ?? simdi;
  final d = await showDatePicker(
    context: context,
    initialDate: ilk,
    firstDate: DateTime(simdi.year - 5),
    lastDate: gelecek ? DateTime(simdi.year + 5) : simdi,
  );
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Form içi tarih alanı (dokununca takvim açılır)
class FTarihAlan extends StatelessWidget {
  final String etiket;
  final String? deger;
  final ValueChanged<String?> onSec;
  final bool temizlenebilir;
  const FTarihAlan(this.etiket, {super.key, required this.deger, required this.onSec, this.temizlenebilir = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Material(
          color: t.card2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final s = await tarihSec(context, baslangic: deger);
              if (s != null) onSec(s);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
              child: Row(children: [
                Icon(Icons.calendar_month_outlined, size: 18, color: t.sub),
                const SizedBox(width: 8),
                Expanded(child: Text(deger == null || deger!.isEmpty ? 'Tarih seçin' : tarihYaz(deger, saat: false), style: TextStyle(color: deger == null ? t.sub : t.ink, fontSize: 15))),
                if (temizlenebilir && deger != null) IconButton(onPressed: () => onSec(null), icon: Icon(Icons.close, size: 18, color: t.sub)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Bugün 'YYYY-MM-DD'
String bugunYmd() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
