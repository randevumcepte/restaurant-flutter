import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /eposta-hesaplari — tedarikçiye fiyat isteği (RFQ) / sipariş gönderen e-posta hesapları: ekle, düzenle, test et, sil.
/// Düzenleme yalnız `duzenleyebilir` (sahip/müdür); silme yalnız sahip (sunucu kontrol eder).
class EpostaHesaplariScreen extends StatelessWidget {
  const EpostaHesaplariScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/eposta-hesaplari',
      baslik: 'E-posta Hesapları (RFQ)',
      ikon: Icons.alternate_email,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['hesaplar']);
        final duzen = v['duzenleyebilir'] == true;
        return KGovde(yenile: yenile, children: [
          const SaBilgi('Fiyat isteği ve siparişler tedarikçiye bu hesaplardan e-postayla gider. Gmail/Outlook için normal şifre değil "uygulama şifresi" gerekir.', ikon: Icons.info_outline),
          if (duzen) Align(alignment: Alignment.centerLeft, child: KButon('Yeni hesap', ikon: Icons.add, onTap: () => _form(ctx, null, yenile))),
          const SizedBox(height: 10),
          if (l.isEmpty)
            KBos(baslik: 'E-posta hesabı yok', aciklama: duzen ? '"Yeni hesap" ile SMTP bilgilerini girin; fiyat istekleri bu adresten gider.' : 'Hesabı işletme sahibi ya da müdür ekler.', ikon: Icons.alternate_email)
          else
            SaIzgara([
              for (final h in l)
                KKart(
                  renk: tamOku(h['aktif']) == 1 ? t.mor1 : t.sub,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(metinOku(h['ad'], metinOku(h['email'])), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
                      if (tamOku(h['varsayilan']) == 1) KRozet('Varsayılan', renk: t.yesil),
                      if (tamOku(h['aktif']) != 1) ...[const SizedBox(width: 6), KRozet('Pasif', renk: t.sub)],
                    ]),
                    Text('${metinOku(h['email'])}${metinOku(h['gonderen_ad']).isNotEmpty ? ' · ${h['gonderen_ad']}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                    Text('SMTP ${metinOku(h['smtp_host'], '—')}:${h['smtp_port']} (${metinOku(h['smtp_guvenlik']).toUpperCase()})${metinOku(h['imap_host']).isNotEmpty ? ' · IMAP ${h['imap_host']}' : ''}',
                        style: TextStyle(color: t.sub2, fontSize: 12.5)),
                    if (metinOku(h['son_test']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Son test (${tarihYaz(h['son_test_at'])}): ${metinOku(h['son_test_not'], h['son_test'])}',
                            style: TextStyle(color: h['son_test'] == 'ok' ? t.yesil : t.kirmizi, fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    if (duzen) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _form(ctx, h, yenile)),
                        KButon('Test et', ikon: Icons.send_outlined, ikincil: true, renk: t.yesil, onTap: () => _test(ctx, h, yenile)),
                        KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
                          if (!await kOnay(ctx, 'Bu e-posta hesabı silinsin mi?', tehlikeli: true, evet: 'Evet, sil')) return;
                          if (!ctx.mounted) return;
                          await saGonder(ctx, '/eposta-hesap-sil', {'id': h['id']}, json: false);
                          yenile();
                        }),
                      ]),
                    ],
                  ]),
                ),
            ], minGenislik: 420),
        ]);
      },
    );
  }

  Future<void> _test(BuildContext context, Map<String, dynamic> h, Future<void> Function() yenile) async {
    final to = await saMetinSor(context, 'Test e-postası', aciklama: 'Boş bırakırsanız hesabın kendi adresine (${h['email']}) gönderilir.', ipucu: 'alici@ornek.com', satir: 1, klavye: TextInputType.emailAddress, evet: 'Gönder');
    if (to == null || !context.mounted) return;
    kToast(context, 'Test e-postası gönderiliyor…');
    await saGonder(context, '/eposta-hesap-test', {'id': h['id'], 'test_to': to}, json: false);
    yenile();
  }

  Future<void> _form(BuildContext context, Map<String, dynamic>? h, Future<void> Function() yenile) async {
    TextEditingController k(String a, [String v = '']) => TextEditingController(text: h == null ? v : metinOku(h[a], v));
    final ad = k('ad'), email = k('email'), gad = k('gonderen_ad'), host = k('smtp_host'), port = k('smtp_port', '587'), user = k('smtp_user'), sifre = TextEditingController();
    var sec = h == null ? 'tls' : metinOku(h['smtp_guvenlik'], 'tls');
    var vars = h != null && tamOku(h['varsayilan']) == 1;
    var aktif = h == null || tamOku(h['aktif']) == 1;
    final ok = await kAltSayfa<bool>(context, baslik: h == null ? 'Yeni E-posta Hesabı' : 'Hesabı Düzenle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Etiket', ad, ipucu: 'Satın Alma Kurumsal'),
            KAlan('E-posta adresi', email, ipucu: 'satinalma@firma.com', klavye: TextInputType.emailAddress, zorunlu: true),
            KAlan('Gönderen adı', gad, ipucu: 'Firma Satın Alma'),
            KAlan('SMTP sunucu', host, ipucu: 'smtp.gmail.com / smtp.office365.com'),
            Row(children: [
              Expanded(child: KAlan('Port', port, klavye: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: KSecim<String>('Güvenlik', deger: sec, secenekler: const [('tls', 'TLS'), ('ssl', 'SSL'), ('yok', 'Yok')], onSec: (x) => ss(() => sec = x ?? 'tls'))),
            ]),
            KAlan('Kullanıcı adı', user, ipucu: 'genelde e-posta adresi'),
            KAlan('Şifre / uygulama şifresi', sifre, ipucu: h == null ? '' : 'değiştirmezseniz boş bırakın'),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: vars, onChanged: (b) => ss(() => vars = b == true), title: Text('Varsayılan hesap', style: TextStyle(color: t.ink))),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: aktif, onChanged: (b) => ss(() => aktif = b == true), title: Text('Aktif', style: TextStyle(color: t.ink))),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
              if (email.text.trim().isEmpty) return kToast(c, 'E-posta zorunlu.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !context.mounted) return;
    await saGonder(context, '/eposta-hesap-kaydet', {
      if (h != null) 'id': h['id'],
      'ad': ad.text.trim(), 'email': email.text.trim(), 'gonderen_ad': gad.text.trim(), 'smtp_host': host.text.trim(), 'smtp_port': port.text.trim(),
      'smtp_guvenlik': sec, 'smtp_user': user.text.trim(), if (sifre.text.isNotEmpty) 'smtp_sifre': sifre.text, if (vars) 'varsayilan': '1', 'aktif': aktif ? '1' : '0',
    }, json: false);
    yenile();
  }
}
