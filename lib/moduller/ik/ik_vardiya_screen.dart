import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /ik-vardiya — Vardiya Planlama (web ile aynı veri ve işlemler):
/// hafta gezinme, planlanan toplam saat + tahmini işçilik, hücreye dokun → vardiya ekle, vardiyaya dokun → düzenle/sil,
/// geçen haftayı kopyala, AI ile planla → önizleme → planı uygula. ✓ = o gün puantajda giriş var.
/// Masaüstünde haftalık tablo, telefonda gün gün liste.
class IkVardiyaScreen extends StatefulWidget {
  const IkVardiyaScreen({super.key});
  @override
  State<IkVardiyaScreen> createState() => _IkVardiyaScreenState();
}

const _gunAd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _IkVardiyaScreenState extends State<IkVardiyaScreen> {
  String? _hafta; // yyyy-mm-dd (pazartesi); null = bu hafta
  int _gunSec = (DateTime.now().weekday - 1).clamp(0, 6);
  List<Map<String, dynamic>>? _oneri; // AI önerisi (önizleme)
  bool _aiYukleniyor = false;

  DateTime _pzt(String s) => DateTime.tryParse(s) ?? DateTime.now();

  void _haftaGit(String hb, int gunFark) {
    final y = _pzt(hb).add(Duration(days: gunFark));
    setState(() {
      _hafta = _ymd(y);
      _oneri = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/ik-vardiya',
      q: _hafta == null ? null : {'hafta': _hafta!},
      baslik: 'Vardiya Planlama',
      ikon: Icons.calendar_month_outlined,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final veri = harita(v['veri']);
        final hb = metinOku(veri['hafta_basi'], _ymd(DateTime.now()));
        final gunler = [for (final g in dizi(veri['gunler'])) metinOku(g).substring(0, 10)];
        final pers = liste(veri['personeller']);
        final idx = harita(veri['idx']);
        final bugun = _ymd(DateTime.now());
        final buHafta = _ymd(DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)));
        final pz = _pzt(hb);
        final oneriIdx = <String, Map<String, dynamic>>{};
        for (final o in _oneri ?? const <Map<String, dynamic>>[]) {
          oneriIdx['${o['personel_id']}|${o['tarih']}'] = o;
        }
        List<Map<String, dynamic>> vardiyalar(dynamic pid, String gun) => liste(harita(idx['$pid'])[gun]);

        return KGovde(yenile: yenile, maxGenislik: 1400, children: [
          // hafta gezinme
          KKart(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(children: [
              IconButton(tooltip: 'Önceki hafta', onPressed: () => _haftaGit(hb, -7), icon: Icon(Icons.chevron_left, color: t.ink)),
              Expanded(
                child: Column(children: [
                  Text('${tarihYaz(hb, saat: false).substring(0, 5)} – ${tarihYaz(_ymd(pz.add(const Duration(days: 6))), saat: false)}',
                      textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  if (hb != buHafta)
                    TextButton(
                      onPressed: () => setState(() {
                        _hafta = buHafta;
                        _oneri = null;
                      }),
                      child: Text('Bu haftaya dön', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              IconButton(tooltip: 'Sonraki hafta', onPressed: () => _haftaGit(hb, 7), icon: Icon(Icons.chevron_right, color: t.ink)),
            ]),
          ),
          KKpiIzgara([
            KKpi(etiket: 'Planlanan toplam saat', deger: '${sayiYaz(veri['toplam_saat'])} sa', ikon: Icons.timer_outlined, renk: t.mavi),
            KKpi(etiket: 'Tahmini işçilik (bu hafta)', deger: tl(veri['toplam_maliyet'], kisa: true), ikon: Icons.payments_outlined, renk: t.amber,
                alt: 'Maaştan yaklaşık saatlik ücretle'),
            KKpi(etiket: 'Personel', deger: '${pers.length}', ikon: Icons.people_outline, renk: t.mor1),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Geçen haftayı kopyala', ikon: Icons.content_copy, ikincil: true, onTap: () async {
              if (!await kOnay(c, 'Geçen haftanın vardiyaları kopyalansın mı?', aciklama: 'Geçen haftanın tüm vardiyaları bu haftaya eklenir; mevcut vardiyalar korunur.', evet: 'Kopyala')) return;
              if (!c.mounted) return;
              if (await kopruGonder(c, '/ik-vardiya/kopyala', {'hafta': hb})) await yenile();
            }),
            if (_oneri == null)
              KButon('AI ile Planla', ikon: Icons.auto_awesome, renk: const Color(0xFF6D28D9), yukleniyor: _aiYukleniyor, onTap: () async {
                setState(() => _aiYukleniyor = true);
                final cv = await kopruGonderCevap(c, '/ik-vardiya/ai-planla', {'hafta': hb});
                if (!mounted) return;
                setState(() => _aiYukleniyor = false);
                if (cv == null || !cv.ok) return;
                final o = liste(cv.veri['oneri']);
                if (o.isEmpty) {
                  if (c.mounted) kToast(c, 'AI bu hafta için yeni vardiya önermedi (herkes planlı ya da izinli olabilir).', hata: true);
                  return;
                }
                setState(() => _oneri = o);
              }),
          ]),
          const SizedBox(height: 12),
          if (_oneri != null)
            KKart(
              renk: t.mor1,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.auto_awesome, color: t.mor1),
                  const SizedBox(width: 8),
                  Expanded(child: Text('AI ${_oneri!.length} vardiya önerdi', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text('İzinli günler atlandı, herkese 1 gün izin günü verildi, hafta sonu tam kadro. Mevcut vardiyalarınız korunur. '
                    'Tabloda ✨ işaretli olanlar önerilerdir — onaylarsanız eklenir.', style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  KButon('Planı Uygula', ikon: Icons.check, renk: t.yesil, onTap: () async {
                    if (!await kOnay(c, 'AI planı uygulansın mı?', aciklama: '${_oneri!.length} vardiya eklenecek (mevcutlar korunur).', evet: 'Evet, uygula')) return;
                    if (!c.mounted) return;
                    if (await kopruGonder(c, '/ik-vardiya/ai-uygula', {'hafta': hb, 'oneri': jsonEncode(_oneri)})) {
                      setState(() => _oneri = null);
                      await yenile();
                    }
                  }),
                  KButon('Vazgeç', ikincil: true, renk: t.sub, onTap: () => setState(() => _oneri = null)),
                ]),
              ]),
            ),
          if (pers.isEmpty)
            const KBos(
              ikon: Icons.people_outline,
              baslik: 'Aktif personel yok',
              aciklama: 'Vardiya planlamak için önce Personel & Maaş ekranından personel ekleyin.',
            )
          else if (genisMi(c))
            _tablo(c, pers, gunler, bugun, vardiyalar, oneriIdx, hb, yenile)
          else
            ..._gunluk(c, pers, gunler, bugun, vardiyalar, oneriIdx, hb, yenile),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Bir hücreye dokunun → vardiya ekleyin. Vardiyaya dokunun → düzenleyin/silin. ✓ işareti o gün puantajda giriş yapıldığını gösterir.',
                style: TextStyle(color: t.sub, fontSize: 12.5)),
          ),
        ]);
      },
    );
  }

  Widget _cip(BuildContext c, Map<String, dynamic> v, VoidCallback onTap) {
    final t = c.watch<TemaProvider>();
    final ger = v['gercek'] == true || v['gercek'] == 1;
    final r = ger ? t.yesil : t.mor1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: r.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: r.withValues(alpha: .4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${ger ? '✓ ' : ''}${metinOku(v['bas'])}–${metinOku(v['bit'])}', style: TextStyle(color: r, fontSize: 12.5, fontWeight: FontWeight.w700)),
              if (metinOku(v['pozisyon']).isNotEmpty) Text(metinOku(v['pozisyon']), style: TextStyle(color: t.sub, fontSize: 11)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _oneriCip(BuildContext c, Map<String, dynamic> o) {
    final t = c.watch<TemaProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: t.yesil.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.yesil.withValues(alpha: .55), style: BorderStyle.solid),
      ),
      child: Text('✨ ${metinOku(o['bas'])}–${metinOku(o['bit'])}', style: TextStyle(color: t.yesil, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _tablo(BuildContext c, List<Map<String, dynamic>> pers, List<String> gunler, String bugun,
      List<Map<String, dynamic>> Function(dynamic, String) vardiyalar, Map<String, Map<String, dynamic>> oneriIdx, String hb, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    return KKart(
      padding: const EdgeInsets.all(8),
      child: Table(
        columnWidths: const {0: FixedColumnWidth(150)},
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        border: TableBorder(horizontalInside: BorderSide(color: t.line.withValues(alpha: .7)), verticalInside: BorderSide(color: t.line.withValues(alpha: .4))),
        children: [
          TableRow(children: [
            Padding(padding: const EdgeInsets.all(8), child: Text('Personel', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w700))),
            for (var i = 0; i < gunler.length; i++)
              Container(
                color: gunler[i] == bugun ? t.mor1.withValues(alpha: .08) : null,
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Text(_gunAd[i % 7], style: TextStyle(color: gunler[i] == bugun ? t.mor1 : t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text(tarihYaz(gunler[i], saat: false).substring(0, 5), style: TextStyle(color: t.sub, fontSize: 11.5)),
                ]),
              ),
          ]),
          for (final p in pers)
            TableRow(children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(p['ad']), style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text(metinOku(p['rol']), style: TextStyle(color: t.sub, fontSize: 11.5)),
                ]),
              ),
              for (final g in gunler)
                InkWell(
                  onTap: () => _form(c, p, g, null, hb, yenile),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    color: g == bugun ? t.mor1.withValues(alpha: .05) : null,
                    padding: const EdgeInsets.all(5),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final v in vardiyalar(p['id'], g)) _cip(c, v, () => _form(c, p, g, v, hb, yenile)),
                      if (oneriIdx['${p['id']}|$g'] != null) _oneriCip(c, oneriIdx['${p['id']}|$g']!),
                      if (vardiyalar(p['id'], g).isEmpty && oneriIdx['${p['id']}|$g'] == null)
                        Center(child: Padding(padding: const EdgeInsets.only(top: 12), child: Icon(Icons.add, size: 16, color: t.line))),
                    ]),
                  ),
                ),
            ]),
        ],
      ),
    );
  }

  List<Widget> _gunluk(BuildContext c, List<Map<String, dynamic>> pers, List<String> gunler, String bugun,
      List<Map<String, dynamic>> Function(dynamic, String) vardiyalar, Map<String, Map<String, dynamic>> oneriIdx, String hb, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    if (gunler.isEmpty) return const [];
    final si = _gunSec.clamp(0, gunler.length - 1);
    final g = gunler[si];
    return [
      KCipler(
        secenekler: [for (var i = 0; i < gunler.length; i++) ('$i', '${_gunAd[i % 7]} ${tarihYaz(gunler[i], saat: false).substring(0, 5)}${gunler[i] == bugun ? ' •' : ''}')],
        secili: '$si',
        onSec: (k) => setState(() => _gunSec = int.parse(k)),
      ),
      KKart(
        child: Column(children: [
          for (final p in pers)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.line.withValues(alpha: .7)))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 110,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(metinOku(p['ad']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(metinOku(p['rol']), style: TextStyle(color: t.sub, fontSize: 11.5)),
                  ]),
                ),
                Expanded(
                  child: Wrap(spacing: 6, runSpacing: 2, children: [
                    for (final v in vardiyalar(p['id'], g)) _cip(c, v, () => _form(c, p, g, v, hb, yenile)),
                    if (oneriIdx['${p['id']}|$g'] != null) _oneriCip(c, oneriIdx['${p['id']}|$g']!),
                  ]),
                ),
                IconButton(
                  tooltip: 'Vardiya ekle',
                  onPressed: () => _form(c, p, g, null, hb, yenile),
                  icon: Icon(Icons.add_circle_outline, color: t.mor1),
                ),
              ]),
            ),
        ]),
      ),
    ];
  }

  Future<void> _form(BuildContext c, Map<String, dynamic> p, String tarih, Map<String, dynamic>? v, String hb, Future<void> Function() yenile) async {
    String bas = v == null ? '09:00' : metinOku(v['bas'], '09:00');
    String bit = v == null ? '17:00' : metinOku(v['bit'], '17:00');
    final poz = TextEditingController(text: v == null ? '' : metinOku(v['pozisyon']));
    final not = TextEditingController(text: v == null ? '' : metinOku(v['not']));
    TimeOfDay saatOku(String s) {
      final pr = s.split(':');
      return TimeOfDay(hour: int.tryParse(pr[0]) ?? 9, minute: pr.length > 1 ? (int.tryParse(pr[1]) ?? 0) : 0);
    }

    String saatYaz(TimeOfDay d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    await kAltSayfa(c, baslik: v == null ? 'Vardiya Ekle' : 'Vardiyayı Düzenle', icerik: (cc) => StatefulBuilder(builder: (cc, ss) {
          final t = cc.watch<TemaProvider>();
          Widget saatSec(String et, String deger, ValueChanged<String> sec) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(et, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: t.line)),
                      onPressed: () async {
                        final s = await showTimePicker(context: cc, initialTime: saatOku(deger));
                        if (s != null) ss(() => sec(saatYaz(s)));
                      },
                      icon: Icon(Icons.schedule, size: 18, color: t.mor1),
                      label: Text(deger, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              );
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('${metinOku(p['ad'])} · ${tarihYaz(tarih, saat: false)}', style: TextStyle(color: t.sub2, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Row(children: [
              saatSec('Başlangıç', bas, (s) => bas = s),
              const SizedBox(width: 10),
              saatSec('Bitiş', bit, (s) => bit = s),
            ]),
            KAlan('Pozisyon (opsiyonel)', poz, ipucu: 'garson / mutfak / kasa ...'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final o in const ['Garson', 'Mutfak', 'Kasa', 'Bar', 'Komi', 'Bulaşık', 'Host'])
                  ActionChip(
                    label: Text(o, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    backgroundColor: t.card2,
                    side: BorderSide(color: t.line),
                    onPressed: () => ss(() => poz.text = o),
                  ),
              ]),
            ),
            KAlan('Not (opsiyonel)', not, ipucu: 'ör. açılış / kapanış'),
            Row(children: [
              if (v != null) ...[
                KButon('Sil', ikon: Icons.delete_outline, renk: t.kirmizi, ikincil: true, onTap: () async {
                  if (!await kOnay(cc, 'Bu vardiya silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                  if (!cc.mounted) return;
                  if (await kopruGonder(cc, '/ik-vardiya/sil', {'id': v['id'], 'hafta': hb})) {
                    if (cc.mounted) Navigator.pop(cc);
                    await yenile();
                  }
                }),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () async {
                  final ok = await kopruGonder(cc, '/ik-vardiya/kaydet', {
                    'hafta': hb,
                    if (v != null) 'id': v['id'],
                    'personel_id': p['id'],
                    'tarih': tarih,
                    'baslangic': bas,
                    'bitis': bit,
                    'pozisyon': poz.text.trim(),
                    'not': not.text.trim(),
                  });
                  if (ok) {
                    if (cc.mounted) Navigator.pop(cc);
                    await yenile();
                  }
                }),
              ),
            ]),
          ]);
        }));
  }
}
