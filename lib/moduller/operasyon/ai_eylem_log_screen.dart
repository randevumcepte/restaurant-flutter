import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Web /ai-eylem-log — AI'ın önerdiği eylemlerin değiştirilemez (SHA256 zincirli) günlüğü (sahip/müdür).
/// İşlemler: filtre (modül, karar, kullanıcı, tarih aralığı), Zinciri Doğrula (/api/ai-eylem/zincir-dogrula),
/// satır detayı + olay zinciri (/api/ai-eylem/detay?id=), PDF rapor (/ai-eylem-log/pdf verisinden cihazda üretilir).
class OpAiEylemLogScreen extends StatefulWidget {
  const OpAiEylemLogScreen({super.key});

  @override
  State<OpAiEylemLogScreen> createState() => _OpAiEylemLogScreenState();
}

const _moduller = [('', 'Tüm modüller'), ('ik', 'İK'), ('satinalma', 'Satınalma'), ('patron', 'Patron')];
const _kararlar = [('', 'Tüm kararlar'), ('onaylandi', 'Onaylandı'), ('reddedildi', 'Vazgeçildi'), ('bekliyor', 'Bekliyor'), ('zamanasimi', 'Zaman Aşımı')];

(String, Color) _kararGorunum(String k) {
  switch (k) {
    case 'onaylandi':
      return ('✓ Onay', const Color(0xFF10B981));
    case 'reddedildi':
      return ('✕ Vazgeçildi', const Color(0xFFF59E0B));
    case 'zamanasimi':
      return ('Zaman aşımı', const Color(0xFF94A3B8));
    default:
      return ('Bekliyor', const Color(0xFF6366F1));
  }
}

(String, Color) _olayGorunum(String tip) {
  switch (tip) {
    case 'onaylandi':
      return ('onaylandı', const Color(0xFF10B981));
    case 'reddedildi':
      return ('vazgeçildi', const Color(0xFFF59E0B));
    case 'zamanasimi':
      return ('zaman aşımı', const Color(0xFF94A3B8));
    case 'yurutuldu':
      return ('yürütüldü ✓', const Color(0xFF059669));
    case 'yurutme_hatasi':
      return ('yürütme hatası', const Color(0xFFF43F5E));
    default:
      return (tip, const Color(0xFF64748B));
  }
}

class _OpAiEylemLogScreenState extends State<OpAiEylemLogScreen> {
  final _anahtar = GlobalKey<KopruEkranState>();
  String? _zincirSonuc;
  bool? _zincirSaglam;
  bool _zincirKontrol = false;
  bool _pdfHazirlaniyor = false;

  String _q(String k, Map<String, dynamic> v, String varsayilan) => _anahtar.currentState?.q?[k] ?? metinOku(v[varsayilan]);

  Future<void> _zincirDogrula() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() {
      _zincirKontrol = true;
      _zincirSonuc = 'Kontrol ediliyor…';
      _zincirSaglam = null;
    });
    try {
      final c = await KopruApi.al(tok, '/api/ai-eylem/zincir-dogrula');
      if (!mounted) return;
      final d = harita(c.j['durum']);
      setState(() {
        _zincirKontrol = false;
        if (!c.ok) {
          _zincirSaglam = false;
          _zincirSonuc = c.hata ?? 'Doğrulanamadı.';
        } else if (d['saglam'] == true) {
          _zincirSaglam = true;
          _zincirSonuc = 'Zincir sağlam · ${sayiYaz(d['sayi'])} satır doğrulandı';
        } else {
          _zincirSaglam = false;
          _zincirSonuc = 'HASAR TESPİT EDİLDİ · İlk kırık satır ID: ${metinOku(d['ilk_kirik_id'], '?')}';
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  Future<void> _detay(Map<String, dynamic> s) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    final gelecek = KopruApi.al(tok, '/api/ai-eylem/detay', q: {'id': '${s['id']}'});
    await kAltSayfa(
      context,
      baslik: 'AI Eylem Detayı',
      icerik: (ctx) => FutureBuilder<KopruCevap>(
        future: gelecek,
        builder: (ctx, snap) {
          if (!snap.hasData) return const Padding(padding: EdgeInsets.all(30), child: KYukleniyor());
          final c = snap.data!;
          if (!c.ok) return KBos(baslik: 'Yüklenemedi', aciklama: c.hata, ikon: Icons.error_outline);
          return _detayGovde(ctx, harita(c.j['oneri']), liste(c.j['olaylar']));
        },
      ),
    );
  }

  Widget _detayGovde(BuildContext ctx, Map<String, dynamic> o, List<Map<String, dynamic>> olaylar) {
    final t = ctx.watch<TemaProvider>();
    String params;
    try {
      params = const JsonEncoder.withIndent('  ').convert(jsonDecode(metinOku(o['params'], '{}')));
    } catch (_) {
      params = metinOku(o['params'], '{}');
    }
    Widget satir(String et, Widget deger) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(et, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            deger,
          ]),
        );
    Text metin(String s, {bool mono = false, Color? renk}) => Text(s, style: TextStyle(color: renk ?? t.ink, fontSize: 13.5, fontFamily: mono ? 'monospace' : null));
    final (kAd, kRenk) = ('önerildi', const Color(0xFF4F46E5));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      satir('Tarih', metin(tarihYaz(o['created_at']))),
      satir('Modül', Align(alignment: Alignment.centerLeft, child: KRozet(metinOku(o['modul'], '—'), renk: t.mor1))),
      satir('Niyet (intent)', metin(metinOku(o['intent'], '—'), mono: true)),
      satir('Özet', metin(metinOku(o['ozet'], '—'))),
      satir(
        'Parametreler',
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
          child: SelectableText(params, style: TextStyle(color: t.ink, fontSize: 12, fontFamily: 'monospace')),
        ),
      ),
      if (metinOku(o['ai_yaniti']).isNotEmpty) satir('AI yanıtı', metin(metinOku(o['ai_yaniti']))),
      satir('Kullanıcı', metin('${metinOku(o['kullanici_ad'], '—')} (${metinOku(o['kullanici_rol'])}) · ID ${metinOku(o['kullanici_id'])}')),
      satir('IP · Tarayıcı / cihaz', SelectableText('${metinOku(o['ip_adres'], '-')}\n${metinOku(o['user_agent'])}', style: TextStyle(color: t.sub2, fontSize: 12, fontFamily: 'monospace'))),
      satir('Önceki imza', SelectableText(metinOku(o['onceki_imza'], '—'), style: TextStyle(color: t.sub2, fontSize: 12, fontFamily: 'monospace'))),
      satir('Bu satırın imzası', SelectableText(metinOku(o['imza'], '—'), style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'))),
      const SizedBox(height: 4),
      KBaslik('Olay zinciri', ikon: Icons.timeline),
      _olaySatir(t, tarihYaz(o['created_at']), kAd, kRenk, 'AI öneri oluşturuldu'),
      for (final ev in olaylar)
        () {
          final (ad, renk) = _olayGorunum(metinOku(ev['tip']));
          final kim = '${metinOku(ev['kullanici_ad'])} (${metinOku(ev['kullanici_rol'])})';
          final msj = metinOku(ev['sonuc_mesaj']);
          return _olaySatir(t, tarihYaz(ev['created_at']), ad, renk, msj.isEmpty ? kim : '$kim · $msj');
        }(),
    ]);
  }

  Widget _olaySatir(TemaProvider t, String zaman, String tip, Color renk, String aciklama) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(zaman, style: TextStyle(color: t.sub, fontSize: 12))),
          KRozet(tip, renk: renk),
          const SizedBox(width: 8),
          Expanded(child: Text(aciklama, style: TextStyle(color: t.sub2, fontSize: 12.5))),
        ]),
      );

  Future<void> _tarihSec(Map<String, dynamic> v, String alan) async {
    final mevcut = DateTime.tryParse(_q(alan, v, alan == 'bas' ? 'basTarih' : 'bitTarih')) ?? DateTime.now();
    final d = await showDatePicker(context: context, initialDate: mevcut, firstDate: DateTime(2024), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (d == null) return;
    final s = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    _anahtar.currentState?.sorgu({alan: s});
  }

  Future<void> _pdf(Map<String, dynamic> v) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null || _pdfHazirlaniyor) return;
    final bas = _q('bas', v, 'basTarih');
    final bit = _q('bit', v, 'bitTarih');
    setState(() => _pdfHazirlaniyor = true);
    try {
      final c = await KopruApi.al(tok, '/ai-eylem-log/pdf', q: {'bas': bas, 'bit': bit});
      if (!mounted) return;
      if (!c.ok) {
        kToast(context, c.hata ?? 'Rapor verisi alınamadı.', hata: true);
        return;
      }
      final bayt = await _pdfUret(c.veri, bas, bit);
      await Printing.layoutPdf(name: 'AI-Eylem-Gunlugu-$bas-$bit.pdf', onLayout: (_) async => bayt);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (mounted) kToast(context, 'PDF hazırlanamadı: $e', hata: true);
    } finally {
      if (mounted) setState(() => _pdfHazirlaniyor = false);
    }
  }

  Future<Uint8List> _pdfUret(Map<String, dynamic> v, String bas, String bit) async {
    final r = await PdfGoogleFonts.notoSansRegular();
    final b = await PdfGoogleFonts.notoSansBold();
    final satirlar = liste(v['satirlar']);
    final kararlar = harita(v['kararlar']);
    final dog = harita(v['dogrulama']);
    final saglam = dog['saglam'] == true;
    final sube = harita(v['sube']);
    final bp = harita(v['bp']);
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: r, bold: b));
    String kararBul(List<Map<String, dynamic>> k, String tip) => k.any((e) => e['tip'] == tip) ? tip : '';
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      build: (c) => [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('AI Eylem Günlüğü — Yasal Denetim Raporu', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text('${metinOku(sube['ad'], 'ResteOS')} · $bas – $bit arası', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            ]),
          ),
          pw.Text('Üretildi: ${tarihYaz(v['uretildiAt'])}\nHazırlayan: ${metinOku(bp['ad'], '-')} (${metinOku(bp['rol'])})',
              textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ]),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: saglam ? PdfColors.green50 : PdfColors.red50, borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            pw.Text('Toplam kayıt (dönem): ${satirlar.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Zincir durumu: ${saglam ? 'SAĞLAM' : 'HASARLI'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: saglam ? PdfColors.green800 : PdfColors.red800)),
            pw.Text('Toplam zincir satırı: ${metinOku(dog['sayi'], '0')}'),
            if (!saglam) pw.Text('İlk kırık satır: #${metinOku(dog['ilk_kirik_id'], '?')}'),
          ]),
        ),
        pw.SizedBox(height: 12),
        pw.Text('KAYIT LİSTESİ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FixedColumnWidth(32), 1: const pw.FixedColumnWidth(82), 2: const pw.FixedColumnWidth(52), 3: const pw.FlexColumnWidth(3),
            4: const pw.FixedColumnWidth(90), 5: const pw.FixedColumnWidth(58), 6: const pw.FlexColumnWidth(1.4), 7: const pw.FixedColumnWidth(66),
          },
          headers: ['#', 'Tarih', 'Modül', 'Niyet · Özet', 'Kullanıcı', 'Karar', 'Yürütme', 'IP'],
          data: [
            for (final s in satirlar)
              () {
                final k = liste(kararlar['${s['id']}']);
                final karar = [kararBul(k, 'onaylandi'), kararBul(k, 'reddedildi'), kararBul(k, 'zamanasimi')].firstWhere((e) => e.isNotEmpty, orElse: () => 'bekliyor');
                final kararAd = {'onaylandi': 'ONAY', 'reddedildi': 'RET', 'zamanasimi': 'Z.AŞIMI'}[karar] ?? 'BEKLİYOR';
                final yurut = k.where((e) => e['tip'] == 'yurutuldu' || e['tip'] == 'yurutme_hatasi').toList();
                final yurutMetin = yurut.isEmpty
                    ? '—'
                    : '${yurut.first['tip'] == 'yurutuldu' ? 'BAŞARILI' : 'HATA'}${metinOku(yurut.first['sonuc_mesaj']).isEmpty ? '' : '\n${metinOku(yurut.first['sonuc_mesaj'])}'}';
                return [
                  '#${s['id']}',
                  tarihYaz(s['created_at']),
                  metinOku(s['modul']).toUpperCase(),
                  '${metinOku(s['intent'])}\n${metinOku(s['ozet'])}',
                  '${metinOku(s['kullanici_ad'])}\n${metinOku(s['kullanici_rol'])} · ID ${metinOku(s['kullanici_id'])}',
                  kararAd,
                  yurutMetin,
                  metinOku(s['ip_adres']),
                ];
              }(),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Text('HASH İMZA DOĞRULAMA', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          'Her satırın imzası (SHA256) bir önceki satırın imzasını içerir. Geçmiş bir satır değişirse zincir kırılır ve tespit edilir. '
          'Bu raporun oluşturulduğu an itibarıyla zincir durumu: ${saglam ? 'SAĞLAM (tüm satırlar doğrulandı)' : 'HASARLI (zincir bozulmuş)'}.',
          style: const pw.TextStyle(fontSize: 9),
        ),
        if (satirlar.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            columnWidths: {0: const pw.FixedColumnWidth(40), 1: const pw.FlexColumnWidth()},
            headers: ['#', 'İmza (SHA256)'],
            data: [for (final s in satirlar) ['#${s['id']}', metinOku(s['imza'])]],
          ),
        ],
      ],
    ));
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _anahtar,
      yol: '/ai-eylem-log',
      baslik: 'AI Eylem Günlüğü',
      ikon: Icons.verified_user_outlined,
      araclar: (ctx, v, yenile) => [
        IconButton(
          tooltip: 'PDF olarak indir / yazdır',
          onPressed: _pdfHazirlaniyor ? null : () => _pdf(v),
          icon: _pdfHazirlaniyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final satirlar = liste(v['satirlar']);
        final kullanicilar = liste(v['kullanicilar']);
        final modul = _q('modul', v, 'modulFil');
        final karar = _q('karar', v, 'kararFil');
        final kul = int.tryParse(_q('kullanici_id', v, 'kulFil')) ?? 0;
        final bas = _q('bas', v, 'basTarih');
        final bit = _q('bit', v, 'bitTarih');
        int say(String k) => satirlar.where((s) => s['karar'] == k).length;
        final filtreler = <Widget>[
          KSecim<String>('Modül', deger: modul, secenekler: _moduller, onSec: (x) => _anahtar.currentState?.sorgu({'modul': x ?? ''})),
          KSecim<String>('Karar', deger: karar, secenekler: _kararlar, onSec: (x) => _anahtar.currentState?.sorgu({'karar': x ?? ''})),
          KSecim<int>('Kullanıcı', deger: kul, secenekler: [(0, 'Tüm kullanıcılar'), for (final k in kullanicilar) (tamOku(k['kullanici_id']), metinOku(k['kullanici_ad'], '—'))],
              onSec: (x) => _anahtar.currentState?.sorgu({'kullanici_id': '${x ?? 0}'})),
        ];
        return KGovde(yenile: yenile, children: [
          KKart(
            renk: _zincirSaglam == null ? t.mor1 : (_zincirSaglam! ? t.yesil : t.kirmizi),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.lock_outline, size: 18, color: t.yesil),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Her satır SHA256 ile bir öncekine zincirlenir; geçmiş kayıt değiştirilemez. Toplam ${sayiYaz(v['toplamSatir'])} kayıt.',
                      style: TextStyle(color: t.sub2, fontSize: 13)),
                ),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                KButon('Zinciri Doğrula', ikon: Icons.verified_outlined, yukleniyor: _zincirKontrol, onTap: _zincirDogrula, renk: _zincirSaglam == false ? t.kirmizi : null),
                KButon('PDF olarak indir', ikon: Icons.picture_as_pdf_outlined, ikincil: true, yukleniyor: _pdfHazirlaniyor, onTap: () => _pdf(v)),
                if (_zincirSonuc != null)
                  KRozet(_zincirSonuc!, renk: _zincirSaglam == null ? t.sub : (_zincirSaglam! ? t.yesil : t.kirmizi), ikon: _zincirSaglam == false ? Icons.warning_amber : Icons.check_circle_outline),
              ]),
            ]),
          ),
          if (genisMi(ctx))
            Row(children: [for (final f in filtreler) Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: f))])
          else
            ...filtreler,
          Row(children: [
            Expanded(child: KButon('Başlangıç: ${tarihYaz(bas, saat: false)}', ikon: Icons.event, ikincil: true, onTap: () => _tarihSec(v, 'bas'))),
            const SizedBox(width: 10),
            Expanded(child: KButon('Bitiş: ${tarihYaz(bit, saat: false)}', ikon: Icons.event, ikincil: true, onTap: () => _tarihSec(v, 'bit'))),
          ]),
          const SizedBox(height: 12),
          KKpiIzgara([
            KKpi(etiket: 'Öneri', deger: '${satirlar.length}', ikon: Icons.smart_toy_outlined, renk: t.mor1),
            KKpi(etiket: 'Onaylandı', deger: '${say('onaylandi')}', ikon: Icons.check_circle_outline, renk: t.yesil),
            KKpi(etiket: 'Vazgeçildi', deger: '${say('reddedildi')}', ikon: Icons.cancel_outlined, renk: t.amber),
            KKpi(etiket: 'Bekliyor', deger: '${say('bekliyor')}', ikon: Icons.hourglass_bottom, renk: t.mavi),
            KKpi(etiket: 'Yürütme hatası', deger: '${satirlar.where((s) => s['yurut_ok'] == false).length}', ikon: Icons.error_outline, renk: t.kirmizi),
          ]),
          if (satirlar.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Bu kriterlere uygun kayıt yok',
                aciklama: 'AI asistanı (Patron AI, İK, Satınalma) bir işlem önerdiğinde burada kayda geçer. '
                    'Filtreleri temizleyin ya da tarih aralığını genişletin.',
                ikon: Icons.verified_user_outlined,
              ),
            )
          else if (genisMi(ctx))
            KKart(
              padding: const EdgeInsets.all(6),
              child: KTablo(
                basliklar: const ['Tarih', 'Modül', 'Niyet · Özet', 'Kullanıcı', 'Karar', 'Sonuç', 'IP'],
                satirlar: [
                  for (final s in satirlar)
                    [
                      tarihYaz(s['created_at']),
                      metinOku(s['modul']),
                      '${metinOku(s['intent'])}\n${metinOku(s['ozet'])}',
                      '${metinOku(s['kullanici_ad'])} · ${metinOku(s['kullanici_rol'])}',
                      _kararGorunum(metinOku(s['karar'])).$1,
                      s['yurut_ok'] == true ? 'Başarılı' : (s['yurut_ok'] == false ? 'HATA: ${metinOku(s['yurut_mesaj'])}' : '—'),
                      metinOku(s['ip_adres']),
                    ],
                ],
                onSatir: (i) => _detay(satirlar[i]),
              ),
            )
          else
            for (final s in satirlar) _kart(t, s),
        ]);
      },
    );
  }

  Widget _kart(TemaProvider t, Map<String, dynamic> s) {
    final (kAd, kRenk) = _kararGorunum(metinOku(s['karar']));
    return KKart(
      renk: kRenk,
      onTap: () => _detay(s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KRozet(metinOku(s['modul'], '—'), renk: t.mor1),
          const SizedBox(width: 6),
          KRozet(kAd, renk: kRenk),
          const Spacer(),
          Text(tarihYaz(s['created_at']), style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        Text(metinOku(s['intent'], '—'), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        if (metinOku(s['ozet']).isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 3), child: Text(metinOku(s['ozet']), maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 13))),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.person_outline, size: 14, color: t.sub),
          const SizedBox(width: 4),
          Expanded(child: Text('${metinOku(s['kullanici_ad'], '—')} · ${metinOku(s['kullanici_rol'])}', style: TextStyle(color: t.sub, fontSize: 12.5))),
          if (s['yurut_ok'] == true) KRozet('Başarılı', renk: t.yesil),
          if (s['yurut_ok'] == false) KRozet('Yürütme hatası', renk: t.kirmizi),
        ]),
      ]),
    );
  }
}
