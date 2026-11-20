import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';
import 'wa_baglan_dialog.dart';

/// Web /whatsapp (whatsapp_panel) — WhatsApp Yönetimi, YEREL.
/// Bağlantı (QR / telefon kodu / oturum kapat) · İşletme bağlantıları · Toplu duyuru · Kontör paketleri + talep ·
/// İstatistik (30 gün) · Mesajlarım (filtreli log) · Alıcılarım. Uçlar: /api/wa/* (web ile aynı).
class OpWhatsappScreen extends StatelessWidget {
  const OpWhatsappScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/whatsapp',
      baslik: 'WhatsApp Yönetimi',
      ikon: Icons.chat_outlined,
      govde: (ctx, veri, yenile) => _WaPanel(veri: veri, yenile: yenile),
    );
  }
}

const _yesil = Color(0xFF25D366);

class _WaPanel extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _WaPanel({required this.veri, required this.yenile});
  @override
  State<_WaPanel> createState() => _WaPanelState();
}

class _WaPanelState extends State<_WaPanel> {
  String _sekme = 'baglanti';
  OpWaDurum? _durum;
  bool _durumYuk = true;
  Timer? _durumT;

  // İşletme bağlantıları
  late final TextEditingController _konum, _igBaslik, _igLink, _webBaslik, _webLink;
  bool _bgKaydediliyor = false;

  // Duyuru
  String _hedef = 'hepsi';
  final _duyuru = TextEditingController();
  bool _duyuruGidiyor = false;
  String? _duyuruSonuc;
  bool _duyuruHata = false;

  // Kontör
  Map<String, dynamic>? _paket;

  // İstatistik
  Map<String, dynamic>? _ozet;

  // Mesajlar
  String _fDurum = '';
  final _fTel = TextEditingController();
  final _fArama = TextEditingController();
  DateTime? _fBas, _fBit;
  int _logSayfa = 1;
  Map<String, dynamic>? _log;
  bool _logYuk = false;

  // Alıcılar
  List<Map<String, dynamic>>? _alicilar;

  String get _sube => '${tamOku(widget.veri['subeId']) == 0 ? 1 : tamOku(widget.veri['subeId'])}';

  @override
  void initState() {
    super.initState();
    final bg = harita(widget.veri['bg']);
    _konum = TextEditingController(text: metinOku(bg['konum']));
    _igBaslik = TextEditingController(text: metinOku(bg['igBaslik'], 'Instagram'));
    _igLink = TextEditingController(text: metinOku(bg['igLink']));
    _webBaslik = TextEditingController(text: metinOku(bg['webBaslik'], 'Web Sitesi'));
    _webLink = TextEditingController(text: metinOku(bg['webLink']));
    _durumYenile();
    _kontorYukle();
    _ozetYukle();
    _durumT = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _durumYenile();
    });
  }

  @override
  void dispose() {
    _durumT?.cancel();
    for (final c in [_konum, _igBaslik, _igLink, _webBaslik, _webLink, _duyuru, _fTel, _fArama]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<Map<String, dynamic>?> _al(String yol, [Map<String, String>? q]) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return null;
    try {
      final c = await KopruApi.al(tok, yol, q: {'sube': _sube, '_': '${DateTime.now().millisecondsSinceEpoch}', ...?q});
      return c.j;
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
      return null;
    }
  }

  Future<void> _hepsiniYenile() async {
    await Future.wait([_durumYenile(), _kontorYukle(), _ozetYukle(), if (_sekme == 'mesajlar') _logYukle(_logSayfa), if (_sekme == 'alicilar') _aliciYukle()]);
  }

  // ───────── Bağlantı ─────────
  Future<void> _durumYenile() async {
    final j = await _al('/api/wa/durum');
    if (!mounted || j == null) return;
    setState(() {
      _durum = OpWaDurum.coz(j);
      _durumYuk = false;
    });
  }

  Future<void> _baglan() async {
    final ok = await opWaBaglanDialog(context, baslik: 'WhatsApp\'ı Bağla', onek: '/api/wa', ek: {'sube': _sube});
    if (ok == true && mounted) kToast(context, 'WhatsApp bağlandı.');
    _durumYenile();
  }

  Future<void> _cikis() async {
    if (!await kOnay(context, 'Oturum kapatılsın mı?', tehlikeli: true, evet: 'Kapat', aciklama: 'Bildirimler WhatsApp yerine SMS\'e düşebilir. Yeniden bağlamak için QR okutmanız gerekir.')) return;
    if (!mounted) return;
    final c = await kopruGonderCevap(context, '/api/wa/cikis', {'sube': _sube}, json: true, sessiz: true);
    if (mounted) kToast(context, c == null ? 'İşlem yapılamadı.' : 'Oturum kapatıldı.', hata: c == null);
    Future.delayed(const Duration(seconds: 1), _durumYenile);
  }

  Future<void> _baglantiKaydet() async {
    setState(() => _bgKaydediliyor = true);
    await kopruGonder(context, '/api/wa/baglantilar-kaydet', {
      'konum_linki': _konum.text.trim(),
      'instagram_baslik': _igBaslik.text.trim(),
      'instagram_linki': _igLink.text.trim(),
      'web_baslik': _webBaslik.text.trim(),
      'web_linki': _webLink.text.trim(),
    }, basariMesaji: 'Bağlantılar kaydedildi.');
    if (mounted) setState(() => _bgKaydediliyor = false);
  }

  // ───────── Duyuru ─────────
  Future<void> _duyuruGonder() async {
    final m = _duyuru.text.trim();
    if (m.isEmpty) {
      setState(() {
        _duyuruSonuc = 'Mesaj boş olamaz.';
        _duyuruHata = true;
      });
      return;
    }
    final etiket = {'hepsi': 'tüm müşterilere', 'son30': 'son 30 günde gelenlere', 'sadik': 'sadık müşterilere'}[_hedef];
    if (!await kOnay(context, 'Duyuru gönderilsin mi?', evet: 'Gönder', aciklama: 'Duyuru $etiket WhatsApp\'tan gönderilecek. Her mesaj 1 kontör harcar.')) return;
    if (!mounted) return;
    setState(() {
      _duyuruGidiyor = true;
      _duyuruSonuc = null;
    });
    final c = await kopruGonderCevap(context, '/api/wa/duyuru-gonder', {'sube': _sube, 'hedef': _hedef, 'mesaj': m}, sessiz: true);
    if (!mounted) return;
    setState(() {
      _duyuruGidiyor = false;
      if (c != null && c.ok) {
        final atl = tamOku(c.j['atlanan']);
        _duyuruSonuc = '${tamOku(c.j['gonderilen'])} kişiye gönderildi${atl > 0 ? ' · $atl atlandı (kontör/numara)' : ''}';
        _duyuruHata = false;
        _duyuru.clear();
      } else {
        _duyuruSonuc = c?.hata ?? 'Gönderilemedi.';
        _duyuruHata = true;
      }
    });
    _kontorYukle();
  }

  // ───────── Kontör ─────────
  Future<void> _kontorYukle() async {
    final j = await _al('/api/wa/paket-durum');
    if (mounted && j != null) setState(() => _paket = j);
  }

  Future<void> _talepAc(String key, Map<String, dynamic> p) async {
    final ilt = TextEditingController();
    await kAltSayfa(context, baslik: 'Kontör Talebi · ${metinOku(p['ad'])}', icerik: (c) {
      final t = c.read<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bu paket için talebinizi bırakıyorsunuz (${metinOku(p['fiyat'])}). Yetkilimize bildirim gider; ödeme ve kontör yükleme için sizinle iletişime geçilir.',
            style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 12),
        KAlan('İletişim / Not (opsiyonel)', ilt, ipucu: 'örn. bugün ödemek istiyorum / 0555 123 45 67'),
        KButon('Talep Gönder', ikon: Icons.send, genis: true, renk: _yesil, onTap: () async {
          final r = await kopruGonderCevap(c, '/api/wa/kontor-talep', {'sube': _sube, 'paket': key, 'iletisim': ilt.text.trim()}, json: true);
          if (r != null && r.ok && c.mounted) {
            Navigator.pop(c);
            if (mounted) kToast(context, r.mesaj ?? 'Talebiniz alındı.');
          }
        }),
      ]);
    });
    ilt.dispose();
  }

  // ───────── İstatistik / log / alıcı ─────────
  Future<void> _ozetYukle() async {
    final j = await _al('/api/wa/ozet-data');
    if (mounted && j != null) setState(() => _ozet = j);
  }

  String _tarihQ(DateTime? d) => d == null ? '' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _logYukle(int sayfa) async {
    setState(() {
      _logYuk = true;
      _logSayfa = sayfa;
    });
    final j = await _al('/api/wa/loglar-data', {
      'sayfa': '$sayfa',
      'durum': _fDurum,
      'telefon': _fTel.text.trim(),
      'baslangic': _tarihQ(_fBas),
      'bitis': _tarihQ(_fBit),
      'arama': _fArama.text.trim(),
    });
    if (!mounted) return;
    setState(() {
      _logYuk = false;
      if (j != null) _log = j;
    });
  }

  Future<void> _aliciYukle() async {
    final j = await _al('/api/wa/aliciler-data');
    if (mounted && j != null) setState(() => _alicilar = liste(j['aliciler']));
  }

  void _sekmeSec(String k) {
    setState(() => _sekme = k);
    if (k == 'mesajlar' && _log == null) _logYukle(1);
    if (k == 'alicilar' && _alicilar == null) _aliciYukle();
    if (k == 'istatistik') _ozetYukle();
    if (k == 'kontor') _kontorYukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return KGovde(
      yenile: () async {
        await widget.yenile();
        await _hepsiniYenile();
      },
      children: [
        _durumSeridi(t),
        const SizedBox(height: 12),
        KCipler(
          secenekler: const [
            ('baglanti', 'Bağlantı'),
            ('duyuru', 'Toplu Duyuru'),
            ('kontor', 'Kontör'),
            ('istatistik', 'İstatistik'),
            ('mesajlar', 'Mesajlarım'),
            ('alicilar', 'Alıcılarım'),
          ],
          secili: _sekme,
          onSec: _sekmeSec,
        ),
        ...switch (_sekme) {
          'duyuru' => _duyuruBolum(t),
          'kontor' => _kontorBolum(t),
          'istatistik' => _istatistikBolum(t),
          'mesajlar' => _mesajBolum(t),
          'alicilar' => _aliciBolum(t),
          _ => _baglantiBolum(t),
        },
      ],
    );
  }

  Widget _durumSeridi(TemaProvider t) {
    final d = _durum;
    final renk = d == null ? t.sub : (d.bagli ? const Color(0xFF16A34A) : (d.qrBekliyor ? t.amber : t.kirmizi));
    final bakiye = tamOku(_paket?['bakiye']);
    return KKart(
      renk: renk,
      child: Row(children: [
        KIkon(d?.bagli == true ? Icons.verified_outlined : Icons.chat_outlined, renk: renk, boyut: 44),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_durumYuk ? 'Durum yükleniyor…' : (d!.bagli ? 'WhatsApp bağlı' : (d.qrBekliyor ? 'QR bekleniyor' : 'WhatsApp bağlı değil')),
                style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(
              d == null ? '' : (d.bagli ? 'Numara: ${d.numara}' : (d.hata != null ? opWaHataMetni(d.hata) : 'Bildirimler gönderilemiyor; "Bağlan" ile QR okutun.')),
              style: TextStyle(color: t.sub, fontSize: 12.5),
            ),
          ]),
        ),
        if (_paket != null) KRozet('${sayiYaz(bakiye)} kontör', renk: bakiye <= 500 ? t.kirmizi : (bakiye <= 1000 ? t.amber : const Color(0xFF16A34A))),
      ]),
    );
  }

  List<Widget> _baglantiBolum(TemaProvider t) {
    final d = _durum;
    final genis = genisMi(context);
    final baglantiKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Bağlantı Durumu', ikon: Icons.link, renk: _yesil,
            sag: d == null ? null : KRozet(d.bagli ? 'Bağlı' : (d.qrBekliyor ? 'QR Bekleniyor' : 'Bağlı Değil'), renk: d.bagli ? const Color(0xFF16A34A) : (d.qrBekliyor ? t.amber : t.kirmizi))),
        Center(child: Icon(d?.bagli == true ? Icons.check_circle : Icons.phonelink_off, size: 56, color: d?.bagli == true ? const Color(0xFF16A34A) : t.sub)),
        const SizedBox(height: 8),
        Text(
          d == null
              ? 'Durum alınıyor…'
              : d.bagli
                  ? 'WhatsApp bağlı numara: ${d.numara}'
                  : (d.qrBekliyor ? 'Oturum başlatıldı, QR okutulmayı bekliyor.' : 'WhatsApp oturumu kapalı. Başlatmak için "WhatsApp\'ı Bağla"ya dokunun.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: t.ink, fontSize: 14),
        ),
        if (d?.hata != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(opWaHataMetni(d!.hata), textAlign: TextAlign.center, style: TextStyle(color: t.kirmizi, fontSize: 12.5))),
        const SizedBox(height: 14),
        if (d?.bagli == true)
          KButon('Oturumu Kapat', ikon: Icons.logout, renk: t.kirmizi, ikincil: true, genis: true, onTap: _cikis)
        else
          KButon(d?.qrBekliyor == true ? 'QR\'ı Göster / Telefonla Bağlan' : 'WhatsApp\'ı Bağla', ikon: Icons.qr_code_2, renk: _yesil, genis: true, onTap: _baglan),
      ]),
    );
    final bilgiKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KBaslik('Nasıl Çalışır?', ikon: Icons.info_outline, renk: t.mavi),
        for (final s in const [
          'WhatsApp bağlandıktan sonra sipariş/rezervasyon bildirimleri kendi WhatsApp numaranız üzerinden iletilir.',
          'Müşterinin WhatsApp\'ı yoksa mesaj otomatik SMS\'e düşebilir — bildirim kaybolmaz.',
          'Mesajlar müşterilere doğal aralıklarla, kişiselleştirilmiş gider.',
          'İlk hafta hazırlık: numaranız stabil çalışsın diye ilk günler günlük gönderim kademeli artar.',
          'Bağlantı koparsa panel size haber verir, bildirimler SMS\'e geçebilir.',
          'İpucu: en az 2 haftadır kullanılan, WhatsApp Business yüklü bir numara en sağlıklı sonucu verir.',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: t.sub)),
              const SizedBox(width: 8),
              Expanded(child: Text(s, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4))),
            ]),
          ),
        Text('Günlük limit: 200', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
    return [
      if (genis)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: baglantiKart), const SizedBox(width: 12), Expanded(child: bilgiKart)])
      else ...[baglantiKart, bilgiKart],
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('İşletme Bağlantıları', ikon: Icons.link_outlined, renk: t.mor1,
              alt: 'Müşteriye WhatsApp mesajı yazarken tek tıkla eklenir. Buton başlığını siz belirlersiniz; boş bıraktıklarınız görünmez.'),
          KAlan('Konum (Google Maps → Paylaş → Bağlantıyı kopyala)', _konum, ipucu: 'https://maps.app.goo.gl/...', klavye: TextInputType.url),
          _ciftAlan('Instagram buton başlığı', _igBaslik, 'Instagram bağlantısı', _igLink, 'https://instagram.com/kullaniciadi'),
          _ciftAlan('Web buton başlığı', _webBaslik, 'Web bağlantısı', _webLink, 'https://...'),
          Align(alignment: Alignment.centerLeft, child: KButon('Bağlantıları Kaydet', ikon: Icons.save_outlined, yukleniyor: _bgKaydediliyor, onTap: _baglantiKaydet)),
        ]),
      ),
    ];
  }

  Widget _ciftAlan(String e1, TextEditingController c1, String e2, TextEditingController c2, String ipucu) {
    if (!genisMi(context)) {
      return Column(children: [KAlan(e1, c1), KAlan(e2, c2, ipucu: ipucu, klavye: TextInputType.url)]);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 220, child: KAlan(e1, c1)),
      const SizedBox(width: 12),
      Expanded(child: KAlan(e2, c2, ipucu: ipucu, klavye: TextInputType.url)),
    ]);
  }

  List<Widget> _duyuruBolum(TemaProvider t) => [
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Toplu Duyuru / Kampanya', ikon: Icons.campaign_outlined, renk: _yesil,
                alt: 'Seçtiğiniz müşteri grubuna tek seferde WhatsApp mesajı gönderin. Her mesaj 1 kontör harcar; kontör biterse gönderim durur. Yalnız sahip/müdür gönderebilir.'),
            KSecim<String>('Hedef Kitle', deger: _hedef, secenekler: const [
              ('hepsi', 'Tüm müşteriler (telefonu olan)'),
              ('son30', 'Son 30 günde gelenler'),
              ('sadik', 'Sadık müşteriler (3+ sipariş)'),
            ], onSec: (v) => setState(() => _hedef = v ?? 'hepsi')),
            KAlan('Mesaj', _duyuru, satir: 4, ipucu: 'Örn: Bu hafta sonu tüm pizzalarda %20 indirim! Sizi bekliyoruz.'),
            Row(children: [
              KButon('Duyuruyu Gönder', ikon: Icons.send, renk: _yesil, yukleniyor: _duyuruGidiyor, onTap: _duyuruGonder),
              const SizedBox(width: 12),
              if (_duyuruSonuc != null)
                Expanded(child: Text(_duyuruSonuc!, style: TextStyle(color: _duyuruHata ? t.kirmizi : const Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w700))),
            ]),
          ]),
        ),
      ];

  List<Widget> _kontorBolum(TemaProvider t) {
    final p = _paket;
    if (p == null) return const [SizedBox(height: 160, child: KYukleniyor())];
    final bakiye = tamOku(p['bakiye']);
    final kontorlu = p['kontorlu'] == true || p['kontorlu'] == 1;
    final paketler = harita(p['paketler']);
    final ilk = paketler.isEmpty ? null : sayiOku(harita(paketler.values.first)['adet']) == 0 ? null : harita(paketler.values.first);
    final ilkBirim = ilk == null ? 0.0 : _fiyatSayi(ilk['fiyat']) / sayiOku(ilk['adet']);
    return [
      KKpiIzgara([
        KKpi(etiket: 'Kontör bakiyesi', deger: sayiYaz(bakiye), ikon: Icons.account_balance_wallet_outlined, renk: bakiye <= 500 ? t.kirmizi : (bakiye <= 1000 ? t.amber : const Color(0xFF16A34A))),
        KKpi(
          etiket: kontorlu ? 'Kontörlü dönem' : 'Ücretsiz / deneme dönemi',
          deger: kontorlu ? '1 mesaj = 1 kontör' : 'Kontör düşmez',
          alt: kontorlu ? 'Bakiyeniz bitmeden paket alın.' : (metinOku(p['deneme_bitis']).isEmpty ? null : 'Bitiş: ${tarihYaz(p['deneme_bitis'], saat: false)}'),
          ikon: Icons.info_outline,
          renk: t.mavi,
        ),
      ]),
      KBaslik('WhatsApp Kontör Paketleri', ikon: Icons.local_offer_outlined, renk: _yesil,
          alt: '1 mesaj = 1 kontör. Sipariş/rezervasyon bildirimi ve manuel mesajlar kontörden düşer. Çok alırsanız tanesi daha ucuza gelir.'),
      LayoutBuilder(builder: (c, k) {
        final n = k.maxWidth >= 900 ? 3 : (k.maxWidth >= 520 ? 2 : 1);
        final g = (k.maxWidth - 10 * (n - 1)) / n;
        final anahtarlar = paketler.keys.toList();
        return Wrap(spacing: 10, runSpacing: 10, children: [
          for (var i = 0; i < anahtarlar.length; i++)
            SizedBox(width: g, child: _paketKart(t, anahtarlar[i], harita(paketler[anahtarlar[i]]), ilkBirim, i == anahtarlar.length - 1)),
        ]);
      }),
      const SizedBox(height: 12),
      Text('Ödeme sonrası kontörünüz manuel olarak yüklenir. "Kontör Al" ile talebinizi bırakın, en kısa sürede sizinle iletişime geçelim.',
          textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5)),
    ];
  }

  double _fiyatSayi(dynamic f) => sayiOku(metinOku(f).replaceAll(RegExp(r'[^0-9,]'), ''));

  Widget _paketKart(TemaProvider t, String key, Map<String, dynamic> p, double ilkBirim, bool enIyi) {
    final adet = sayiOku(p['adet']);
    final fiyat = _fiyatSayi(p['fiyat']);
    final birim = adet > 0 ? fiyat / adet : 0.0;
    final avantaj = ilkBirim > 0 ? (ilkBirim - birim) * adet : 0.0;
    return KKart(
      margin: EdgeInsets.zero,
      renk: enIyi ? t.gold : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (enIyi) Padding(padding: const EdgeInsets.only(bottom: 6), child: KRozet('En avantajlı', renk: t.gold, ikon: Icons.star)),
        Text(metinOku(p['ad']), style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('tanesi ${birim.toStringAsFixed(3).replaceAll('.', ',')} TL', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 8),
        Text(metinOku(p['fiyat']), style: TextStyle(color: _yesil, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(avantaj >= 1 ? '${sayiYaz(avantaj.round())} TL avantaj' : '—', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        KButon('Kontör Al', ikon: Icons.add_shopping_cart, renk: _yesil, genis: true, onTap: () => _talepAc(key, p)),
      ]),
    );
  }

  List<Widget> _istatistikBolum(TemaProvider t) {
    final o = _ozet;
    if (o == null) return const [SizedBox(height: 160, child: KYukleniyor())];
    final gunler = liste(o['gunler']);
    final toplam30 = gunler.fold<int>(0, (a, g) => a + tamOku(g['basarili']) + tamOku(g['basarisiz']) + tamOku(g['sms']));
    return [
      KKpiIzgara([
        KKpi(etiket: 'Bağlı numara', deger: metinOku(o['numara'], '—'), ikon: Icons.phone_android, renk: t.mavi),
        KKpi(etiket: 'Bugün toplam', deger: sayiYaz(o['bugun']), alt: '✓ ${tamOku(o['bugun_ok'])}  ✕ ${tamOku(o['bugun_fail'])}  ↷ ${tamOku(o['bugun_sms'])} SMS', ikon: Icons.today, renk: _yesil),
        KKpi(etiket: '7 gün', deger: sayiYaz(o['son7']), alt: '${tamOku(o['son7_ok'])} başarılı', ikon: Icons.date_range, renk: t.mor1),
        KKpi(etiket: '30 gün', deger: sayiYaz(o['son30']), alt: '${tamOku(o['son30_ok'])} başarılı', ikon: Icons.calendar_month_outlined, renk: t.mor1),
        KKpi(etiket: 'Haftalık başarı', deger: yuzde(o['basari']), ikon: Icons.verified_outlined, renk: t.amber),
        KKpi(etiket: 'Günlük limit', deger: sayiYaz(o['gunluk_limit'] ?? 200), ikon: Icons.speed, renk: t.mavi),
      ]),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KBaslik('Son 30 Gün — Günlük Mesaj Hacmi', ikon: Icons.bar_chart, renk: _yesil),
          if (toplam30 == 0)
            const KBos(
              baslik: 'Son 30 günde gönderilen mesaj yok',
              aciklama: 'WhatsApp bağlandığında sipariş/rezervasyon bildirimleri ve duyurular burada günlük olarak görünür. Önce "Bağlantı" sekmesinden WhatsApp\'ı bağlayın.',
              ikon: Icons.bar_chart,
            )
          else
            _GunlukGrafik(gunler: gunler),
          const SizedBox(height: 8),
          Wrap(spacing: 14, runSpacing: 6, children: [
            _lejant(t, 'Başarılı', _yesil),
            _lejant(t, 'Başarısız', t.kirmizi),
            _lejant(t, 'SMS\'e düştü', t.amber),
          ]),
        ]),
      ),
    ];
  }

  Widget _lejant(TemaProvider t, String e, Color r) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: r, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(e, style: TextStyle(color: t.sub2, fontSize: 12.5)),
      ]);

  static const _dEt = {'1': 'Gönderildi', '2': 'Başarısız', '3': 'SMS\'e Düştü', '0': 'Kuyrukta'};

  Color _dRenk(TemaProvider t, String d) => switch (d) { '1' => const Color(0xFF16A34A), '2' => t.kirmizi, '3' => t.amber, _ => t.sub };

  Future<void> _tarihSec(bool bas) async {
    final simdi = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: (bas ? _fBas : _fBit) ?? simdi,
      firstDate: DateTime(simdi.year - 3),
      lastDate: simdi.add(const Duration(days: 1)),
      helpText: bas ? 'Başlangıç tarihi' : 'Bitiş tarihi',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (d == null) return;
    setState(() => bas ? _fBas = d : _fBit = d);
    _logYukle(1);
  }

  List<Widget> _mesajBolum(TemaProvider t) {
    final j = _log;
    final kayitlar = liste(j?['kayitlar']);
    final toplam = tamOku(j?['toplam']);
    final boyut = tamOku(j?['boyut']) == 0 ? 20 : tamOku(j?['boyut']);
    final sayfaSay = toplam == 0 ? 1 : (toplam / boyut).ceil();
    final filtreVar = _fDurum.isNotEmpty || _fTel.text.isNotEmpty || _fArama.text.isNotEmpty || _fBas != null || _fBit != null;
    return [
      KCipler(
        secenekler: const [('', 'Tümü'), ('1', 'Gönderildi'), ('2', 'Başarısız'), ('3', 'SMS\'e Düştü')],
        secili: _fDurum,
        onSec: (k) {
          setState(() => _fDurum = k);
          _logYukle(1);
        },
      ),
      Wrap(spacing: 10, runSpacing: 0, crossAxisAlignment: WrapCrossAlignment.end, children: [
        SizedBox(width: genisMi(context) ? 200 : double.infinity, child: KAlan('Telefon', _fTel, ipucu: '905...', klavye: TextInputType.phone)),
        SizedBox(width: genisMi(context) ? 260 : double.infinity, child: KAlan('Mesajda ara', _fArama, ipucu: '...')),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            KButon(_fBas == null ? 'Başlangıç' : tarihYaz(_tarihQ(_fBas), saat: false), ikon: Icons.event, ikincil: true, onTap: () => _tarihSec(true)),
            KButon(_fBit == null ? 'Bitiş' : tarihYaz(_tarihQ(_fBit), saat: false), ikon: Icons.event, ikincil: true, onTap: () => _tarihSec(false)),
            KButon('Filtrele', ikon: Icons.filter_alt_outlined, onTap: () => _logYukle(1)),
            if (filtreVar)
              KButon('Sıfırla', ikon: Icons.clear, ikincil: true, onTap: () {
                setState(() {
                  _fDurum = '';
                  _fTel.clear();
                  _fArama.clear();
                  _fBas = null;
                  _fBit = null;
                });
                _logYukle(1);
              }),
          ]),
        ),
      ]),
      if (j == null || (_logYuk && kayitlar.isEmpty))
        const SizedBox(height: 140, child: KYukleniyor())
      else if (kayitlar.isEmpty)
        KBos(
          baslik: filtreVar ? 'Filtreye uyan mesaj yok' : 'Henüz WhatsApp mesajı gönderilmedi',
          aciklama: filtreVar
              ? 'Filtreleri değiştirin ya da "Sıfırla" ile tüm mesajları görün.'
              : 'Sipariş/rezervasyon bildirimleri ve toplu duyurular gönderildikçe burada listelenir. WhatsApp bağlı değilse "Bağlantı" sekmesinden bağlayın.',
          ikon: Icons.mark_chat_unread_outlined,
        )
      else if (genisMi(context))
        KKart(
          padding: const EdgeInsets.all(6),
          child: KTablo(
            basliklar: const ['Tarih', 'Telefon', 'Durum', 'Mesaj', 'Hata'],
            satirlar: [
              for (final k in kayitlar)
                [tarihYaz(k['created_at']), metinOku(k['telefon'], '—'), _dEt['${tamOku(k['durum'])}'] ?? metinOku(k['durum']), metinOku(k['mesaj']), metinOku(k['hata'])],
            ],
            onSatir: (i) => _mesajDetay(kayitlar[i]),
          ),
        )
      else
        for (final k in kayitlar)
          KKart(
            margin: const EdgeInsets.only(bottom: 8),
            renk: _dRenk(t, '${tamOku(k['durum'])}'),
            onTap: () => _mesajDetay(k),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(metinOku(k['telefon'], '—'), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700))),
                KRozet(_dEt['${tamOku(k['durum'])}'] ?? metinOku(k['durum']), renk: _dRenk(t, '${tamOku(k['durum'])}')),
              ]),
              const SizedBox(height: 4),
              Text(metinOku(k['mesaj']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 13)),
              const SizedBox(height: 4),
              Text(tarihYaz(k['created_at']) + (metinOku(k['hata']).isEmpty ? '' : ' · ${metinOku(k['hata'])}'), style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
      if (kayitlar.isNotEmpty)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: _logSayfa <= 1 ? null : () => _logYukle(_logSayfa - 1), icon: const Icon(Icons.chevron_left)),
          Text('$_logSayfa / $sayfaSay  ($toplam)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          IconButton(onPressed: _logSayfa >= sayfaSay ? null : () => _logYukle(_logSayfa + 1), icon: const Icon(Icons.chevron_right)),
        ]),
    ];
  }

  void _mesajDetay(Map<String, dynamic> k) {
    kAltSayfa(context, baslik: 'Mesaj · ${metinOku(k['telefon'], '—')}', icerik: (c) {
      final t = c.read<TemaProvider>();
      final d = '${tamOku(k['durum'])}';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [KRozet(_dEt[d] ?? d, renk: _dRenk(t, d)), const SizedBox(width: 8), Text(tarihYaz(k['created_at']), style: TextStyle(color: t.sub, fontSize: 13))]),
        const SizedBox(height: 12),
        SelectableText(metinOku(k['mesaj'], '(boş)'), style: TextStyle(color: t.ink, fontSize: 14.5, height: 1.45)),
        if (metinOku(k['hata']).isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Hata: ${metinOku(k['hata'])}', style: TextStyle(color: t.kirmizi, fontSize: 13)),
        ],
      ]);
    });
  }

  List<Widget> _aliciBolum(TemaProvider t) {
    final a = _alicilar;
    if (a == null) return const [SizedBox(height: 140, child: KYukleniyor())];
    if (a.isEmpty) {
      return const [
        KBos(
          baslik: 'Henüz alıcı yok',
          aciklama: 'WhatsApp\'tan mesaj gönderilen her numara burada toplam/başarılı sayısıyla listelenir. Mesaj gönderildikçe dolar.',
          ikon: Icons.people_outline,
        ),
      ];
    }
    if (genisMi(context)) {
      return [
        KKart(
          padding: const EdgeInsets.all(6),
          child: KTablo(
            basliklar: const ['Telefon', 'Toplam', 'Başarılı', 'İlk', 'Son'],
            sagaYasla: const {1, 2},
            satirlar: [for (final x in a) [metinOku(x['telefon'], '—'), sayiYaz(x['toplam']), sayiYaz(x['basarili']), tarihYaz(x['ilk']), tarihYaz(x['son'])]],
          ),
        ),
      ];
    }
    return [
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(children: [
          for (final x in a)
            KSatir(
              solIkon: KIkon(Icons.person_outline, renk: _yesil),
              baslik: metinOku(x['telefon'], '—'),
              alt: 'İlk: ${tarihYaz(x['ilk'])} · Son: ${tarihYaz(x['son'])}',
              sag: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(sayiYaz(x['toplam']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                Text('${sayiYaz(x['basarili'])} başarılı', style: TextStyle(color: t.sub, fontSize: 11.5)),
              ]),
            ),
        ]),
      ),
    ];
  }
}

/// 30 günlük yığılmış çubuk grafik (başarılı / başarısız / SMS)
class _GunlukGrafik extends StatelessWidget {
  final List<Map<String, dynamic>> gunler;
  const _GunlukGrafik({required this.gunler});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    var enCok = 1;
    for (final g in gunler) {
      final s = tamOku(g['basarili']) + tamOku(g['basarisiz']) + tamOku(g['sms']);
      if (s > enCok) enCok = s;
    }
    const yuk = 170.0;
    return SizedBox(
      height: yuk + 26,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < gunler.length; i++)
          Expanded(
            child: Tooltip(
              message: '${metinOku(gunler[i]['gun'])}\nBaşarılı: ${tamOku(gunler[i]['basarili'])}\nBaşarısız: ${tamOku(gunler[i]['basarisiz'])}\nSMS: ${tamOku(gunler[i]['sms'])}',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(height: yuk * tamOku(gunler[i]['sms']) / enCok, color: t.amber),
                  Container(height: yuk * tamOku(gunler[i]['basarisiz']) / enCok, color: t.kirmizi),
                  Container(height: yuk * tamOku(gunler[i]['basarili']) / enCok, color: _yesil),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 22,
                    child: i % 5 == 0 || i == gunler.length - 1
                        ? FittedBox(child: Text(metinOku(gunler[i]['gun']), style: TextStyle(color: t.sub, fontSize: 10)))
                        : null,
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
