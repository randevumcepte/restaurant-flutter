import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /personel-yemek — Personel Yemeği (web ile aynı): ay seçimi, aylık toplam, kişi bazlı özet,
/// kayıt ekle (personel/genel, tarih, açıklama, tutar), kayıt sil.
class IkPersonelYemekScreen extends StatefulWidget {
  const IkPersonelYemekScreen({super.key});
  @override
  State<IkPersonelYemekScreen> createState() => _IkPersonelYemekScreenState();
}

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

String _ayAd(String ay) {
  final p = ay.split('-');
  if (p.length != 2) return ay;
  final m = int.tryParse(p[1]) ?? 0;
  return '${m > 0 && m < 13 ? _aylar[m] : p[1]} ${p[0]}';
}

String _ayKaydir(String ay, int n) {
  final p = ay.split('-');
  final y = int.tryParse(p.first) ?? DateTime.now().year;
  final m = int.tryParse(p.length > 1 ? p[1] : '') ?? DateTime.now().month;
  final d = DateTime(y, m + n, 1);
  return '${d.year}-${d.month.toString().padLeft(2, '0')}';
}

String _gunStr(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _IkPersonelYemekScreenState extends State<IkPersonelYemekScreen> {
  final _anahtar = GlobalKey<KopruEkranState>();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _anahtar,
      yol: '/personel-yemek',
      baslik: 'Personel Yemeği',
      ikon: Icons.lunch_dining_outlined,
      fab: (c, v, yenile) => FloatingActionButton.extended(
        heroTag: 'py_ekle',
        onPressed: () => _ekle(c, v, yenile),
        icon: const Icon(Icons.add),
        label: const Text('Kayıt Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final ay = metinOku(v['ay'], '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
    final simdiAy = _ayKaydir(_gunStr(DateTime.now()).substring(0, 7), 0);
    final persAd = harita(v['persAd']);
    String ad(dynamic pid) => tamOku(pid) > 0 ? metinOku(persAd['${tamOku(pid)}'], 'Personel') : 'Genel';
    final kayitlar = liste(v['liste']);
    final kisi = harita(v['kisiOzet']);
    final genis = genisMi(context);

    return KGovde(yenile: yenile, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('Çalışanların işte yediği yemeklerin maliyetini takip edin. Aylık toplam ve kişi bazlı özet, gider/maaş değerlendirmesi içindir.',
            style: TextStyle(color: t.sub, fontSize: 13)),
      ),
      KKart(
        child: Row(children: [
          IconButton(tooltip: 'Önceki ay', onPressed: () => _anahtar.currentState?.sorgu({'ay': _ayKaydir(ay, -1)}), icon: Icon(Icons.chevron_left, color: t.ink)),
          Expanded(
            child: Column(children: [
              Text(_ayAd(ay), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('Toplam: ${tl(v['ayToplam'])}', style: TextStyle(color: t.amber, fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
          IconButton(
            tooltip: 'Sonraki ay',
            onPressed: ay.compareTo(simdiAy) >= 0 ? null : () => _anahtar.currentState?.sorgu({'ay': _ayKaydir(ay, 1)}),
            icon: Icon(Icons.chevron_right, color: ay.compareTo(simdiAy) >= 0 ? t.line : t.ink),
          ),
        ]),
      ),
      if (kisi.isNotEmpty) ...[
        KBaslik('Kişi bazlı', ikon: Icons.groups_outlined, alt: _ayAd(ay)),
        KKart(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kisi.entries)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: ad(e.key), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
                  TextSpan(text: ' · ${tamOku(harita(e.value)['adet'])} öğün · ', style: TextStyle(color: t.sub, fontSize: 13)),
                  TextSpan(text: tl(harita(e.value)['tutar']), style: TextStyle(color: t.amber, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ])),
              ),
          ]),
        ),
      ],
      KBaslik('Kayıtlar', ikon: Icons.list_alt, alt: '${kayitlar.length} kayıt'),
      if (kayitlar.isEmpty)
        const KBos(
          ikon: Icons.lunch_dining_outlined,
          baslik: 'Bu ay kayıt yok',
          aciklama: 'Personel yemeği kaydı bu ekrandan "Kayıt Ekle" ile girilir. Başka bir ayı görmek için yukarıdaki oklarla ay değiştirin.',
        )
      else if (genis)
        KKart(
          child: KTablo(
            basliklar: const ['Tarih', 'Personel', 'Açıklama', 'Tutar'],
            sagaYasla: const {3},
            satirlar: [for (final y in kayitlar) [tarihYaz(y['tarih'], saat: false), ad(y['personel_id']), metinOku(y['aciklama']), tl(y['tutar'])]],
            onSatir: (i) => _sil(context, kayitlar[i], ad(kayitlar[i]['personel_id']), yenile),
          ),
        )
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final y in kayitlar)
              KSatir(
                baslik: ad(y['personel_id']),
                alt: '${tarihYaz(y['tarih'], saat: false)}${metinOku(y['aciklama']).isNotEmpty ? ' · ${metinOku(y['aciklama'])}' : ''}',
                solIkon: KIkon(Icons.restaurant, renk: t.amber),
                sag: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tl(y['tutar']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
                  IconButton(tooltip: 'Sil', onPressed: () => _sil(context, y, ad(y['personel_id']), yenile), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
                ]),
              ),
          ]),
        ),
      if (genis && kayitlar.isNotEmpty) Text('Silmek için satıra dokunun.', style: TextStyle(color: t.sub, fontSize: 12)),
    ]);
  }

  Future<void> _sil(BuildContext context, Map<String, dynamic> y, String ad, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Kayıt silinsin mi?', aciklama: '$ad · ${tarihYaz(y['tarih'], saat: false)} · ${tl(y['tutar'])}', evet: 'Sil', tehlikeli: true)) return;
    if (!context.mounted) return;
    if (await kopruGonder(context, '/personel-yemek/sil', {'id': tamOku(y['id'])}, basariMesaji: 'Silindi.')) await yenile();
  }

  Future<void> _ekle(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final pers = liste(v['personeller']);
    int pid = 0;
    DateTime tarih = DateTime.now();
    final acik = TextEditingController(), tutar = TextEditingController();
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Personel Yemeği — Kayıt Ekle',
        icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
              final t = sc.watch<TemaProvider>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KSecim<int>('Personel', deger: pid, secenekler: [(0, '— Genel —'), for (final p in pers) (tamOku(p['id']), metinOku(p['ad']))], onSec: (x) => ss(() => pid = x ?? 0)),
                KSatir(
                  baslik: 'Tarih',
                  alt: tarihYaz(_gunStr(tarih), saat: false),
                  solIkon: KIkon(Icons.event, renk: t.mavi),
                  sag: Icon(Icons.edit_calendar, color: t.sub),
                  onTap: () async {
                    final d = await showDatePicker(context: sc, initialDate: tarih, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                    if (d != null) ss(() => tarih = d);
                  },
                ),
                const SizedBox(height: 12),
                KAlan('Açıklama', acik, ipucu: 'öğle yemeği'),
                KAlan('Tutar (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
                KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
                  if (sayiOku(tutar.text) <= 0) {
                    kToast(sc, 'Tutar girin.', hata: true);
                    return;
                  }
                  Navigator.pop(sc, true);
                }),
              ]);
            }));
    if (tamam != true || !context.mounted) return;
    final ok = await kopruGonder(context, '/personel-yemek/ekle', {
      'personel_id': pid > 0 ? '$pid' : '', 'tarih': _gunStr(tarih), 'aciklama': acik.text.trim(), 'tutar': tutar.text.trim().replaceAll(',', '.'),
    }, basariMesaji: 'Personel yemeği kaydedildi.');
    if (ok) await yenile();
  }
}
