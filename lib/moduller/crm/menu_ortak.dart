import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_api.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Menü & Ürünler ekranlarının ortak yardımcıları (yalnız bu modül içinde kullanılır).

/// Web'deki sahip/müdür kapısı (happy hour, fix menü gibi formlar bu rolleri ister).
bool menuYoneticiMi(BuildContext context) {
  final rol = (context.read<AuthProvider>().rol ?? '').toString();
  return rol == 'sahip' || rol == 'mudur';
}

Map<String, String> _basliklar(String token) => {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Resteos-Kopru': '1',
    };

/// Dosyalı web formu (multipart) — köprü başlıklarıyla. Başarı/hata bildirimini gösterir.
Future<KopruCevap?> menuDosyaGonder(
  BuildContext context,
  String yol,
  Map<String, String> alanlar,
  String dosyaAlan,
  XFile dosya, {
  String? basariMesaji,
}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    final req = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}$yol'));
    req.headers.addAll(_basliklar(tok));
    req.fields.addAll(alanlar);
    req.files.add(http.MultipartFile.fromBytes(dosyaAlan, await dosya.readAsBytes(), filename: dosya.name));
    final r = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 90)));
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    KopruCevap c;
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      c = KopruCevap(r.statusCode, d is Map ? Map<String, dynamic>.from(d) : {'ok': r.statusCode < 400 ? 1 : 0});
    } catch (_) {
      c = KopruCevap(r.statusCode, {'ok': 0, 'hata': 'Sunucu yanıtı okunamadı (HTTP ${r.statusCode}).'});
    }
    if (context.mounted) {
      if (c.ok) {
        kToast(context, c.mesaj ?? basariMesaji ?? 'Kaydedildi.');
      } else {
        kToast(context, c.hata ?? metinOku(c.j['mesaj'], 'Yüklenemedi.'), hata: true);
      }
    }
    return c;
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  } catch (_) {
    if (context.mounted) kToast(context, 'İnternet bağlantısı yok; dosya gönderilemedi.', hata: true);
    return null;
  }
}

/// Ham HTML dönen web sayfasını al (JSON view'ı olmayan eski sayfalar için). Hata → null.
Future<String?> menuHtmlAl(BuildContext context, String yol, {Map<String, String>? q}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    var u = Uri.parse('${AppConfig.baseUrl}$yol');
    if (q != null && q.isNotEmpty) u = u.replace(queryParameters: {...u.queryParameters, ...q});
    final r = await http.get(u, headers: _basliklar(tok)).timeout(const Duration(seconds: 30));
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    if (r.statusCode != 200) return null;
    return utf8.decode(r.bodyBytes);
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  } catch (_) {
    return null;
  }
}

/// HTML varlıklarını çöz (&amp; &quot; &#039; &lt; &gt;)
String htmlCoz(String s) => s
    .replaceAll('&quot;', '"')
    .replaceAll('&#039;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// Saat seç → "HH:mm"
Future<String?> menuSaatSec(BuildContext context, String? mevcut) async {
  final p = (mevcut ?? '').split(':');
  final ilk = p.length >= 2 ? TimeOfDay(hour: int.tryParse(p[0]) ?? 12, minute: int.tryParse(p[1]) ?? 0) : const TimeOfDay(hour: 17, minute: 0);
  final s = await showTimePicker(context: context, initialTime: ilk, builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!));
  if (s == null) return null;
  return '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}';
}

/// Tarih seç → "yyyy-MM-dd"
Future<String?> menuTarihSec(BuildContext context, String? mevcut) async {
  final ilk = DateTime.tryParse(mevcut ?? '') ?? DateTime.now();
  final s = await showDatePicker(context: context, initialDate: ilk, firstDate: DateTime(2020), lastDate: DateTime(2100));
  if (s == null) return null;
  return '${s.year}-${s.month.toString().padLeft(2, '0')}-${s.day.toString().padLeft(2, '0')}';
}

/// Form içinde "seçici" kutusu (saat/tarih/renk) — KAlan görünümünde, dokununca seçim açar.
class MenuSeciciKutu extends StatelessWidget {
  final String etiket;
  final String? deger;
  final String bosMetin;
  final IconData ikon;
  final VoidCallback onTap;
  final VoidCallback? onTemizle;
  const MenuSeciciKutu({super.key, required this.etiket, required this.deger, required this.onTap, this.bosMetin = 'Seçin', this.ikon = Icons.schedule, this.onTemizle});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final dolu = (deger ?? '').isNotEmpty;
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
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 46),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
              child: Row(children: [
                Icon(ikon, size: 18, color: t.sub),
                const SizedBox(width: 8),
                Expanded(child: Text(dolu ? deger! : bosMetin, style: TextStyle(color: dolu ? t.ink : t.sub, fontSize: 15))),
                if (dolu && onTemizle != null)
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'Temizle', onPressed: onTemizle, icon: Icon(Icons.close, size: 18, color: t.sub)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Anahtar/değer satırı (switch) — form içinde
class MenuAnahtar extends StatelessWidget {
  final String baslik;
  final String? alt;
  final bool deger;
  final ValueChanged<bool> onDegis;
  const MenuAnahtar({super.key, required this.baslik, this.alt, required this.deger, required this.onDegis});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: SwitchListTile(
        value: deger,
        onChanged: onDegis,
        activeThumbColor: t.mor1,
        title: Text(baslik, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: alt == null ? null : Text(alt!, style: TextStyle(color: t.sub, fontSize: 12)),
      ),
    );
  }
}

/// "#RRGGBB" → Color (geçersizse null)
Color? hexRenk(String? s) {
  var h = (s ?? '').trim().replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

/// Color → "#RRGGBB"
String renkHex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
