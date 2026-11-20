import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'masa_afis_pdf.dart';

/// Web /masa-yonetim — Masa & QR yönetimi / arşiv.
/// Masa ekle (QR otomatik), düzenle (ad/kapasite/bölge), arşivle (QR korunur), arşivden geri getir,
/// QR afiş önizleme + yazdır + PDF paylaş + PNG indir; tüm masalar için toplu afiş.
class OpMasaYonetimScreen extends StatelessWidget {
  const OpMasaYonetimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sube = context.read<AuthProvider>().sube ?? 'Restoran';
    return KopruEkran(
      yol: '/masa-yonetim',
      baslik: 'Masa & QR Yönetimi',
      ikon: Icons.qr_code_2,
      araclar: (ctx, v, yenile) {
        final aktif = liste(v['aktif']);
        return [
          IconButton(
            tooltip: 'Tüm QR afişlerini yazdır',
            onPressed: aktif.isEmpty ? null : () => opMasaAfisYazdir(ctx, sube, aktif, OpMasaAfisDuzen.a6),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Tüm QR afişlerini PDF olarak paylaş',
            onPressed: aktif.isEmpty ? null : () => opMasaAfisPaylas(ctx, sube, aktif, OpMasaAfisDuzen.a6, dosya: 'QR-Kodlari-$sube'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ];
      },
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        heroTag: 'opMasaEkle',
        backgroundColor: ctx.read<TemaProvider>().mor1,
        onPressed: () => _masaForm(ctx, null, liste(v['bolgeler']), yenile),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Masa Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      govde: (ctx, v, yenile) => _Govde(veri: v, yenile: yenile, sube: sube),
    );
  }
}

// ───────── ekle / düzenle formu ─────────
Future<void> _masaForm(BuildContext context, Map<String, dynamic>? m, List<Map<String, dynamic>> bolgeler, Future<void> Function() yenile) async {
  final adK = TextEditingController(text: metinOku(m?['ad']));
  final kapK = TextEditingController(text: m == null ? '4' : '${tamOku(m['kapasite']) == 0 ? 4 : tamOku(m['kapasite'])}');
  int? bolge = m == null ? null : (m['bolge_id'] == null ? null : tamOku(m['bolge_id']));
  var gonderiliyor = false;
  final ok = await kAltSayfa<bool>(
    context,
    baslik: m == null ? 'Yeni Masa' : '${metinOku(m['ad'])} — Düzenle',
    icerik: (c) => StatefulBuilder(builder: (c, st) {
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Masa adı', adK, ipucu: 'Örn. Masa 5 / Teras 2'),
          KAlan('Kapasite (kişi)', kapK, klavye: TextInputType.number),
          KSecim<int?>(
            'Bölge',
            deger: bolge,
            secenekler: [(null, m == null ? 'Varsayılan bölge' : 'Değiştirme'), for (final b in bolgeler) (tamOku(b['id']), metinOku(b['ad']))],
            onSec: (x) => st(() => bolge = x),
          ),
          if (m != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('QR kodu değişmez — basılı afişler geçerli kalır.', style: TextStyle(color: c.read<TemaProvider>().sub, fontSize: 12.5)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Ad boş bırakılırsa sıradaki numara verilir. QR kodu otomatik oluşur.', style: TextStyle(color: c.read<TemaProvider>().sub, fontSize: 12.5)),
            ),
          KButon(m == null ? 'Masayı Ekle' : 'Kaydet', ikon: Icons.check, genis: true, yukleniyor: gonderiliyor, onTap: () async {
            final kap = int.tryParse(kapK.text.trim()) ?? 4;
            st(() => gonderiliyor = true);
            bool basarili;
            if (m == null) {
              basarili = await kopruGonder(c, '/masa-yonetim/ekle', {
                'ad': adK.text.trim(),
                'kapasite': '${kap.clamp(1, 50)}',
                if (bolge != null) 'bolge_id': '$bolge',
              });
            } else {
              basarili = await kopruGonder(c, '/api/patron/masa-guncelle', {
                'id': tamOku(m['id']),
                'ad': adK.text.trim(),
                'kapasite': kap.clamp(1, 50),
                'bolge_id': ?bolge,
              }, json: true, basariMesaji: 'Güncellendi (QR değişmedi)');
            }
            if (!c.mounted) return;
            st(() => gonderiliyor = false);
            if (basarili) Navigator.pop(c, true);
          }),
        ]);
    }),
  );
  adK.dispose();
  kapK.dispose();
  if (ok == true) await yenile();
}

class _Govde extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  final String sube;
  const _Govde({required this.veri, required this.yenile, required this.sube});
  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  String _sekme = 'aktif';
  String _ara = '';

  bool _eslesir(Map<String, dynamic> m) {
    if (_ara.isEmpty) return true;
    final q = _ara.toLowerCase();
    return metinOku(m['ad']).toLowerCase().contains(q) || metinOku(m['bolge']).toLowerCase().contains(q);
  }

  Color _durumRenk(TemaProvider t, String d) => switch (d) {
        'dolu' => t.kirmizi,
        'rezerve' => t.amber,
        'hesap' || 'odeme' => t.mavi,
        _ => t.yesil,
      };

  String _durumAd(String d) => switch (d) {
        'dolu' => 'Dolu',
        'rezerve' => 'Rezerve',
        'hesap' || 'odeme' => 'Hesap',
        'bos' || '' => 'Boş',
        _ => d,
      };

  Future<void> _arsivle(Map<String, dynamic> m) async {
    final ad = metinOku(m['ad'], 'Bu masa');
    final evet = await kOnay(context, '$ad arşive taşınsın mı?',
        evet: 'Arşivle',
        tehlikeli: true,
        aciklama: 'Bu masanın QR kodu metal/ahşap gibi fiziksel bir yere basılmış olabilir.\n\n'
            'Masa SİLİNMEZ, arşive taşınır — QR kodu KORUNUR ve istediğin an aynı kodla geri getirebilirsin. Böylece yeniden bastırma masrafı olmaz.');
    if (!evet || !mounted) return;
    if (await kopruGonder(context, '/masa-yonetim/sil', {'id': tamOku(m['id'])})) await widget.yenile();
  }

  Future<void> _geri(Map<String, dynamic> m) async {
    if (await kopruGonder(context, '/masa-yonetim/geri', {'id': tamOku(m['id'])})) await widget.yenile();
  }

  void _afis(Map<String, dynamic> m) {
    final url = metinOku(m['qr_url']);
    if (url.isEmpty) {
      kToast(context, 'Bu masanın QR kodu henüz oluşmamış.', hata: true);
      return;
    }
    kAltSayfa(context, baslik: 'QR Afişi — ${metinOku(m['ad'])}', icerik: (c) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: t.line)),
          child: Column(children: [
            Text(widget.sube, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF14121A), fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Karekodu telefonunuzla okutun', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5)),
            const SizedBox(height: 12),
            QrImageView(data: url, size: 210, backgroundColor: Colors.white),
            const SizedBox(height: 10),
            Text(metinOku(m['ad'], '-'), style: const TextStyle(color: Color(0xFF14121A), fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            const Text('Menü · Sipariş · Garson Çağır · Öde', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),
        SelectableText(url, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          KButon('Yazdır', ikon: Icons.print_outlined, onTap: () => opMasaAfisYazdir(c, widget.sube, [m], OpMasaAfisDuzen.a6)),
          KButon('PDF paylaş', ikon: Icons.share_outlined, ikincil: true, onTap: () => opMasaAfisPaylas(c, widget.sube, [m], OpMasaAfisDuzen.a6, dosya: 'QR-${metinOku(m['ad'])}')),
          KButon('PNG indir', ikon: Icons.download_outlined, ikincil: true, renk: t.yesil, onTap: () => opMasaQrPngKaydet(c, m)),
        ]),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final aktif = liste(widget.veri['aktif']);
    final arsiv = liste(widget.veri['arsiv']);
    final bolgeler = liste(widget.veri['bolgeler']);
    final dolu = aktif.where((m) => metinOku(m['durum']) == 'dolu').length;
    final kapasite = aktif.fold<int>(0, (s, m) => s + tamOku(m['kapasite']));

    final cocuklar = <Widget>[
      KKpiIzgara([
        KKpi(etiket: 'Aktif masa', deger: sayiYaz(aktif.length), ikon: Icons.table_restaurant_outlined, renk: t.mor1),
        KKpi(etiket: 'Toplam kapasite', deger: '${sayiYaz(kapasite)} kişi', ikon: Icons.event_seat_outlined, renk: t.mavi),
        KKpi(etiket: 'Şu an dolu', deger: sayiYaz(dolu), ikon: Icons.restaurant, renk: t.kirmizi),
        KKpi(etiket: 'Arşivde', deger: sayiYaz(arsiv.length), alt: 'QR korunuyor', ikon: Icons.inventory_2_outlined, renk: t.amber),
      ]),
      KCipler(
        secenekler: [('aktif', 'Masalar (${aktif.length})'), ('arsiv', 'Arşiv (${arsiv.length})')],
        secili: _sekme,
        onSec: (k) => setState(() => _sekme = k),
      ),
      KAra(ipucu: 'Masa ya da bölge ara…', onDegis: (s) => setState(() => _ara = s.trim())),
    ];

    if (_sekme == 'aktif') {
      final suz = aktif.where(_eslesir).toList();
      if (aktif.isEmpty) {
        cocuklar.add(KBos(
          ikon: Icons.table_restaurant_outlined,
          baslik: 'Henüz masa yok',
          aciklama: 'Masalar bu ekrandan eklenir; her masaya otomatik bir QR kodu verilir. Sağ alttaki "Masa Ekle" ile başlayın.',
          aksiyon: KButon('Masa Ekle', ikon: Icons.add, onTap: () => _masaForm(context, null, bolgeler, widget.yenile)),
        ));
      } else if (suz.isEmpty) {
        cocuklar.add(KBos(ikon: Icons.search_off, baslik: 'Eşleşen masa yok', aciklama: '"$_ara" aramasına uyan aktif masa bulunamadı.'));
      } else {
        final gruplar = <String, List<Map<String, dynamic>>>{};
        for (final m in suz) {
          gruplar.putIfAbsent(metinOku(m['bolge'], 'Bölgesiz'), () => []).add(m);
        }
        gruplar.forEach((bolge, ms) {
          cocuklar.add(KBaslik(bolge, ikon: Icons.map_outlined, alt: '${ms.length} masa · ${ms.fold<int>(0, (s, m) => s + tamOku(m['kapasite']))} kişi'));
          cocuklar.add(LayoutBuilder(builder: (c, k) {
            final w = k.maxWidth;
            final n = w >= 1000 ? 5 : (w >= 760 ? 4 : (w >= 520 ? 3 : 2));
            const ara = 10.0;
            final g = (w - ara * (n - 1)) / n;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(spacing: ara, runSpacing: ara, children: [for (final m in ms) SizedBox(width: g, child: _masaKart(t, m, bolgeler))]),
            );
          }));
        });
      }
    } else {
      final suz = arsiv.where(_eslesir).toList();
      if (arsiv.isEmpty) {
        cocuklar.add(const KBos(
          ikon: Icons.inventory_2_outlined,
          baslik: 'Arşiv boş',
          aciklama: 'Kaldırılan masalar silinmez, buraya taşınır ve QR kodları korunur. Masalar sekmesinde bir masayı arşivlediğinizde burada görünür.',
        ));
      } else {
        cocuklar.add(KKart(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < suz.length; i++)
              KSatir(
                cizgi: i < suz.length - 1,
                solIkon: KIkon(Icons.inventory_2_outlined, renk: t.amber),
                baslik: metinOku(suz[i]['ad'], '-'),
                alt: '${metinOku(suz[i]['bolge'], 'Bölgesiz')} · ${tamOku(suz[i]['kapasite'])} kişi · aynı QR geçerli',
                sag: KButon('Geri getir', ikon: Icons.unarchive_outlined, renk: t.yesil, onTap: () => _geri(suz[i])),
              ),
          ]),
        ));
      }
    }
    return KGovde(yenile: widget.yenile, children: cocuklar);
  }

  Widget _masaKart(TemaProvider t, Map<String, dynamic> m, List<Map<String, dynamic>> bolgeler) {
    final d = metinOku(m['durum'], 'bos');
    final r = _durumRenk(t, d);
    final url = metinOku(m['qr_url']);
    return KKart(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      onTap: () => _afis(m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 110,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          alignment: Alignment.center,
          child: url.isEmpty
              ? const Text('QR yok', style: TextStyle(color: Color(0xFF6B7280), fontSize: 12.5))
              : QrImageView(data: url, size: 96, padding: EdgeInsets.zero, backgroundColor: Colors.white),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text(metinOku(m['ad'], '-'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
          Container(width: 9, height: 9, decoration: BoxDecoration(color: r, shape: BoxShape.circle)),
        ]),
        Text('${tamOku(m['kapasite'])} kişi · ${_durumAd(d)}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _ib(Icons.qr_code_2, 'QR afişi', t.mor1, () => _afis(m)),
          _ib(Icons.download_outlined, 'QR kodunu indir (PNG)', t.yesil, () => opMasaQrPngKaydet(context, m)),
          _ib(Icons.edit_outlined, 'Düzenle', t.mavi, () => _masaForm(context, m, bolgeler, widget.yenile)),
          _ib(Icons.archive_outlined, 'Arşivle', t.kirmizi, () => _arsivle(m)),
        ]),
      ]),
    );
  }

  Widget _ib(IconData i, String ipucu, Color r, VoidCallback f) => IconButton(
        tooltip: ipucu,
        onPressed: f,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
        padding: EdgeInsets.zero,
        icon: Icon(i, size: 20, color: r),
      );
}
