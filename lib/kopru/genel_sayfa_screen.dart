import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../ui/kit.dart';
import 'kopru_ekran.dart';

/// GENEL SAYFA — uygulamada özel tasarımı olmayan web sayfasının verisini düzenli gösterir
/// (sayılar KPI, bilgiler satır, listeler kart). Veri ve yetki web'dekiyle aynıdır; menüde hiçbir
/// bağlantı boş açılmaz. Özel ekran yazılınca EkranKayit onu kullanır.
class GenelSayfaScreen extends StatelessWidget {
  final String url;
  final String baslik;
  const GenelSayfaScreen({super.key, required this.url, required this.baslik});

  @override
  Widget build(BuildContext context) {
    final yol = url.split('?').first;
    final q = Uri.parse(url).queryParameters;
    return KopruEkran(
      yol: yol,
      q: q.isEmpty ? null : q,
      baslik: baslik,
      ikon: Icons.article_outlined,
      govde: (ctx, v, yenile) => KGovde(yenile: yenile, children: GenelVeriGorunum.parcalar(ctx, v)),
    );
  }
}

class GenelVeriGorunum {
  static const _atla = {'title', 'sayfa_baslik', 'baslik', 'path', 'aktifMi', 'csrf', 'token', 'ustHtml', 'gorsel', 'html', 'svg', 'js', 'css'};
  static const _baslikAnahtarlari = ['ad', 'baslik', 'isim', 'name', 'urun_adi', 'urun', 'malzeme', 'malzeme_adi', 'musteri', 'musteri_adi', 'tedarikci', 'personel', 'masa', 'konu', 'aciklama', 'tip'];

  static String etiket(String k) {
    final s = k.replaceAll('_', ' ').replaceAllMapped(RegExp(r'([a-zçğıöşü])([A-ZÇĞİÖŞÜ])'), (m) => '${m[1]} ${m[2]}').trim();
    if (s.isEmpty) return k;
    return s[0].toUpperCase() + s.substring(1);
  }

  static bool _htmlMi(String s) => s.length > 600 || s.contains('<div') || s.contains('<svg') || s.contains('<span') || s.contains('<table');
  static bool _paraMi(String k) => RegExp(r'(tutar|toplam|fiyat|bakiye|ciro|maliyet|borc|alacak|odeme|gelir|gider|kar|tl)$|_tl$|tutari', caseSensitive: false).hasMatch(k);

  static String deger(String k, dynamic v) {
    if (v == null) return '—';
    if (v is bool) return v ? 'Evet' : 'Hayır';
    if (v is num) return _paraMi(k) ? tl(v) : sayiYaz(v);
    final s = '$v';
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) return tarihYaz(s);
    if (_paraMi(k) && double.tryParse(s) != null) return tl(s);
    return s;
  }

  static List<Widget> parcalar(BuildContext context, Map<String, dynamic> v, {int derinlik = 0}) {
    final t = context.watch<TemaProvider>();
    final kpi = <Widget>[];
    final bilgi = <Widget>[];
    final bolumler = <Widget>[];
    v.forEach((k, x) {
      if (k.startsWith('_') || _atla.contains(k)) return;
      if (x == null) return;
      if (x is num) {
        kpi.add(KKpi(etiket: etiket(k), deger: deger(k, x)));
      } else if (x is bool) {
        bilgi.add(KSatir(baslik: etiket(k), sag: KRozet(x ? 'Evet' : 'Hayır', renk: x ? t.yesil : t.sub)));
      } else if (x is String) {
        if (x.isEmpty || _htmlMi(x)) return;
        bilgi.add(KSatir(baslik: etiket(k), alt: deger(k, x)));
      } else if (x is List) {
        final maps = liste(x);
        if (maps.isNotEmpty) {
          bolumler.add(KBaslik(etiket(k), ikon: Icons.list_alt, alt: '${maps.length} kayıt'));
          bolumler.add(_ListeGorunum(kayitlar: maps));
        } else if (x.isNotEmpty && x.every((e) => e is String || e is num)) {
          bolumler.add(KBaslik(etiket(k), ikon: Icons.label_outline));
          bolumler.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [for (final e in x.take(60)) KRozet('$e', renk: t.mavi)]),
          ));
        }
      } else if (x is Map && derinlik < 2) {
        final m = harita(x);
        if (m.isEmpty) return;
        // Değerleri liste olan harita (ör. kategoriye göre gruplu) → her grup bir liste
        if (m.values.every((e) => e is List)) {
          bolumler.add(KBaslik(etiket(k), ikon: Icons.folder_open_outlined));
          for (final e in m.entries) {
            final l = liste(e.value);
            if (l.isEmpty) continue;
            bolumler.add(Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(etiket(e.key), style: TextStyle(color: t.sub2, fontSize: 13.5, fontWeight: FontWeight.w700))));
            bolumler.add(_ListeGorunum(kayitlar: l));
          }
          return;
        }
        final ic = parcalar(context, m, derinlik: derinlik + 1);
        if (ic.isEmpty) return;
        bolumler.add(KBaslik(etiket(k), ikon: Icons.folder_open_outlined));
        bolumler.addAll(ic);
      }
    });
    final o = <Widget>[];
    if (kpi.isNotEmpty) o.add(KKpiIzgara(kpi));
    if (bilgi.isNotEmpty) o.add(KKart(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: bilgi)));
    o.addAll(bolumler);
    if (o.isEmpty && derinlik == 0) o.add(const KBos(baslik: 'Gösterilecek kayıt yok', aciklama: 'Bu ekranda henüz veri girilmemiş.'));
    return o;
  }
}

class _ListeGorunum extends StatefulWidget {
  final List<Map<String, dynamic>> kayitlar;
  const _ListeGorunum({required this.kayitlar});
  @override
  State<_ListeGorunum> createState() => _ListeGorunumState();
}

class _ListeGorunumState extends State<_ListeGorunum> {
  int _goster = 20;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final l = widget.kayitlar;
    return KKart(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in l.take(_goster)) _satir(t, r),
        if (l.length > _goster)
          TextButton(onPressed: () => setState(() => _goster += 40), child: Text('Daha fazla göster (${l.length - _goster})', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _satir(TemaProvider t, Map<String, dynamic> r) {
    String? bAnahtar;
    for (final a in GenelVeriGorunum._baslikAnahtarlari) {
      if (r[a] is String && (r[a] as String).trim().isNotEmpty) { bAnahtar = a; break; }
    }
    bAnahtar ??= r.keys.firstWhere((k) => r[k] is String && (r[k] as String).isNotEmpty && !GenelVeriGorunum._htmlMi(r[k] as String), orElse: () => '');
    final baslik = bAnahtar.isEmpty ? '#${r['id'] ?? ''}' : '${r[bAnahtar]}';
    String? sagDeger;
    final alt = <String>[];
    r.forEach((k, v) {
      if (k == bAnahtar || k == 'id' || k.endsWith('_id') || k.startsWith('_') || v == null) return;
      if (v is Map || v is List) return;
      if (v is String && (v.isEmpty || GenelVeriGorunum._htmlMi(v))) return;
      if (sagDeger == null && GenelVeriGorunum._paraMi(k)) { sagDeger = GenelVeriGorunum.deger(k, v); return; }
      if (alt.length < 4) alt.add('${GenelVeriGorunum.etiket(k)}: ${GenelVeriGorunum.deger(k, v)}');
    });
    return KSatir(
      baslik: baslik,
      alt: alt.join(' · '),
      sag: sagDeger == null ? null : Text(sagDeger!, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
    );
  }
}
