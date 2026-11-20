import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /qr-menu-rengi (iframe → /tema) — restoranın QR menü teması: hazır kartela, özel marka rengi
/// (elle ya da LOGODAN otomatik), QR menü varsayılan modu (koyu/açık) ve canlı önizleme.
/// Veri/kayıt: /api/patron/tema, /api/patron/tema-kaydet, /api/patron/tema-mod (oturumdaki şube; yetki sunucuda).
/// Eski TemaSecimScreen'de "logodan renk al" yoktu → bu ekran onun yerine yazıldı.
class MenuQrRengiScreen extends StatelessWidget {
  const MenuQrRengiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/api/patron/tema',
      baslik: 'QR Menü Rengi',
      ikon: Icons.color_lens_outlined,
      altBaslik: 'Restoranın QR menü temasını seç — anında kaydedilir',
      govde: (ctx, v, yenile) => _Govde(veri: v, yenile: yenile),
      araclar: (ctx, v, yenile) => [
        IconButton(tooltip: 'QR menüyü önizle', icon: const Icon(Icons.open_in_new), onPressed: () => _onizle(ctx)),
      ],
    );
  }

  static Future<void> _onizle(BuildContext context) async {
    final sid = context.read<AuthProvider>().subeId;
    final u = Uri.parse('${AppConfig.baseUrl}/menu-onizle${sid != null ? '?sube=$sid' : ''}');
    if (!await launchUrl(u, mode: LaunchMode.externalApplication) && context.mounted) {
      kToast(context, 'Önizleme açılamadı (önce en az bir masa eklenmeli).', hata: true);
    }
  }
}

/// Logodaki baskın canlı renk (web _logoRenk ile aynı: 48x48, beyaz/siyah/gri elenir, en doygun kova)
Future<String?> logodanRenk(Uint8List bayt) async {
  try {
    final codec = await ui.instantiateImageCodec(bayt, targetWidth: 48, targetHeight: 48);
    final fr = await codec.getNextFrame();
    final bd = await fr.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return null;
    final d = bd.buffer.asUint8List();
    final kova = <int, List<double>>{}; // anahtar → [n, r, g, b, doygunluk]
    for (var i = 0; i + 3 < d.length; i += 4) {
      final r = d[i], g = d[i + 1], b = d[i + 2], a = d[i + 3];
      if (a < 128) continue;
      final mx = [r, g, b].reduce((x, y) => x > y ? x : y);
      final mn = [r, g, b].reduce((x, y) => x < y ? x : y);
      final sat = mx == 0 ? 0.0 : (mx - mn) / mx;
      final lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      if (lum > 0.92 || lum < 0.08 || sat < 0.18) continue;
      final k = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      final o = kova.putIfAbsent(k, () => [0, 0, 0, 0, 0]);
      o[0] += 1;
      o[1] += r;
      o[2] += g;
      o[3] += b;
      o[4] += sat;
    }
    List<double>? en;
    for (final o in kova.values) {
      if (en == null || o[4] > en[4]) en = o;
    }
    if (en == null) return null;
    String hx(double v) => v.round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
    return '#${hx(en[1] / en[0])}${hx(en[2] / en[0])}${hx(en[3] / en[0])}';
  } catch (_) {
    return null;
  }
}

class _Govde extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _Govde({required this.veri, required this.yenile});

  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  late final TextEditingController _ana;
  late final TextEditingController _detay;
  bool _detayAyri = false;
  Uint8List? _logo;
  String? _isleniyor; // kaydedilen tema anahtarı

  static const List<String> _palet = [
    '#C41E3A', '#E8541E', '#F59E0B', '#16A34A', '#0D9488', '#2563EB', '#4F46E5', '#7C3AED', '#DB2777', '#78350F', '#1E293B', '#E9C46A',
  ];

  @override
  void initState() {
    super.initState();
    final r2 = metinOku(widget.veri['renk2']);
    _ana = TextEditingController(text: metinOku(widget.veri['renk'], '#C41E3A'));
    _detay = TextEditingController(text: r2.isEmpty ? '#E9C46A' : r2);
    _detayAyri = r2.isNotEmpty;
  }

  @override
  void dispose() {
    _ana.dispose();
    _detay.dispose();
    super.dispose();
  }

  bool get _duzenle => widget.veri['duzenleyebilir'] != false;

  Future<void> _sec(String key, {String? renk, String? renk2}) async {
    setState(() => _isleniyor = key);
    final ok = await kopruGonder(context, '/api/patron/tema-kaydet', {
      'tema': key,
      'renk': ?renk,
      'renk2': ?renk2,
    }, basariMesaji: 'QR menü teması kaydedildi.');
    if (!mounted) return;
    setState(() => _isleniyor = null);
    if (ok) widget.yenile();
  }

  Future<void> _mod(String mod) async {
    if (await kopruGonder(context, '/api/patron/tema-mod', {'mod': mod}, basariMesaji: mod == 'acik' ? 'QR menü açık modda açılacak.' : 'QR menü koyu modda açılacak.')) {
      widget.yenile();
    }
  }

  Future<void> _logoSec() async {
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 600);
    } catch (_) {}
    if (x == null) return;
    final b = await x.readAsBytes();
    final r = await logodanRenk(b);
    if (!mounted) return;
    setState(() {
      _logo = b;
      if (r != null) _ana.text = r;
    });
    if (r != null) {
      kToast(context, 'Logodan renk alındı: $r — kaydetmek için "Uygula"ya basın.');
    } else {
      kToast(context, 'Logodan belirgin bir renk bulunamadı. Rengi elle seçebilirsiniz.', hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final temalar = liste(widget.veri['temalar']);
    final secili = metinOku(widget.veri['secili'], 'altin');
    final mod = metinOku(widget.veri['mod'], 'koyu');
    final ozelSecili = secili == 'ozel';

    Widget temaKart(Map<String, dynamic> m) {
      final key = metinOku(m['key']);
      final sec = key == secili;
      final c1 = hexRenk(metinOku(m['ana'])) ?? t.mor1;
      final c2 = hexRenk(metinOku(m['ana3'])) ?? c1;
      final ink = hexRenk(metinOku(m['ink'])) ?? Colors.white;
      return Material(
        color: const Color(0xFF171319),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: !_duzenle || _isleniyor != null || sec ? null : () => _sec(key),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: sec ? c1 : const Color(0x22FFFFFF), width: sec ? 2.2 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                height: 54,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(colors: [c1, c2])),
                alignment: Alignment.center,
                child: _isleniyor == key
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
                    : Text(metinOku(m['emoji']), style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(metinOku(m['ad'], key), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF3E9EE), fontSize: 13.5, fontWeight: FontWeight.w700))),
                if (sec) Icon(Icons.check_circle, size: 18, color: c1),
              ]),
            ]),
          ),
        ),
      );
    }

    Widget renkSatir(String etiket, TextEditingController ctl) {
      final r = hexRenk(ctl.text);
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: r ?? t.card2, borderRadius: BorderRadius.circular(11), border: Border.all(color: t.line))),
            const SizedBox(width: 10),
            SizedBox(
              width: 130,
              child: TextField(
                controller: ctl,
                enabled: _duzenle,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: t.card2,
                  hintText: '#RRGGBB',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: t.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: t.line)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in _palet)
              InkWell(
                onTap: _duzenle ? () => setState(() => ctl.text = p) : null,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: hexRenk(p),
                    shape: BoxShape.circle,
                    border: Border.all(color: ctl.text.toUpperCase() == p ? t.ink : t.line, width: ctl.text.toUpperCase() == p ? 2.4 : 1),
                  ),
                ),
              ),
          ]),
        ]),
      );
    }

    final anaR = hexRenk(_ana.text);
    final detR = _detayAyri ? hexRenk(_detay.text) : anaR;

    return KGovde(yenile: widget.yenile, maxGenislik: 980, children: [
      if (!_duzenle)
        KKart(
          renk: t.amber,
          child: Text('Temayı yalnız işletme sahibi / yönetici değiştirebilir. Mevcut seçimi görüntülüyorsunuz.', style: TextStyle(color: t.sub2, fontSize: 13)),
        ),
      KBaslik('QR menü açılış modu', ikon: Icons.brightness_6_outlined, alt: 'Müşteri kendi cihazında yine değiştirebilir'),
      KCipler(
        secenekler: const [('koyu', '🌙  Koyu'), ('acik', '☀️  Açık')],
        secili: mod,
        onSec: (k) {
          if (_duzenle && k != mod) _mod(k);
        },
      ),
      const SizedBox(height: 6),
      KBaslik('Hazır temalar', ikon: Icons.palette_outlined, alt: 'Dokunun — anında kaydedilir'),
      if (temalar.isEmpty)
        const KBos(baslik: 'Tema listesi gelmedi', aciklama: 'Sunucu tema kartelasını döndürmedi; yenileyip tekrar deneyin.', ikon: Icons.palette_outlined)
      else
        LayoutBuilder(builder: (c, s) {
          final sutun = s.maxWidth >= 900 ? 5 : (s.maxWidth >= 600 ? 4 : (s.maxWidth >= 380 ? 3 : 2));
          final w = (s.maxWidth - (sutun - 1) * 10) / sutun;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final m in temalar) SizedBox(width: w, child: temaKart(m))]);
        }),
      const SizedBox(height: 18),
      KKart(
        renk: ozelSecili ? (anaR ?? t.mor1) : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.brush_outlined, color: t.gold),
            const SizedBox(width: 8),
            Expanded(child: Text('Kendi markanın rengi', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
            if (ozelSecili) KRozet('Seçili', renk: t.yesil, ikon: Icons.check),
          ]),
          const SizedBox(height: 4),
          Text('Markanızın rengini seçin ya da logonuzu yükleyin — sistem logodaki baskın rengi bulup otomatik uygular.', style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)),
          const SizedBox(height: 12),
          // önizleme şeridi
          Container(
            height: 46,
            decoration: BoxDecoration(color: const Color(0xFF171319), borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text('Ürün adı', style: TextStyle(color: detR ?? t.gold, fontSize: 14, fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(color: anaR ?? t.mor1, borderRadius: BorderRadius.circular(99)),
                child: const Text('Sepete ekle', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          renkSatir('Ana renk (butonlar)', _ana),
          MenuAnahtar(
            baslik: 'Detay rengi ayrı olsun',
            alt: 'Kapalıysa detaylar (altın yerine) ana rengi kullanır',
            deger: _detayAyri,
            onDegis: (v) {
              if (_duzenle) setState(() => _detayAyri = v);
            },
          ),
          if (_detayAyri) renkSatir('Detay rengi (altın yerine)', _detay),
          if (_duzenle)
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              KButon('Logo yükle → rengi otomatik al', ikon: Icons.upload_outlined, ikincil: true, renk: t.gold, onTap: _logoSec),
              if (_logo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(color: Colors.white, padding: const EdgeInsets.all(4), child: Image.memory(_logo!, width: 40, height: 40, fit: BoxFit.contain)),
                ),
            ]),
          const SizedBox(height: 14),
          if (_duzenle)
            KButon('Bu rengi uygula', ikon: Icons.check, genis: true, renk: anaR, yukleniyor: _isleniyor == 'ozel', onTap: () {
              if (anaR == null) {
                kToast(context, 'Ana renk #RRGGBB biçiminde olmalı.', hata: true);
                return;
              }
              if (_detayAyri && hexRenk(_detay.text) == null) {
                kToast(context, 'Detay rengi #RRGGBB biçiminde olmalı.', hata: true);
                return;
              }
              _sec('ozel', renk: renkHex(anaR), renk2: _detayAyri ? renkHex(hexRenk(_detay.text)!) : '');
            }),
        ]),
      ),
      KButon('QR menüyü önizle', ikon: Icons.open_in_new, ikincil: true, genis: true, onTap: () => MenuQrRengiScreen._onizle(context)),
    ]);
  }
}
