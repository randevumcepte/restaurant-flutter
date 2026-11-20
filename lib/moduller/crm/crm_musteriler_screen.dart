import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_musteri360_screen.dart';
import 'crm_ortak.dart';

/// Web /musteriler — en çok harcayan 50 müşteri; müşteri ekle (/musteriler/ekle) ve düzenle (/musteriler/guncelle).
/// Uygulamada ek olarak liste içinde arama (yerel süzme) ve dokununca Müşteri 360 detayı.
class CrmMusterilerScreen extends StatefulWidget {
  const CrmMusterilerScreen({super.key});

  @override
  State<CrmMusterilerScreen> createState() => _CrmMusterilerScreenState();
}

class _CrmMusterilerScreenState extends State<CrmMusterilerScreen> {
  String _ara = '';

  Future<void> _form(BuildContext context, Future<void> Function() yenile, [Map<String, dynamic>? m]) async {
    final adC = TextEditingController(text: metinOku(m?['ad']));
    final telC = TextEditingController(text: metinOku(m?['telefon']));
    final adresC = TextEditingController(text: metinOku(m?['adres']));
    final dogumC = TextEditingController();
    bool gonderiyor = false;
    await kAltSayfa(context, baslik: m == null ? 'Yeni müşteri' : 'Müşteri düzenle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Ad Soyad', adC, ipucu: 'örn. Ayşe Yılmaz', zorunlu: true),
            KAlan('Telefon', telC, ipucu: '05xx xxx xx xx', klavye: TextInputType.phone),
            KAlan('Adres', adresC, ipucu: 'Paket sipariş için', satir: 2),
            KAlan('Doğum tarihi (opsiyonel)', dogumC, ipucu: 'YYYY-AA-GG — doğum günü kutlaması için'),
            const SizedBox(height: 4),
            KButon(m == null ? 'Kaydet' : 'Güncelle', ikon: Icons.save_outlined, genis: true, yukleniyor: gonderiyor, onTap: () async {
              if (adC.text.trim().isEmpty) {
                kToast(c, 'Ad Soyad zorunlu.', hata: true);
                return;
              }
              ss(() => gonderiyor = true);
              final ok = await kopruGonder(c, m == null ? '/musteriler/ekle' : '/musteriler/guncelle', {
                if (m != null) 'id': '${m['id']}',
                'ad': adC.text.trim(),
                'telefon': telC.text.trim(),
                'adres': adresC.text.trim(),
                if (dogumC.text.trim().isNotEmpty) 'dogum_tarihi': dogumC.text.trim(),
              }, basariMesaji: m == null ? 'Müşteri eklendi.' : 'Müşteri güncellendi.');
              if (!c.mounted) return;
              ss(() => gonderiyor = false);
              if (ok) {
                Navigator.pop(c);
                yenile();
              }
            }),
          ]);
        }));
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/musteriler',
      baslik: 'Müşteriler',
      ikon: Icons.groups_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        onPressed: () => _form(ctx, yenile),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Müşteri ekle', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final q = _ara.toLowerCase();
        final hepsi = liste(v['musteriler']);
        final l = q.isEmpty
            ? hepsi
            : hepsi.where((m) => metinOku(m['ad']).toLowerCase().contains(q) || metinOku(m['telefon']).contains(q)).toList();
        final genis = genisMi(ctx);
        return KGovde(yenile: yenile, children: [
          KBaslik('Toplam ${sayiYaz(v['toplam'])} müşteri', ikon: Icons.groups_outlined, alt: 'En çok harcayan 50 müşteri listelenir'),
          KAra(ipucu: 'Listede ad veya telefon ara…', onDegis: (x) => setState(() => _ara = x.trim())),
          const SizedBox(height: 12),
          if (l.isEmpty)
            KBos(
              baslik: hepsi.isEmpty ? 'Henüz müşteri yok' : 'Aramayla eşleşen müşteri yok',
              aciklama: hepsi.isEmpty
                  ? 'Sağ alttaki "Müşteri ekle" ile ekleyebilir ya da POS\'ta adisyona müşteri bağlayabilirsiniz. Paket sipariş ve QR menü kayıtları da buraya düşer.'
                  : 'Bu liste yalnız en çok harcayan 50 kişiyi içerir. Tüm müşterilerde aramak için Müşteri 360 ekranını kullanın.',
              ikon: Icons.person_search_outlined,
            )
          else if (genis)
            KKart(
              padding: const EdgeInsets.all(6),
              child: KTablo(
                basliklar: const ['Müşteri', 'Telefon', 'Adres', 'Sipariş', 'Harcama', 'Puan'],
                sagaYasla: const {3, 4, 5},
                satirlar: [
                  for (final m in l)
                    [metinOku(m['ad'], '—'), metinOku(m['telefon'], '—'), metinOku(m['adres'], '—'), sayiYaz(m['siparis_sayisi']), tl(m['toplam_harcama'], kisa: true), sayiYaz(m['puan'])]
                ],
                onSatir: (i) => _detay(ctx, l[i], yenile),
              ),
            )
          else
            for (final m in l)
              KKart(
                padding: EdgeInsets.zero,
                child: KSatir(
                  cizgi: false,
                  solIkon: CrmAvatar(metinOku(m['ad'], 'M'), renk: t.mor1),
                  baslik: metinOku(m['ad'], 'İsimsiz'),
                  alt: '${metinOku(m['telefon'], '—')} · ${sayiYaz(m['siparis_sayisi'])} sipariş${metinOku(m['adres']).isEmpty ? '' : '\n${metinOku(m['adres'])}'}',
                  sag: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(tl(m['toplam_harcama'], kisa: true), style: TextStyle(color: t.yesil, fontWeight: FontWeight.bold, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    KRozet('${sayiYaz(m['puan'])} puan', renk: t.amber),
                  ]),
                  onTap: () => _detay(ctx, m, yenile),
                ),
              ),
        ]);
      },
    );
  }

  Future<void> _detay(BuildContext context, Map<String, dynamic> m, Future<void> Function() yenile) async {
    final t = context.read<TemaProvider>();
    await kAltSayfa(context, baslik: metinOku(m['ad'], 'Müşteri'), icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${metinOku(m['telefon'], '—')}\n${metinOku(m['adres'], 'Adres yok')}', style: TextStyle(color: t.sub2, fontSize: 14, height: 1.5)),
          const SizedBox(height: 12),
          KButon('Düzenle', ikon: Icons.edit_outlined, genis: true, onTap: () {
            Navigator.pop(c);
            _form(context, yenile, m);
          }),
          const SizedBox(height: 10),
          KButon('Müşteri 360 detayı', ikon: Icons.support_agent_outlined, ikincil: true, genis: true, onTap: () {
            Navigator.pop(c);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => CrmMusteriDetayScreen(id: tamOku(m['id']), ad: metinOku(m['ad'], 'Müşteri'))));
          }),
        ]));
  }
}
