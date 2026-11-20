import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /mutfak-defteri — Kontrol Defteri: Sıcaklık (HACCP) · Fire/İsraf · Açılış/Kapanış · Prep/Par.
/// Ekle (sekmeye göre alanlar), sil, örnek kayıt yükle/sil — web formlarının aynısı.
class MutfakDefteriScreen extends StatefulWidget {
  const MutfakDefteriScreen({super.key});

  @override
  State<MutfakDefteriScreen> createState() => _MutfakDefteriScreenState();
}

class _Cfg {
  final String ad, baslikLbl, baslikPh, degerLbl, deger2Lbl, ipucu;
  final List<String> kategoriler;
  final bool birim;
  final IconData ikon;
  final Color renk;
  const _Cfg(this.ad, this.ikon, this.renk, this.baslikLbl, this.baslikPh, this.kategoriler, this.degerLbl, this.deger2Lbl, this.birim, this.ipucu);
}

const Map<String, _Cfg> _cfg = {
  'sicaklik': _Cfg('Sıcaklık (HACCP)', Icons.thermostat, Color(0xFF0EA5E9), 'Nokta / Cihaz', 'Örn: Buzdolabı 1 · Et dolabı · Bain-marie',
      ['Buzdolabı', 'Dondurucu', 'Sıcak bekletme', 'Pişirme', 'Soğutma', 'Teslim alma'], 'Ölçülen °C', 'Üst limit °C', false,
      'Soğuk zincirde ölçülen ≤ üst limit, sıcak bekletme ve pişirmede ölçülen ≥ alt limit ise UYGUN sayılır. Limitler Türk Gıda Kodeksi / HACCP planına göre.'),
  'fire': _Cfg('Fire / İsraf', Icons.delete_outline, Color(0xFFF97316), 'Ürün / Malzeme', 'Örn: Domates · Pişmiş pilav · Tavuk but',
      ['Hazırlık fire', 'Bozulma / SKT', 'Tabak / porsiyon', 'Pişirme hatası'], 'Miktar', 'Tutar (₺)', true,
      'Atılan her şeyi kategorisi ve TL değeriyle yaz. Haftalık bak: en çok nerede israf var, porsiyonu/siparişi ona göre ayarla.'),
  'checklist': _Cfg('Açılış / Kapanış', Icons.checklist, Color(0xFF10B981), 'Kontrol maddesi', 'Örn: Fırın açıldı · Soğuk oda temiz · Gaz kapatıldı',
      ['Açılış', 'Servis öncesi', 'Kapanış'], '', '', false,
      'Açılış ve kapanış kontrollerini tek tek işaretle. Net madde yaz: "istasyon hazır" değil, "ızgara 180°C ve mise en place tam".'),
  'prep': _Cfg('Prep / Par', Icons.restaurant_menu, Color(0xFF8B5CF6), 'Ürün / Yarı mamül', 'Örn: Köfte harcı · Sos · Doğranmış soğan', [], 'Par (hedef)', 'Mevcut', true,
      'Günün beklenen yoğunluğuna göre PAR (hedef) ve mevcut miktarı yaz. Hazırlanacak miktar = Par − Mevcut otomatik hesaplanır.'),
};

const Map<String, double> _limit = {'Buzdolabı': 4, 'Dondurucu': -18, 'Sıcak bekletme': 63, 'Pişirme': 75, 'Soğutma': 5, 'Teslim alma': 4};
const Set<String> _sicak = {'Sıcak bekletme', 'Pişirme'};

class _MutfakDefteriScreenState extends State<MutfakDefteriScreen> {
  final _k = GlobalKey<KopruEkranState>();

  Future<void> _ekle(String tip) async {
    final c = _cfg[tip]!;
    final baslik = TextEditingController(), deger = TextEditingController(), deger2 = TextEditingController(), birim = TextEditingController();
    String? kat = c.kategoriler.isEmpty ? null : c.kategoriler.first;
    String tarih = stBugun();
    bool elleLimit = false;
    if (tip == 'sicaklik' && kat != null) deger2.text = sayiYaz(_limit[kat]);
    final ok = await kAltSayfa<bool>(context, baslik: '${c.ad} · Yeni kayıt', icerik: (ctx) => StatefulBuilder(builder: (ctx, ss) {
          final t = ctx.read<TemaProvider>();
          final a = double.tryParse(deger.text.replaceAll(',', '.'));
          final b = double.tryParse(deger2.text.replaceAll(',', '.'));
          Widget? onizle;
          if (a != null && b != null) {
            if (tip == 'sicaklik') {
              final uygun = _sicak.contains(kat) ? a >= b : a <= b;
              onizle = KRozet(uygun ? 'UYGUN olarak kaydedilecek' : 'UYGUNSUZ — düzeltici işlem yap', renk: uygun ? t.yesil : t.kirmizi,
                  ikon: uygun ? Icons.check_circle_outline : Icons.warning_amber_outlined);
            } else if (tip == 'prep') {
              final h = a - b > 0 ? a - b : 0;
              onizle = KRozet(h > 0 ? 'Hazırlanacak: ${sayiYaz(h)}' : 'Par tamam, hazırlık gerekmez', renk: h > 0 ? t.mavi : t.yesil);
            }
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.ipucu, style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35)),
            const SizedBox(height: 10),
            if (c.kategoriler.isNotEmpty) ...[
              Text('Kategori', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              KCipler(
                secenekler: [for (final k in c.kategoriler) (k, k)],
                secili: kat ?? '',
                onSec: (s) => ss(() {
                  kat = s;
                  if (tip == 'sicaklik' && !elleLimit && _limit.containsKey(s)) deger2.text = sayiYaz(_limit[s]);
                }),
              ),
              const SizedBox(height: 8),
            ],
            KAlan(c.baslikLbl, baslik, ipucu: c.baslikPh, zorunlu: true),
            if (c.degerLbl.isNotEmpty || c.deger2Lbl.isNotEmpty)
              Row(children: [
                if (c.degerLbl.isNotEmpty)
                  Expanded(child: _sayiAlan(c.degerLbl, deger, tip == 'fire', () => ss(() {}))),
                if (c.birim) ...[const SizedBox(width: 8), Expanded(child: KAlan('Birim', birim, ipucu: 'kg / adet / L'))],
                if (c.deger2Lbl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _sayiAlan(tip == 'sicaklik' ? (_sicak.contains(kat) ? 'Alt limit °C' : 'Üst limit °C') : c.deger2Lbl, deger2, false, () => ss(() => elleLimit = true)),
                  ),
                ],
              ]),
            StTarihAlan('Tarih', deger: tarih, onSec: (s) => ss(() => tarih = s ?? tarih)),
            if (onizle != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Align(alignment: Alignment.centerLeft, child: onizle)),
            KButon('Ekle', ikon: Icons.add_circle_outline, genis: true, onTap: () async {
              if (baslik.text.trim().isEmpty) {
                kToast(ctx, '${c.baslikLbl} zorunlu.', hata: true);
                return;
              }
              final r = await stGonder(ctx, '/mutfak-defteri/ekle', {
                'tip': tip, 'kategori': kat ?? '', 'baslik': baslik.text.trim(), 'deger': deger.text.trim().replaceAll(',', '.'),
                'deger2': deger2.text.trim().replaceAll(',', '.'), 'birim': birim.text.trim(), 'tarih': tarih,
              }, basari: 'Kayıt eklendi.');
              if (r.ok && ctx.mounted) Navigator.pop(ctx, true);
            }),
          ]);
        }));
    if (ok == true) _k.currentState?.yukle();
  }

  Widget _sayiAlan(String etiket, TextEditingController k, bool metin, VoidCallback degisti) {
    return Builder(builder: (c) {
      final t = c.read<TemaProvider>();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: k,
            onChanged: (_) => degisti(),
            keyboardType: metin ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true, signed: true),
            style: TextStyle(color: t.ink, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: t.card2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            ),
          ),
        ]),
      );
    });
  }

  Future<void> _sil(Map<String, dynamic> k, String tip) async {
    if (!await kOnay(context, 'Kayıt silinsin mi?', aciklama: '${k['baslik']}', evet: 'Sil', tehlikeli: true)) return;
    if (!mounted) return;
    final r = await stGonder(context, '/mutfak-defteri/sil', {'id': k['id'], 'tip': tip}, basari: 'Silindi.');
    if (r.ok) _k.currentState?.yukle();
  }

  Future<void> _ornek(String tip, bool sil) async {
    if (!await kOnay(context, sil ? 'Örnek kayıtlar silinsin mi?' : 'Örnek kayıtlar yüklensin mi?',
        aciklama: sil ? 'Yalnız "Örnek kayıt" notlu kayıtlar silinir; sizin girdikleriniz kalır.' : 'Defteri denemek için 4 sekmeye örnek kayıtlar eklenir; sonra tek tuşla silebilirsiniz.')) {
      return;
    }
    if (!mounted) return;
    final r = await stGonder(context, '/mutfak-defteri/ornek', {'tip': tip, if (sil) 'islem': 'sil'}, basari: sil ? 'Örnek kayıtlar silindi.' : 'Örnek kayıtlar yüklendi.');
    if (r.ok) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/mutfak-defteri',
      baslik: 'Kontrol Defteri',
      ikon: Icons.menu_book_outlined,
      fab: (ctx, v, y) {
        final tip = metinOku(v['tip'], 'sicaklik');
        return FloatingActionButton.extended(
          heroTag: 'mdFab',
          backgroundColor: _cfg[tip]?.renk,
          onPressed: () => _ekle(tip),
          icon: const Icon(Icons.add),
          label: const Text('Kayıt Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
        );
      },
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final tip = metinOku(v['tip'], 'sicaklik');
    final c = _cfg[tip] ?? _cfg['sicaklik']!;
    final kayitlar = liste(v['liste']);
    final sayilar = harita(v['sayilar']);
    final bugun = stBugun();
    final bugunk = kayitlar.where((k) => metinOku(k['tarih']).startsWith(bugun)).toList();
    // tarihe göre grupla
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final k in kayitlar) {
      (gruplar[metinOku(k['tarih']).split(' ').first] ??= []).add(k);
    }
    return KGovde(yenile: yenile, children: [
      KCipler(
        secenekler: [
          for (final e in _cfg.entries) (e.key, '${e.value.ad}${tamOku(sayilar[e.key]) > 0 ? ' · ${tamOku(sayilar[e.key])}' : ''}'),
        ],
        secili: tip,
        onSec: (s) => _k.currentState?.sorgu({'tip': s}),
      ),
      const SizedBox(height: 8),
      _ozet(t, tip, bugunk),
      KKart(
        renk: c.renk,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.lightbulb_outline, color: c.renk, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(c.ipucu, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4))),
        ]),
      ),
      if (kayitlar.isEmpty)
        KBos(
          baslik: '${c.ad} defteri boş',
          ikon: c.ikon,
          aciklama: 'Henüz kayıt yok. Sağ alttaki "Kayıt Ekle" ile ilk kaydı girin ya da örnek kayıtlarla deneyin.',
          aksiyon: KButon('Örnek kayıt yükle', ikon: Icons.auto_awesome, ikincil: true, onTap: () => _ornek(tip, false)),
        )
      else
        for (final g in gruplar.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text('${g.key == bugun ? 'Bugün' : tarihYaz(g.key, saat: false)} · ${g.value.length} kayıt', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          for (final k in g.value) _kayit(context, tip, k),
        ],
      if (v['ornekVar'] == true)
        Center(
          child: TextButton.icon(
            onPressed: () => _ornek(tip, true),
            icon: Icon(Icons.delete_sweep_outlined, color: t.kirmizi),
            label: Text('Örnek kayıtları sil', style: TextStyle(color: t.kirmizi, fontWeight: FontWeight.w700)),
          ),
        ),
    ]);
  }

  Widget _ozet(TemaProvider t, String tip, List<Map<String, dynamic>> bugunk) {
    switch (tip) {
      case 'sicaklik':
        final uygunsuz = bugunk.where((k) => k['sonuc'] == 'uygunsuz').length;
        return KKpiIzgara([
          KKpi(etiket: 'Bugün ölçüm', deger: '${bugunk.length}', ikon: Icons.thermostat, renk: t.mavi),
          KKpi(etiket: 'Uygunsuz', deger: '$uygunsuz', ikon: Icons.warning_amber_outlined, renk: uygunsuz > 0 ? t.kirmizi : t.yesil),
        ]);
      case 'fire':
        final tutar = bugunk.fold<double>(0, (s, k) => s + sayiOku(k['deger2']));
        return KKpiIzgara([
          KKpi(etiket: 'Bugün fire kaydı', deger: '${bugunk.length}', ikon: Icons.delete_outline, renk: t.amber),
          KKpi(etiket: 'Bugün israf (₺)', deger: tl(tutar, kisa: true), ikon: Icons.payments_outlined, renk: t.kirmizi),
        ]);
      case 'checklist':
        int say(String k) => bugunk.where((x) => x['kategori'] == k).length;
        return KKpiIzgara([
          KKpi(etiket: 'Açılış', deger: '${say('Açılış')}', ikon: Icons.wb_sunny_outlined, renk: t.amber),
          KKpi(etiket: 'Servis öncesi', deger: '${say('Servis öncesi')}', ikon: Icons.room_service_outlined, renk: t.mavi),
          KKpi(etiket: 'Kapanış', deger: '${say('Kapanış')}', ikon: Icons.nightlight_outlined, renk: t.mor1),
        ]);
      default:
        final hazir = bugunk.where((k) => sayiOku(k['deger']) - sayiOku(k['deger2']) > 0).length;
        return KKpiIzgara([
          KKpi(etiket: 'Bugün prep kalemi', deger: '${bugunk.length}', ikon: Icons.restaurant_menu, renk: t.mor1),
          KKpi(etiket: 'Hazırlanacak', deger: '$hazir', ikon: Icons.soup_kitchen_outlined, renk: hazir > 0 ? t.amber : t.yesil),
        ]);
    }
  }

  Widget _kayit(BuildContext context, String tip, Map<String, dynamic> k) {
    final t = context.read<TemaProvider>();
    final sonuc = metinOku(k['sonuc']);
    String detay = '';
    Color? renk;
    if (tip == 'sicaklik') {
      final sicak = _sicak.contains(k['kategori']);
      detay = '${metinOku(k['deger'], '—')} °C · ${sicak ? 'alt' : 'üst'} limit ${metinOku(k['deger2'], '—')} °C';
      renk = sonuc.isEmpty ? null : stDurumRenk(t, sonuc);
    } else if (tip == 'fire') {
      detay = '${metinOku(k['deger'], '—')} ${metinOku(k['birim'])}${metinOku(k['deger2']).isNotEmpty ? ' · ${tl(k['deger2'])}' : ''}';
      renk = t.amber;
    } else if (tip == 'prep') {
      final h = sayiOku(k['deger']) - sayiOku(k['deger2']);
      detay = 'Par ${metinOku(k['deger'], '—')} · Mevcut ${metinOku(k['deger2'], '—')} ${metinOku(k['birim'])} · ${h > 0 ? 'Hazırlanacak ${sayiYaz(h)}' : 'Tamam'}';
      renk = h > 0 ? t.mavi : t.yesil;
    } else {
      renk = t.yesil;
    }
    return KKart(
      renk: renk,
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text('${k['baslik']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold))),
              if (metinOku(k['kategori']).isNotEmpty) ...[const SizedBox(width: 6), KRozet('${k['kategori']}', renk: t.sub)],
            ]),
            if (detay.isNotEmpty) Text(detay, style: TextStyle(color: t.sub2, fontSize: 12.5)),
            Text([
              if (metinOku(k['personel_ad']).isNotEmpty) '${k['personel_ad']}',
              if (metinOku(k['created_at']).length > 15) metinOku(k['created_at']).substring(11, 16),
              if (metinOku(k['not']).isNotEmpty) '${k['not']}',
            ].join(' · '), style: TextStyle(color: t.sub, fontSize: 11.5)),
          ]),
        ),
        if (sonuc.isNotEmpty)
          KRozet(const {'uygun': 'Uygun', 'uygunsuz': 'Uygunsuz', 'yapildi': 'Yapıldı'}[sonuc] ?? sonuc, renk: stDurumRenk(t, sonuc)),
        IconButton(tooltip: 'Sil', onPressed: () => _sil(k, tip), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
      ]),
    );
  }
}
