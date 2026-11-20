import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import 'masaustu_kit.dart';

/// ResteOS ORTAK TASARIM KİTİ — web panelden taşınan tüm ekranlar bu parçalarla yapılır.
/// Kurallar: renkler TemaProvider'dan (gece/gündüz birlikte döner); 14px ve altı yazı en fazla w700;
/// her liste boşsa NEDENİNİ söyler (KBos); her hata "Tekrar dene" verir (KHata); dokunma hedefi ≥ 44px.

// ───────────────────────── biçim yardımcıları ─────────────────────────
final NumberFormat _tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final NumberFormat _tl0 = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);
final NumberFormat _sayi = NumberFormat.decimalPattern('tr_TR');

double sayiOku(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(' ', '').replaceAll(',', '.')) ?? 0;
}

int tamOku(dynamic v) => sayiOku(v).round();

String metinOku(dynamic v, [String bos = '']) {
  if (v == null) return bos;
  final s = '$v'.trim();
  return s.isEmpty || s == 'null' ? bos : s;
}

/// 1234.5 → "1.234,50 ₺" ; kisa: "1.235 ₺"
String tl(dynamic v, {bool kisa = false}) => (kisa ? _tl0 : _tl).format(sayiOku(v));

/// Binlik ayraçlı sayı (ondalık varsa en fazla 2 hane)
String sayiYaz(dynamic v) {
  final d = sayiOku(v);
  if (d == d.roundToDouble()) return _sayi.format(d.round());
  return NumberFormat('#,##0.##', 'tr_TR').format(d);
}

String yuzde(dynamic v) => '%${NumberFormat('0.#', 'tr_TR').format(sayiOku(v))}';

/// "2026-11-20 14:05:00" → "20.11.2026 14:05" (saat yoksa yalnız tarih)
String tarihYaz(dynamic v, {bool saat = true}) {
  final s = metinOku(v);
  if (s.isEmpty) return '—';
  final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
  if (d == null) return s;
  final saatVar = saat && s.length > 10 && !(d.hour == 0 && d.minute == 0 && s.contains('00:00:00'));
  return DateFormat(saatVar ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy', 'tr_TR').format(d);
}

/// "#7C3AED" / "7C3AED" → Color (geçersizse varsayılan)
Color renkOku(dynamic v, [Color varsayilan = const Color(0xFF7C3AED)]) {
  final s = metinOku(v).replaceAll('#', '');
  if (s.length == 6) {
    final n = int.tryParse(s, radix: 16);
    if (n != null) return Color(0xFF000000 | n);
  }
  if (s.startsWith('var(')) return varsayilan;
  return varsayilan;
}

// ───────────────────────── sayfa kabuğu ─────────────────────────
/// Push ile açılan her ekranın kabuğu: başlık + geri + sağ araçlar + gövde (telefon/masaüstü uyumlu).
class KSayfa extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  final String? altBaslik;
  final List<Widget> araclar;
  final Widget govde;
  final Widget? fab;
  const KSayfa({super.key, required this.baslik, required this.govde, this.ikon = Icons.dashboard_outlined, this.altBaslik, this.araclar = const [], this.fab});

  @override
  Widget build(BuildContext context) {
    final geri = Navigator.of(context).canPop();
    final s = MasaustuSayfa(baslik: baslik, ikon: ikon, altBaslik: altBaslik, araclar: araclar, govde: govde, geri: geri);
    if (fab == null) return s;
    return Stack(children: [s, Positioned(right: 18, bottom: 18 + MediaQuery.of(context).padding.bottom, child: fab!)]);
  }
}

/// İçerik genişliği sınırlı, ortalanmış kaydırılabilir gövde (masaüstünde satır çok uzamasın).
class KGovde extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? yenile;
  final EdgeInsets? padding;
  final double maxGenislik;
  const KGovde({super.key, required this.children, this.yenile, this.padding, this.maxGenislik = 1180});

  @override
  Widget build(BuildContext context) {
    final p = padding ?? EdgeInsets.fromLTRB(genisMi(context) ? 22 : 14, 14, genisMi(context) ? 22 : 14, 90);
    final liste = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: p,
      children: [
        Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxGenislik), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children))),
      ],
    );
    if (yenile == null) return liste;
    return RefreshIndicator(onRefresh: yenile!, child: liste);
  }
}

// ───────────────────────── kart / başlık ─────────────────────────
class KKart extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? renk;       // sol vurgu şeridi
  final VoidCallback? onTap;
  final EdgeInsets margin;
  const KKart({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.renk, this.onTap, this.margin = const EdgeInsets.only(bottom: 12)});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ic = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
        boxShadow: t.golge,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: renk == null
              ? ic
              : IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Container(width: 4, color: renk), Expanded(child: ic)])),
        ),
      ),
    );
  }
}

/// Bölüm başlığı (ikon + başlık + sağda isteğe bağlı aksiyon)
class KBaslik extends StatelessWidget {
  final String metin;
  final IconData? ikon;
  final Color? renk;
  final Widget? sag;
  final String? alt;
  const KBaslik(this.metin, {super.key, this.ikon, this.renk, this.sag, this.alt});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final r = renk ?? t.mor1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Row(children: [
        if (ikon != null) ...[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: r.withValues(alpha: .14), borderRadius: BorderRadius.circular(10)),
            child: Icon(ikon, size: 18, color: r),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metin, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            if (alt != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(alt!, style: TextStyle(color: t.sub, fontSize: 12.5))),
          ]),
        ),
        if (sag != null) sag!,
      ]),
    );
  }
}

// ───────────────────────── KPI / rozet ─────────────────────────
/// Tek gösterge kutusu: etiket + büyük değer + isteğe bağlı alt yazı
class KKpi extends StatelessWidget {
  final String etiket;
  final String deger;
  final String? alt;
  final IconData? ikon;
  final Color? renk;
  final VoidCallback? onTap;
  const KKpi({super.key, required this.etiket, required this.deger, this.alt, this.ikon, this.renk, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final r = renk ?? t.mor1;
    return Material(
      color: Color.alphaBlend(r.withValues(alpha: t.koyu ? .16 : .07), t.card),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: r.withValues(alpha: .28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              if (ikon != null) ...[Icon(ikon, size: 17, color: r), const SizedBox(width: 6)],
              Expanded(child: Text(etiket, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600))),
            ]),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(deger, style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.3)),
            ),
            if (alt != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(alt!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12))),
          ]),
        ),
      ),
    );
  }
}

/// KPI ızgarası: telefonda 2, tablette 3, masaüstünde 4-5 sütun
class KKpiIzgara extends StatelessWidget {
  final List<Widget> kutular;
  const KKpiIzgara(this.kutular, {super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final n = w >= 1050 ? 5 : (w >= 760 ? 4 : (w >= 520 ? 3 : 2));
      const ara = 10.0;
      final g = (w - ara * (n - 1)) / n;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(spacing: ara, runSpacing: ara, children: [for (final k in kutular) SizedBox(width: g, child: k)]),
      );
    });
  }
}

/// Durum rozeti (hap)
class KRozet extends StatelessWidget {
  final String metin;
  final Color renk;
  final IconData? ikon;
  const KRozet(this.metin, {super.key, required this.renk, this.ikon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: renk.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: renk.withValues(alpha: .35))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ikon != null) ...[Icon(ikon, size: 13, color: renk), const SizedBox(width: 4)],
        Text(metin, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ───────────────────────── durum ekranları ─────────────────────────
/// Boş durum: ne eksik, neden, nereden girilir (ResteOS kuralı: boş liste nedenini söyler)
class KBos extends StatelessWidget {
  final String baslik;
  final String? aciklama;
  final IconData ikon;
  final Widget? aksiyon;
  const KBos({super.key, required this.baslik, this.aciklama, this.ikon = Icons.inbox_outlined, this.aksiyon});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.card2, shape: BoxShape.circle),
          child: Icon(ikon, size: 34, color: t.sub),
        ),
        const SizedBox(height: 12),
        Text(baslik, textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
        if (aciklama != null) ...[
          const SizedBox(height: 6),
          Text(aciklama!, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13.5, height: 1.4)),
        ],
        if (aksiyon != null) ...[const SizedBox(height: 14), aksiyon!],
      ]),
    );
  }
}

class KHata extends StatelessWidget {
  final String mesaj;
  final VoidCallback? tekrar;
  final bool yetkisiz;
  const KHata(this.mesaj, {super.key, this.tekrar, this.yetkisiz = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: KBos(
        ikon: yetkisiz ? Icons.lock_outline : Icons.cloud_off_outlined,
        baslik: yetkisiz ? 'Bu ekran için yetkiniz yok' : 'Yüklenemedi',
        aciklama: yetkisiz ? 'Yetki işletme yöneticisi tarafından Personel & Yetki ekranından verilir.' : mesaj,
        aksiyon: (!yetkisiz && tekrar != null) ? KButon('Tekrar dene', ikon: Icons.refresh, onTap: tekrar) : null,
      ),
    );
  }
}

class KYukleniyor extends StatelessWidget {
  final String? metin;
  const KYukleniyor({super.key, this.metin});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: t.mor1)),
        if (metin != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(metin!, style: TextStyle(color: t.sub, fontSize: 13))),
      ]),
    );
  }
}

// ───────────────────────── butonlar ─────────────────────────
class KButon extends StatelessWidget {
  final String metin;
  final IconData? ikon;
  final VoidCallback? onTap;
  final Color? renk;
  final bool ikincil;
  final bool yukleniyor;
  final bool genis;
  const KButon(this.metin, {super.key, this.ikon, this.onTap, this.renk, this.ikincil = false, this.yukleniyor = false, this.genis = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final r = renk ?? t.mor1;
    final ic = Row(mainAxisSize: genis ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (yukleniyor)
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ikincil ? r : Colors.white))
      else if (ikon != null)
        Icon(ikon, size: 18, color: ikincil ? r : Colors.white),
      if (yukleniyor || ikon != null) const SizedBox(width: 8),
      Flexible(child: Text(metin, overflow: TextOverflow.ellipsis, style: TextStyle(color: ikincil ? r : Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
    ]);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Material(
        color: ikincil ? r.withValues(alpha: .10) : (onTap == null ? r.withValues(alpha: .45) : r),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: yukleniyor ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: ikincil ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: r.withValues(alpha: .35))) : null,
            child: ic,
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── filtre çipleri / arama ─────────────────────────
class KCipler extends StatelessWidget {
  final List<(String, String)> secenekler; // (anahtar, etiket)
  final String secili;
  final ValueChanged<String> onSec;
  const KCipler({super.key, required this.secenekler, required this.secili, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        for (final (k, e) in secenekler)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: k == secili ? Colors.white : t.sub2)),
              selected: k == secili,
              onSelected: (_) => onSec(k),
              selectedColor: t.mor1,
              backgroundColor: t.card,
              side: BorderSide(color: k == secili ? t.mor1 : t.line),
              showCheckmark: false,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
            ),
          ),
      ]),
    );
  }
}

class KAra extends StatelessWidget {
  final String ipucu;
  final ValueChanged<String> onDegis;
  final TextEditingController? kontrol;
  const KAra({super.key, this.ipucu = 'Ara…', required this.onDegis, this.kontrol});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: kontrol,
        onChanged: onDegis,
        style: TextStyle(color: t.ink, fontSize: 15),
        decoration: InputDecoration(
          hintText: ipucu,
          hintStyle: TextStyle(color: t.sub),
          prefixIcon: Icon(Icons.search, color: t.sub),
          filled: true,
          fillColor: t.card,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: t.mor1, width: 1.6)),
        ),
      ),
    );
  }
}

// ───────────────────────── liste satırı ─────────────────────────
class KSatir extends StatelessWidget {
  final String baslik;
  final String? alt;
  final Widget? solIkon;
  final Widget? sag;
  final VoidCallback? onTap;
  final bool cizgi;
  const KSatir({super.key, required this.baslik, this.alt, this.solIkon, this.sag, this.onTap, this.cizgi = true});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        decoration: cizgi ? BoxDecoration(border: Border(bottom: BorderSide(color: t.line.withValues(alpha: .7)))) : null,
        child: Row(children: [
          if (solIkon != null) ...[solIkon!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslik, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
              if (alt != null && alt!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(alt!, style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.3))),
            ]),
          ),
          if (sag != null) ...[const SizedBox(width: 10), sag!],
        ]),
      ),
    );
  }
}

/// Yuvarlak renkli ikon kutusu (liste sol tarafı)
class KIkon extends StatelessWidget {
  final IconData ikon;
  final Color renk;
  final double boyut;
  const KIkon(this.ikon, {super.key, required this.renk, this.boyut = 38});
  @override
  Widget build(BuildContext context) => Container(
        width: boyut,
        height: boyut,
        decoration: BoxDecoration(color: renk.withValues(alpha: .14), borderRadius: BorderRadius.circular(boyut * .3)),
        child: Icon(ikon, color: renk, size: boyut * .52),
      );
}

// ───────────────────────── tablo ─────────────────────────
/// Basit tablo: başlıklar + satırlar. Telefonda yatay kaydırılır; sayısal sütunlar sağa yaslı.
class KTablo extends StatelessWidget {
  final List<String> basliklar;
  final List<List<String>> satirlar;
  final Set<int> sagaYasla;
  final void Function(int satir)? onSatir;
  const KTablo({super.key, required this.basliklar, required this.satirlar, this.sagaYasla = const {}, this.onSatir});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (satirlar.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 40,
        dataRowMinHeight: 42,
        dataRowMaxHeight: 64,
        horizontalMargin: 10,
        columnSpacing: 22,
        headingTextStyle: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w700),
        dataTextStyle: TextStyle(color: t.ink, fontSize: 13.5),
        showCheckboxColumn: false,
        columns: [for (var i = 0; i < basliklar.length; i++) DataColumn(label: Text(basliklar[i]), numeric: sagaYasla.contains(i))],
        rows: [
          for (var r = 0; r < satirlar.length; r++)
            DataRow(
              onSelectChanged: onSatir == null ? null : (_) => onSatir!(r),
              cells: [
                for (var i = 0; i < basliklar.length; i++)
                  DataCell(ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Text(i < satirlar[r].length ? satirlar[r][i] : '', maxLines: 3, overflow: TextOverflow.ellipsis),
                  )),
              ],
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── bildirimler / onay ─────────────────────────
void kToast(BuildContext context, String mesaj, {bool hata = false}) {
  final m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(mesaj, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    backgroundColor: hata ? const Color(0xFFDC2626) : const Color(0xFF059669),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: Duration(seconds: hata ? 4 : 2),
  ));
}

Future<bool> kOnay(BuildContext context, String soru, {String evet = 'Evet', String hayir = 'Vazgeç', bool tehlikeli = false, String? aciklama}) async {
  final t = context.read<TemaProvider>();
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(soru, style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
      content: aciklama == null ? null : Text(aciklama, style: TextStyle(color: t.sub2, fontSize: 14, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(hayir, style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: tehlikeli ? const Color(0xFFDC2626) : t.mor1),
          onPressed: () => Navigator.pop(c, true),
          child: Text(evet, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  return r == true;
}

/// Alt sayfa (form) — telefonda alttan, masaüstünde ortada pencere
Future<T?> kAltSayfa<T>(BuildContext context, {required String baslik, required Widget Function(BuildContext) icerik}) {
  final t = context.read<TemaProvider>();
  Widget kabuk(BuildContext c) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 6),
          child: Row(children: [
            Expanded(child: Text(baslik, style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
            IconButton(onPressed: () => Navigator.pop(c), icon: Icon(Icons.close, color: t.sub)),
          ]),
        ),
        Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(18, 0, 18, 18), child: icerik(c))),
      ]);
  if (genisMi(context)) {
    return showDialog<T>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720), child: kabuk(c)),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: t.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom), child: kabuk(c)),
  );
}

/// Form alanı (etiketli metin kutusu)
class KAlan extends StatelessWidget {
  final String etiket;
  final TextEditingController kontrol;
  final String? ipucu;
  final TextInputType? klavye;
  final int satir;
  final bool zorunlu;
  const KAlan(this.etiket, this.kontrol, {super.key, this.ipucu, this.klavye, this.satir = 1, this.zorunlu = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(zorunlu ? '$etiket *' : etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: kontrol,
          keyboardType: klavye,
          maxLines: satir,
          style: TextStyle(color: t.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: ipucu,
            hintStyle: TextStyle(color: t.sub),
            filled: true,
            fillColor: t.card2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.mor1, width: 1.6)),
          ),
        ),
      ]),
    );
  }
}

/// Açılır seçim (etiketli)
class KSecim<T> extends StatelessWidget {
  final String etiket;
  final T? deger;
  final List<(T, String)> secenekler;
  final ValueChanged<T?> onSec;
  const KSecim(this.etiket, {super.key, required this.deger, required this.secenekler, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          initialValue: secenekler.any((s) => s.$1 == deger) ? deger : null,
          isExpanded: true,
          dropdownColor: t.card,
          style: TextStyle(color: t.ink, fontSize: 15),
          items: [for (final (v, e) in secenekler) DropdownMenuItem(value: v, child: Text(e, overflow: TextOverflow.ellipsis))],
          onChanged: onSec,
          decoration: InputDecoration(
            filled: true,
            fillColor: t.card2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
          ),
        ),
      ]),
    );
  }
}

/// Material icon adı (web menüsündeki 'inventory_2' vb.) → IconData. Bilinmeyen → varsayılan.
IconData ikonAdi(String? ad, [IconData varsayilan = Icons.circle_outlined]) => kIkonHaritasi[ad ?? ''] ?? varsayilan;

const Map<String, IconData> kIkonHaritasi = {
  'sell': Icons.sell_outlined,
  'card_giftcard': Icons.card_giftcard,
  'group': Icons.group_outlined,
  'beach_access': Icons.beach_access_outlined,
  'devices_other': Icons.devices_other_outlined,
  'bakery_dining': Icons.bakery_dining_outlined,
  'wb_sunny': Icons.wb_sunny_outlined, 'dashboard': Icons.dashboard_outlined, 'table_restaurant': Icons.table_restaurant_outlined,
  'soup_kitchen': Icons.soup_kitchen_outlined, 'event_available': Icons.event_available_outlined, 'delivery_dining': Icons.delivery_dining_outlined,
  'room_service': Icons.room_service_outlined, 'co_present': Icons.co_present_outlined, 'notifications_active': Icons.notifications_active_outlined,
  'cleaning_services': Icons.cleaning_services_outlined, 'security': Icons.security_outlined, 'build': Icons.build_outlined, 'wash': Icons.wash_outlined,
  'restaurant_menu': Icons.restaurant_menu_outlined, 'menu_book': Icons.menu_book_outlined, 'palette': Icons.palette_outlined, 'color_lens': Icons.color_lens_outlined,
  'local_offer': Icons.local_offer_outlined, 'local_bar': Icons.local_bar_outlined, 'dinner_dining': Icons.dinner_dining_outlined, 'qr_code': Icons.qr_code,
  'assignment': Icons.assignment_outlined, 'mark_email_read': Icons.mark_email_read_outlined, 'fact_check': Icons.fact_check_outlined, 'block': Icons.block,
  'inventory_2': Icons.inventory_2_outlined, 'auto_awesome': Icons.auto_awesome_outlined, 'shopping_cart_checkout': Icons.shopping_cart_checkout,
  'inventory': Icons.inventory_outlined, 'move_to_inbox': Icons.move_to_inbox_outlined, 'query_stats': Icons.query_stats, 'document_scanner': Icons.document_scanner_outlined,
  'event_note': Icons.event_note_outlined, 'payments': Icons.payments_outlined, 'request_quote': Icons.request_quote_outlined, 'local_shipping': Icons.local_shipping_outlined,
  'timelapse': Icons.timelapse, 'account_balance': Icons.account_balance_outlined, 'store': Icons.store_outlined, 'radar': Icons.radar,
  'storefront': Icons.storefront_outlined, 'leaderboard': Icons.leaderboard_outlined, 'grading': Icons.grading, 'receipt_long': Icons.receipt_long_outlined,
  'handshake': Icons.handshake_outlined, 'approval': Icons.approval_outlined, 'account_balance_wallet': Icons.account_balance_wallet_outlined,
  'smart_toy': Icons.smart_toy_outlined, 'warning_amber': Icons.warning_amber_outlined, 'qr_code_scanner': Icons.qr_code_scanner, 'alternate_email': Icons.alternate_email,
  'apps': Icons.apps, 'badge': Icons.badge_outlined, 'schedule': Icons.schedule, 'emoji_events': Icons.emoji_events_outlined, 'space_dashboard': Icons.space_dashboard_outlined,
  'qr_code_2': Icons.qr_code_2, 'map': Icons.map_outlined, 'shield': Icons.shield_outlined, 'chat': Icons.chat_outlined, 'forum': Icons.forum_outlined,
  'my_location': Icons.my_location, 'print': Icons.print_outlined, 'devices': Icons.devices_outlined, 'gavel': Icons.gavel, 'rule_folder': Icons.rule_folder_outlined,
  'history': Icons.history, 'verified_user': Icons.verified_user_outlined, 'groups': Icons.groups_outlined, 'calendar_month': Icons.calendar_month_outlined,
  'crisis_alert': Icons.crisis_alert, 'how_to_reg': Icons.how_to_reg_outlined, 'analytics': Icons.analytics_outlined, 'bar_chart': Icons.bar_chart, 'sync_alt': Icons.sync_alt,
  'balance': Icons.balance, 'description': Icons.description_outlined, 'event_repeat': Icons.event_repeat, 'percent': Icons.percent, 'summarize': Icons.summarize_outlined,
  'hourglass_bottom': Icons.hourglass_bottom, 'trending_down': Icons.trending_down, 'book': Icons.book_outlined, 'campaign': Icons.campaign_outlined,
  'celebration': Icons.celebration_outlined, 'person_search': Icons.person_search_outlined, 'workspace_premium': Icons.workspace_premium_outlined,
  'person_off': Icons.person_off_outlined, 'sentiment_satisfied': Icons.sentiment_satisfied_outlined, 'loyalty': Icons.loyalty_outlined, 'reviews': Icons.reviews_outlined,
  'share': Icons.share_outlined, 'casino': Icons.casino_outlined, 'lunch_dining': Icons.lunch_dining_outlined, 'checklist': Icons.checklist, 'science': Icons.science_outlined,
  'pest_control': Icons.pest_control_outlined, 'warning': Icons.warning_amber_outlined, 'verified': Icons.verified_outlined, 'policy': Icons.policy_outlined,
  'kitchen': Icons.kitchen_outlined, 'cake': Icons.cake_outlined, 'kebab_dining': Icons.kebab_dining_outlined, 'restaurant': Icons.restaurant, 'event_seat': Icons.event_seat_outlined,
  'timer': Icons.timer_outlined, 'auto_graph': Icons.auto_graph, 'delete_sweep': Icons.delete_sweep_outlined, 'blender': Icons.blender_outlined,
  'health_and_safety': Icons.health_and_safety_outlined, 'cancel': Icons.cancel_outlined, 'call': Icons.call_outlined, 'contact_phone': Icons.contact_phone_outlined,
  'phone_in_talk': Icons.phone_in_talk_outlined, 'phone_forwarded': Icons.phone_forwarded_outlined, 'school': Icons.school_outlined, 'manage_accounts': Icons.manage_accounts_outlined,
  'swap_horiz': Icons.swap_horiz, 'point_of_sale': Icons.point_of_sale, 'apartment': Icons.apartment, 'shopping_cart': Icons.shopping_cart_outlined, 'insights': Icons.insights,
  'event_seat_outlined': Icons.event_seat_outlined, 'support_agent': Icons.support_agent, 'diversity_3': Icons.diversity_3_outlined, 'computer': Icons.computer,
  'settings': Icons.settings_outlined, 'folder_open': Icons.folder_open_outlined, 'tune': Icons.tune, 'folder': Icons.folder_outlined, 'trending_up': Icons.trending_up,
  'people': Icons.people_outline, 'person': Icons.person_outline, 'savings': Icons.savings_outlined, 'local_atm': Icons.local_atm, 'inventory_2_outlined': Icons.inventory_2_outlined,
};
