import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /odeme-ayar — Kaçak Önleme / Ödeme.
/// Web sayfası verisini /api/patron/odeme-modu ucundan okur, /api/patron/odeme-modu-kaydet ile yazar (aynısı burada).
/// Ödeme modu (Klasik / Ön Ödemeli / Açık Hesap + Kart), QR masada ödeme yolları, Kaçak Radarı (süre), bölge bazlı mod.
/// Düzenleme yalnız yetkili (sunucu `duzenleyebilir` bayrağı) — diğerleri salt okur.
class OpOdemeAyarScreen extends StatelessWidget {
  const OpOdemeAyarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/api/patron/odeme-modu',
      baslik: 'Kaçak Önleme / Ödeme',
      ikon: Icons.shield_outlined,
      araclar: (ctx, v, yenile) => [
        IconButton(tooltip: 'Bu sistem ne işe yarar?', onPressed: () => _bilgi(ctx), icon: const Icon(Icons.help_outline)),
      ],
      govde: (ctx, v, yenile) => _Govde(key: ValueKey(v.hashCode), veri: v, yenile: yenile),
    );
  }
}

const _modAd = {'': 'Varsayılan', 'post_pay': 'Klasik', 'on_odeme': 'Ön Ödemeli', 'acik_kart': 'Açık Hesap + Kart'};

class _Govde extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _Govde({super.key, required this.veri, required this.yenile});
  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  late String _mod;
  late bool _kacak, _qrKasa, _qrOnline, _qrCalisir, _duz;
  late int _dk;
  late List<Map<String, dynamic>> _bolgeler;
  bool _kaydediyor = false, _degisti = false;

  bool _b(dynamic v, bool vars) => v == null ? vars : !(v == false || v == 0 || v == '0');

  @override
  void initState() {
    super.initState();
    final v = widget.veri;
    _mod = metinOku(v['mod'], 'post_pay');
    _kacak = _b(v['kacak_aktif'], true);
    _dk = tamOku(v['kacak_dk']) <= 0 ? 90 : tamOku(v['kacak_dk']);
    _qrKasa = _b(v['qr_kasa'], true);
    _qrOnline = _b(v['qr_online'], true);
    _qrCalisir = v['qr_online_calisir'] == true || v['qr_online_calisir'] == 1;
    _duz = v['duzenleyebilir'] == true || v['duzenleyebilir'] == 1;
    _bolgeler = [for (final b in liste(v['bolgeler'])) {'id': b['id'], 'ad': metinOku(b['ad']), 'mod': metinOku(b['mod'])}];
  }

  void _ayarla(VoidCallback f) => setState(() {
        f();
        _degisti = true;
      });

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    final ok = await kopruGonder(
      context,
      '/api/patron/odeme-modu-kaydet',
      {
        'mod': _mod,
        'kacak_aktif': _kacak ? '1' : '0',
        'kacak_dk': '$_dk',
        'qr_online': _qrOnline ? '1' : '0',
        'qr_kasa': _qrKasa ? '1' : '0',
        'bolgeler': jsonEncode([for (final b in _bolgeler) {'id': b['id'], 'mod': b['mod'] ?? ''}]),
      },
      basariMesaji: 'Kaydedildi ✓',
    );
    if (!mounted) return;
    setState(() {
      _kaydediyor = false;
      if (ok) _degisti = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final modlar = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('Ödeme Modu', ikon: Icons.payments_outlined, alt: 'Parayı ne zaman alacağını seç'),
      _modKart(t, 'post_pay', '🍽️', 'Klasik (servis sonrası öde)', 'Müşteri yer, sonra öder. Aktif koruma: aşağıdaki Kaçak Radarı.', false),
      _modKart(t, 'on_odeme', '💳', 'Ön Ödemeli', 'Sipariş önce ödenir, sonra mutfağa düşer. Kaçak = sıfır.', true),
      _modKart(t, 'acik_kart', '🔐', 'Açık Hesap + Kart', 'QR’da kart bağlanır, çıkışta otomatik çekilir.', true),
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.amber.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.amber.withValues(alpha: .4))),
        child: Text('🔒 “Ön Ödemeli” ve “Açık Hesap + Kart”, canlı ödeme (Iyzico/PayTR) devreye girince tam aktifleşir. Şu an her modda aktif koruma: Kaçak Radarı.',
            style: TextStyle(color: t.ink, fontSize: 12.5, height: 1.4)),
      ),
    ]);

    final qr = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('QR Masada Ödeme Seçenekleri', ikon: Icons.qr_code_2, renk: t.mavi),
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          _anahtar(t, 'Garsona / kasada öde',
              'Müşteri “hesabı öde” deyince garsona tutarlı ödeme çağrısı ve bildirim gider; garson nakit ya da kartla tahsil eder.', _qrKasa, (x) => _ayarla(() => _qrKasa = x)),
          Divider(color: t.line, height: 1),
          _anahtar(
            t,
            'Kartla online öde (müşterinin telefonundan)',
            _qrCalisir
                ? 'Müşteri kendi telefonundan kartla öder; ödenen ürünler hesaptan düşer.'
                : 'Açık olsa bile müşteriye görünmez: online ödeme sağlayıcısı (PayTR / iyzico) henüz bağlı değil.',
            _qrOnline,
            (x) => _ayarla(() => _qrOnline = x),
            altRenk: _qrCalisir ? null : t.amber,
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        child: Text('İkisi de kapatılırsa müşteri yine garsona ödeyebilir (hesap ödenmeden kalmasın diye).', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
    ]);

    final radar = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('Kaçak Radarı', ikon: Icons.radar, renk: t.kirmizi),
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          _anahtar(t, 'Uzun süredir açık + ödenmemiş masaları uyar', 'Garson ekranında kırmızı “ödemeden ayrılma riski” kartı gösterilir.', _kacak,
              (x) => _ayarla(() => _kacak = x)),
          if (_kacak)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Text('Uyarı süresi', style: TextStyle(color: t.sub2, fontSize: 13.5)),
                Expanded(
                  child: Slider(
                    value: _dk.toDouble().clamp(15, 240),
                    min: 15,
                    max: 240,
                    divisions: 15,
                    label: '$_dk dk',
                    activeColor: t.mavi,
                    onChanged: _duz ? (x) => _ayarla(() => _dk = x.round()) : null,
                  ),
                ),
                SizedBox(width: 62, child: Text('$_dk dk', textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700))),
              ]),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
        child: Text('Örn: 90 dk’dan uzun süredir açık ve ödenmemiş bir masa varsa garson uyarılır. Süreyi restoranın ortalama oturma süresine göre ayarla.',
            style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35)),
      ),
    ]);

    final bolge = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('Bölge Bazlı Mod', ikon: Icons.map_outlined, renk: t.mor1, alt: '“Varsayılan” = üstteki restoran modu'),
      if (_bolgeler.isEmpty)
        const KKart(
          child: KBos(
            ikon: Icons.map_outlined,
            baslik: 'Tanımlı bölge yok',
            aciklama: 'Bölgeler (Salon, Bahçe, Teras…) İşletme Düzeni ekranından eklenir. Bölge eklenince her birine ayrı ödeme modu verebilirsiniz.',
          ),
        )
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < _bolgeler.length; i++)
              KSatir(
                cizgi: i < _bolgeler.length - 1,
                solIkon: KIkon(Icons.place_outlined, renk: t.mor1, boyut: 34),
                baslik: metinOku(_bolgeler[i]['ad'], '-'),
                sag: SizedBox(
                  width: 170,
                  child: DropdownButton<String>(
                    value: _modAd.containsKey(_bolgeler[i]['mod']) ? _bolgeler[i]['mod'] as String : '',
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    dropdownColor: t.card,
                    style: TextStyle(color: t.ink, fontSize: 14),
                    items: [for (final e in _modAd.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: _duz ? (x) => _ayarla(() => _bolgeler[i]['mod'] = x ?? '') : null,
                  ),
                ),
              ),
          ]),
        ),
    ]);

    final kaydet = _duz
        ? KButon(_degisti ? 'Değişiklikleri Kaydet' : 'Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediyor, onTap: _kaydet)
        : KKart(
            renk: t.sub,
            child: Text('Bu ayarları yalnız işletme sahibi / müdür değiştirebilir. Siz yalnız görüntülüyorsunuz.', style: TextStyle(color: t.sub2, fontSize: 13)),
          );

    if (genisMi(context)) {
      return KGovde(yenile: widget.yenile, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [modlar, qr])),
          const SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [radar, bolge, const SizedBox(height: 6), kaydet])),
        ]),
      ]);
    }
    return KGovde(yenile: widget.yenile, children: [modlar, qr, radar, bolge, const SizedBox(height: 6), kaydet]);
  }

  Widget _modKart(TemaProvider t, String k, String emoji, String ad, String aciklama, bool kilit) {
    final sec = _mod == k;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: sec ? t.mor1.withValues(alpha: t.koyu ? .18 : .08) : t.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _duz ? () => _ayarla(() => _mod = k) : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: sec ? t.mor1 : t.line, width: sec ? 1.6 : 1)),
            child: Row(children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kilit ? '$ad 🔒' : ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(aciklama, style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.3)),
                ]),
              ),
              Icon(sec ? Icons.radio_button_checked : Icons.radio_button_off, color: sec ? t.mor1 : t.sub),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _anahtar(TemaProvider t, String baslik, String alt, bool deger, ValueChanged<bool> f, {Color? altRenk}) => SwitchListTile(
        value: deger,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: Colors.white,
        activeTrackColor: const Color(0xFF22C55E),
        title: Text(baslik, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text(alt, style: TextStyle(color: altRenk ?? t.sub, fontSize: 12.5, height: 1.3)),
        onChanged: _duz ? f : null,
      );
}

void _bilgi(BuildContext context) {
  kAltSayfa(context, baslik: 'Bu sistem ne işe yarar?', icerik: (c) {
    final t = c.watch<TemaProvider>();
    Widget p(String s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(s, style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.45)));
    Widget mod(String e, String ad, String s, Color r) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: r.withValues(alpha: .08), border: Border(left: BorderSide(color: r, width: 3)), borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$e  $ad', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(s, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      p('Restoranın en sessiz kayıplarından biri “ödemeden kalkan masa” ve kontrolsüz açık hesaplardır. Bu ekranda iki şeyi ayarlarsın: parayı ne zaman alacağın (ödeme modu) ve riskli masaları yakalayan radar.'),
      KBaslik('Ödeme Modları', ikon: Icons.payments_outlined),
      mod('🍽️', 'Klasik — en yaygın', 'Müşteri önce yer, sonra öder. Garsonlu/masalı düzen için en doğal akış. Tek koruması Kaçak Radarı’dır.', const Color(0xFF10B981)),
      mod('💳', 'Ön Ödemeli', 'Sipariş önce ödenir, parası alınınca mutfağa düşer. Kaçak riski sıfır. Yoğun, self-servis, bahçe veya QR’dan sipariş için ideal. 🔒 Canlı ödeme (Iyzico/PayTR) kurulunca tam aktifleşir.', const Color(0xFF4F46E5)),
      mod('🔐', 'Açık Hesap + Kart', 'Müşteri QR’da kartını bağlar, masa boyunca sipariş verir, çıkışta tutar otomatik çekilir. Uzun oturan, çok adisyonlu masalar için. 🔒 Canlı ödeme kurulunca tam aktifleşir.', const Color(0xFF7C3AED)),
      KBaslik('Kaçak Radarı', ikon: Icons.radar, renk: t.kirmizi),
      p('Açıkken; uzun süredir açık ve hâlâ ödenmemiş masalar garson ekranında kırmızı “ödemeden ayrılma riski” kartı olarak belirir. Süreyi restoranının ortalama oturma süresine göre ayarla (ör. 90 dk).'),
      KBaslik('Bölge Bazlı (opsiyonel)', ikon: Icons.map_outlined),
      p('Her bölgeye ayrı mod verebilirsin: ör. Bahçe = Ön Ödemeli (kaçak çok), Salon = Klasik. “Varsayılan” seçilirse o bölge üstteki restoran modunu kullanır.'),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.amber.withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.amber.withValues(alpha: .35))),
        child: Text('Öneri: Başlangıç için Klasik + Kaçak Radarı 90 dk yeterli. Canlı ödeme kurulunca kaçağın yoğun olduğu bölgeleri Ön Ödemeli’ye al.',
            style: TextStyle(color: t.ink, fontSize: 13, height: 1.4)),
      ),
    ]);
  });
}
