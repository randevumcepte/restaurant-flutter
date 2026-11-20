import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _tipler = [
  ('excel', "Genel / Muhasebeci Excel'i"),
  ('logo_dosya', 'Logo — Aktarım Dosyası'),
  ('logo_api', 'Logo — REST API (Tiger/GO)'),
  ('netsis_dosya', 'Netsis — Aktarım Dosyası'),
  ('netsis_api', 'Netsis — REST API (NetOpenX)'),
  ('entegrator', 'e-Dönüşüm Entegratörü (Paraşüt vb.)'),
];

const _hesaplar = [
  ('kasa', 'Kasa (Nakit)'), ('pos', 'Kredi Kartı (POS)'), ('banka', 'Banka / Online'), ('alici', 'Alıcılar (Açık Hesap)'),
  ('satis', 'Yurtiçi Satışlar'), ('hesaplanan_kdv', 'Hesaplanan KDV'), ('mal', 'İlk Madde / Mal'), ('tedarikci', 'Satıcılar (Tedarikçi)'), ('smm', 'Satılan Malın Maliyeti'),
];

String _tipAd(String k) {
  for (final (a, b) in _tipler) {
    if (a == k) return b;
  }
  return k;
}

/// /muhasebe-entegrasyon — Logo/Netsis/Excel mahsup fişi (CSV) indir, cari ekstre, ERP'ye API gönderimi, bağlantı ayarları, aktarım geçmişi
class MuhasebeEntegrasyonScreen extends StatefulWidget {
  const MuhasebeEntegrasyonScreen({super.key});
  @override
  State<MuhasebeEntegrasyonScreen> createState() => _MuhasebeEntegrasyonScreenState();
}

class _MuhasebeEntegrasyonScreenState extends State<MuhasebeEntegrasyonScreen> {
  String _period = 'ay';
  String? _bas;
  String? _bit;
  bool _smm = false;
  bool _gonderiyor = false;

  Map<String, String> get _donemQ => {
        if (_bas != null && _bit != null) ...{'bas': _bas!, 'bit': _bit!} else 'period': _period,
        'smm': _smm ? '1' : '0',
      };

  String get _donemEk => _bas != null && _bit != null ? '${_bas!.replaceAll('-', '')}_${_bit!.replaceAll('-', '')}' : _period;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/muhasebe-entegrasyon',
      baslik: 'Muhasebe Entegrasyonu',
      ikon: Icons.sync_alt,
      araclar: (ctx, v, yenile) => [IconButton(tooltip: 'Bağlantı ayarları', onPressed: () => _ayarlar(ctx, v, yenile), icon: const Icon(Icons.settings_outlined))],
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final ayar = v['ayar'] is Map ? harita(v['ayar']) : null;
    final hp = harita(v['hp']);
    final gecmis = liste(v['gecmis']);
    final secili = metinOku(ayar?['baglanti_tipi'], 'excel');
    final bagli = ayar != null && tamOku(ayar['aktif']) == 1;
    final api = secili.endsWith('_api');

    final aktarim = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Veri aktarımı', ikon: Icons.download_outlined, alt: 'Dönem seçin, mahsup fişini indirin (Logo / Netsis / Excel uyumlu CSV).'),
        KCipler(
          secenekler: const [('gun', 'Bugün'), ('hafta', 'Son 7 Gün'), ('ay', 'Son 30 Gün')],
          secili: _bas == null ? _period : '',
          onSec: (p) => setState(() { _period = p; _bas = null; _bit = null; }),
        ),
        Row(children: [
          Expanded(child: FTarihAlan('Özel: Başlangıç', deger: _bas, temizlenebilir: true, onSec: (s) => setState(() => _bas = s))),
          const SizedBox(width: 10),
          Expanded(child: FTarihAlan('Bitiş', deger: _bit, temizlenebilir: true, onSec: (s) => setState(() => _bit = s))),
        ]),
        if ((_bas == null) != (_bit == null))
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Özel dönem için iki tarihi de seçin; aksi halde yukarıdaki hazır dönem kullanılır.', style: TextStyle(color: t.amber, fontSize: 12.5))),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _smm,
          activeColor: t.mor1,
          onChanged: (x) => setState(() => _smm = x ?? false),
          title: Text('SMM (Satılan Malın Maliyeti) fişini dahil et', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text('Reçete maliyetinden ${metinOku(hp['smm'], '621')} / ${metinOku(hp['mal'], '153')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 10, runSpacing: 10, children: [
          KButon('Aktarım dosyası indir (CSV)', ikon: Icons.download, renk: t.yesil,
              onTap: () => dosyaIndirKaydet(context, '/muhasebe-entegrasyon/disa-aktar', q: _donemQ, dosyaAdi: 'muhasebe-$secili-$_donemEk.csv').then((_) => yenile())),
          KButon('Cari ekstre (CSV)', ikon: Icons.description_outlined, ikincil: true,
              onTap: () => dosyaIndirKaydet(context, '/muhasebe-entegrasyon/cari-ekstre', q: _donemQ, dosyaAdi: 'cari-ekstre-$_donemEk.csv')),
          if (api) KButon("ERP'ye gönder (API)", ikon: Icons.rocket_launch_outlined, yukleniyor: _gonderiyor, onTap: () => _gonder(context, yenile)),
        ]),
        if (api)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('REST API gönderimi, müşterinin lisanslı Logo/Netsis sunucusuna bağlanır; API adresi + kimlik bilgisi Bağlantı Ayarları\'nda girilmeli.', style: TextStyle(color: t.amber, fontSize: 12.5)),
          ),
        const SizedBox(height: 12),
        Text(
          'Fiş çift taraflıdır (Borç = Alacak): satış tahsilatı ödeme tipine göre Kasa/POS/Banka/Alıcılar\'a, matrah ${metinOku(hp['satis'])} Yurtiçi Satışlar + ${metinOku(hp['hesaplanan_kdv'])} Hesaplanan KDV\'ye; alışlar ${metinOku(hp['mal'])} Mal / ${metinOku(hp['tedarikci'])} Satıcılar; SMM açıksa ${metinOku(hp['smm'], '621')} / ${metinOku(hp['mal'])} stok çıkışına yazılır.',
          style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4),
        ),
      ]),
    );

    final plan = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Hesap planı eşlemesi', ikon: Icons.account_tree_outlined),
        for (final (k, ad) in _hesaplar) FSatir(ad, metinOku(hp[k], '—')),
        const SizedBox(height: 10),
        KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, genis: true, onTap: () => _ayarlar(context, v, yenile)),
      ]),
    );

    return KGovde(yenile: yenile, children: [
      KKart(
        renk: bagli ? t.yesil : t.amber,
        child: Row(children: [
          KIkon(bagli ? Icons.check_circle_outline : Icons.warning_amber_outlined, renk: bagli ? t.yesil : t.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bagli ? 'Aktif bağlantı: ${_tipAd(secili)}' : 'Muhasebe bağlantısı seçilmedi — varsayılan Genel Excel ile dışa aktarabilirsiniz',
                  style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Satış + alış verisi mahsup fişi (CSV) olarak üretilir; muhasebeciniz Logo/Netsis/Excel\'e tek tıkla aktarır.${ayar != null ? ' · Satış KDV: %${metinOku(ayar['kdv_orani'], '10')}' : ''}',
                  style: TextStyle(color: t.sub, fontSize: 12.5)),
            ]),
          ),
          if (genisMi(context)) KButon('Bağlantı ayarları', ikon: Icons.settings_outlined, onTap: () => _ayarlar(context, v, yenile)),
        ]),
      ),
      if (!genisMi(context)) Padding(padding: const EdgeInsets.only(bottom: 12), child: KButon('Bağlantı ayarları', ikon: Icons.settings_outlined, genis: true, onTap: () => _ayarlar(context, v, yenile))),
      if (genisMi(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: aktarim), const SizedBox(width: 12), Expanded(child: plan)])
      else ...[aktarim, plan],
      KBaslik('Aktarım geçmişi', ikon: Icons.history, sag: KRozet('${gecmis.length}', renk: t.mor1)),
      KKart(
        child: gecmis.isEmpty
            ? const KBos(baslik: 'Henüz aktarım yapılmadı', aciklama: 'Aktarım dosyası indirdiğinizde ya da ERP\'ye gönderdiğinizde burada listelenir.', ikon: Icons.history)
            : genisMi(context)
                ? KTablo(
                    basliklar: const ['Tarih', 'Dönem', 'Bağlantı', 'Satır', 'Borç', 'Alacak', 'Durum'],
                    sagaYasla: const {3, 4, 5},
                    satirlar: [
                      for (final g in gecmis)
                        [tarihYaz(g['created_at']), metinOku(g['donem']), _tipAd(metinOku(g['baglanti_tipi'])), sayiYaz(g['satir']), tl(g['borc_toplam'], kisa: true), tl(g['alacak_toplam'], kisa: true), _durumAd(g['durum'])],
                    ],
                  )
                : Column(children: [
                    for (final g in gecmis)
                      KSatir(
                        solIkon: KIkon(Icons.sync_alt, renk: metinOku(g['durum']) == 'hata' ? t.kirmizi : t.mavi),
                        baslik: metinOku(g['donem']),
                        alt: '${tarihYaz(g['created_at'])} · ${_tipAd(metinOku(g['baglanti_tipi']))} · ${sayiYaz(g['satir'])} satır · ${_durumAd(g['durum'])}',
                        sag: Text(tl(g['borc_toplam'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                  ]),
      ),
    ]);
  }

  static String _durumAd(dynamic d) => const {'olusturuldu': 'Oluşturuldu', 'gonderildi': 'Gönderildi', 'hata': 'Hata'}[metinOku(d)] ?? metinOku(d, '—');

  Future<void> _gonder(BuildContext context, Future<void> Function() yenile) async {
    setState(() => _gonderiyor = true);
    final c = await kopruGonderCevap(context, '/muhasebe-entegrasyon/gonder', {
      'period': _period,
      'bas': _bas ?? '',
      'bit': _bit ?? '',
      'smm': _smm ? 1 : 0,
    }, sessiz: true);
    if (!context.mounted) return;
    setState(() => _gonderiyor = false);
    if (c == null) return;
    if (c.ok) {
      kToast(context, c.mesaj ?? "ERP'ye gönderildi.");
      await yenile();
    } else {
      final yanit = metinOku(c.j['yanit']);
      await kOnay(context, 'Gönderilemedi', evet: 'Tamam', hayir: 'Kapat', aciklama: '${c.hata ?? ''}${yanit.isEmpty ? '' : '\n\n$yanit'}');
      await yenile();
    }
  }

  Future<void> _ayarlar(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final ayar = v['ayar'] is Map ? harita(v['ayar']) : <String, dynamic>{};
    final hp = harita(v['hp']);
    String tip = metinOku(ayar['baglanti_tipi'], 'excel');
    bool aktif = tamOku(ayar['aktif']) == 1;
    final firma = TextEditingController(text: metinOku(ayar['firma_kodu']));
    final apiUrl = TextEditingController(text: metinOku(ayar['api_url']));
    final apiKul = TextEditingController(text: metinOku(ayar['api_kullanici']));
    final apiSif = TextEditingController();
    final kdv = TextEditingController(text: metinOku(ayar['kdv_orani'], '10'));
    final hk = {for (final (k, _) in _hesaplar) k: TextEditingController(text: metinOku(hp[k]))};
    bool gonderiyor = false;
    bool kaydedildi = false;
    await kAltSayfa(context, baslik: 'Bağlantı ayarları', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KSecim<String>('Muhasebe bağlantı tipi', deger: tip, secenekler: _tipler, onSec: (x) => ss(() => tip = x ?? 'excel')),
        if (tip.endsWith('_api')) ...[
          Text('ERP REST API bilgileri (otomatik gönderim için):', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 8),
          KAlan('API adresi', apiUrl, ipucu: 'örn. http://sunucu:port/api', klavye: TextInputType.url),
          KAlan('API kullanıcı', apiKul),
          KAlan('API şifre', apiSif, ipucu: 'Değiştirmek için yazın'),
        ],
        Row(children: [
          Expanded(child: KAlan('Firma/Şube kodu', firma, ipucu: '(opsiyonel)')),
          const SizedBox(width: 10),
          Expanded(child: KAlan('Satış KDV %', kdv, klavye: TextInputType.number)),
        ]),
        Text('Hesap planı eşlemesi', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(spacing: 10, children: [
          for (final (k, ad) in _hesaplar) SizedBox(width: 230, child: KAlan(ad, hk[k]!, klavye: TextInputType.number)),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: aktif,
          activeThumbColor: t.mor1,
          onChanged: (x) => ss(() => aktif = x),
          title: Text('Bu bağlantıyı aktif olarak işaretle', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        ),
        if (tip.endsWith('_api'))
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Not: web panelde olduğu gibi şifre alanı boş kaydedilirse sunucudaki kayıtlı şifre de boşalır; API kullanıyorsanız şifreyi her kayıtta girin.', style: TextStyle(color: t.amber, fontSize: 12.5)),
          ),
        KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: gonderiyor, onTap: () async {
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/muhasebe-entegrasyon/ayar-kaydet', {
            'baglanti_tipi': tip,
            'firma_kodu': firma.text.trim(),
            'api_url': apiUrl.text.trim(),
            'api_kullanici': apiKul.text.trim(),
            'api_sifre': apiSif.text,
            'kdv_orani': tamOku(kdv.text),
            'aktif': aktif,
            'hesap_plani': {for (final e in hk.entries) e.key: e.value.text.trim()},
          }, json: true, basariMesaji: 'Bağlantı ayarları kaydedildi.');
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            kaydedildi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (kaydedildi) await yenile();
  }
}
