import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// AI modülü ortak yardımcıları: web renk ifadesi → Color, HTML/markdown kalın metin, web yoluna gitme, güvenli POST.

/// Web'deki renk ifadesi ('#F43F5E', 'var(--kirmizi)', 't-amber') → Color
Color cssRenk(BuildContext context, dynamic v, [Color? varsayilan]) {
  final t = context.read<TemaProvider>();
  final s = metinOku(v).trim();
  if (s.isEmpty) return varsayilan ?? t.mor1;
  if (s.startsWith('#')) return renkOku(s, varsayilan ?? t.mor1);
  final k = s.replaceAll('var(', '').replaceAll(')', '').replaceAll('--', '').replaceAll('t-', '').trim();
  switch (k) {
    case 'mor1':
    case 'mor':
    case 'mor2':
      return t.mor1;
    case 'kirmizi':
    case 'pred':
    case 'red':
    case 'rose':
      return t.kirmizi;
    case 'amber':
    case 'pamber':
      return t.amber;
    case 'yesil':
    case 'pgreen':
    case 'green':
      return t.yesil;
    case 'mavi':
    case 'pblue':
    case 'blue':
      return const Color(0xFF5B8DEF);
    case 'sub':
    case 'sub2':
      return t.sub;
    case 'pembe':
      return const Color(0xFFEC4899);
  }
  return varsayilan ?? t.mor1;
}

/// Durum (risk/dikkat/iyi/notr) → (etiket, renk)
(String, Color) durumRenk(String d) {
  switch (d) {
    case 'risk':
      return ('RİSK', const Color(0xFFF43F5E));
    case 'dikkat':
      return ('DİKKAT', const Color(0xFFF59E0B));
    case 'iyi':
      return ('İYİ', const Color(0xFF10B981));
  }
  return ('NÖTR', const Color(0xFF64748B));
}

String _varlik(String s) => s
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&amp;', '&')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&#039;', "'");

/// Düz metin (HTML etiketleri ve ** işaretleri temizlenmiş)
String duzMetin(dynamic v) {
  var s = metinOku(v);
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s.replaceAll('**', '');
  return _varlik(s).trim();
}

/// HTML (<b>, <strong>, <br>) ve markdown (**kalın**, satır başı "- ") içeren metni zengin metne çevirir.
List<InlineSpan> zenginParcalar(String ham, TextStyle temel, {Color? vurgu}) {
  var s = ham.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<\s*(b|strong)\s*>', caseSensitive: false), '**').replaceAll(RegExp(r'<\s*/\s*(b|strong)\s*>', caseSensitive: false), '**');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = _varlik(s);
  s = s.replaceAllMapped(RegExp(r'^[ \t]*[-*•]\s+', multiLine: true), (_) => '•  ');
  final parcalar = s.split('**');
  return [
    for (var i = 0; i < parcalar.length; i++)
      if (parcalar[i].isNotEmpty)
        TextSpan(
          text: parcalar[i],
          style: i.isOdd ? temel.copyWith(fontWeight: FontWeight.w700, color: vurgu ?? temel.color) : temel,
        ),
  ];
}

class ZenginMetin extends StatelessWidget {
  final String metin;
  final TextStyle stil;
  final int? maxSatir;
  const ZenginMetin(this.metin, {super.key, required this.stil, this.maxSatir});
  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(children: zenginParcalar(metin, stil)),
        maxLines: maxSatir,
        overflow: maxSatir == null ? null : TextOverflow.ellipsis,
      );
}

/// Web yoluna git: telefon / dış bağlantı → sistem; iç yol → uygulamadaki ekranı (EkranKayit) aç.
Future<void> aiGit(BuildContext context, String? url, {String baslik = ''}) async {
  final u = metinOku(url);
  if (u.isEmpty || u == '#') return;
  if (u.startsWith('tel:') || u.startsWith('mailto:')) {
    await launchUrl(Uri.parse(u));
    return;
  }
  if (u.startsWith('http://') || u.startsWith('https://')) {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    return;
  }
  if (!context.mounted) return;
  final ad = baslik.isEmpty ? _yolBaslik(u) : baslik;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(u.startsWith('/') ? u : '/$u', ad)));
}

/// Sunucudaki göreli dosya (ses kaydı vb.) → tam adres
String tamAdres(String yol) => yol.startsWith('http') ? yol : '${AppConfig.baseUrl}${yol.startsWith('/') ? '' : '/'}$yol';

String _yolBaslik(String u) {
  final y = u.split('?').first.replaceAll('/', ' ').replaceAll('-', ' ').trim();
  if (y.isEmpty) return 'Sayfa';
  return y[0].toUpperCase() + y.substring(1);
}

/// JSON POST (AI uçları). Uç yetkisiz kişiye 401 döndürse bile oturumu KAPATMAZ (uygulama çıkışı yerine "yetkiniz yok" der).
Future<KopruCevap> aiPost(BuildContext context, String yol, Map<String, dynamic> veri, {bool form = false}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return KopruCevap(0, {'ok': 0, 'hata': 'Oturum bulunamadı.'});
  try {
    return form ? await KopruApi.gonder(tok, yol, veri) : await KopruApi.gonderJson(tok, yol, veri);
  } on ApiYetkiHatasi {
    return KopruCevap(401, {'ok': 0, 'hata': 'Bu işlem için yetkiniz yok.'});
  }
}

/// JSON GET (AI uçları) — 401'de oturumu kapatmaz.
Future<KopruCevap> aiAl(BuildContext context, String yol, {Map<String, String>? q}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return KopruCevap(0, {'ok': 0, 'hata': 'Oturum bulunamadı.'});
  try {
    return await KopruApi.al(tok, yol, q: q);
  } on ApiYetkiHatasi {
    return KopruCevap(401, {'ok': 0, 'hata': 'Bu bilgi için yetkiniz yok.'});
  }
}

/// Cevaptaki mesajı oku (uçlar 'mesaj' ya da 'hata' döndürür)
String cevapMesaj(KopruCevap c, {String basari = 'İşlem yapıldı.', String hata = 'İşlem yapılamadı.'}) {
  final m = metinOku(c.j['mesaj']);
  if (m.isNotEmpty) return m;
  if (c.ok) return basari;
  return metinOku(c.j['hata'], hata);
}

/// Saate göre selam
String selamMetni() {
  final h = DateTime.now().hour;
  return h < 5 ? 'İyi geceler' : (h < 11 ? 'Günaydın' : (h < 18 ? 'İyi günler' : 'İyi akşamlar'));
}

const _gunAd = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
const _ayAd = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

/// "Cuma, 20 Kasım"
String bugunMetni([DateTime? d]) {
  final x = d ?? DateTime.now();
  return '${_gunAd[x.weekday - 1]}, ${x.day} ${_ayAd[x.month - 1]}';
}

String ayAdi(int ay) => _ayAd[(ay - 1).clamp(0, 11)];
String gunAdi(int weekday) => _gunAd[(weekday - 1).clamp(0, 6)];

/// Küçük bölüm başlığı (büyük harfli, ikonlu)
class AiBolum extends StatelessWidget {
  final String metin;
  final IconData ikon;
  final Color? renk;
  final Widget? sag;
  const AiBolum(this.metin, {super.key, required this.ikon, this.renk, this.sag});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(children: [
        Icon(ikon, size: 20, color: renk ?? t.mor1),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w800))),
        ?sag,
      ]),
    );
  }
}

/// Sütunlu ızgara: genişliğe göre n sütun (telefonda 1)
class AiIzgara extends StatelessWidget {
  final List<Widget> cocuklar;
  final double minGenislik;
  final double ara;
  const AiIzgara({super.key, required this.cocuklar, this.minGenislik = 320, this.ara = 10});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (c, k) {
      final n = (k.maxWidth / minGenislik).floor().clamp(1, 4);
      final g = (k.maxWidth - ara * (n - 1)) / n;
      return Wrap(spacing: ara, runSpacing: ara, children: [for (final x in cocuklar) SizedBox(width: g, child: x)]);
    });
  }
}
