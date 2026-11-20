import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// BİLDİRİM MERKEZİ (web'deki zil — routes/bildirim_merkezi.php):
///   GET  /api/bildirim/kutu    → {okunmamis, liste:[{id, tip, baslik, govde, link, oncelik, zaman, okundu, created_at}]} (son 40)
///   POST /api/bildirim/okundu  → {id} tek bildirim; boş gövde = tümü okundu
/// Bildirime dokununca okundu işaretlenir ve ilgili web yolu uygulamadaki ekranında açılır (EkranKayit).
class BildirimMerkeziScreen extends StatefulWidget {
  const BildirimMerkeziScreen({super.key});
  @override
  State<BildirimMerkeziScreen> createState() => _BildirimMerkeziScreenState();
}

const _oncelikRenk = {2: Color(0xFFF43F5E), 1: Color(0xFFF59E0B), 0: Color(0xFF7C3AED)};

const _tipIkon = <String, IconData>{
  'kritik_stok': Icons.inventory_2_outlined, 'gec_tedarik': Icons.local_shipping_outlined,
  'kds_gecikme': Icons.timer_outlined, 'kds_bekleyen': Icons.soup_kitchen_outlined, 'stok_kritik': Icons.inventory_2_outlined, 'uretim_riski': Icons.warning_amber,
  'skt_gecti': Icons.event_busy_outlined, 'skt_yaklasan': Icons.event_outlined, 'kuver': Icons.restaurant, 'rez_grup': Icons.groups_outlined, 'urun_tukendi': Icons.block,
  'iptal_iade': Icons.undo, 'mal_geldi': Icons.move_to_inbox_outlined, 'sicaklik_limit': Icons.device_thermostat, 'sicaklik_olcum': Icons.thermostat,
  'garson_cagri': Icons.room_service_outlined, 'cagri_yanitsiz': Icons.notifications_active_outlined, 'masa_uzun': Icons.schedule, 'iskonto_ikram': Icons.redeem,
  'memnuniyet_dusuk': Icons.sentiment_dissatisfied_outlined, 'yeni_rezervasyon': Icons.event_available_outlined, 'rez_gelmedi': Icons.hourglass_bottom,
  'bekleme_uzun': Icons.hourglass_top, 'vip_geliyor': Icons.star_outline, 'yeni_paket': Icons.delivery_dining_outlined, 'paket_bekliyor': Icons.takeout_dining_outlined,
  'kurye_gecikti': Icons.two_wheeler, 'tahsil_bekliyor': Icons.payments_outlined, 'kasa_acik_kaldi': Icons.point_of_sale, 'kasa_fark': Icons.balance,
  'talep_yeni': Icons.assignment_outlined, 'ekip_talep_onay': Icons.fact_check_outlined, 'talep_sonuc': Icons.assignment_turned_in_outlined,
  'teklif_geldi': Icons.request_quote_outlined, 'siparis_gecikti': Icons.local_shipping_outlined, 'teslimat_bugun': Icons.local_shipping_outlined,
  'butce': Icons.account_balance_wallet_outlined, 'fiyat_zam': Icons.trending_up, 'ekip_gelmedi': Icons.person_off_outlined, 'ekip_gec_kaldi': Icons.alarm,
  'ekip_erken_cikti': Icons.logout, 'ekip_izin_talebi': Icons.beach_access_outlined, 'ekip_avans_talebi': Icons.payments_outlined, 'yarin_ekip_eksik': Icons.event_note_outlined,
  'ekip_belge_doluyor': Icons.badge_outlined, 'gorev_atandi': Icons.push_pin_outlined, 'gorev_gecikti': Icons.assignment_late_outlined, 'ariza_acik': Icons.build_outlined,
  'cihaz_offline': Icons.wifi_off, 'mali_fis_hata': Icons.receipt_long_outlined, 'ajanda': Icons.event_note_outlined, 'happy_hour': Icons.local_bar_outlined,
};

/// Bildirim tipi adları (sunucu _bmKatalog ile aynı)
const _tipAd = <String, String>{
  'kritik_stok': 'Malzeme kritik seviyede',
  'gec_tedarik': 'Tedarikçi siparişi gecikti',
  'skt_gecti': "SKT'si geçmiş parti",
  'skt_yaklasan': "SKT'si 7 gün içinde dolacak parti",
  'ekip_gelmedi': "Ekibimden biri vardiyasına gelmedi",
  'ekip_gec_kaldi': "Ekibimden biri işe geç kaldı",
  'ekip_erken_cikti': "Ekibimden biri mesaiyi erken bitirdi",
  'ekip_izin_talebi': "Ekibimden izin talebi geldi",
  'ekip_avans_talebi': "Ekibimden avans talebi geldi",
  'ekip_talep_onay': "Ekibimden satın alma talebi onayımı bekliyor",
  'yarin_ekip_eksik': "Yarın ekibimde izinli / vardiyası olmayan kişi var",
  'ekip_belge_doluyor': "Ekibimden birinin sağlık/hijyen belgesi doluyor",
  'gorev_gecikti': "Departman görevinin süresi geçti",
  'gorev_atandi': "Bana görev atandı",
  'talep_sonuc': "Talebim onaylandı / reddedildi / teslim alındı",
  'kds_gecikme': "KDS: sipariş 15 dakikayı geçti",
  'kds_bekleyen': "Hazırlanmayı bekleyen ürün birikti",
  'stok_kritik': "Malzeme kritik seviyede",
  'uretim_riski': "Üretim riski (malzeme bitti / bitiyor)",
  'kuver': "Bugün beklenen kuver / rezervasyon yoğunluğu",
  'rez_grup': "Kalabalık grup / ön siparişli rezervasyon geldi",
  'urun_tukendi': "Menüde ürün tükendi (86)",
  'iptal_iade': "İptal / iade yapıldı",
  'mal_geldi': "Siparişin geldi (mal kabul tamamlandı)",
  'kontrol_defteri': "Sabah kontrol defteri doldurulmadı",
  'sicaklik_limit': "Sıcaklık LİMİT DIŞI (acil)",
  'sicaklik_olcum': "Sıcaklık ölçümü yapılmadı",
  'hijyen_kontrol': "Hijyen / temizlik kontrolü bekliyor",
  'dof_acik': "Açık uygunsuzluk (DÖF)",
  'numune': "Bugün şahit numune alınmadı",
  'alerjen_eksik': "Alerjeni tanımlanmamış ürün",
  'denetim_yaklasan': "Denetim / ilaçlama / kalibrasyon yaklaşıyor",
  'gorev_acik': "Açık görev var",
  'garson_cagri': "Garson / masa çağrısı",
  'cagri_yanitsiz': "Masa çağrısı 3 dakikadır yanıtsız",
  'masa_uzun': "Masa 2,5 saatten uzun süredir açık",
  'iskonto_ikram': "Büyük iskonto / ikram yapıldı",
  'memnuniyet_dusuk': "Düşük memnuniyet puanı geldi",
  'yeni_rezervasyon': "Yeni rezervasyon",
  'rez_gelmedi': "Rezervasyon 15 dakikayı geçti, misafir gelmedi",
  'bekleme_uzun': "Bekleme listesinde 20 dakikayı geçen misafir",
  'vip_geliyor': "VIP misafir bugün geliyor",
  'rez_onay': "Rezervasyon onay bekliyor",
  'santral_rez': "Santraldan rezervasyon geldi / kaçan çağrı",
  'rez_yarin': "Yarınki rezervasyonlara hatırlatma",
  'noshow': "No-show oranı yükseldi",
  'etkinlik': "Grup / etkinlik takibi",
  'happy_hour': "Happy Hour başlıyor / bitiyor",
  'acik_adisyon': "Dünden açık kalan adisyon",
  'yeni_paket': "Yeni paket / QR / WhatsApp siparişi",
  'paket_bekliyor': "Paket hazır, 10 dakikadır kurye almadı",
  'kurye_gecikti': "Kurye 45 dakikayı geçti",
  'tahsil_bekliyor': "Teslim edildi ama tahsil edilmedi",
  'kasa_acik_kaldi': "Kasa dünden açık (Z / gün sonu alınmadı)",
  'kasa_fark': "Kasa sayımında fark çıktı",
  'talep_yeni': "Yeni satın alma talebi düştü",
  'talep_onayda': "Talep patron onayında",
  'teklif_geldi': "Tedarikçiden teklif geldi",
  'siparis_onay': "Sipariş patrondan onaylandı / reddedildi",
  'siparis_gecikti': "Tedarikçi siparişi gecikti",
  'teslimat_bugun': "Bugün beklenen teslimatlar",
  'tedarikci_yanit': "Tedarikçi siparişi onayladı / değişiklik istedi",
  'fiyat_anlasma': "Fiyat anlaşmasının süresi doluyor",
  'fiyat_zam': "Malzemede ani fiyat artışı",
  'sayim_fark': "Sayımda yüksek fark çıktı",
  'transfer_istek': "Başka şubeden transfer isteği / önerisi geldi",
  'transfer_durum': "Transferim onaylandı / yolda / teslim alındı",
  'transfer_oneri': "Kardeş şubede fazla / SKT riski olan ürün var",
  'ozluk_eksik': "Özlük / maaş bilgisi eksik personel",
  'izin_bekliyor': "Bekleyen izin / avans talepleri",
  'beyanname': "Beyanname / vergi tarihi yaklaşıyor",
  'tekrarlayan_gider': "Tekrarlayan gider bu ay işlenecek",
  'muhasebe_aktarim': "Mahsup fişi muhasebeye aktarılmadı",
  'cek_senet': "Çek / senet vadesi geliyor",
  'uyuyan_musteri': "Uyuyan müşteri arttı",
  'icerik_takvimi': "Haftalık içerik takvimi hazırlanmadı",
  'sikayet_acik': "Açık şikayet çözüm bekliyor",
  'musteri_kayip': "Müşteri kaybolmak üzere",
  'dogum_gunu': "Bu hafta doğum günü olan müşteriler",
  'cihaz_offline': "Cihaz / yazıcı çevrimdışı",
  'wa_hat_koptu': "WhatsApp hattı koptu / çıkış yaptı (hat sahibi + yönetim)",
  'mali_fis_hata': "Mali fiş / ÖKC hatası",
  'surum_eski': "Eski sürüm cihaz",
  'ariza_acik': "Açık arıza / destek kaydı",
  'it_guvenlik': "Yedek / KVKK / lisans / pasif hesap uyarısı",
};

class _BildirimMerkeziScreenState extends State<BildirimMerkeziScreen> {
  List<Map<String, dynamic>> _liste = [];
  int _okunmamis = 0;
  bool _yukleniyor = true;
  String? _hata;
  String _filtre = 'hepsi'; // hepsi | yeni | onemli
  String _tip = '';
  Timer? _zaman;

  @override
  void initState() {
    super.initState();
    _yukle();
    _zaman = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _yukle(sessiz: true);
    });
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> _yukle({bool sessiz = false}) async {
    if (!sessiz) setState(() => _yukleniyor = _liste.isEmpty);
    final c = await aiAl(context, '/api/bildirim/kutu');
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      if (c.ok) {
        _liste = liste(c.j['liste']);
        _okunmamis = tamOku(c.j['okunmamis']);
        _hata = null;
      } else if (!sessiz || _liste.isEmpty) {
        _hata = metinOku(c.j['hata'], 'Bildirimler alınamadı.');
      }
    });
  }

  Future<void> _okundu([int? id]) async {
    await aiPost(context, '/api/bildirim/okundu', id == null ? {} : {'id': id});
  }

  Future<void> _tumuOkundu() async {
    if (_okunmamis == 0) return;
    setState(() {
      for (final b in _liste) {
        b['okundu'] = true;
      }
      _okunmamis = 0;
    });
    await _okundu();
    if (mounted) kToast(context, 'Tümü okundu olarak işaretlendi.');
  }

  Future<void> _tikla(Map<String, dynamic> b) async {
    if (b['okundu'] != true) {
      setState(() {
        b['okundu'] = true;
        _okunmamis = (_okunmamis - 1).clamp(0, 99999);
      });
      _okundu(tamOku(b['id']));
    }
    final link = metinOku(b['link']);
    if (link.isEmpty || link == '#') return;
    await aiGit(context, link, baslik: _temizBaslik(metinOku(b['baslik'])));
    if (mounted) _yukle(sessiz: true);
  }

  Future<void> _tekOkundu(Map<String, dynamic> b) async {
    if (b['okundu'] == true) return;
    setState(() {
      b['okundu'] = true;
      _okunmamis = (_okunmamis - 1).clamp(0, 99999);
    });
    await _okundu(tamOku(b['id']));
  }

  /// Başlıktaki baştaki emojiyi at (web gibi)
  String _temizBaslik(String s) => s.replaceFirst(RegExp(r'^[^\p{L}\p{N}]+', unicode: true), '');

  String _tipEtiket(String tip) => _tipAd[tip] ?? (tip.isEmpty ? 'Genel' : tip.replaceAll('_', ' '));

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final tipler = <String>{for (final b in _liste) metinOku(b['tip'])}..remove('');
    final gorunen = _liste.where((b) {
      if (_filtre == 'yeni' && b['okundu'] == true) return false;
      if (_filtre == 'onemli' && tamOku(b['oncelik']) < 1) return false;
      if (_tip.isNotEmpty && metinOku(b['tip']) != _tip) return false;
      return true;
    }).toList();

    Widget govde;
    if (_yukleniyor && _liste.isEmpty) {
      govde = const KYukleniyor();
    } else if (_hata != null && _liste.isEmpty) {
      govde = KHata(_hata!, tekrar: _yukle);
    } else {
      govde = KGovde(yenile: _yukle, maxGenislik: 860, children: [
        KKpiIzgara([
          KKpi(etiket: 'Okunmamış', deger: '$_okunmamis', ikon: Icons.mark_email_unread_outlined, renk: _okunmamis > 0 ? t.kirmizi : t.yesil, onTap: () => setState(() => _filtre = 'yeni')),
          KKpi(etiket: 'Önemli / acil', deger: '${_liste.where((b) => tamOku(b['oncelik']) >= 1).length}', ikon: Icons.priority_high, renk: t.amber, onTap: () => setState(() => _filtre = 'onemli')),
          KKpi(etiket: 'Son 40 bildirim', deger: '${_liste.length}', ikon: Icons.notifications_outlined, renk: t.mor1, onTap: () => setState(() {
                _filtre = 'hepsi';
                _tip = '';
              })),
        ]),
        KCipler(
          secenekler: [('hepsi', 'Tümü'), ('yeni', 'Okunmamış ($_okunmamis)'), ('onemli', 'Önemli')],
          secili: _filtre,
          onSec: (k) => setState(() => _filtre = k),
        ),
        if (tipler.length > 1)
          KSecim<String>('Bildirim türü',
              deger: _tip,
              secenekler: [('', 'Tüm türler'), for (final x in (tipler.toList()..sort((a, b) => _tipEtiket(a).compareTo(_tipEtiket(b))))) (x, _tipEtiket(x))],
              onSec: (v) => setState(() => _tip = v ?? '')),
        if (gorunen.isEmpty)
          KBos(
            ikon: Icons.task_alt,
            baslik: _liste.isEmpty ? 'Henüz bildirim yok' : (_filtre == 'yeni' ? 'Okunmamış bildirim yok' : 'Bu filtrede bildirim yok'),
            aciklama: _liste.isEmpty
                ? 'Departmanın ve görevlerinle ilgili olaylar (kritik stok, geciken sipariş, onay bekleyen talep, görev ataması…) oldukça burada görünür. Hangi bildirimleri alacağını Bildirim Tercihleri ekranından seçebilirsin.'
                : 'Filtreyi değiştirerek diğer bildirimleri görebilirsin.',
            aksiyon: _liste.isEmpty ? KButon('Bildirim Tercihleri', ikon: Icons.tune, ikincil: true, onTap: () => aiGit(context, '/bildirim-ayar', baslik: 'Bildirim Tercihleri')) : null,
          )
        else
          KKart(
            padding: EdgeInsets.zero,
            child: Column(children: [for (var i = 0; i < gorunen.length; i++) _oge(t, gorunen[i], i < gorunen.length - 1)]),
          ),
      ]);
    }

    return KSayfa(
      baslik: 'Bildirimler',
      ikon: Icons.notifications_outlined,
      araclar: [
        if (_okunmamis > 0) TextButton.icon(onPressed: _tumuOkundu, icon: const Icon(Icons.done_all, size: 18), label: const Text('Tümü okundu')),
        IconButton(tooltip: 'Bildirim tercihleri', onPressed: () => aiGit(context, '/bildirim-ayar', baslik: 'Bildirim Tercihleri'), icon: const Icon(Icons.tune)),
        IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh)),
      ],
      govde: govde,
    );
  }

  Widget _oge(TemaProvider t, Map<String, dynamic> b, bool cizgi) {
    final yeni = b['okundu'] != true;
    final r = _oncelikRenk[tamOku(b['oncelik'])] ?? _oncelikRenk[0]!;
    final tip = metinOku(b['tip']);
    final link = metinOku(b['link']);
    return Material(
      color: yeni ? Color.alphaBlend(r.withValues(alpha: t.koyu ? .10 : .05), t.card) : Colors.transparent,
      child: InkWell(
        onTap: () => _tikla(b),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(12, 11, 6, 11),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: yeni ? r : Colors.transparent, width: 3),
              bottom: cizgi ? BorderSide(color: t.line.withValues(alpha: .7)) : BorderSide.none,
            ),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KIkon(_tipIkon[tip] ?? Icons.notifications_outlined, renk: r, boyut: 38),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_temizBaslik(metinOku(b['baslik'])), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: yeni ? FontWeight.w700 : FontWeight.w500)),
                if (metinOku(b['govde']).isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 3), child: Text(metinOku(b['govde']), style: TextStyle(color: t.sub2, fontSize: 13, height: 1.35))),
                const SizedBox(height: 5),
                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(metinOku(b['zaman'], tarihYaz(b['created_at'])), style: TextStyle(color: t.sub, fontSize: 12)),
                  if (tip.isNotEmpty) Text('· ${_tipEtiket(tip)}', style: TextStyle(color: t.sub, fontSize: 12)),
                  if (tamOku(b['oncelik']) >= 2) KRozet('ACİL', renk: r),
                ]),
              ]),
            ),
            if (yeni)
              IconButton(tooltip: 'Okundu işaretle', onPressed: () => _tekOkundu(b), icon: Icon(Icons.mark_email_read_outlined, color: t.sub, size: 20))
            else if (link.isNotEmpty && link != '#')
              Padding(padding: const EdgeInsets.all(12), child: Icon(Icons.chevron_right, color: t.sub)),
          ]),
        ),
      ),
    );
  }
}

/// Zil: ikon + okunmamış rozeti; 60 sn'de bir /api/bildirim/kutu yoklar; dokununca Bildirim Merkezi açılır.
/// Kullanım (AppBar / üst şerit araçlarına): `const BildirimZili()` — renk vermek için `BildirimZili(renk: Colors.white)`.
class BildirimZili extends StatefulWidget {
  final Color? renk;
  final double boyut;
  const BildirimZili({super.key, this.renk, this.boyut = 24});
  @override
  State<BildirimZili> createState() => _BildirimZiliState();
}

class _BildirimZiliState extends State<BildirimZili> with SingleTickerProviderStateMixin {
  int _say = 0;
  int? _onceki;
  Timer? _zaman;
  late final AnimationController _salla = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _yokla());
    _zaman = Timer.periodic(const Duration(seconds: 60), (_) => _yokla());
  }

  @override
  void dispose() {
    _zaman?.cancel();
    _salla.dispose();
    super.dispose();
  }

  Future<void> _yokla() async {
    if (!mounted) return;
    final c = await aiAl(context, '/api/bildirim/kutu');
    if (!mounted || !c.ok) return;
    final n = tamOku(c.j['okunmamis']);
    if (_onceki != null && n > _onceki!) _salla.forward(from: 0);
    _onceki = n;
    if (n != _say) setState(() => _say = n);
  }

  Future<void> _ac() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BildirimMerkeziScreen()));
    _yokla();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return IconButton(
      tooltip: _say > 0 ? '$_say okunmamış bildirim' : 'Bildirimler',
      onPressed: _ac,
      icon: AnimatedBuilder(
        animation: _salla,
        builder: (c, ch) {
          final v = _salla.value;
          final aci = v == 0 ? 0.0 : (1 - v) * .35 * ((v * 10).floor().isEven ? 1 : -1);
          return Transform.rotate(angle: aci, child: ch);
        },
        child: Badge(
          isLabelVisible: _say > 0,
          backgroundColor: t.kirmizi,
          label: Text(_say > 99 ? '99+' : '$_say', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          child: Icon(_say > 0 ? Icons.notifications_active_outlined : Icons.notifications_outlined, color: widget.renk, size: widget.boyut),
        ),
      ),
    );
  }
}
