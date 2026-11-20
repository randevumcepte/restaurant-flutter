import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Kayıt defteri tipi (web blade'deki $alanlar dizisinin aynısı)
class KaliteItDefterTip {
  final String ad;
  final IconData ikon;
  final Color renk;
  final String baslikIpucu;
  final String degerEtiket;
  final String sonEtiket;
  final String ipucu;
  final bool oncelik;
  final bool kapat;
  const KaliteItDefterTip(this.ad, this.ikon, this.renk, this.baslikIpucu, this.degerEtiket, this.sonEtiket, this.ipucu, {this.oncelik = false, this.kapat = false});
}

/// Defter ayarı: hangi web sayfası, hangi uçlar
class KaliteItDefterAyar {
  final String baslik;
  final IconData ikon;
  final String yol; // GET sayfa
  final String ekleYol;
  final String silYol;
  final String? kapatYol;
  final String varsayilanTip;
  final Map<String, KaliteItDefterTip> tipler;
  const KaliteItDefterAyar({
    required this.baslik,
    required this.ikon,
    required this.yol,
    required this.ekleYol,
    required this.silYol,
    this.kapatYol,
    required this.varsayilanTip,
    required this.tipler,
  });
}

/// URL'den tip oku: '/kalite-kayit?tip=numune' → 'numune'
String kaliteItUrlTip(String url, String varsayilan) {
  try {
    final t = Uri.parse(url).queryParameters['tip'];
    if (t != null && t.isNotEmpty) return t;
  } catch (_) {}
  return varsayilan;
}

/// Ortak kayıt defteri ekranı: /kalite-kayit (numune, ilaçlama, kalibrasyon, tedarikçi belgesi, denetim)
/// ve /it-kayit (arıza, lisans, yedek, KVKK, bakım). Sekme = tip; ekle / kapat (arıza) / sil.
class KaliteItDefterEkran extends StatefulWidget {
  final KaliteItDefterAyar ayar;
  final String tip;
  const KaliteItDefterEkran({super.key, required this.ayar, required this.tip});

  @override
  State<KaliteItDefterEkran> createState() => _KaliteItDefterEkranState();
}

class _KaliteItDefterEkranState extends State<KaliteItDefterEkran> {
  late String _tip;
  String _ara = '';
  String _durumFiltre = 'tumu'; // tumu | doldu | yaklasti | acik

  @override
  void initState() {
    super.initState();
    _tip = widget.ayar.tipler.containsKey(widget.tip) ? widget.tip : widget.ayar.varsayilanTip;
  }

  KaliteItDefterTip get _a => widget.ayar.tipler[_tip] ?? widget.ayar.tipler[widget.ayar.varsayilanTip]!;

  /// son_tarih durumu: 'doldu' | 'yaklasti' | 'gecerli' | null
  String? _sonDurum(dynamic v) {
    final s = metinOku(v);
    if (s.isEmpty) return null;
    final d = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (d == null) return null;
    final simdi = DateTime.now();
    if (d.isBefore(simdi)) return 'doldu';
    if (d.difference(simdi).inDays <= 15) return 'yaklasti';
    return 'gecerli';
  }

  Future<void> _ekle(Future<void> Function() yenile) async {
    final a = _a;
    final baslik = TextEditingController();
    final deger = TextEditingController();
    final not = TextEditingController();
    DateTime tarih = DateTime.now();
    DateTime? son;
    String oncelik = 'orta';
    final kaydet = await kAltSayfa<bool>(context, baslik: 'Yeni kayıt · ${a.ad}', icerik: (ctx) {
      return StatefulBuilder(builder: (ctx, setD) {
        final t = context.read<TemaProvider>();
        Widget tarihSec(String etiket, DateTime? d, ValueChanged<DateTime?> sec, {bool temizle = true}) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Material(
                  color: t.card2,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final s = await showDatePicker(context: ctx, initialDate: d ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
                      if (s != null) sec(s);
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                      child: Row(children: [
                        Icon(Icons.event, size: 18, color: t.sub),
                        const SizedBox(width: 8),
                        Expanded(child: Text(d == null ? 'Tarih seçin' : tarihYaz(_iso(d), saat: false), style: TextStyle(color: d == null ? t.sub : t.ink, fontSize: 15))),
                        if (d != null && temizle) IconButton(onPressed: () => sec(null), icon: Icon(Icons.close, size: 18, color: t.sub)),
                      ]),
                    ),
                  ),
                ),
              ]),
            );
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Kayıt / başlık', baslik, zorunlu: true, ipucu: a.baslikIpucu),
          KAlan(a.degerEtiket, deger),
          if (a.oncelik)
            KSecim<String>('Öncelik', deger: oncelik, secenekler: const [('orta', 'Orta'), ('yuksek', 'Yüksek'), ('dusuk', 'Düşük')], onSec: (v) => setD(() => oncelik = v ?? 'orta')),
          tarihSec('Tarih', tarih, (v) => setD(() => tarih = v ?? DateTime.now()), temizle: false),
          tarihSec(a.sonEtiket, son, (v) => setD(() => son = v)),
          KAlan('Not', not, satir: 2, ipucu: 'İsteğe bağlı'),
          KButon('Ekle', ikon: Icons.add, renk: a.renk, genis: true, onTap: () {
            if (baslik.text.trim().isEmpty) {
              kToast(ctx, 'Başlık gerekli.', hata: true);
              return;
            }
            Navigator.pop(ctx, true);
          }),
        ]);
      });
    });
    if (kaydet != true || !mounted) return;
    final ok = await kopruGonder(context, widget.ayar.ekleYol, {
      'tip': _tip,
      'baslik': baslik.text.trim(),
      'deger': deger.text.trim(),
      if (a.oncelik) 'oncelik': oncelik,
      'tarih': _iso(tarih),
      'son_tarih': son == null ? '' : _iso(son!),
      'not': not.text.trim(),
    }, basariMesaji: 'Kayıt eklendi.');
    if (ok) await yenile();
  }

  Future<void> _kapat(Map<String, dynamic> k, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Kayıt kapatılsın mı?', evet: 'Kapat', aciklama: '${metinOku(k['baslik'])}\nArıza çözüldü olarak işaretlenir (çözüm süresi IT raporuna yazılır).')) return;
    if (!mounted) return;
    final ok = await kopruGonder(context, widget.ayar.kapatYol!, {'id': tamOku(k['id']), 'tip': _tip}, basariMesaji: 'Kayıt kapatıldı.');
    if (ok) await yenile();
  }

  Future<void> _sil(Map<String, dynamic> k, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Silinsin mi?', evet: 'Sil', tehlikeli: true, aciklama: metinOku(k['baslik']))) return;
    if (!mounted) return;
    final ok = await kopruGonder(context, widget.ayar.silYol, {'id': tamOku(k['id']), 'tip': _tip}, basariMesaji: 'Silindi.');
    if (ok) await yenile();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: widget.ayar.yol,
      q: {'tip': _tip},
      baslik: widget.ayar.baslik,
      ikon: widget.ayar.ikon,
      fab: (ctx, veri, yenile) => FloatingActionButton.extended(
        heroTag: 'kalite_it_defter_ekle',
        backgroundColor: _a.renk,
        onPressed: () => _ekle(yenile),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      govde: _govde,
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final a = _a;
    final tiplerWeb = harita(veri['tipler']);
    final sekmeler = <(String, String)>[
      for (final e in (tiplerWeb.isNotEmpty ? tiplerWeb.entries : widget.ayar.tipler.entries.map((e) => MapEntry(e.key, e.value.ad))))
        (e.key, metinOku(e.value, widget.ayar.tipler[e.key]?.ad ?? e.key)),
    ];
    final tum = liste(veri['liste']);
    bool kapaliMi(Map<String, dynamic> k) => metinOku(k['durum']) == 'kapandi';
    final doldu = tum.where((k) => !kapaliMi(k) && _sonDurum(k['son_tarih']) == 'doldu').length;
    final yaklasti = tum.where((k) => !kapaliMi(k) && _sonDurum(k['son_tarih']) == 'yaklasti').length;
    final acik = tum.where((k) => metinOku(k['durum']) == 'acik').length;

    var kayitlar = tum;
    if (_ara.isNotEmpty) {
      final q = _ara.toLowerCase();
      kayitlar = kayitlar
          .where((k) => '${metinOku(k['baslik'])} ${metinOku(k['deger'])} ${metinOku(k['personel_ad'])} ${metinOku(k['not'])}'.toLowerCase().contains(q))
          .toList();
    }
    if (_durumFiltre == 'doldu') kayitlar = kayitlar.where((k) => !kapaliMi(k) && _sonDurum(k['son_tarih']) == 'doldu').toList();
    if (_durumFiltre == 'yaklasti') kayitlar = kayitlar.where((k) => !kapaliMi(k) && _sonDurum(k['son_tarih']) == 'yaklasti').toList();
    if (_durumFiltre == 'acik') kayitlar = kayitlar.where((k) => metinOku(k['durum']) == 'acik').toList();

    return KGovde(yenile: yenile, children: [
      KCipler(
        secenekler: sekmeler,
        secili: _tip,
        onSec: (k) => setState(() {
          _tip = k;
          _durumFiltre = 'tumu';
        }),
      ),
      KKart(
        renk: a.renk,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline, color: a.renk, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(a.ipucu, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4))),
        ]),
      ),
      KKpiIzgara([
        KKpi(etiket: 'Kayıt', deger: sayiYaz(tum.length), ikon: a.ikon, renk: a.renk, onTap: () => setState(() => _durumFiltre = 'tumu'), alt: 'Son 100 kayıt'),
        if (a.kapat) KKpi(etiket: 'Açık arıza', deger: sayiYaz(acik), ikon: Icons.pending_actions, renk: const Color(0xFFF97316), onTap: () => setState(() => _durumFiltre = _durumFiltre == 'acik' ? 'tumu' : 'acik')),
        KKpi(etiket: 'Süresi doldu', deger: sayiYaz(doldu), ikon: Icons.error_outline, renk: const Color(0xFFF43F5E), onTap: () => setState(() => _durumFiltre = _durumFiltre == 'doldu' ? 'tumu' : 'doldu')),
        KKpi(etiket: 'Yaklaşan (15 gün)', deger: sayiYaz(yaklasti), ikon: Icons.schedule, renk: const Color(0xFFF59E0B), onTap: () => setState(() => _durumFiltre = _durumFiltre == 'yaklasti' ? 'tumu' : 'yaklasti')),
      ]),
      if (_durumFiltre != 'tumu')
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            KRozet(_durumFiltre == 'doldu' ? 'Filtre: süresi dolan' : (_durumFiltre == 'yaklasti' ? 'Filtre: yaklaşan' : 'Filtre: açık arızalar'), renk: a.renk, ikon: Icons.filter_alt),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => _durumFiltre = 'tumu'), child: const Text('Kaldır')),
          ]),
        ),
      if (tum.length > 4) KAra(ipucu: 'Başlık, değer, personel, not ara…', onDegis: (v) => setState(() => _ara = v.trim())),
      if (tum.isEmpty)
        KKart(
          child: KBos(
            ikon: a.ikon,
            baslik: 'Henüz ${a.ad.toLowerCase()} kaydı yok',
            aciklama: 'Bu şubede bu deftere kayıt girilmemiş. Sağ alttaki "Ekle" ile ilk kaydı oluşturun; bitiş/son tarih girerseniz süresi dolan ve yaklaşanlar burada ve brifingde uyarı verir.',
            aksiyon: KButon('Ekle', ikon: Icons.add, renk: a.renk, onTap: () => _ekle(yenile)),
          ),
        )
      else if (kayitlar.isEmpty)
        const KKart(child: KBos(ikon: Icons.search_off, baslik: 'Eşleşen kayıt yok', aciklama: 'Arama metnini ya da filtreyi değiştirin.'))
      else
        _izgara(context, [for (final k in kayitlar) _kart(t, a, k, yenile)]),
    ]);
  }

  Widget _izgara(BuildContext context, List<Widget> kartlar) {
    if (!genisMi(context)) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kartlar);
    return LayoutBuilder(builder: (ctx, c) {
      const ara = 12.0;
      final g = (c.maxWidth - ara) / 2;
      return Wrap(spacing: ara, children: [for (final k in kartlar) SizedBox(width: g, child: k)]);
    });
  }

  static const _oncRenk = {'yuksek': Color(0xFFF43F5E), 'orta': Color(0xFFF59E0B), 'dusuk': Color(0xFF64748B)};
  static const _oncAd = {'yuksek': 'Yüksek', 'orta': 'Orta', 'dusuk': 'Düşük'};

  Widget _kart(TemaProvider t, KaliteItDefterTip a, Map<String, dynamic> k, Future<void> Function() yenile) {
    final kapali = metinOku(k['durum']) == 'kapandi';
    final sd = _sonDurum(k['son_tarih']);
    final sdRenk = sd == 'doldu' ? const Color(0xFFF43F5E) : (sd == 'yaklasti' ? const Color(0xFFF59E0B) : const Color(0xFF2FBE94));
    final onc = metinOku(k['oncelik']);
    final detay = [
      if (metinOku(k['tarih']).isNotEmpty) tarihYaz(k['tarih'], saat: false),
      if (metinOku(k['deger']).isNotEmpty) metinOku(k['deger']),
      if (metinOku(k['personel_ad']).isNotEmpty) metinOku(k['personel_ad']),
    ].join(' · ');
    final not = metinOku(k['not']);
    return Opacity(
      opacity: kapali ? .6 : 1,
      child: KKart(
        renk: kapali ? const Color(0xFF10B981) : (sd == 'doldu' ? sdRenk : a.renk),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KIkon(a.ikon, renk: a.renk),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(metinOku(k['baslik']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                if (detay.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(detay, style: TextStyle(color: t.sub, fontSize: 12.5))),
                if (not.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(not, style: TextStyle(color: t.sub, fontSize: 12.5, fontStyle: FontStyle.italic))),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (a.oncelik && !kapali && onc.isNotEmpty) KRozet(_oncAd[onc] ?? onc, renk: _oncRenk[onc] ?? const Color(0xFF64748B)),
                  if (kapali) const KRozet('Kapandı', renk: Color(0xFF10B981), ikon: Icons.check),
                  if (sd != null)
                    KRozet('${sd == 'doldu' ? 'Doldu' : (sd == 'yaklasti' ? 'Yaklaştı' : 'Geçerli')} · ${tarihYaz(k['son_tarih'], saat: false)}', renk: sdRenk, ikon: Icons.event),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (a.kapat && !kapali && widget.ayar.kapatYol != null)
              KButon('Kapat', ikon: Icons.check, renk: const Color(0xFF059669), ikincil: true, onTap: () => _kapat(k, yenile)),
            IconButton(tooltip: 'Sil', onPressed: () => _sil(k, yenile), icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E))),
          ]),
        ]),
      ),
    );
  }
}

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
