import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /cagrilar — Çağrı Merkezi (Arayan Tanıma): bugünkü / kaçan çağrı sayısı + son 40 gelen çağrı,
/// tanınan müşterinin sipariş sayısı, harcaması, adresi. Uygulamada ek: arama, sonuç filtresi, numarayı geri ara.
class OpCagriMerkeziScreen extends StatefulWidget {
  const OpCagriMerkeziScreen({super.key});
  @override
  State<OpCagriMerkeziScreen> createState() => _OpCagriMerkeziScreenState();
}

const Map<String, (String, Color, IconData)> _kCagriSonuc = {
  'kacan': ('Kaçan', Color(0xFFE11D48), Icons.phone_missed_outlined),
  'siparis': ('Sipariş', Color(0xFF059669), Icons.shopping_cart_outlined),
  'cevaplandi': ('Cevaplandı', Color(0xFF64748B), Icons.call_outlined),
};

class _OpCagriMerkeziScreenState extends State<OpCagriMerkeziScreen> {
  String _ara = '';
  String _filtre = 'hepsi';

  String _once(dynamic v) {
    final d = DateTime.tryParse(metinOku(v).replaceFirst(' ', 'T'));
    if (d == null) return metinOku(v);
    final f = DateTime.now().difference(d);
    if (f.inSeconds < 60) return 'az önce';
    if (f.inMinutes < 60) return '${f.inMinutes} dk önce';
    if (f.inHours < 24) return '${f.inHours} saat önce';
    if (f.inDays < 7) return '${f.inDays} gün önce';
    return tarihYaz(v);
  }

  Future<void> _ara2(String tel) async {
    final temiz = tel.replaceAll(RegExp(r'[^0-9+]'), '');
    if (temiz.isEmpty) return;
    final ok = await launchUrl(Uri.parse('tel:$temiz'));
    if (!ok && mounted) kToast(context, 'Bu cihazdan arama başlatılamadı.', hata: true);
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/cagrilar',
      baslik: 'Çağrı Merkezi',
      ikon: Icons.contact_phone_outlined,
      altBaslik: 'Telefon çaldığında müşteri geçmişi otomatik ekrana gelir',
      otomatik: const Duration(seconds: 30),
      araclar: (ctx, veri, yenile) => [
        IconButton(
          tooltip: 'Gelen çağrı ekranı',
          icon: const Icon(Icons.ring_volume_outlined),
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/cagri-ekran', 'Gelen Çağrı Ekranı'))),
        ),
      ],
      govde: (ctx, veri, yenile) {
        final t = context.watch<TemaProvider>();
        final hepsi = liste(veri['cagrilar']);
        final q = _ara.toLowerCase().trim();
        final gorunen = hepsi.where((c) {
          if (_filtre != 'hepsi' && metinOku(c['sonuc']) != _filtre) return false;
          if (q.isEmpty) return true;
          return metinOku(c['telefon']).toLowerCase().contains(q) || metinOku(c['musteri']).toLowerCase().contains(q);
        }).toList();

        Widget satir(Map<String, dynamic> c) {
          final s = _kCagriSonuc[metinOku(c['sonuc'])] ?? (metinOku(c['sonuc'], 'Bilinmiyor'), const Color(0xFF64748B), Icons.call_outlined);
          final tanindi = metinOku(c['musteri']).isNotEmpty;
          final tel = metinOku(c['telefon']);
          return KSatir(
            solIkon: KIkon(s.$3, renk: s.$2),
            baslik: tanindi ? '${c['musteri']}  ·  $tel' : 'Bilinmeyen numara  ·  $tel',
            alt: tanindi
                ? '${sayiYaz(c['siparis_sayisi'])} sipariş · ${tl(c['toplam_harcama'], kisa: true)}${metinOku(c['adres']).isEmpty ? '' : ' · ${metinOku(c['adres'])}'}'
                : 'Yeni / kayıtsız müşteri',
            sag: Row(mainAxisSize: MainAxisSize.min, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                KRozet(s.$1, renk: s.$2),
                const SizedBox(height: 4),
                Text(_once(c['created_at']), style: TextStyle(color: t.sub, fontSize: 11.5)),
              ]),
              if (tel.isNotEmpty)
                IconButton(tooltip: 'Geri ara', onPressed: () => _ara2(tel), icon: Icon(Icons.call, color: t.yesil)),
            ]),
          );
        }

        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Bugün çağrı', deger: sayiYaz(veri['bugun']), ikon: Icons.call_received, renk: const Color(0xFF6366F1)),
            KKpi(etiket: 'Bugün kaçan', deger: sayiYaz(veri['kacan']), ikon: Icons.phone_missed_outlined, renk: const Color(0xFFE11D48), onTap: () => setState(() => _filtre = 'kacan')),
            if (genisMi(context)) KKpi(etiket: 'Listede tanınan müşteri', deger: sayiYaz(hepsi.where((c) => metinOku(c['musteri']).isNotEmpty).length), ikon: Icons.person_search_outlined, renk: const Color(0xFF059669)),
          ]),
          KAra(ipucu: 'Telefon ya da müşteri adı ara…', onDegis: (v) => setState(() => _ara = v)),
          KCipler(
            secenekler: const [('hepsi', 'Tümü'), ('kacan', 'Kaçan'), ('siparis', 'Sipariş'), ('cevaplandi', 'Cevaplandı')],
            secili: _filtre,
            onSec: (k) => setState(() => _filtre = k),
          ),
          if (gorunen.isEmpty)
            KKart(
              child: KBos(
                ikon: Icons.phone_disabled_outlined,
                baslik: hepsi.isEmpty ? 'Henüz çağrı kaydı yok' : 'Filtreye uyan çağrı yok',
                aciklama: hepsi.isEmpty
                    ? 'Arayan tanıma için santralin (FreePBX) gelen çağrıyı sisteme bildirmesi gerekir. Kurulum yapılınca her gelen çağrı burada ve Gelen Çağrı Ekranı\'nda görünür.'
                    : 'Filtreyi "Tümü" yapın ya da aramayı temizleyin.',
              ),
            )
          else
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [for (final c in gorunen) satir(c)]),
            ),
        ]);
      },
    );
  }
}
