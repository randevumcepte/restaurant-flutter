import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

// ───────────────────────── /banka ─────────────────────────
class BankaScreen extends StatefulWidget {
  const BankaScreen({super.key});
  @override
  State<BankaScreen> createState() => _BankaScreenState();
}

class _BankaScreenState extends State<BankaScreen> {
  final _k = GlobalKey<KopruEkranState>();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/banka',
      baslik: 'Banka Hesapları',
      ikon: Icons.account_balance_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'banka_ekle', onPressed: () => _hesapEkle(ctx, yenile), icon: const Icon(Icons.add), label: const Text('Hesap ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final hesaplar = liste(v['hesaplar']);
        final sec = tamOku(v['sec']);
        final har = liste(v['hareketler']);
        Map<String, dynamic>? secili;
        for (final h in hesaplar) {
          if (tamOku(h['id']) == sec) secili = h;
        }
        return KGovde(yenile: yenile, children: [
          FHero(etiket: 'Toplam banka pozisyonu (aktif hesaplar)', deger: tl(v['toplam']), renk: t.mavi, ikon: Icons.account_balance_outlined, alt: '${hesaplar.length} hesap'),
          if (hesaplar.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Henüz banka hesabı yok',
                aciklama: 'Banka hesabını açılış bakiyesiyle ekle; para giriş/çıkışlarını işledikçe bakiye güncellenir ve Bilanço\'ya yansır.',
                ikon: Icons.account_balance_outlined,
                aksiyon: KButon('Hesap ekle', ikon: Icons.add, onTap: () => _hesapEkle(ctx, yenile)),
              ),
            )
          else
            FIzgara([for (final h in hesaplar) _hesapKart(ctx, t, h, tamOku(h['id']) == sec, yenile)], minGenislik: 320),
          if (secili != null) ...[
            const SizedBox(height: 8),
            KBaslik('Hareketler · ${metinOku(secili['banka_adi'])}', ikon: Icons.swap_vert, renk: t.mavi, alt: 'Son 50 hareket',
                sag: KButon('Hareket işle', ikon: Icons.add, onTap: () => _hareket(ctx, sec, yenile))),
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: har.isEmpty
                  ? const KBos(baslik: 'Bu hesapta hareket yok', aciklama: 'EFT, havale, ödeme gibi para giriş/çıkışlarını "Hareket işle" ile gir.', ikon: Icons.swap_vert)
                  : Column(children: [
                      for (final m in har)
                        KSatir(
                          solIkon: KIkon(metinOku(m['tip']) == 'giris' ? Icons.arrow_downward : Icons.arrow_upward, renk: metinOku(m['tip']) == 'giris' ? t.yesil : t.kirmizi),
                          baslik: metinOku(m['aciklama'], metinOku(m['tip']) == 'giris' ? 'Para girişi' : 'Para çıkışı'),
                          alt: tarihYaz(m['tarih'], saat: false),
                          sag: Text('${metinOku(m['tip']) == 'giris' ? '+' : '−'} ${tl(m['tutar'])}',
                              style: TextStyle(color: metinOku(m['tip']) == 'giris' ? t.yesil : t.kirmizi, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        ),
                    ]),
            ),
          ] else if (hesaplar.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('Hareketleri görmek ve işlemek için bir hesaba dokunun.', style: TextStyle(color: t.sub, fontSize: 13))),
        ]);
      },
    );
  }

  Widget _hesapKart(BuildContext context, TemaProvider t, Map<String, dynamic> h, bool secili, Future<void> Function() yenile) {
    return KKart(
      renk: secili ? t.mavi : null,
      onTap: () => _k.currentState?.sorgu({'hesap': '${h['id']}'}),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          KIkon(Icons.account_balance_outlined, renk: t.mavi),
          const SizedBox(width: 10),
          Expanded(
            child: Text('${metinOku(h['banka_adi'])}${metinOku(h['hesap_adi']).isEmpty ? '' : ' · ${metinOku(h['hesap_adi'])}'}',
                style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          if (tamOku(h['aktif']) != 1) KRozet('Pasif', renk: t.sub),
        ]),
        const SizedBox(height: 10),
        Text('${tl(h['bakiye'])} ${metinOku(h['para_birimi'], 'TRY')}', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.bold)),
        if (metinOku(h['iban']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: SelectableText(metinOku(h['iban']), style: TextStyle(color: t.sub, fontSize: 12.5))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: KButon(secili ? 'Seçili' : 'Hareketler', ikon: Icons.swap_vert, ikincil: true, onTap: () => _k.currentState?.sorgu({'hesap': '${h['id']}'}))),
          const SizedBox(width: 8),
          KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
            if (!await kOnay(context, 'Hesap ve hareketleri silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: metinOku(h['banka_adi']))) return;
            if (!context.mounted) return;
            if (await kopruGonder(context, '/banka/sil', {'id': h['id']})) await _k.currentState?.sorgu({}, birlestir: false);
          }),
        ]),
      ]),
    );
  }

  Future<void> _hesapEkle(BuildContext context, Future<void> Function() yenile) async {
    final banka = TextEditingController();
    final hesap = TextEditingController();
    final iban = TextEditingController();
    final bakiye = TextEditingController(text: '0');
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Banka hesabı ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KAlan('Banka', banka, ipucu: 'Ziraat, İş Bankası…', zorunlu: true),
        KAlan('Hesap adı', hesap, ipucu: 'Ana hesap'),
        KAlan('IBAN', iban, ipucu: 'TR..'),
        KAlan('Açılış bakiyesi (₺)', bakiye, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true)),
        KButon('Hesap ekle', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (banka.text.trim().isEmpty) {
            kToast(c, 'Banka adı gerekli.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/banka/ekle', {'banka_adi': banka.text.trim(), 'hesap_adi': hesap.text.trim(), 'iban': iban.text.trim(), 'bakiye': sayiOku(bakiye.text)});
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (eklendi) await yenile();
  }

  Future<void> _hareket(BuildContext context, int hesapId, Future<void> Function() yenile) async {
    final tutar = TextEditingController();
    final aciklama = TextEditingController();
    String tip = 'giris';
    String tarih = bugunYmd();
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Hareket işle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KCipler(secenekler: const [('giris', 'Para Girişi (+)'), ('cikis', 'Para Çıkışı (−)')], secili: tip, onSec: (x) => ss(() => tip = x)),
        FTarihAlan('Tarih', deger: tarih, onSec: (s) => ss(() => tarih = s ?? bugunYmd())),
        KAlan('Tutar (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
        KAlan('Açıklama', aciklama, ipucu: 'EFT, havale, ödeme…'),
        KButon('İşle', ikon: Icons.check, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (sayiOku(tutar.text) <= 0) {
            kToast(c, 'Geçerli tutar girin.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/banka/hareket', {'hesap_id': hesapId, 'tarih': tarih, 'tip': tip, 'tutar': sayiOku(tutar.text), 'aciklama': aciklama.text.trim()});
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (eklendi) await yenile();
  }
}

// ───────────────────────── /cek-senet ─────────────────────────
const _csDurum = [('portfoyde', 'Portföyde'), ('tahsil', 'Tahsil edildi'), ('odendi', 'Ödendi'), ('ciro', 'Ciro edildi'), ('karsiliksiz', 'Karşılıksız')];

Color _csRenk(String d) => switch (d) {
      'portfoyde' => const Color(0xFF5B8DEF),
      'tahsil' || 'odendi' => const Color(0xFF2FBE94),
      'ciro' => const Color(0xFF8B5CF6),
      'karsiliksiz' => const Color(0xFFF43F5E),
      _ => const Color(0xFF64748B),
    };

String _csAd(String d) {
  for (final (k, a) in _csDurum) {
    if (k == d) return a;
  }
  return d;
}

class CekSenetScreen extends StatefulWidget {
  const CekSenetScreen({super.key});
  @override
  State<CekSenetScreen> createState() => _CekSenetScreenState();
}

class _CekSenetScreenState extends State<CekSenetScreen> {
  String _filtre = 'hepsi';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/cek-senet',
      baslik: 'Çek / Senet',
      ikon: Icons.request_quote_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'cs_ekle', onPressed: () => _ekle(ctx, yenile), icon: const Icon(Icons.add), label: const Text('Ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final tum = liste(v['liste']);
        final l = switch (_filtre) {
          'alinan' || 'verilen' => tum.where((c) => metinOku(c['yon']) == _filtre).toList(),
          'portfoyde' => tum.where((c) => metinOku(c['durum']) == 'portfoyde').toList(),
          _ => tum,
        };
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Portföydeki alacak (alınan)', deger: tl(v['alacak'], kisa: true), ikon: Icons.call_received, renk: t.yesil),
            KKpi(etiket: 'Portföydeki borç (verilen)', deger: tl(v['borc'], kisa: true), ikon: Icons.call_made, renk: t.kirmizi),
          ]),
          if (tum.isNotEmpty)
            KCipler(
              secenekler: [('hepsi', 'Tümü ${tum.length}'), ('portfoyde', 'Portföyde'), ('alinan', 'Alınan'), ('verilen', 'Verilen')],
              secili: _filtre,
              onSec: (s) => setState(() => _filtre = s),
            ),
          if (l.isEmpty)
            KKart(
              child: KBos(
                baslik: tum.isEmpty ? 'Henüz çek/senet yok' : 'Bu filtrede kayıt yok',
                aciklama: 'Aldığın ve verdiğin çek-senetleri ekle, vade takibi yap. Portföydekiler Bilanço\'ya alacak/borç olarak yansır.',
                ikon: Icons.request_quote_outlined,
                aksiyon: tum.isEmpty ? KButon('Ekle', ikon: Icons.add, onTap: () => _ekle(ctx, yenile)) : null,
              ),
            )
          else
            FIzgara([for (final c in l) _kart(ctx, t, c, yenile)], minGenislik: 380),
        ]);
      },
    );
  }

  Widget _kart(BuildContext context, TemaProvider t, Map<String, dynamic> c, Future<void> Function() yenile) {
    final alinan = metinOku(c['yon']) == 'alinan';
    final durum = metinOku(c['durum'], 'portfoyde');
    final vade = DateTime.tryParse(metinOku(c['vade']));
    final gecti = durum == 'portfoyde' && vade != null && vade.isBefore(DateTime.now());
    return KKart(
      renk: alinan ? t.yesil : t.kirmizi,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          KRozet('${metinOku(c['tip']) == 'senet' ? 'SENET' : 'ÇEK'} · ${alinan ? 'AL' : 'VER'}', renk: alinan ? t.yesil : t.kirmizi),
          const SizedBox(width: 8),
          KRozet(_csAd(durum), renk: _csRenk(durum)),
          const Spacer(),
          Text(tl(c['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Text(metinOku(c['kisi'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w600)),
        Text(
          [
            if (metinOku(c['banka']).isNotEmpty) metinOku(c['banka']),
            if (metinOku(c['no']).isNotEmpty) metinOku(c['no']),
            vade == null ? 'vadesiz' : 'vade ${tarihYaz(c['vade'], saat: false)}',
          ].join(' · '),
          style: TextStyle(color: t.sub, fontSize: 12.5),
        ),
        if (gecti) Padding(padding: const EdgeInsets.only(top: 4), child: KRozet('Vade geçti', renk: t.kirmizi, ikon: Icons.warning_amber_outlined)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: KSecim<String>('Durum', key: ValueKey('cs${c['id']}-$durum'), deger: durum, secenekler: _csDurum, onSec: (x) async {
              if (x == null || x == durum) return;
              if (await kopruGonder(context, '/cek-senet/durum', {'id': c['id'], 'durum': x}, basariMesaji: 'Durum: ${_csAd(x)}')) await yenile();
            }),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: Icon(Icons.delete_outline, color: t.sub),
            onPressed: () async {
              if (!await kOnay(context, 'Silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: '${metinOku(c['kisi'], '—')} · ${tl(c['tutar'])}')) return;
              if (!context.mounted) return;
              if (await kopruGonder(context, '/cek-senet/sil', {'id': c['id']})) await yenile();
            },
          ),
        ]),
      ]),
    );
  }

  Future<void> _ekle(BuildContext context, Future<void> Function() yenile) async {
    final kisi = TextEditingController();
    final tutar = TextEditingController();
    final banka = TextEditingController();
    final no = TextEditingController();
    String tip = 'cek';
    String yon = 'alinan';
    String? vade;
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Çek / senet ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KCipler(secenekler: const [('cek', 'Çek'), ('senet', 'Senet')], secili: tip, onSec: (x) => ss(() => tip = x)),
        KCipler(secenekler: const [('alinan', 'Alınan (alacak)'), ('verilen', 'Verilen (borç)')], secili: yon, onSec: (x) => ss(() => yon = x)),
        KAlan('Kişi / Firma', kisi, ipucu: 'Keşideci / lehtar'),
        KAlan('Tutar (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
        FTarihAlan('Vade', deger: vade, temizlenebilir: true, onSec: (s) => ss(() => vade = s)),
        KAlan('Banka', banka, ipucu: 'Banka'),
        KAlan('Çek / senet no', no),
        KButon('Ekle', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (sayiOku(tutar.text) <= 0) {
            kToast(c, 'Tutar gerekli.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/cek-senet/ekle', {
            'tip': tip,
            'yon': yon,
            'kisi': kisi.text.trim(),
            'tutar': sayiOku(tutar.text),
            'vade': vade ?? '',
            'banka': banka.text.trim(),
            'no': no.text.trim(),
          });
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (eklendi) await yenile();
  }
}

// ───────────────────────── /depozito ─────────────────────────
const _dpDurum = [('bekliyor', 'Bekliyor'), ('alindi', 'Alındı'), ('iade', 'İade'), ('tamam', 'Tamamlandı')];

Color _dpRenk(String d) => switch (d) {
      'bekliyor' => const Color(0xFFF59E0B),
      'alindi' => const Color(0xFF2FBE94),
      'iade' => const Color(0xFF64748B),
      'tamam' => const Color(0xFF5B8DEF),
      _ => const Color(0xFF64748B),
    };

class DepozitoScreen extends StatefulWidget {
  const DepozitoScreen({super.key});
  @override
  State<DepozitoScreen> createState() => _DepozitoScreenState();
}

class _DepozitoScreenState extends State<DepozitoScreen> {
  String _filtre = 'hepsi';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/depozito',
      baslik: 'Kapora / Depozito',
      ikon: Icons.savings_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'dp_ekle', onPressed: () => _ekle(ctx, yenile), icon: const Icon(Icons.add), label: const Text('Kapora ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final tum = liste(v['liste']);
        final q = _ara.toLowerCase();
        final l = tum.where((d) {
          if (_filtre != 'hepsi' && metinOku(d['durum']) != _filtre) return false;
          if (q.isEmpty) return true;
          return '${metinOku(d['ad'])} ${metinOku(d['telefon'])}'.toLowerCase().contains(q);
        }).toList();
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Bekleyen kapora (tahsil edilecek)', deger: tl(v['bekleyen'], kisa: true), ikon: Icons.hourglass_bottom, renk: t.amber),
            KKpi(etiket: 'Toplam alınan kapora', deger: tl(v['alinan'], kisa: true), ikon: Icons.savings_outlined, renk: t.yesil),
          ]),
          if (tum.isNotEmpty) ...[
            KAra(ipucu: 'Ad / telefon ara…', onDegis: (s) => setState(() => _ara = s)),
            KCipler(secenekler: [('hepsi', 'Tümü ${tum.length}'), ..._dpDurum], secili: _filtre, onSec: (s) => setState(() => _filtre = s)),
          ],
          if (l.isEmpty)
            KKart(
              child: KBos(
                baslik: tum.isEmpty ? 'Henüz kapora kaydı yok' : 'Aramaya uyan kayıt yok',
                aciklama: 'Grup/etkinlik rezervasyonlarında kapora al, no-show\'u azalt. Etkinlik gününde "Tamamlandı" yap, iadeyi "İade" olarak işaretle.',
                ikon: Icons.savings_outlined,
                aksiyon: tum.isEmpty ? KButon('Kapora ekle', ikon: Icons.add, onTap: () => _ekle(ctx, yenile)) : null,
              ),
            )
          else
            FIzgara([for (final d in l) _kart(ctx, t, d, yenile)], minGenislik: 380),
        ]);
      },
    );
  }

  Widget _kart(BuildContext context, TemaProvider t, Map<String, dynamic> d, Future<void> Function() yenile) {
    final durum = metinOku(d['durum'], 'bekliyor');
    final kalan = sayiOku(d['tutar']) - sayiOku(d['alinan']);
    return KKart(
      renk: _dpRenk(durum),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(metinOku(d['ad']), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold))),
          Text(tl(d['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 3),
        Text(
          [
            metinOku(d['etkinlik_tarih']).isEmpty ? 'tarihsiz' : tarihYaz(d['etkinlik_tarih'], saat: false),
            if (tamOku(d['kisi']) > 0) '${tamOku(d['kisi'])} kişi',
            if (metinOku(d['telefon']).isNotEmpty) metinOku(d['telefon']),
          ].join(' · '),
          style: TextStyle(color: t.sub, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          KRozet('Alınan ${tl(d['alinan'], kisa: true)}', renk: t.yesil),
          if (durum == 'bekliyor' && kalan > 0) KRozet('Kalan ${tl(kalan, kisa: true)}', renk: t.amber),
        ]),
        if (metinOku(d['not']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(metinOku(d['not']), style: TextStyle(color: t.sub2, fontSize: 13))),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: KSecim<String>('Durum', key: ValueKey('dp${d['id']}-$durum'), deger: durum, secenekler: _dpDurum, onSec: (x) async {
              if (x == null || x == durum) return;
              if (await kopruGonder(context, '/depozito/durum', {'id': d['id'], 'durum': x}, basariMesaji: 'Durum güncellendi.')) await yenile();
            }),
          ),
          IconButton(
            tooltip: 'Sil',
            icon: Icon(Icons.delete_outline, color: t.sub),
            onPressed: () async {
              if (!await kOnay(context, 'Kapora kaydı silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: metinOku(d['ad']))) return;
              if (!context.mounted) return;
              if (await kopruGonder(context, '/depozito/sil', {'id': d['id']})) await yenile();
            },
          ),
        ]),
      ]),
    );
  }

  Future<void> _ekle(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController();
    final tel = TextEditingController();
    final kisi = TextEditingController();
    final tutar = TextEditingController();
    final alinan = TextEditingController(text: '0');
    final not = TextEditingController();
    String? tarih;
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Kapora ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KAlan('Ad / Etkinlik', ad, ipucu: 'Yılmaz ailesi nişan', zorunlu: true),
        KAlan('Telefon', tel, klavye: TextInputType.phone),
        FTarihAlan('Etkinlik tarihi', deger: tarih, temizlenebilir: true, onSec: (s) => ss(() => tarih = s)),
        KAlan('Kişi', kisi, klavye: TextInputType.number),
        KAlan('Kapora tutarı (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true)),
        KAlan('Alınan (₺)', alinan, klavye: const TextInputType.numberWithOptions(decimal: true)),
        KAlan('Not', not, satir: 2),
        KButon('Ekle', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (ad.text.trim().isEmpty) {
            kToast(c, 'Ad gerekli.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/depozito/ekle', {
            'ad': ad.text.trim(),
            'telefon': tel.text.trim(),
            'etkinlik_tarih': tarih ?? '',
            'kisi': tamOku(kisi.text),
            'tutar': sayiOku(tutar.text),
            'alinan': sayiOku(alinan.text),
            'not': not.text.trim(),
          });
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (eklendi) await yenile();
  }
}
