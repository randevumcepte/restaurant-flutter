import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Web /cagri-ekran — Gelen çağrı ekranı (ekran-pop). Web gibi her 3 sn /api/callerid-aktif yoklanır;
/// çağrı gelince müşteri kartı açılır (ad, sipariş sayısı, toplam harcama, puan, adres, son siparişler).
/// Kapat / Sipariş Oluştur → çağrı "görüldü" işaretlenir (/api/callerid-goruldu). Tarayıcı açılmaz.
class OpCagriEkranScreen extends StatefulWidget {
  const OpCagriEkranScreen({super.key});
  @override
  State<OpCagriEkranScreen> createState() => _OpCagriEkranScreenState();
}

class _OpCagriEkranScreenState extends State<OpCagriEkranScreen> {
  Timer? _zaman;
  Map<String, dynamic>? _cagri;
  int? _aktifId;
  final Set<int> _kapatilan = {};
  String? _hata;
  bool _ilk = true;
  bool _istekte = false;
  bool _yetkisiz = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _basla());
  }

  /// Önce web sayfasının yetki kapısı (/cagri-ekran) denetlenir; yetki varsa yoklama başlar.
  Future<void> _basla() async {
    if (!mounted) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/cagri-ekran');
      if (!mounted) return;
      if (c.yetkisiz) {
        setState(() { _yetkisiz = true; _ilk = false; });
        return;
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
      return;
    }
    _yokla();
    _zaman = Timer.periodic(const Duration(seconds: 3), (_) => _yokla());
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> _yokla() async {
    if (_istekte || !mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    _istekte = true;
    try {
      final c = await KopruApi.al(tok, '/api/callerid-aktif');
      if (!mounted) return;
      setState(() {
        _ilk = false;
        if (!c.ok) {
          _hata = c.hata;
          return;
        }
        _hata = null;
        final cg = harita(c.j['cagri']);
        if (cg.isEmpty) {
          _cagri = null;
          _aktifId = null;
        } else {
          final id = tamOku(cg['id']);
          if (_kapatilan.contains(id)) return;
          _cagri = cg;
          _aktifId = id;
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } finally {
      _istekte = false;
    }
  }

  Future<void> _kapat({bool siparis = false}) async {
    final id = _aktifId;
    final tel = metinOku(_cagri?['telefon']);
    if (id != null) {
      _kapatilan.add(id);
      final tok = context.read<AuthProvider>().token;
      if (tok != null) {
        // Web ile aynı: sessizce "görüldü" işaretle
        KopruApi.gonder(tok, '/api/callerid-goruldu', {'cagri_id': id}).catchError((_) => KopruCevap(0, const {}));
      }
    }
    setState(() { _cagri = null; _aktifId = null; });
    if (siparis) {
      if (tel.isNotEmpty) kToast(context, 'Arayan: $tel — paket siparişini bu numarayla açın.');
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/paket', 'Paket Servis')));
    }
  }

  Future<void> _testCagri() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    final ok = await kOnay(context, 'Test çağrısı üretilsin mi?', aciklama: 'Kayıtlı müşterilerden rastgele bir numarayla sahte bir gelen çağrı oluşturulur; ekranın çalıştığını görmek içindir.');
    if (!ok) return;
    final c = await KopruApi.al(tok, '/callerid-test');
    if (!mounted) return;
    kToast(context, c.j['test'] == true || c.ok ? 'Test çağrısı üretildi; birkaç saniye içinde açılır.' : (c.hata ?? 'Test çağrısı üretilemedi.'), hata: !(c.j['test'] == true || c.ok));
    _yokla();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return KSayfa(
      baslik: 'Gelen Çağrı Ekranı',
      ikon: Icons.ring_volume_outlined,
      altBaslik: 'Çağrı gelince müşteri kartı otomatik açılır (3 sn\'de bir kontrol)',
      araclar: [
        IconButton(tooltip: 'Çağrı kayıtları', icon: const Icon(Icons.history), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/cagrilar', 'Çağrı Merkezi')))),
        IconButton(tooltip: 'Test çağrısı üret', icon: const Icon(Icons.science_outlined), onPressed: _testCagri),
        IconButton(tooltip: 'Yenile', icon: const Icon(Icons.refresh), onPressed: _yokla),
      ],
      govde: _yetkisiz
          ? const KHata('', yetkisiz: true)
          : _ilk
          ? const KYukleniyor(metin: 'Çağrı bekleniyor…')
          : KGovde(maxGenislik: 640, yenile: _yokla, children: [
              if (_hata != null)
                KKart(renk: t.amber, child: Text('Bağlantı sorunu: $_hata — yeniden denenecek.', style: TextStyle(color: t.sub2, fontSize: 13))),
              if (_cagri == null) _bekleme(t) else _kart(t, _cagri!),
            ]),
    );
  }

  Widget _bekleme(TemaProvider t) => KKart(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(color: t.mor1.withValues(alpha: .12), shape: BoxShape.circle),
              child: Icon(Icons.phone_in_talk_outlined, size: 54, color: t.mor1),
            ),
            const SizedBox(height: 16),
            Text('Çağrı bekleniyor…', style: TextStyle(color: t.ink, fontSize: 19, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Bir müşteri aradığında kartı burada açılır. Bu ekranı telefonun yanındaki cihazda açık bırakın.',
                textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13.5)),
          ]),
        ),
      );

  Widget _kart(TemaProvider t, Map<String, dynamic> c) {
    final m = harita(c['musteri']);
    final yeni = c['yeni_musteri'] == true || m.isEmpty;
    final tel = metinOku(c['telefon']);
    final sonlar = liste(m['son_siparisler']);
    return KKart(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)])),
          child: Row(children: [
            const Icon(Icons.phone_callback, color: Colors.white, size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('GELEN ÇAĞRI', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                Text(tel.isEmpty ? '—' : tel, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                if (metinOku(c['hat']).isNotEmpty) Text('Hat: ${c['hat']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ]),
            ),
            Text('${tamOku(c['saniye'])} sn önce', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (yeni)
              Row(children: [
                Text('Bilinmeyen numara', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                KRozet('YENİ MÜŞTERİ', renk: t.amber),
              ])
            else ...[
              Text(metinOku(m['ad'], 'Müşteri'), style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              KKpiIzgara([
                KKpi(etiket: 'Sipariş', deger: sayiYaz(m['siparis_sayisi']), renk: t.mavi, ikon: Icons.receipt_long_outlined),
                KKpi(etiket: 'Toplam', deger: tl(m['toplam_harcama'], kisa: true), renk: t.yesil, ikon: Icons.payments_outlined),
                KKpi(etiket: 'Puan', deger: sayiYaz(m['puan']), renk: t.gold, ikon: Icons.loyalty_outlined),
              ]),
              if (metinOku(m['adres']).isNotEmpty)
                KSatir(solIkon: KIkon(Icons.place_outlined, renk: t.kirmizi), baslik: metinOku(m['adres']), cizgi: false),
              if (metinOku(m['notlar']).isNotEmpty)
                KSatir(solIkon: KIkon(Icons.sticky_note_2_outlined, renk: t.amber), baslik: metinOku(m['notlar']), cizgi: false),
              if (sonlar.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('SON SİPARİŞLER', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6)),
                for (final s in sonlar)
                  KSatir(baslik: '#${s['id']} · ${metinOku(s['tarih'])}', sag: Text(tl(s['toplam']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
              ],
            ],
            const SizedBox(height: 16),
            Wrap(spacing: 10, runSpacing: 10, children: [
              KButon('Kapat', ikon: Icons.close, ikincil: true, renk: t.sub2, onTap: () => _kapat()),
              KButon('Sipariş Oluştur', ikon: Icons.receipt_long, renk: t.yesil, onTap: () => _kapat(siparis: true)),
              if (tel.isNotEmpty)
                KButon('Ara', ikon: Icons.call, ikincil: true, renk: t.mavi, onTap: () => launchUrl(Uri.parse('tel:${tel.replaceAll(RegExp(r'[^0-9+]'), '')}'))),
            ]),
          ]),
        ),
      ]),
    );
  }
}
