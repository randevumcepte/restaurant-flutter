import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';

/// ResteOS masaüstü (PC/tablet) ekranları için ORTAK, TEMA-DUYARLI (gece/gündüz)
/// bileşen kütüphanesi. SepetTakip tarzı: aydınlık/yoğun, tablo + kart ızgara +
/// renkli durum rozetleri + renkli aksiyon butonları. Tüm renkler TemaProvider'dan
/// gelir; kullanıcı gece/gündüz çevirince tüm ekranlar birlikte döner.

/// Sayfa kabuğu: üst başlık şeridi (geri + ikon + başlık + sağ araçlar) + gövde.
/// Yönetim ekranları (push ile açılan) bunu kullanır.
class MasaustuSayfa extends StatelessWidget {
  final String baslik;
  final IconData ikon;
  final String? altBaslik;
  final List<Widget> araclar;
  final Widget govde;
  final bool geri;
  const MasaustuSayfa({
    super.key,
    required this.baslik,
    required this.ikon,
    required this.govde,
    this.altBaslik,
    this.araclar = const [],
    this.geri = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            color: t.card,
            border: Border(bottom: BorderSide(color: t.line)),
          ),
          child: Row(children: [
            if (geri)
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: Icon(Icons.arrow_back, color: t.sub2, size: 22),
                tooltip: 'Geri',
              ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [t.mor1, t.mavi]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(ikon, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(baslik, style: TextStyle(color: t.ink, fontSize: 19, fontWeight: FontWeight.bold)),
              if (altBaslik != null) Text(altBaslik!, style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
            const Spacer(),
            ...araclar,
            // Gece/gündüz her sayfada ulaşılabilir olsun
            const SizedBox(width: 4),
            const TemaButonu(),
          ]),
        ),
        Expanded(child: govde),
      ]),
    );
  }
}

/// Gece/gündüz çevirici ikon (her masaüstü sayfasının sağ üstünde).
class TemaButonu extends StatelessWidget {
  const TemaButonu({super.key});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return IconButton(
      tooltip: t.koyu ? 'Gündüz moduna geç' : 'Gece moduna geç',
      onPressed: () => context.read<TemaProvider>().cevir(),
      icon: Icon(t.koyu ? Icons.light_mode : Icons.dark_mode, color: t.gold, size: 22),
    );
  }
}

/// Tema-duyarlı kart yüzeyi.
class MKart extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? kenar;
  const MKart({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.kenar});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kutu = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kenar ?? t.line),
        boxShadow: t.golge,
      ),
      child: child,
    );
    if (onTap == null) return kutu;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: kutu),
    );
  }
}

/// KPI / istatistik kartı: üst renkli başlık + büyük değer + alt döküm satırları.
class MIstatKart extends StatelessWidget {
  final String baslik;
  final Color renk;
  final String? deltaEtiket; // ör "▲ %12"
  final List<MIstatSatir> satirlar;
  final String? buyukDeger;
  const MIstatKart({super.key, required this.baslik, required this.renk, this.deltaEtiket, this.satirlar = const [], this.buyukDeger});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
        boxShadow: t.golge,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: renk,
          child: Row(children: [
            Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (deltaEtiket != null)
              Text(deltaEtiket!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (buyukDeger != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(buyukDeger!, style: TextStyle(color: t.ink, fontSize: 24, fontWeight: FontWeight.bold)),
              ),
            for (final s in satirlar)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s.etiket, style: TextStyle(color: t.sub, fontSize: 13)),
                  Text(s.deger, style: TextStyle(color: s.renk ?? t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class MIstatSatir {
  final String etiket;
  final String deger;
  final Color? renk;
  const MIstatSatir(this.etiket, this.deger, {this.renk});
}

/// Durum rozeti (yeşil/turuncu/kırmızı ...).
class MRozet extends StatelessWidget {
  final String metin;
  final Color renk;
  final IconData? ikon;
  const MRozet(this.metin, this.renk, {super.key, this.ikon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ikon != null) ...[Icon(ikon, size: 13, color: renk), const SizedBox(width: 4)],
        Text(metin, style: TextStyle(color: renk, fontSize: 11.5, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

/// Renkli aksiyon butonu (dolu = vurgulu, boş = ince kenarlı).
class MButon extends StatelessWidget {
  final String etiket;
  final Color renk;
  final VoidCallback onTap;
  final bool dolu;
  final IconData? ikon;
  const MButon(this.etiket, this.renk, this.onTap, {super.key, this.dolu = true, this.ikon});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Material(
      color: dolu ? renk : t.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: dolu ? null : Border.all(color: t.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (ikon != null) ...[Icon(ikon, size: 15, color: dolu ? Colors.white : t.sub2), const SizedBox(width: 6)],
            Text(etiket, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: dolu ? Colors.white : t.sub2)),
          ]),
        ),
      ),
    );
  }
}

/// Bölüm başlığı (sol renkli çubuk + başlık + sayaç rozeti).
class MBolumBaslik extends StatelessWidget {
  final String baslik;
  final Color renk;
  final int? sayi;
  final Widget? sag;
  const MBolumBaslik(this.baslik, {super.key, this.renk = const Color(0xFF7C3AED), this.sayi, this.sag});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: Row(children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(baslik, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t.ink)),
        if (sayi != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
            child: Text('$sayi', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
        const Spacer(),
        ?sag,
      ]),
    );
  }
}

/// Basit tema-duyarlı tablo: başlık + satırlar. Sütunlar flex+hizalama ile.
class MSutun {
  final String baslik;
  final int flex;
  final TextAlign hiza;
  const MSutun(this.baslik, {this.flex = 10, this.hiza = TextAlign.left});
}

class MTablo extends StatelessWidget {
  final List<MSutun> sutunlar;
  final List<List<Widget>> satirlar; // her satır: sutunlar ile aynı uzunlukta hücreler
  const MTablo({super.key, required this.sutunlar, required this.satirlar});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Alignment hizaTo(TextAlign a) => a == TextAlign.right
        ? Alignment.centerRight
        : (a == TextAlign.center ? Alignment.center : Alignment.centerLeft);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
        boxShadow: t.golge,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // başlık
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          color: t.card2,
          child: Row(children: [
            for (final s in sutunlar)
              Expanded(flex: s.flex, child: Text(s.baslik, textAlign: s.hiza, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.sub))),
          ]),
        ),
        for (int r = 0; r < satirlar.length; r++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: r == satirlar.length - 1 ? null : Border(bottom: BorderSide(color: t.line.withValues(alpha: 0.6))),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              for (int c = 0; c < sutunlar.length; c++)
                Expanded(flex: sutunlar[c].flex, child: Align(alignment: hizaTo(sutunlar[c].hiza), child: satirlar[r][c])),
            ]),
          ),
      ]),
    );
  }
}
