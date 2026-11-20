import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Satın alma modülü ortak yardımcıları (yalnız bu modül kullanır).

/// Web'deki AJAX ucuna gönder; sunucunun `mesaj` / `hata` alanını aynen gösterir.
/// Web uçlarının çoğu hatada {ok:false, mesaj:'...'} döner — bu yüzden kopruGonder yerine bu kullanılır.
Future<KopruCevap?> saGonder(BuildContext context, String yol, Map<String, dynamic> veri,
    {String? basari, bool json = true, bool sessiz = false, bool hataSessiz = false}) async {
  final c = await kopruGonderCevap(context, yol, veri, json: json, sessiz: true);
  if (c == null || !context.mounted) return c;
  if (c.ok) {
    if (!sessiz) kToast(context, c.mesaj ?? basari ?? 'Kaydedildi.');
  } else if (!hataSessiz) {
    kToast(context, saHata(c), hata: true);
  }
  return c;
}

/// Hata metni: önce mesaj, sonra hata
String saHata(KopruCevap c) {
  final m = c.j['mesaj'];
  if (m is String && m.trim().isNotEmpty) return m.trim();
  return c.hata ?? 'İşlem yapılamadı.';
}

/// JSON dönen GET ucu (ör. /api/patron/talep-detay)
Future<KopruCevap?> saAl(BuildContext context, String yol, {Map<String, String>? q}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    return await KopruApi.al(tok, yol, q: q);
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  }
}

/// Excel / PDF indir ve kaydet (masaüstünde kaydetme penceresi, telefonda paylaş/kaydet)
Future<void> saDosyaIndir(BuildContext context, String yol, String dosyaAdi, {Map<String, String>? q}) async {
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
  if (b == null || b.isEmpty) {
    kToast(context, 'Dosya alınamadı (veri yok ya da yetki yok).', hata: true);
    return;
  }
  try {
    final yolu = await FilePicker.platform.saveFile(dialogTitle: 'Kaydet', fileName: dosyaAdi, bytes: b);
    if (yolu != null && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final f = File(yolu);
      if (!f.existsSync() || f.lengthSync() == 0) await f.writeAsBytes(b);
    }
    if (yolu != null && context.mounted) kToast(context, 'Kaydedildi: $dosyaAdi');
  } catch (e) {
    if (context.mounted) kToast(context, 'Kaydedilemedi: $e', hata: true);
  }
}

/// Panoya kopyala
Future<void> saKopyala(BuildContext context, String metin, [String mesaj = 'Kopyalandı.']) async {
  await Clipboard.setData(ClipboardData(text: metin));
  if (context.mounted) kToast(context, mesaj);
}

/// Tek metin soran pencere (red sebebi, not vb.). hazirlar: hızlı seçilebilir cümleler.
Future<String?> saMetinSor(BuildContext context, String baslik,
    {String? aciklama, String ipucu = '', String evet = 'Tamam', List<String> hazirlar = const [], int enAz = 0, bool tehlikeli = false, String baslangic = '', int satir = 3, TextInputType? klavye}) {
  final k = TextEditingController(text: baslangic);
  return kAltSayfa<String>(context, baslik: baslik, icerik: (c) {
    final t = c.watch<TemaProvider>();
    return StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (aciklama != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(aciklama, style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.4))),
        if (hazirlar.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final h in hazirlar) ActionChip(label: Text(h, style: TextStyle(fontSize: 12.5, color: t.sub2)), onPressed: () => ss(() => k.text = h), backgroundColor: t.card2, side: BorderSide(color: t.line)),
            ]),
          ),
        KAlan('', k, ipucu: ipucu, satir: satir, klavye: klavye),
        KButon(evet, genis: true, renk: tehlikeli ? t.kirmizi : null, onTap: () {
          final s = k.text.trim();
          if (s.length < enAz) {
            kToast(c, enAz > 0 ? 'En az $enAz karakter yazın.' : 'Boş olamaz.', hata: true);
            return;
          }
          Navigator.pop(c, s);
        }),
      ]);
    });
  });
}

/// Tarih seç → 'yyyy-MM-dd'
Future<String?> saTarihSec(BuildContext context, {String? ilk, DateTime? enErken}) async {
  final simdi = DateTime.now();
  final bas = DateTime.tryParse(ilk ?? '') ?? simdi;
  final d = await showDatePicker(
    context: context,
    initialDate: enErken != null && bas.isBefore(enErken) ? enErken : bas,
    firstDate: enErken ?? DateTime(simdi.year - 3),
    lastDate: DateTime(simdi.year + 3),
  );
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

String bugunStr() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// "az önce / 5 dk önce / 3 sa önce / 2 gün önce"
String gecenZaman(dynamic ts) {
  final d = DateTime.tryParse(metinOku(ts).replaceFirst(' ', 'T'));
  if (d == null) return '';
  final f = DateTime.now().difference(d).inSeconds;
  if (f < 60) return 'az önce';
  if (f < 3600) return '${f ~/ 60} dk önce';
  if (f < 86400) return '${f ~/ 3600} sa önce';
  return '${f ~/ 86400} gün önce';
}

/// Satın alma talep durumları (web ile aynı renk/metin)
const Map<String, (String, Color)> kTalepDurum = {
  'departman_onay': ('Şef / Sorumlu Onayında', Color(0xFF8B5CF6)),
  'yeni': ('Yeni', Color(0xFF4F46E5)),
  'teklif': ('Teklif Bekleniyor', Color(0xFFF59E0B)),
  'onayda': ('Onayda', Color(0xFFF59E0B)),
  'fiyat_onay': ('Fiyat Onayında', Color(0xFFF59E0B)),
  'onaylandi': ('Onaylandı', Color(0xFF10B981)),
  'siparis': ('Siparişte', Color(0xFF0EA5E9)),
  'tamamlandi': ('Tamamlandı', Color(0xFF10B981)),
  'reddedildi': ('Reddedildi', Color(0xFFF43F5E)),
  'transfer': ('Şubeden Transfer', Color(0xFF0891B2)),
  'iptal': ('İptal (talebe döndü)', Color(0xFF64748B)),
};

KRozet talepDurumRozet(String d) {
  final x = kTalepDurum[d];
  return KRozet(x?.$1 ?? d, renk: x?.$2 ?? const Color(0xFF64748B));
}

/// Basit bilgi kutusu (renkli şerit + metin)
class SaBilgi extends StatelessWidget {
  final String metin;
  final Color? renk;
  final IconData ikon;
  final Widget? sag;
  const SaBilgi(this.metin, {super.key, this.renk, this.ikon = Icons.info_outline, this.sag});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final r = renk ?? t.mavi;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: r.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: r.withValues(alpha: .3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ikon, size: 18, color: r),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: TextStyle(color: t.ink, fontSize: 13, height: 1.4))),
        if (sag != null) ...[const SizedBox(width: 8), sag!],
      ]),
    );
  }
}

/// İki sütunlu (masaüstü) / tek sütun (telefon) kart ızgarası
class SaIzgara extends StatelessWidget {
  final List<Widget> cocuklar;
  final double minGenislik;
  const SaIzgara(this.cocuklar, {super.key, this.minGenislik = 420});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final n = (c.maxWidth / minGenislik).floor().clamp(1, 3);
      if (n == 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cocuklar);
      const ara = 12.0;
      final g = (c.maxWidth - ara * (n - 1)) / n;
      return Wrap(spacing: ara, children: [for (final k in cocuklar) SizedBox(width: g, child: k)]);
    });
  }
}

/// Etiket : değer satırı
class SaDeger extends StatelessWidget {
  final String etiket;
  final String deger;
  final Color? renk;
  final bool kalin;
  const SaDeger(this.etiket, this.deger, {super.key, this.renk, this.kalin = false});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(etiket, style: TextStyle(color: t.sub, fontSize: 13))),
        const SizedBox(width: 8),
        Flexible(child: Text(deger, textAlign: TextAlign.right, style: TextStyle(color: renk ?? t.ink, fontSize: 13.5, fontWeight: kalin ? FontWeight.w700 : FontWeight.w600))),
      ]),
    );
  }
}

/// Liste için arama süzgeci (küçük harf, Türkçe)
bool saIcerir(String kaynak, String q) {
  if (q.trim().isEmpty) return true;
  String n(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  return n(kaynak).contains(n(q.trim()));
}

/// Web adresindeki ekranı uygulama içinde aç (EkranKayit: özel ekran ya da genel görünüm)
Future<T?> saAc<T>(BuildContext context, String url, String ad) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));

/// Web adresinin uygulama ekranı (widget olarak)
Widget saEkran(String url, [String ad = '']) => EkranKayit.uret(url, ad);

/// Dosya yükle (multipart, web formundaki <input type=file> ile aynı alan adı). Köprü başlıklarıyla gider.
/// dosyalar: (alanAdi, dosyaAdi, baytlar). Cevap KopruCevap (redirect → {ok, mesaj, hata}).
Future<KopruCevap?> saDosyaYukle(BuildContext context, String yol, List<(String, String, List<int>)> dosyalar, {Map<String, String> alanlar = const {}}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}$yol'));
    req.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $tok', 'X-Resteos-Kopru': '1'});
    req.fields.addAll(alanlar);
    for (final (alan, ad, b) in dosyalar) {
      req.files.add(http.MultipartFile.fromBytes(alan, b, filename: ad));
    }
    final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 180)));
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map) return KopruCevap(r.statusCode, Map<String, dynamic>.from(d));
    } catch (_) {}
    return KopruCevap(r.statusCode, {'ok': r.statusCode < 400 ? 1 : 0, 'hata': r.statusCode < 400 ? null : 'Yükleme başarısız (HTTP ${r.statusCode}).'});
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  } catch (e) {
    return KopruCevap(0, {'ok': 0, 'hata': 'Yüklenemedi: bağlantı hatası.'});
  }
}
