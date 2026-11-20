import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /kalite (departman_is view'ı, kod=kalite): HACCP kontrol listesi — sıcaklık / hijyen / uygunsuzluk.
/// Aynı uçlar: /api/departman-is/panel|gecmis (GET), /api/departman-is/ekle|durum|sil (POST JSON).
/// Sekmeler: Açık İşler (8 sn'de bir canlı) + Geçmiş (dönem + durum filtresi).
class KaliteDepartmanIsScreen extends StatefulWidget {
  final String kod;
  final String baslik;
  final Color renk;
  final IconData ikon;
  const KaliteDepartmanIsScreen({
    super.key,
    this.kod = 'kalite',
    this.baslik = 'Kalite / Gıda Güvenliği (HACCP)',
    this.renk = const Color(0xFF16A34A),
    this.ikon = Icons.verified_user_outlined,
  });

  @override
  State<KaliteDepartmanIsScreen> createState() => _KaliteDepartmanIsScreenState();
}

const _kYesil = Color(0xFF10B981);
const _kAmber = Color(0xFFF59E0B);
const _kKirmizi = Color(0xFFF43F5E);
const _kGri = Color(0xFF64748B);
const _kMavi = Color(0xFF4F46E5);
const _kMor = Color(0xFF7C3AED);

const Map<String, (String, IconData, Color)> _kTip = {
  'gorev': ('Görev', Icons.task_alt, _kMavi),
  'kontrol': ('Kontrol', Icons.checklist, _kYesil),
  'olay': ('Olay', Icons.report_outlined, _kKirmizi),
  'ariza': ('Arıza', Icons.report_problem_outlined, _kKirmizi),
  'bakim': ('Bakım', Icons.handyman_outlined, _kAmber),
  'etkinlik': ('Etkinlik', Icons.celebration_outlined, _kMor),
  'kayit': ('Kayıt', Icons.description_outlined, _kGri),
};
const Map<String, (String, Color)> _kOnc = {'yuksek': ('Yüksek', _kKirmizi), 'orta': ('Orta', _kAmber), 'dusuk': ('Düşük', _kGri)};
const Map<String, String> _kTekrar = {'gunluk': 'Günlük', 'haftalik': 'Haftalık', 'aylik': 'Aylık'};

class _KaliteDepartmanIsScreenState extends State<KaliteDepartmanIsScreen> {
  String _sekme = 'acik';
  String _filtre = 'tumu'; // tumu | gecikmis | yuksek
  String _gun = '30';
  String _durum = 'tumu';
  final _acikKey = GlobalKey<KopruEkranState>();
  final _gecmisKey = GlobalKey<KopruEkranState>();

  Future<void> _yenile() async {
    if (_sekme == 'acik') {
      await _acikKey.currentState?.yukle();
    } else {
      await _gecmisKey.currentState?.yukle();
    }
  }

  // ───────── işlemler ─────────
  Future<void> _post(String yol, Map<String, dynamic> veri, {String? mesaj}) async {
    final ok = await kopruGonder(context, yol, veri, json: true, basariMesaji: mesaj ?? 'Kaydedildi.');
    if (ok) {
      await _acikKey.currentState?.yukle(sessiz: true);
      await _gecmisKey.currentState?.yukle(sessiz: true);
    }
  }

  Future<void> _presetEkle(Map<String, dynamic> pr) => _post('/api/departman-is/ekle', {
        'kod': widget.kod,
        'tip': metinOku(pr['tip'], 'gorev'),
        'baslik': metinOku(pr['baslik']),
        'oncelik': metinOku(pr['oncelik'], 'orta'),
        'tekrar': metinOku(pr['tekrar']),
      }, mesaj: 'Eklendi: ${metinOku(pr['baslik'])}');

  Future<void> _durumDegis(Map<String, dynamic> x, String durum) async {
    String deger = '';
    if (durum == 'tamam' && x['tip'] == 'kontrol') {
      final g = await _olcumSor(metinOku(x['baslik']));
      if (g == null) return;
      deger = g;
    }
    if (!mounted) return;
    if (durum == 'iptal' && !await kOnay(context, 'İş iptal edilsin mi?', evet: 'İptal et', tehlikeli: true, aciklama: metinOku(x['baslik']))) return;
    await _post('/api/departman-is/durum', {'id': tamOku(x['id']), 'durum': durum, 'deger': deger},
        mesaj: durum == 'tamam' ? 'Tamamlandı.' : (durum == 'iptal' ? 'İptal edildi.' : 'Başlatıldı.'));
  }

  Future<void> _sil(Map<String, dynamic> x) async {
    if (!await kOnay(context, 'Bu kayıt silinsin mi?', evet: 'Sil', tehlikeli: true, aciklama: metinOku(x['baslik']))) return;
    await _post('/api/departman-is/sil', {'id': tamOku(x['id'])}, mesaj: 'Silindi.');
  }

  Future<String?> _olcumSor(String baslik) async {
    final c = TextEditingController();
    final sonuc = await kAltSayfa<String>(context, baslik: 'Ölçüm / değer', icerik: (ctx) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(baslik, style: TextStyle(color: context.read<TemaProvider>().sub, fontSize: 13.5)),
        ),
        KAlan('Ölçüm', c, ipucu: 'ör. 4 °C', klavye: const TextInputType.numberWithOptions(decimal: true, signed: true)),
        KButon('Kaydet ve tamamla', ikon: Icons.check, renk: _kYesil, genis: true, onTap: () => Navigator.pop(ctx, c.text.trim())),
      ]);
    });
    return sonuc;
  }

  Future<void> _yeniForm() async {
    final baslik = TextEditingController();
    final aciklama = TextEditingController();
    String tip = 'gorev', oncelik = 'orta', tekrar = '';
    DateTime? sonTarih;
    final kaydet = await kAltSayfa<bool>(context, baslik: 'Yeni İş / Kayıt', icerik: (ctx) {
      return StatefulBuilder(builder: (ctx, setD) {
        final t = context.read<TemaProvider>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KSecim<String>('Tür', deger: tip, secenekler: const [
            ('gorev', 'Görev'), ('kontrol', 'Kontrol'), ('olay', 'Olay / Tutanak'), ('ariza', 'Arıza'), ('bakim', 'Bakım'), ('etkinlik', 'Etkinlik'), ('kayit', 'Kayıt'),
          ], onSec: (v) => setD(() => tip = v ?? 'gorev')),
          KAlan('Başlık', baslik, zorunlu: true, ipucu: 'ör. Soğuk oda sıcaklık kontrolü'),
          Row(children: [
            Expanded(child: KSecim<String>('Öncelik', deger: oncelik, secenekler: const [('orta', 'Orta'), ('yuksek', 'Yüksek'), ('dusuk', 'Düşük')], onSec: (v) => setD(() => oncelik = v ?? 'orta'))),
            const SizedBox(width: 10),
            Expanded(child: KSecim<String>('Tekrar', deger: tekrar, secenekler: const [('', 'Tek seferlik'), ('gunluk', 'Günlük'), ('haftalik', 'Haftalık'), ('aylik', 'Aylık')], onSec: (v) => setD(() => tekrar = v ?? ''))),
          ]),
          Text('Son tarih (isteğe bağlı)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _TarihKutu(
            deger: sonTarih,
            onSec: (d) => setD(() => sonTarih = d),
          ),
          const SizedBox(height: 12),
          KAlan('Açıklama / not', aciklama, satir: 2),
          KButon('Ekle', ikon: Icons.check, renk: widget.renk, genis: true, onTap: () {
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
    await _post('/api/departman-is/ekle', {
      'kod': widget.kod,
      'tip': tip,
      'oncelik': oncelik,
      'tekrar': tekrar,
      'baslik': baslik.text.trim(),
      'son_tarih': sonTarih == null ? '' : _isoGun(sonTarih!),
      'aciklama': aciklama.text.trim(),
    }, mesaj: 'İş eklendi.');
  }

  void _bugunTamamlananlar() {
    setState(() {
      _sekme = 'gecmis';
      _gun = '1';
      _durum = 'tamam';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return KSayfa(
      baslik: widget.baslik,
      ikon: widget.ikon,
      araclar: [IconButton(tooltip: 'Yenile', onPressed: _yenile, icon: const Icon(Icons.refresh))],
      fab: _sekme == 'acik'
          ? FloatingActionButton.extended(
              heroTag: 'kalite_dep_yeni',
              backgroundColor: widget.renk,
              onPressed: _yeniForm,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Yeni İş / Kayıt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
      govde: Column(children: [
        Container(
          color: t.bg,
          padding: EdgeInsets.fromLTRB(genisMi(context) ? 22 : 14, 12, genisMi(context) ? 22 : 14, 0),
          child: KCipler(
            secenekler: const [('acik', 'Açık İşler'), ('gecmis', 'Geçmiş')],
            secili: _sekme,
            onSec: (k) => setState(() => _sekme = k),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _sekme == 'acik' ? 0 : 1, children: [
            KopruEkran(
              key: _acikKey,
              kabuksuz: true,
              yol: '/api/departman-is/panel',
              q: {'kod': widget.kod},
              baslik: widget.baslik,
              otomatik: const Duration(seconds: 8),
              govde: (ctx, veri, yenile) => _acikGovde(ctx, veri, yenile),
            ),
            if (_sekme == 'gecmis')
              KopruEkran(
                key: _gecmisKey,
                kabuksuz: true,
                yol: '/api/departman-is/gecmis',
                q: {'kod': widget.kod, 'gun': _gun, 'durum': _durum},
                baslik: widget.baslik,
                govde: (ctx, veri, yenile) => _gecmisGovde(ctx, veri, yenile),
              )
            else
              const SizedBox.shrink(),
          ]),
        ),
      ]),
    );
  }

  // ───────── AÇIK İŞLER ─────────
  Widget _acikGovde(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final oz = harita(veri['ozet']);
    final presetler = liste(veri['presetler']);
    var isler = liste(veri['isler']);
    if (_filtre == 'gecikmis') isler = isler.where((x) => x['gecikti'] == true).toList();
    if (_filtre == 'yuksek') isler = isler.where((x) => x['oncelik'] == 'yuksek').toList();

    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        _rozet('Açık iş', sayiYaz(oz['acik']), Icons.pending_actions, _kMavi, _filtre == 'tumu', () => setState(() => _filtre = 'tumu')),
        _rozet('Bugün tamamlanan', sayiYaz(oz['bugun_tamam']), Icons.task_alt, _kYesil, false, _bugunTamamlananlar, alt: 'Geçmişe git'),
        _rozet('Geciken', sayiYaz(oz['geciken']), Icons.schedule, _kKirmizi, _filtre == 'gecikmis', () => setState(() => _filtre = _filtre == 'gecikmis' ? 'tumu' : 'gecikmis'), alt: 'Filtrele'),
        _rozet('Yüksek öncelik', sayiYaz(oz['yuksek']), Icons.priority_high, _kAmber, _filtre == 'yuksek', () => setState(() => _filtre = _filtre == 'yuksek' ? 'tumu' : 'yuksek'), alt: 'Filtrele'),
      ]),
      if (presetler.isNotEmpty) ...[
        KBaslik('Hızlı ekle (hazır şablon)', ikon: Icons.bolt, renk: widget.renk),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final pr in presetler)
            ActionChip(
              avatar: Icon(Icons.add, size: 16, color: widget.renk),
              label: Text(metinOku(pr['baslik']), style: TextStyle(color: widget.renk, fontSize: 13, fontWeight: FontWeight.w700)),
              backgroundColor: widget.renk.withValues(alpha: .06),
              side: BorderSide(color: widget.renk.withValues(alpha: .5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              onPressed: () => _presetEkle(pr),
            ),
        ]),
        const SizedBox(height: 16),
      ],
      KBaslik(_filtre == 'tumu' ? 'Açık işler' : (_filtre == 'gecikmis' ? 'Geciken işler' : 'Yüksek öncelikli işler'),
          ikon: Icons.list_alt, renk: widget.renk, alt: 'Ölçüm isteyen kontrollerde "Tamam" dediğinizde değer sorulur; limit dışı sıcaklık otomatik uygunsuzluk açar.'),
      if (isler.isEmpty)
        KKart(
          child: KBos(
            ikon: _filtre == 'gecikmis' ? Icons.schedule : (_filtre == 'yuksek' ? Icons.priority_high : Icons.inbox_outlined),
            baslik: _filtre == 'tumu' ? 'Açık iş yok' : (_filtre == 'gecikmis' ? 'Gecikmiş iş yok — harika.' : 'Yüksek öncelikli iş yok'),
            aciklama: _filtre == 'tumu'
                ? 'Bu departmanda bekleyen kontrol / görev bulunmuyor. Sağ alttaki "Yeni İş / Kayıt" ile ekleyebilir ya da yukarıdaki hazır şablonlardan (sıcaklık, hijyen…) seçebilirsiniz. Tekrarlı işler tamamlandıkça sistem bir sonrakini kendisi açar.'
                : 'Filtreyi kaldırıp tüm açık işleri görebilirsiniz.',
            aksiyon: _filtre == 'tumu' ? null : KButon('Filtreyi kaldır', ikincil: true, onTap: () => setState(() => _filtre = 'tumu')),
          ),
        )
      else
        _izgara(context, [for (final x in isler) _isKart(t, x)]),
    ]);
  }

  Widget _rozet(String etiket, String deger, IconData ikon, Color renk, bool secili, VoidCallback onTap, {String? alt}) {
    return Container(
      decoration: secili ? BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: renk, width: 2)) : null,
      child: KKpi(etiket: etiket, deger: deger, ikon: ikon, renk: renk, onTap: onTap, alt: secili ? 'Seçili filtre' : alt),
    );
  }

  Widget _izgara(BuildContext context, List<Widget> kartlar) {
    if (!genisMi(context)) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kartlar);
    return LayoutBuilder(builder: (ctx, c) {
      const ara = 12.0;
      final g = (c.maxWidth - ara) / 2;
      return Wrap(spacing: ara, children: [for (final k in kartlar) SizedBox(width: g, child: k)]);
    });
  }

  Widget _isKart(TemaProvider t, Map<String, dynamic> x) {
    final tp = _kTip[x['tip']] ?? _kTip['gorev']!;
    final on = _kOnc[x['oncelik']] ?? _kOnc['orta']!;
    final yapiliyor = x['durum'] == 'yapiliyor';
    final gecikti = x['gecikti'] == true;
    final deger = metinOku(x['deger']);
    final aciklama = metinOku(x['aciklama']);
    final atanan = metinOku(x['atanan_ad']);
    return KKart(
      renk: gecikti ? _kKirmizi : tp.$3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KIkon(tp.$2, renk: tp.$3),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: metinOku(x['baslik']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                if (deger.isNotEmpty) TextSpan(text: '  ·  $deger', style: const TextStyle(color: _kYesil, fontSize: 15, fontWeight: FontWeight.bold)),
              ])),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                KRozet(tp.$1, renk: tp.$3),
                KRozet(on.$1, renk: on.$2),
                if (_kTekrar[x['tekrar']] != null) KRozet(_kTekrar[x['tekrar']]!, renk: _kGri, ikon: Icons.autorenew),
                if (metinOku(x['son_tarih']).isNotEmpty)
                  KRozet('${tarihYaz(x['son_tarih'], saat: false)}${gecikti ? ' · gecikti' : ''}', renk: gecikti ? _kKirmizi : _kGri, ikon: Icons.event),
                if (yapiliyor) const KRozet('Yapılıyor', renk: _kAmber, ikon: Icons.timelapse),
              ]),
              if (atanan.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Atanan: $atanan', style: TextStyle(color: t.sub, fontSize: 12.5))),
              if (aciklama.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(aciklama, style: TextStyle(color: t.sub, fontSize: 13, height: 1.35))),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
          if (!yapiliyor) KButon('Başla', ikon: Icons.play_arrow, ikincil: true, renk: _kGri, onTap: () => _durumDegis(x, 'yapiliyor')),
          KButon(x['tip'] == 'kontrol' ? 'Ölç / Tamam' : 'Tamam', ikon: Icons.check, renk: _kYesil, onTap: () => _durumDegis(x, 'tamam')),
          IconButton(tooltip: 'İptal et', onPressed: () => _durumDegis(x, 'iptal'), icon: Icon(Icons.close, color: t.sub)),
          IconButton(tooltip: 'Sil', onPressed: () => _sil(x), icon: const Icon(Icons.delete_outline, color: _kKirmizi)),
        ]),
      ]),
    );
  }

  // ───────── GEÇMİŞ ─────────
  Widget _gecmisGovde(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final oz = harita(veri['ozet']);
    final kayitlar = liste(veri['kayitlar']);
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Tamamlanan', deger: sayiYaz(oz['tamam']), ikon: Icons.check_circle_outline, renk: _kYesil),
        KKpi(etiket: 'İptal', deger: sayiYaz(oz['iptal']), ikon: Icons.cancel_outlined, renk: _kKirmizi),
        KKpi(etiket: 'Toplam kayıt', deger: sayiYaz(oz['toplam']), ikon: Icons.insights, renk: _kMavi),
      ]),
      KCipler(
        secenekler: const [('1', 'Bugün'), ('7', '7 gün'), ('30', '30 gün'), ('90', '90 gün'), ('365', '1 yıl'), ('9999', 'Tümü')],
        secili: _gun,
        onSec: (k) => setState(() => _gun = k),
      ),
      KCipler(
        secenekler: const [('tumu', 'Hepsi'), ('tamam', 'Tamam'), ('iptal', 'İptal')],
        secili: _durum,
        onSec: (k) => setState(() => _durum = k),
      ),
      if (kayitlar.isEmpty)
        const KKart(
          child: KBos(
            ikon: Icons.history,
            baslik: 'Bu filtrelerde kayıt bulunamadı',
            aciklama: 'Geçmiş, "Açık İşler" sekmesinde tamamlanan ya da iptal edilen işlerden oluşur. Dönemi genişletin (ör. 90 gün / Tümü) ya da durum filtresini "Hepsi" yapın.',
          ),
        )
      else
        _izgara(context, [for (final x in kayitlar) _gecmisKart(t, x)]),
    ]);
  }

  Widget _gecmisKart(TemaProvider t, Map<String, dynamic> x) {
    final tp = _kTip[x['tip']] ?? _kTip['gorev']!;
    final on = _kOnc[x['oncelik']] ?? _kOnc['orta']!;
    final iptal = x['durum'] == 'iptal';
    final deger = metinOku(x['deger']);
    final sure = metinOku(x['sure']);
    return KKart(
      renk: iptal ? _kKirmizi : _kYesil,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KIkon(tp.$2, renk: tp.$3, boyut: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metinOku(x['baslik']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (deger.isNotEmpty) KRozet(deger, renk: iptal ? _kKirmizi : _kYesil),
              KRozet(iptal ? 'İptal' : 'Tamam', renk: iptal ? _kKirmizi : _kYesil, ikon: iptal ? Icons.cancel_outlined : Icons.check_circle_outline),
              KRozet(tp.$1, renk: tp.$3),
              KRozet(on.$1, renk: on.$2),
              if (_kTekrar[x['tekrar']] != null) KRozet(_kTekrar[x['tekrar']]!, renk: _kGri, ikon: Icons.autorenew),
            ]),
            if (metinOku(x['olusturan_ad']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('Oluşturan: ${metinOku(x['olusturan_ad'])}', style: TextStyle(color: t.sub, fontSize: 12.5))),
            if (metinOku(x['aciklama']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(metinOku(x['aciklama']), style: TextStyle(color: t.sub, fontSize: 12.5))),
            const SizedBox(height: 6),
            if (metinOku(x['acilma']).isNotEmpty) Text('Açılış: ${metinOku(x['acilma'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
            if (metinOku(x['tamam']).isNotEmpty) Text('${iptal ? 'İptal' : 'Tamamlandı'}: ${metinOku(x['tamam'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(sure.isEmpty ? '—' : sure, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Süre', style: TextStyle(color: t.sub2, fontSize: 11.5)),
        ]),
      ]),
    );
  }
}

String _isoGun(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Tarih seçme kutusu (dokununca takvim açılır; çarpı ile temizlenir)
class _TarihKutu extends StatelessWidget {
  final DateTime? deger;
  final ValueChanged<DateTime?> onSec;
  const _TarihKutu({required this.deger, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Material(
      color: t.card2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final s = await showDatePicker(context: context, initialDate: deger ?? DateTime.now(), firstDate: DateTime(2015), lastDate: DateTime(2100));
          if (s != null) onSec(s);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Row(children: [
            Icon(Icons.event, size: 18, color: t.sub),
            const SizedBox(width: 8),
            Expanded(child: Text(deger == null ? 'Tarih seçin' : tarihYaz(_isoGun(deger!), saat: false), style: TextStyle(color: deger == null ? t.sub : t.ink, fontSize: 15))),
            if (deger != null) IconButton(onPressed: () => onSec(null), icon: Icon(Icons.close, size: 18, color: t.sub)),
          ]),
        ),
      ),
    );
  }
}
