import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'masa_plan_editor_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_config.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'garson_yonetimi_screen.dart';

/// /isletme-duzeni — İşletme Düzeni (web ile aynı veri ve uçlar). Sekmeler:
///  Masa Planı: özet, bölge doluluk kartları, bölgeye göre masalar (ekle / düzenle / taşı / arşive al / QR göster-yazdır),
///             garson atamaları, son hareketler
///  Garson Yönetimi: GarsonYonetimiGovde (canlı)
///  Kasa Yönetimi: kasa ekle / ad değiştir / kapat, kasiyer sayfaları, personel ve masa ataması
///  Bölge Ayarları: ekle / yeniden adlandır / sil
///  Yetki & Roller: rol dağılımı + Departman & Yetki / Personel ekranlarına geçiş
///  Genel Ayarlar: ilgili ayar ekranları
class IkIsletmeDuzeniScreen extends StatefulWidget {
  final String? ilkSekme;
  const IkIsletmeDuzeniScreen({super.key, this.ilkSekme});
  @override
  State<IkIsletmeDuzeniScreen> createState() => _IkIsletmeDuzeniScreenState();
}

const _rolAd = {'sahip': 'Sahip', 'mudur': 'Müdür', 'satinalmaci': 'Satın Almacı', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak'};

/// Kasiyer sayfa seçenekleri (sunucu _kasaSayfaSecenekleri ile aynı sıra; /pos hep açık)
const _kasaSayfalar = [
  ('/pos', 'Masalar'), ('/departman-brief', 'Sabah Brifingim'), ('/dashboard', 'Özet'), ('/mutfak', 'Mutfak'),
  ('/rezervasyon', 'Rezervasyon'), ('/paket', 'Paket'), ('/kasa', 'Kasa (Vardiya)'), ('/z-raporu', 'Z Raporu'),
];

Color _durumRenk(String d) => const {
      'bos': Color(0xFF10B981),
      'dolu': Color(0xFFF43F5E),
      'birlesik': Color(0xFF7C3AED),
      'rezerve': Color(0xFFF59E0B),
      'hesap': Color(0xFF4F46E5),
    }[d] ??
    const Color(0xFF64748B);

String _durumAd(String d) => const {'bos': 'Boş', 'dolu': 'Dolu', 'birlesik': 'Birleşik', 'rezerve': 'Rezerve', 'hesap': 'Hesap istendi'}[d] ?? d;

class _IkIsletmeDuzeniScreenState extends State<IkIsletmeDuzeniScreen> {
  late String _sekme = widget.ilkSekme ?? 'plan';
  int _alan = 0; // 0 = tüm bölgeler
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/isletme-duzeni',
      baslik: 'İşletme Düzeni',
      ikon: Icons.space_dashboard_outlined,
      fab: (c, v, yenile) {
        if (_sekme == 'plan') {
          return FloatingActionButton.extended(heroTag: 'idz_masa', onPressed: () => _masaEkle(c, v, yenile), icon: const Icon(Icons.add), label: const Text('Masa Ekle', style: TextStyle(fontWeight: FontWeight.w700)));
        }
        if (_sekme == 'garson') {
          return FloatingActionButton.extended(heroTag: 'idz_garson', onPressed: () => yeniGarsonEkle(c, yenile), icon: const Icon(Icons.person_add_alt_1), label: const Text('Yeni Garson', style: TextStyle(fontWeight: FontWeight.w700)));
        }
        return const SizedBox.shrink();
      },
      govde: (c, v, yenile) {
        final sekmeler = KCipler(
          secenekler: const [('plan', 'Masa Planı'), ('garson', 'Garson Yönetimi'), ('kasa', 'Kasa Yönetimi'), ('bolge', 'Bölge Ayarları'), ('yetki', 'Yetki & Roller'), ('genel', 'Genel Ayarlar')],
          secili: _sekme,
          onSec: (k) => setState(() => _sekme = k),
        );
        if (_sekme == 'garson') {
          return Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 0), child: sekmeler),
            Expanded(child: GarsonYonetimiGovde(duzen: v, yenile: yenile)),
          ]);
        }
        List<Widget> ic;
        switch (_sekme) {
          case 'kasa':
            ic = _kasa(c, v, yenile);
            break;
          case 'bolge':
            ic = _bolge(c, v, yenile);
            break;
          case 'yetki':
            ic = _yetki(c, v);
            break;
          case 'genel':
            ic = _genel(c);
            break;
          default:
            ic = _plan(c, v, yenile);
        }
        return KGovde(yenile: yenile, children: [sekmeler, ...ic]);
      },
    );
  }

  void _ac(BuildContext context, String yol, String ad) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(yol, ad)));

  Future<void> _planDuzenle(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final kaydedildi = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MasaPlanEditorScreen(veri: v, ilkAlan: _alan)));
    if (kaydedildi == true) yenile();
  }

  // ═════════════ MASA PLANI ═════════════
  List<Widget> _plan(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final bolgeler = liste(v['bolgeler']);
    final masalar = liste(v['masalar']);
    final garsonlar = liste(v['garsonlar']);
    final kasalar = liste(v['kasalar']);
    final hareket = liste(v['hareketler']);
    final bosSay = masalar.where((m) => metinOku(m['durum'], 'bos') == 'bos').length;
    final garsonSay = garsonlar.where((g) => metinOku(g['rol']) == 'garson').length;
    final bAd = {for (final b in bolgeler) tamOku(b['id']): metinOku(b['ad'])};
    var gorunen = _alan == 0 ? masalar : masalar.where((m) => tamOku(m['bolge_id']) == _alan).toList();
    if (_ara.isNotEmpty) gorunen = gorunen.where((m) => metinOku(m['ad']).toLowerCase().contains(_ara.toLowerCase())).toList();

    return [
      KKpiIzgara([
        KKpi(etiket: 'Toplam Masa', deger: '${masalar.length}', alt: tamOku(v['yeniMasa']) > 0 ? 'Son 7 günde +${tamOku(v['yeniMasa'])}' : null, ikon: Icons.chair_outlined, renk: t.mor1),
        KKpi(etiket: 'Boş Masa', deger: '$bosSay', alt: masalar.isEmpty ? null : '%${(bosSay * 100 / masalar.length).round()} boş', ikon: Icons.event_seat_outlined, renk: t.yesil),
        KKpi(etiket: 'Aktif Garson', deger: '$garsonSay', ikon: Icons.groups_outlined, renk: t.amber, onTap: () => setState(() => _sekme = 'garson')),
        KKpi(etiket: 'Kasa Sayısı', deger: '${kasalar.length}', ikon: Icons.point_of_sale, renk: t.mavi, onTap: () => setState(() => _sekme = 'kasa')),
        if (tamOku(v['cagriSay']) > 0)
          KKpi(etiket: 'Bekleyen Çağrı', deger: '${tamOku(v['cagriSay'])}', ikon: Icons.notifications_active_outlined, renk: t.kirmizi, onTap: () => _ac(context, '/garson-cagrilari', 'Garson Çağrıları')),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        KButon('Masa Ekle', ikon: Icons.table_restaurant_outlined, onTap: () => _masaEkle(context, v, yenile)),
        if (masalar.isNotEmpty) KButon('Planı Düzenle', ikon: Icons.open_with, renk: t.mavi, onTap: () => _planDuzenle(context, v, yenile)),
        KButon('Alan Ekle', ikon: Icons.add_home_work_outlined, ikincil: true, onTap: () => _bolgeEkle(context, yenile)),
        KButon('Masa Taşı', ikon: Icons.swap_horiz, ikincil: true, onTap: () => _masaTasi(context, v, null, yenile)),
        KButon('QR Kodlar', ikon: Icons.qr_code_2, ikincil: true, onTap: () => _ac(context, '/masa-yonetim', 'Masa & QR Yönetimi')),
        KButon('Salon Şeması', ikon: Icons.grid_on, ikincil: true, onTap: () => _ac(context, '/salon-sema', 'Salon Şeması')),
      ]),
      const SizedBox(height: 14),
      KBaslik('Bölgeler ve Masalar', ikon: Icons.bar_chart),
      if (bolgeler.isEmpty)
        KBos(
          ikon: Icons.add_home_work_outlined,
          baslik: 'Henüz bölge yok',
          aciklama: 'Masalar bölgelere (Salon, Bahçe, Teras…) yerleşir. Önce bir bölge ekleyin, sonra masa ekleyin.',
          aksiyon: KButon('Bölge Ekle', ikon: Icons.add, onTap: () => _bolgeEkle(context, yenile)),
        )
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            _alanKart(t, 0, 'Tümü', masalar),
            for (final b in bolgeler) _alanKart(t, tamOku(b['id']), metinOku(b['ad']), masalar.where((m) => tamOku(m['bolge_id']) == tamOku(b['id'])).toList()),
          ]),
        ),
      if (masalar.isNotEmpty) KAra(ipucu: 'Masa ara…', onDegis: (s) => setState(() => _ara = s.trim())),
      if (masalar.isEmpty && bolgeler.isNotEmpty)
        KBos(
          ikon: Icons.table_restaurant_outlined,
          baslik: 'Henüz masa yok',
          aciklama: 'Her masaya kalıcı QR otomatik oluşur. "Masa Ekle" ile başlayın.',
          aksiyon: KButon('Masa Ekle', ikon: Icons.add, onTap: () => _masaEkle(context, v, yenile)),
        )
      else if (gorunen.isEmpty && masalar.isNotEmpty)
        const KBos(ikon: Icons.search_off, baslik: 'Eşleşen masa yok', aciklama: 'Bu alanda masa yok ya da arama eşleşmedi.')
      else
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final m in gorunen) _masaKutu(context, t, v, m, bAd, yenile),
        ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (c, k) {
        final iki = k.maxWidth >= 760;
        final ga = _garsonKart(context, t, v, garsonlar, yenile);
        final hk = _hareketKart(context, t, hareket);
        if (!iki) return Column(children: [ga, hk]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: ga), const SizedBox(width: 12), Expanded(child: hk)]);
      }),
      KKart(
        child: Row(children: [
          Icon(Icons.info_outline, color: t.mavi, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Masaların salondaki yerini, şeklini ve boyunu "Planı Düzenle" ile sürükleyerek değiştirin; kaydedince Salon Şeması ve POS masa haritası da güncellenir.',
                style: TextStyle(color: t.sub2, fontSize: 12.5)),
          ),
        ]),
      ),
    ];
  }

  Widget _alanKart(TemaProvider t, int id, String ad, List<Map<String, dynamic>> ms) {
    final dolu = ms.where((m) => ['dolu', 'birlesik'].contains(metinOku(m['durum']))).length;
    final oran = ms.isEmpty ? 0 : (dolu * 100 / ms.length).round();
    final sec = _alan == id;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _alan = id),
        child: Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sec ? t.mor1.withValues(alpha: .12) : t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sec ? t.mor1 : t.line, width: sec ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${ms.length} masa · %$oran dolu', style: TextStyle(color: t.sub, fontSize: 12)),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: oran / 100, minHeight: 5, color: t.mor1, backgroundColor: t.line, borderRadius: BorderRadius.circular(4)),
          ]),
        ),
      ),
    );
  }

  Widget _masaKutu(BuildContext context, TemaProvider t, Map<String, dynamic> v, Map<String, dynamic> m, Map<int, String> bAd, Future<void> Function() yenile) {
    final d = metinOku(m['durum'], 'bos');
    final r = _durumRenk(d);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _masaIslem(context, v, m, bAd, yenile),
      child: Container(
        width: 118,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: r.withValues(alpha: .10), borderRadius: BorderRadius.circular(14), border: Border.all(color: r.withValues(alpha: .45))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(metinOku(m['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold))),
            Icon(Icons.more_vert, size: 16, color: t.sub),
          ]),
          const SizedBox(height: 2),
          Text('${tamOku(m['kapasite'])} kişilik', style: TextStyle(color: t.sub, fontSize: 12)),
          if (_alan == 0) Text(bAd[tamOku(m['bolge_id'])] ?? 'Bölgesiz', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12)),
          const SizedBox(height: 4),
          Text(sayiOku(m['tutar']) > 0 ? '${_durumAd(d)} · ${tl(m['tutar'], kisa: true)}' : _durumAd(d), style: TextStyle(color: r, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _masaIslem(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> m, Map<int, String> bAd, Future<void> Function() yenile) async {
    final secim = await kAltSayfa<String>(context,
        baslik: '${metinOku(m['ad'])} · ${bAd[tamOku(m['bolge_id'])] ?? 'Bölgesiz'}',
        icerik: (sc) {
          final t = sc.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${tamOku(m['kapasite'])} kişilik · ${_durumAd(metinOku(m['durum'], 'bos'))}${sayiOku(m['tutar']) > 0 ? ' · ${tl(m['tutar'])}' : ''}', style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 8),
            KSatir(baslik: 'Düzenle', alt: 'Ad, kapasite, bölge', solIkon: KIkon(Icons.edit_outlined, renk: t.mavi), onTap: () => Navigator.pop(sc, 'duzenle')),
            KSatir(baslik: 'Başka bölgeye taşı', solIkon: KIkon(Icons.swap_horiz, renk: const Color(0xFFDB2777)), onTap: () => Navigator.pop(sc, 'tasi')),
            if (metinOku(m['qr_token']).isNotEmpty) KSatir(baslik: 'QR kodu göster / yazdır', alt: 'Kalıcı masa QR\'ı', solIkon: KIkon(Icons.qr_code_2, renk: t.mor1), onTap: () => Navigator.pop(sc, 'qr')),
            KSatir(baslik: 'Garson ataması', alt: 'Bu masaya bakan garsonları düzenle', solIkon: KIkon(Icons.groups_outlined, renk: t.yesil), onTap: () => Navigator.pop(sc, 'garson')),
            KSatir(baslik: 'Arşive taşı (sil)', alt: 'QR korunur; Masa & QR Yönetimi\'nden geri alınır', solIkon: KIkon(Icons.archive_outlined, renk: t.kirmizi), onTap: () => Navigator.pop(sc, 'sil'), cizgi: false),
          ]);
        });
    if (secim == null || !context.mounted) return;
    switch (secim) {
      case 'duzenle':
        await _masaDuzenle(context, v, m, yenile);
        break;
      case 'tasi':
        await _masaTasi(context, v, m, yenile);
        break;
      case 'qr':
        await _qrGoster(context, v, m);
        break;
      case 'garson':
        final gs = liste(v['garsonlar']);
        if (gs.isEmpty) {
          kToast(context, 'Aktif garson yok. Önce garson ekleyin.', hata: true);
          return;
        }
        final gid = await kAltSayfa<int>(context,
            baslik: 'Hangi garson?',
            icerik: (sc) => Column(children: [
                  for (final g in gs)
                    KSatir(baslik: metinOku(g['ad']), alt: garsonAtamaOzet(v, tamOku(g['id'])), onTap: () => Navigator.pop(sc, tamOku(g['id']))),
                ]));
        if (gid != null && context.mounted) await garsonAtaAc(context, v, gid, yenile);
        break;
      case 'sil':
        if (!await kOnay(context, '${metinOku(m['ad'])} arşive taşınsın mı?', aciklama: 'Masanın QR kodu korunur; geri getirildiğinde aynı QR geçerli olur. Açık hesabı olan masa arşivlenemez.', evet: 'Arşive taşı', tehlikeli: true)) return;
        if (!context.mounted) return;
        if (await kopruGonder(context, '/masa-yonetim/sil', {'id': tamOku(m['id'])})) await yenile();
        break;
    }
  }

  Future<void> _masaEkle(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final bolgeler = liste(v['bolgeler']);
    if (bolgeler.isEmpty) {
      kToast(context, 'Önce en az bir bölge ekleyin.', hata: true);
      return _bolgeEkle(context, yenile);
    }
    final ad = TextEditingController();
    int kap = 4;
    int bolge = _alan != 0 ? _alan : tamOku(bolgeler.first['id']);
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Masa Ekle',
        icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
              final t = sc.watch<TemaProvider>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KAlan('Masa adı', ad, ipucu: 'Örn. "Masa 1", "B4" (boşsa otomatik)'),
                _kapasiteSecici(t, kap, (x) => ss(() => kap = x)),
                KSecim<int>('Bölge', deger: bolge, secenekler: [for (final b in bolgeler) (tamOku(b['id']), metinOku(b['ad']))], onSec: (x) => ss(() => bolge = x ?? bolge)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Her masaya kalıcı QR otomatik oluşur. Silinen masa arşive gider, QR korunur.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                ),
                KButon('Masa Ekle', ikon: Icons.add, genis: true, onTap: () => Navigator.pop(sc, true)),
              ]);
            }));
    if (tamam != true || !context.mounted) return;
    if (await kopruGonder(context, '/masa-yonetim/ekle', {'ad': ad.text.trim(), 'kapasite': '$kap', 'bolge_id': '$bolge'})) await yenile();
  }

  Widget _kapasiteSecici(TemaProvider t, int kap, ValueChanged<int> degis) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: Text('Kapasite', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700))),
          IconButton.filledTonal(onPressed: kap > 1 ? () => degis(kap - 1) : null, icon: const Icon(Icons.remove)),
          SizedBox(width: 48, child: Text('$kap', textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton.filledTonal(onPressed: kap < 50 ? () => degis(kap + 1) : null, icon: const Icon(Icons.add)),
        ]),
      );

  Future<void> _masaDuzenle(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> m, Future<void> Function() yenile) async {
    final bolgeler = liste(v['bolgeler']);
    final ad = TextEditingController(text: metinOku(m['ad']));
    int kap = tamOku(m['kapasite']).clamp(1, 50);
    int bolge = tamOku(m['bolge_id']);
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Masa Düzenle',
        icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
              final t = sc.watch<TemaProvider>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KAlan('Masa adı', ad, zorunlu: true),
                _kapasiteSecici(t, kap, (x) => ss(() => kap = x)),
                KSecim<int>('Bölge', deger: bolge, secenekler: [for (final b in bolgeler) (tamOku(b['id']), metinOku(b['ad']))], onSec: (x) => ss(() => bolge = x ?? bolge)),
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('QR kodu değişmez.', style: TextStyle(color: t.sub, fontSize: 12.5))),
                KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
                  if (ad.text.trim().isEmpty) return kToast(sc, 'Masa adı boş olamaz.', hata: true);
                  Navigator.pop(sc, true);
                }),
              ]);
            }));
    if (tamam != true || !context.mounted) return;
    final ok = await kopruGonder(context, '/api/patron/masa-guncelle', {'id': tamOku(m['id']), 'ad': ad.text.trim(), 'kapasite': kap, 'bolge_id': bolge > 0 ? '$bolge' : ''},
        json: true, basariMesaji: 'Masa güncellendi.');
    if (ok) await yenile();
  }

  Future<void> _masaTasi(BuildContext context, Map<String, dynamic> v, Map<String, dynamic>? m, Future<void> Function() yenile) async {
    final bolgeler = liste(v['bolgeler']);
    final masalar = liste(v['masalar']);
    if (masalar.isEmpty || bolgeler.isEmpty) {
      kToast(context, 'Taşımak için en az bir masa ve bölge olmalı.', hata: true);
      return;
    }
    final bAd = {for (final b in bolgeler) tamOku(b['id']): metinOku(b['ad'])};
    int masa = m == null ? tamOku(masalar.first['id']) : tamOku(m['id']);
    int bolge = tamOku(bolgeler.first['id']);
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Masa Taşı',
        icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
              final t = sc.watch<TemaProvider>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KSecim<int>('Masa', deger: masa, secenekler: [for (final x in masalar) (tamOku(x['id']), '${bAd[tamOku(x['bolge_id'])] ?? 'Bölgesiz'} · ${metinOku(x['ad'])}')], onSec: (x) => ss(() => masa = x ?? masa)),
                KSecim<int>('Taşınacak bölge', deger: bolge, secenekler: [for (final b in bolgeler) (tamOku(b['id']), metinOku(b['ad']))], onSec: (x) => ss(() => bolge = x ?? bolge)),
                Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Aynı bölgede konum değiştirmek için "Planı Düzenle"yi kullanın.', style: TextStyle(color: t.sub, fontSize: 12.5))),
                KButon('Taşı', ikon: Icons.swap_horiz, genis: true, onTap: () => Navigator.pop(sc, true)),
              ]);
            }));
    if (tamam != true || !context.mounted) return;
    if (await kopruGonder(context, '/isletme-duzeni/masa-bolge', {'id': '$masa', 'bolge_id': '$bolge'})) await yenile();
  }

  Future<void> _qrGoster(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> m) async {
    final url = '${AppConfig.baseUrl}/m/${metinOku(m['qr_token'])}';
    final sube = metinOku(v['subeAd'], 'Restoran');
    await kAltSayfa(context,
        baslik: '${metinOku(m['ad'])} — QR',
        icerik: (sc) {
          final t = sc.watch<TemaProvider>();
          return Column(children: [
            Text(sube, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(color: Colors.white, padding: const EdgeInsets.all(10), child: QrImageView(data: url, size: 220, backgroundColor: Colors.white)),
            const SizedBox(height: 8),
            SelectableText(url, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12)),
            const SizedBox(height: 12),
            KButon('Afiş Yazdır (A6)', ikon: Icons.print_outlined, genis: true, onTap: () => _qrYazdir(sc, sube, metinOku(m['ad']), url)),
          ]);
        });
  }

  Future<void> _qrYazdir(BuildContext context, String sube, String ad, String url) async {
    try {
      final base = await PdfGoogleFonts.nunitoRegular();
      final bold = await PdfGoogleFonts.nunitoExtraBold();
      final doc = pw.Document(theme: pw.ThemeData.withFont(base: base, bold: bold));
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a6,
        margin: const pw.EdgeInsets.all(16),
        build: (c) => pw.Center(
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Text(sube, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Karekodu telefonunuzla okutun', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: url, width: 150, height: 150),
            pw.SizedBox(height: 12),
            pw.Text(ad, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 2),
            pw.Text('Menü · Sipariş · Garson Çağır · Öde', style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      ));
      await Printing.layoutPdf(onLayout: (f) async => doc.save(), name: 'QR-$ad');
    } catch (e) {
      if (context.mounted) kToast(context, 'Yazdırılamadı (yazı tipi için internet gerekir).', hata: true);
    }
  }

  Widget _garsonKart(BuildContext context, TemaProvider t, Map<String, dynamic> v, List<Map<String, dynamic>> garsonlar, Future<void> Function() yenile) {
    final sirali = [...garsonlar]..sort((a, b) => (metinOku(a['rol']) == 'garson' ? 0 : 1).compareTo(metinOku(b['rol']) == 'garson' ? 0 : 1));
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Garson Atamaları', ikon: Icons.groups_outlined, sag: TextButton(onPressed: () => setState(() => _sekme = 'garson'), child: const Text('Tümü'))),
        if (sirali.isEmpty)
          const KBos(ikon: Icons.person_off_outlined, baslik: 'Aktif garson yok', aciklama: 'Garson / müdür rolündeki aktif personel burada görünür. Personel ekranından ekleyin.')
        else
          for (final g in sirali.take(6))
            KSatir(
              baslik: metinOku(g['ad']),
              alt: '${_rolAd[metinOku(g['rol'])] ?? metinOku(g['rol'])} · ${garsonAtamaOzet(v, tamOku(g['id']))}',
              solIkon: CircleAvatar(radius: 18, backgroundColor: t.mor1.withValues(alpha: .14), child: Text(metinOku(g['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700))),
              sag: Icon(Icons.tune, color: t.sub),
              onTap: () => garsonAtaAc(context, v, tamOku(g['id']), yenile),
            ),
      ]),
    );
  }

  Widget _hareketKart(BuildContext context, TemaProvider t, List<Map<String, dynamic>> hareket) => KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Son Hareketler', ikon: Icons.schedule, sag: TextButton(onPressed: () => _ac(context, '/hareketler', 'Hareketler'), child: const Text('Tümü'))),
          if (hareket.isEmpty)
            Text('Henüz hareket yok. Bu ekranda yaptığınız değişiklikler (masa, bölge, kasa, atama) burada görünür.', style: TextStyle(color: t.sub, fontSize: 13))
          else
            for (final h in hareket) KSatir(baslik: metinOku(h['aksiyon']), alt: tarihYaz(h['created_at']), solIkon: Icon(Icons.circle, size: 9, color: t.mor1)),
        ]),
      );

  Future<void> _bolgeEkle(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController();
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Yeni Alan / Bölge',
        icerik: (sc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KAlan('Alan adı', ad, ipucu: 'Örn. "Bahçe", "Teras", "İç Salon"', zorunlu: true),
              KButon('Alan Ekle', ikon: Icons.add, genis: true, onTap: () {
                if (ad.text.trim().isEmpty) return kToast(sc, 'Bölge adı girin.', hata: true);
                Navigator.pop(sc, true);
              }),
            ]));
    if (tamam != true || !context.mounted) return;
    if (await kopruGonder(context, '/isletme-duzeni/bolge-ekle', {'ad': ad.text.trim()})) await yenile();
  }

  // ═════════════ KASA YÖNETİMİ ═════════════
  List<Widget> _kasa(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final kasalar = liste(v['kasalar']);
    final personeller = liste(v['personeller']);
    final masalar = liste(v['masalar']);
    final bAd = {for (final b in liste(v['bolgeler'])) tamOku(b['id']): metinOku(b['ad'])};
    return [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Kasa Noktaları', ikon: Icons.point_of_sale, alt: '${kasalar.length} kasa'),
          Text('Birden fazla kasanız varsa ekleyin; her kasaya personel ve/veya masa atayın. Kasa eklemezseniz tek-havuz (tek çekmece) çalışır.', style: TextStyle(color: t.sub, fontSize: 13)),
          const SizedBox(height: 10),
          KButon('Kasa Ekle', ikon: Icons.add, onTap: () async {
            final ad = TextEditingController();
            final ok = await kAltSayfa<bool>(context,
                baslik: 'Yeni Kasa',
                icerik: (sc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      KAlan('Kasa adı', ad, ipucu: 'Örn. "Kasa 1", "Bar Kasa"', zorunlu: true),
                      KButon('Ekle', ikon: Icons.add, genis: true, onTap: () {
                        if (ad.text.trim().isEmpty) return kToast(sc, 'Kasa adı girin.', hata: true);
                        Navigator.pop(sc, true);
                      }),
                    ]));
            if (ok != true || !context.mounted) return;
            if (await kopruGonder(context, '/kasalar/ekle', {'ad': ad.text.trim()})) await yenile();
          }),
        ]),
      ),
      if (kasalar.isEmpty)
        const KBos(ikon: Icons.point_of_sale, baslik: 'Kasa noktası yok', aciklama: 'Tek-havuz (tek çekmece) modunda çalışıyorsunuz. Birden fazla fiziksel kasanız varsa yukarıdan ekleyin.')
      else
        for (final k in kasalar) _kasaKart(context, t, k, personeller, masalar, bAd, yenile),
    ];
  }

  Widget _kasaKart(BuildContext context, TemaProvider t, Map<String, dynamic> k, List<Map<String, dynamic>> personeller, List<Map<String, dynamic>> masalar, Map<int, String> bAd,
      Future<void> Function() yenile) {
    final kid = tamOku(k['id']);
    final masaIdler = {for (final x in dizi(k['masa_idler'])) tamOku(x)};
    Set<String> acik;
    final sy = k['sayfalar'];
    if (sy == null || metinOku(sy).isEmpty) {
      acik = {for (final s in _kasaSayfalar) s.$1};
    } else {
      dynamic l = sy;
      if (sy is String) {
        try {
          l = jsonDecode(sy);
        } catch (_) {
          l = const [];
        }
      }
      acik = {'/pos', for (final x in dizi(l)) metinOku(x)};
    }
    return KKart(
      renk: t.mavi,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.storefront_outlined, color: t.mavi),
          const SizedBox(width: 8),
          Expanded(child: Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
          IconButton(
            tooltip: 'Adı değiştir',
            icon: Icon(Icons.edit_outlined, color: t.sub),
            onPressed: () async {
              final ad = TextEditingController(text: metinOku(k['ad']));
              final ok = await kAltSayfa<bool>(context,
                  baslik: 'Kasa adı',
                  icerik: (sc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        KAlan('Kasa adı', ad, zorunlu: true),
                        KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(sc, true)),
                      ]));
              if (ok != true || !context.mounted || ad.text.trim().isEmpty) return;
              if (await kopruGonder(context, '/kasalar/duzenle', {'id': kid, 'ad': ad.text.trim()})) await yenile();
            },
          ),
          IconButton(
            tooltip: 'Kasayı kapat',
            icon: Icon(Icons.delete_outline, color: t.kirmizi),
            onPressed: () async {
              if (!await kOnay(context, '${metinOku(k['ad'])} kapatılsın mı?', evet: 'Kapat', tehlikeli: true, aciklama: 'Açık vardiyası olan kasa kapatılamaz.')) return;
              if (!context.mounted) return;
              if (await kopruGonder(context, '/kasalar/sil', {'id': kid})) await yenile();
            },
          ),
        ]),
        const SizedBox(height: 8),
        _altBaslik(t, 'KASİYER BU KASADA HANGİ SAYFALARI GÖRSÜN'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (u, e) in _kasaSayfalar)
            FilterChip(
              label: Text(u == '/pos' ? '$e (hep açık)' : e, style: const TextStyle(fontSize: 13)),
              selected: acik.contains(u),
              selectedColor: t.amber.withValues(alpha: .2),
              checkmarkColor: t.amber,
              onSelected: u == '/pos'
                  ? null
                  : (s) async {
                      final yeni = {...acik};
                      s ? yeni.add(u) : yeni.remove(u);
                      if (await kopruGonder(context, '/kasalar/sayfalar', {'id': kid, 'sayfa': yeni.where((x) => x != '/pos').toList()})) await yenile();
                    },
            ),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          TextButton(
            onPressed: () async {
              if (await kopruGonder(context, '/kasalar/sayfalar', {'id': kid, 'sayfa': [for (final s in _kasaSayfalar) if (s.$1 != '/pos') s.$1]})) await yenile();
            },
            child: const Text('Ana Kasa (hepsi)'),
          ),
          TextButton(
            onPressed: () async {
              if (await kopruGonder(context, '/kasalar/sayfalar', {'id': kid, 'sayfa': <String>[]})) await yenile();
            },
            child: const Text('Sadece Sipariş'),
          ),
        ]),
        const SizedBox(height: 8),
        _altBaslik(t, 'PERSONEL (bu kasaya atanınca girişte otomatik burada çalışır)'),
        if (personeller.isEmpty)
          Text('Aktif personel yok.', style: TextStyle(color: t.sub, fontSize: 13))
        else
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in personeller)
              Builder(builder: (_) {
                final bu = tamOku(p['varsayilan_kasa_id']) == kid;
                return FilterChip(
                  label: Text(metinOku(p['ad']), style: const TextStyle(fontSize: 13)),
                  selected: bu,
                  selectedColor: t.mavi.withValues(alpha: .18),
                  checkmarkColor: t.mavi,
                  onSelected: (_) async {
                    if (await kopruGonder(context, '/kasalar/atama', {'personel_id': tamOku(p['id']), 'kasa_id': bu ? '0' : '$kid'})) await yenile();
                  },
                );
              }),
          ]),
        const SizedBox(height: 12),
        _altBaslik(t, 'MASALAR (bu kasaya bağlı masalar, isteğe bağlı)'),
        Row(children: [
          Expanded(child: Text(masaIdler.isEmpty ? 'Bağlı masa yok' : '${masaIdler.length} masa bağlı', style: TextStyle(color: t.sub2, fontSize: 13.5))),
          KButon('Masaları Seç', ikon: Icons.checklist, ikincil: true, onTap: masalar.isEmpty
              ? null
              : () async {
                  final sec = {...masaIdler};
                  final ok = await kAltSayfa<bool>(context,
                      baslik: '${metinOku(k['ad'])} — bağlı masalar',
                      icerik: (sc) => StatefulBuilder(builder: (sc, ss) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final m in masalar)
                                FilterChip(
                                  label: Text('${bAd[tamOku(m['bolge_id'])] ?? ''} · ${metinOku(m['ad'])}', style: const TextStyle(fontSize: 13)),
                                  selected: sec.contains(tamOku(m['id'])),
                                  onSelected: (s) => ss(() => s ? sec.add(tamOku(m['id'])) : sec.remove(tamOku(m['id']))),
                                ),
                            ]),
                            const SizedBox(height: 12),
                            KButon('Masaları Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(sc, true)),
                          ])));
                  if (ok != true || !context.mounted) return;
                  if (await kopruGonder(context, '/isletme-duzeni/kasa-masa', {'kasa_id': kid, 'masa_idler': sec.toList()})) await yenile();
                }),
        ]),
      ]),
    );
  }

  Widget _altBaslik(TemaProvider t, String m) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 2),
        child: Text(m, style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .2)),
      );

  // ═════════════ BÖLGE AYARLARI ═════════════
  List<Widget> _bolge(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final bolgeler = liste(v['bolgeler']);
    final masalar = liste(v['masalar']);
    return [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Bölge Ayarları', ikon: Icons.person_pin_circle_outlined, alt: '${bolgeler.length} bölge'),
          Text('Salonun alanları: Bahçe, Teras, İç Salon, Üst Kat… Masalar bu bölgelere yerleşir.', style: TextStyle(color: t.sub, fontSize: 13)),
          const SizedBox(height: 10),
          KButon('Bölge Ekle', ikon: Icons.add, onTap: () => _bolgeEkle(context, yenile)),
        ]),
      ),
      if (bolgeler.isEmpty)
        const KBos(ikon: Icons.add_home_work_outlined, baslik: 'Henüz bölge yok', aciklama: 'Yukarıdan bölge ekleyin; masalar bölgelere yerleşir.')
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final b in bolgeler)
              Builder(builder: (_) {
                final n = masalar.where((m) => tamOku(m['bolge_id']) == tamOku(b['id'])).length;
                return KSatir(
                  baslik: metinOku(b['ad']),
                  alt: '$n masa',
                  solIkon: KIkon(Icons.deck_outlined, renk: t.amber),
                  sag: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Yeniden adlandır',
                      icon: Icon(Icons.edit_outlined, color: t.mavi),
                      onPressed: () async {
                        final ad = TextEditingController(text: metinOku(b['ad']));
                        final ok = await kAltSayfa<bool>(context,
                            baslik: 'Bölge adı',
                            icerik: (sc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                  KAlan('Bölge adı', ad, zorunlu: true),
                                  KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
                                    if (ad.text.trim().isEmpty) return kToast(sc, 'Bölge adı boş olamaz.', hata: true);
                                    Navigator.pop(sc, true);
                                  }),
                                ]));
                        if (ok != true || !context.mounted) return;
                        if (await kopruGonder(context, '/isletme-duzeni/bolge-duzenle', {'id': tamOku(b['id']), 'ad': ad.text.trim()})) await yenile();
                      },
                    ),
                    IconButton(
                      tooltip: 'Sil',
                      icon: Icon(Icons.delete_outline, color: t.kirmizi),
                      onPressed: () async {
                        if (n > 0) {
                          kToast(context, 'Bu bölgede $n masa var. Önce masaları başka bölgeye taşıyın.', hata: true);
                          return;
                        }
                        if (!await kOnay(context, '${metinOku(b['ad'])} bölgesi silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                        if (!context.mounted) return;
                        if (await kopruGonder(context, '/isletme-duzeni/bolge-sil', {'id': tamOku(b['id'])})) await yenile();
                      },
                    ),
                  ]),
                );
              }),
          ]),
        ),
    ];
  }

  // ═════════════ YETKİ & ROLLER ═════════════
  List<Widget> _yetki(BuildContext context, Map<String, dynamic> v) {
    final t = context.watch<TemaProvider>();
    final pers = liste(v['personeller']);
    final grup = <String, List<String>>{};
    for (final p in pers) {
      grup.putIfAbsent(metinOku(p['rol'], 'diger'), () => []).add(metinOku(p['ad']));
    }
    return [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Yetki & Roller', ikon: Icons.verified_user_outlined),
          Text('Aktif personelin rollere göre dağılımı. Sayfa yetkilerini Departman & Yetki ekranından, kişi bilgilerini ve kişiye özel yetkileri Personel ekranından düzenlersiniz.',
              style: TextStyle(color: t.sub, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Departman & Yetki', ikon: Icons.admin_panel_settings_outlined, onTap: () => _ac(context, '/departman-yonetim', 'Departman & Yetki')),
            KButon('Personel Yönetimi', ikon: Icons.badge_outlined, ikincil: true, onTap: () => _ac(context, '/personel', 'Personel & Maaş')),
          ]),
        ]),
      ),
      if (grup.isEmpty)
        const KBos(ikon: Icons.person_off_outlined, baslik: 'Aktif personel yok', aciklama: 'Personel & Maaş ekranından personel ekleyin.')
      else
        for (final e in grup.entries)
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_rolAd[e.key] ?? e.key, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                KRozet('${e.value.length}', renk: t.mor1),
              ]),
              const SizedBox(height: 4),
              Text(e.value.take(6).join(', ') + (e.value.length > 6 ? ' +${e.value.length - 6}' : ''), style: TextStyle(color: t.sub2, fontSize: 13)),
            ]),
          ),
    ];
  }

  // ═════════════ GENEL AYARLAR ═════════════
  List<Widget> _genel(BuildContext context) {
    final t = context.watch<TemaProvider>();
    const l = [
      ('/masa-yonetim', Icons.qr_code_2, 'QR Afişleri / Arşiv', 'QR indir ve yazdır, arşivlenen masaları geri al', Color(0xFF7C3AED)),
      ('/salon-sema', Icons.grid_on, 'Salon Şeması', 'Kat ve parsel krokisi, Masa Planı ile eşitlenir', Color(0xFF059669)),
      ('/isletme-konum', Icons.my_location, 'İşletme Konum', 'Harita konumu ve mesai alanı', Color(0xFFD97706)),
      ('/yazici-ayarlari', Icons.print_outlined, 'Yazıcı Ayarları', 'Mutfak ve kasa yazıcıları', Color(0xFF2563EB)),
      ('/bagli-cihazlar', Icons.devices_outlined, 'Bağlı Cihazlar', 'Tablet ve kasa cihazları', Color(0xFF0891B2)),
    ];
    return [
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          for (final (u, ik, b, a, r) in l)
            KSatir(baslik: b, alt: a, solIkon: KIkon(ik, renk: r), sag: Icon(Icons.chevron_right, color: t.sub), onTap: () => _ac(context, u, b)),
        ]),
      ),
    ];
  }
}
