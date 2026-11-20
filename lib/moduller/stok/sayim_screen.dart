import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /sayim — fiziksel sayım: takipli malzemeler + sistem (teorik) stoğu; sayılanı gir → fark + TL kayıp,
/// kaydedince defter fiili sayıma eşitlenir. Son sayımlar + detay (kalem bazında fark + AI yorum).
class SayimScreen extends StatefulWidget {
  const SayimScreen({super.key});

  @override
  State<SayimScreen> createState() => _SayimScreenState();
}

class _SayimScreenState extends State<SayimScreen> {
  final _k = GlobalKey<KopruEkranState>();
  final Map<int, TextEditingController> _giris = {};
  String _ara = '';
  String _kat = '__tum__';
  bool _sadeceBekleyen = false;
  bool _gonderiliyor = false;
  Map<String, dynamic>? _sonuc;

  @override
  void dispose() {
    for (final c in _giris.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _kontrol(int id) => _giris.putIfAbsent(id, () => TextEditingController());

  double? _sayilan(int id) {
    final s = _giris[id]?.text.trim() ?? '';
    if (s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  Future<void> _kaydet(List<Map<String, dynamic>> malzemeler) async {
    final sayilan = <String, String>{};
    int eksik = 0, fazla = 0;
    double fm = 0;
    for (final m in malzemeler) {
      final id = tamOku(m['malzeme_id']);
      final v = _sayilan(id);
      if (v == null) continue;
      sayilan['$id'] = '$v';
      final fark = v - sayiOku(m['teorik']);
      if (fark < -0.0001) eksik++;
      if (fark > 0.0001) fazla++;
      fm += fark * sayiOku(m['guncel_maliyet']);
    }
    if (sayilan.isEmpty) {
      kToast(context, 'Hiç sayım girilmemiş.', hata: true);
      return;
    }
    final onay = await kOnay(context, 'Sayım kaydedilsin mi?',
        aciklama: '${sayilan.length} kalem sayıldı · $eksik eksik · $fazla fazla.\nKaydedince sistem stoğu sayılan miktara eşitlenir (fark, sayım düzeltmesi olarak yazılır).',
        evet: 'Kaydet');
    if (!onay || !mounted) return;
    setState(() => _gonderiliyor = true);
    final r = await stGonder(context, '/sayim/kaydet', {'sayilan': sayilan}, basari: 'Sayım kaydedildi');
    if (!mounted) return;
    setState(() {
      _gonderiliyor = false;
      if (r.ok) {
        _sonuc = {'kalem': sayilan.length, 'eksik': eksik, 'fazla': fazla, 'fm': fm};
        for (final c in _giris.values) {
          c.clear();
        }
      }
    });
    if (r.ok) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/sayim',
      baslik: 'Stok Sayımı',
      ikon: Icons.fact_check_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Sayım geçmişi', icon: const Icon(Icons.history), onPressed: () => stAc(ctx, '/sayim/gecmis', 'Sayım Geçmişi')),
      ],
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final malzemeler = liste(v['malzemeler']);
    final sonSayimlar = liste(v['sonSayimlar']);
    final katlar = <String>{for (final m in malzemeler) metinOku(m['kategori'], '—')}.toList()..sort();
    final q = _ara.toLowerCase();
    final gorunen = malzemeler.where((m) {
      if (q.isNotEmpty && !'${m['ad']}'.toLowerCase().contains(q)) return false;
      if (_kat != '__tum__' && metinOku(m['kategori'], '—') != _kat) return false;
      if (_sadeceBekleyen && _sayilan(tamOku(m['malzeme_id'])) != null) return false;
      return true;
    }).toList();
    // canlı özet
    int sayilanN = 0, eksik = 0, fazla = 0;
    double fm = 0;
    for (final m in malzemeler) {
      final s = _sayilan(tamOku(m['malzeme_id']));
      if (s == null) continue;
      sayilanN++;
      final f = s - sayiOku(m['teorik']);
      if (f < -0.0001) eksik++;
      if (f > 0.0001) fazla++;
      fm += f * sayiOku(m['guncel_maliyet']);
    }
    final genis = genisMi(context);
    return KGovde(yenile: yenile, children: [
      if (_sonuc != null) _sonucKart(t),
      KKpiIzgara([
        KKpi(etiket: 'Sayılacak kalem', deger: '${malzemeler.length}', ikon: Icons.inventory_2_outlined, renk: t.mavi),
        KKpi(etiket: 'Sayılan', deger: '$sayilanN', ikon: Icons.check_circle_outline, renk: t.yesil),
        KKpi(etiket: 'Eksik / Fazla', deger: '$eksik / $fazla', ikon: Icons.compare_arrows, renk: t.amber),
        KKpi(etiket: 'Fark (TL)', deger: '${fm < 0 ? '−' : (fm > 0 ? '+' : '')}${tl(fm.abs(), kisa: true)}', ikon: Icons.payments_outlined, renk: fm < 0 ? t.kirmizi : (fm > 0 ? t.amber : t.yesil)),
      ]),
      if (sonSayimlar.isNotEmpty) ...[
        const SizedBox(height: 6),
        KBaslik('Son sayımlar', ikon: Icons.history, sag: TextButton(onPressed: () => stAc(context, '/sayim/gecmis', 'Sayım Geçmişi'), child: const Text('Tümü'))),
        SizedBox(
          height: 74,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in sonSayimlar)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(width: 190, child: _sayimMini(context, s)),
              ),
          ]),
        ),
        const SizedBox(height: 10),
      ],
      KAra(ipucu: 'Malzeme ara', onDegis: (s) => setState(() => _ara = s)),
      const SizedBox(height: 8),
      if (katlar.length > 1)
        KCipler(
          secenekler: [('__tum__', 'Tümü'), for (final k in katlar) (k, k)],
          secili: _kat,
          onSec: (s) => setState(() => _kat = s),
        ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _sadeceBekleyen,
        onChanged: (b) => setState(() => _sadeceBekleyen = b),
        title: Text('Yalnız sayılmayanları göster', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      if (malzemeler.isEmpty)
        const KBos(
          baslik: 'Sayılacak malzeme yok',
          ikon: Icons.inventory_2_outlined,
          aciklama: 'Sayım yalnız "stok takipli" malzemeleri listeler. Stok / Malzeme ekranından malzeme kartı açın ya da takibi açın.',
        )
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtrede malzeme yok', ikon: Icons.filter_alt_off_outlined, aciklama: 'Aramayı ya da kategori seçimini değiştirin.')
      else if (genis)
        LayoutBuilder(builder: (c, s) {
          final w = (s.maxWidth - 12) / 2;
          return Wrap(spacing: 12, children: [for (final m in gorunen) SizedBox(width: w, child: _satir(context, m))]);
        })
      else
        for (final m in gorunen) _satir(context, m),
      const SizedBox(height: 8),
      KButon(_gonderiliyor ? 'Kaydediliyor…' : 'Sayımı Kaydet ($sayilanN kalem)', ikon: Icons.save_outlined, genis: true, yukleniyor: _gonderiliyor,
          onTap: _gonderiliyor || sayilanN == 0 ? null : () => _kaydet(malzemeler)),
    ]);
  }

  Widget _sonucKart(TemaProvider t) {
    final fm = sayiOku(_sonuc!['fm']);
    final renk = fm < 0 ? t.kirmizi : (fm > 0 ? t.amber : t.yesil);
    return KKart(
      renk: renk,
      child: Row(children: [
        KIkon(Icons.task_alt, renk: renk),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sayım kaydedildi', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            Text('${_sonuc!['kalem']} kalem sayıldı · ${_sonuc!['eksik']} eksik · ${_sonuc!['fazla']} fazla', style: TextStyle(color: t.sub, fontSize: 12.5)),
            Text(fm < 0 ? 'Toplam açık: ${tl(fm.abs())} (kayıp)' : (fm > 0 ? 'Toplam fazla: ${tl(fm)}' : 'Fark yok — tertemiz.'),
                style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ),
        IconButton(onPressed: () => setState(() => _sonuc = null), icon: Icon(Icons.close, color: t.sub)),
      ]),
    );
  }

  Widget _sayimMini(BuildContext context, Map<String, dynamic> s) {
    final t = context.read<TemaProvider>();
    final fm = sayiOku(s['fark_maliyet']);
    return KKart(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(10),
      onTap: () => sayimDetayAc(context, tamOku(s['id'])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s['tarih']} · ${s['kalem']} kalem', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(fm < 0 ? '−${tl(fm.abs(), kisa: true)} açık' : (fm > 0 ? '+${tl(fm, kisa: true)} fazla' : 'Fark yok'),
            style: TextStyle(color: fm < 0 ? t.kirmizi : (fm > 0 ? t.amber : t.yesil), fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _satir(BuildContext context, Map<String, dynamic> m) {
    final t = context.read<TemaProvider>();
    final id = tamOku(m['malzeme_id']);
    final k = _kontrol(id);
    final s = _sayilan(id);
    final fark = s == null ? null : s - sayiOku(m['teorik']);
    final renk = fark == null ? t.sub : (fark < -0.0001 ? t.kirmizi : (fark > 0.0001 ? t.amber : t.yesil));
    void adim(double d) {
      final yeni = ((s ?? sayiOku(m['teorik'])) + d);
      k.text = mik(yeni < 0 ? 0 : yeni).replaceAll('.', '');
      setState(() {});
    }

    return KKart(
      renk: fark == null ? null : renk,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${m['ad']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('${metinOku(m['kategori'], '—')} · Sistem: ${mik(m['teorik'])} ${m['birim']}', style: TextStyle(color: t.sub, fontSize: 12)),
            if (fark != null)
              Text(
                fark.abs() < 0.0001
                    ? 'Fark yok'
                    : 'Fark ${fark > 0 ? '+' : ''}${mik(fark)} ${m['birim']} · ${fark < 0 ? '−' : '+'}${tl((fark * sayiOku(m['guncel_maliyet'])).abs(), kisa: true)}',
                style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
          ]),
        ),
        IconButton(onPressed: () => adim(-1), icon: Icon(Icons.remove_circle_outline, color: t.sub2), tooltip: 'Azalt'),
        SizedBox(
          width: 78,
          child: TextField(
            controller: k,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: '—',
              isDense: true,
              filled: true,
              fillColor: t.card2,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            ),
          ),
        ),
        IconButton(onPressed: () => adim(1), icon: Icon(Icons.add_circle_outline, color: t.sub2), tooltip: 'Artır'),
      ]),
    );
  }
}

/// Sayım detayı (kalem bazında fark + AI yorum) — web'deki modalın aynısı (/api/patron/sayim-detay)
Future<void> sayimDetayAc(BuildContext context, int id) {
  return kAltSayfa(context, baslik: 'Sayım Detayı', icerik: (c) => _SayimDetay(id: id));
}

class _SayimDetay extends StatefulWidget {
  final int id;
  const _SayimDetay({required this.id});

  @override
  State<_SayimDetay> createState() => _SayimDetayState();
}

class _SayimDetayState extends State<_SayimDetay> {
  Map<String, dynamic>? _d;
  String? _hata;

  @override
  void initState() {
    super.initState();
    stAl(context, '/api/patron/sayim-detay', q: {'id': '${widget.id}'}).then((c) {
      if (!mounted) return;
      setState(() {
        if (c.ok) {
          _d = c.veri;
        } else {
          _hata = c.yetkisiz ? 'Sayım detayını işletme sahibi ve müdür görebilir.' : (c.hata ?? 'Sayım bulunamadı.');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (_hata != null) return KBos(baslik: 'Detay gösterilemiyor', aciklama: _hata, ikon: Icons.lock_outline);
    final d = _d;
    if (d == null) return const Padding(padding: EdgeInsets.all(24), child: KYukleniyor());
    final fm = sayiOku(d['toplam_fark_maliyet']);
    final renk = fm < 0 ? t.kirmizi : (fm > 0 ? t.amber : t.yesil);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sayım — ${d['tarih']}', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      KKpi(etiket: fm < 0 ? 'Toplam Açık (Kayıp)' : (fm > 0 ? 'Toplam Fazla' : 'Fark Yok'), deger: fm == 0 ? 'Tertemiz' : tl(fm.abs()), ikon: Icons.balance, renk: renk),
      const SizedBox(height: 10),
      for (final a in liste(d['ai']))
        KKart(
          renk: a['seviye'] == 'riskli' ? t.kirmizi : (a['seviye'] == 'uyari' ? t.amber : (a['seviye'] == 'iyi' ? t.yesil : t.mavi)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.auto_awesome, color: t.mor1, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text('${a['mesaj']}', style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.4))),
          ]),
        ),
      KBaslik('Kalem bazında fark', ikon: Icons.list_alt),
      if (liste(d['kalemler']).isEmpty)
        const KBos(baslik: 'Kalem yok', aciklama: 'Bu sayımda kaydedilmiş kalem bulunmuyor.')
      else
        for (final k in liste(d['kalemler']))
          () {
            final f = sayiOku(k['fark']);
            final fmk = sayiOku(k['fark_maliyet']);
            final r = f < -0.0001 ? t.kirmizi : (f > 0.0001 ? t.amber : t.yesil);
            return KSatir(
              baslik: '${k['malzeme']}',
              alt: 'Sistem ${mik(k['teorik'])} · Sayılan ${mik(k['sayilan'])} ${k['birim']}',
              sag: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${f > 0.0001 ? '+' : ''}${mik(f)}', style: TextStyle(color: r, fontSize: 14, fontWeight: FontWeight.w700)),
                if (fmk.abs() >= 1) Text('${fmk < 0 ? '−' : '+'}${tl(fmk.abs(), kisa: true)}', style: TextStyle(color: r, fontSize: 12)),
              ]),
            );
          }(),
    ]);
  }
}

/// Web /sayim/gecmis — tüm sayımlar (tarih, kalem, eksik/fazla, TL fark) + detay
class SayimGecmisScreen extends StatelessWidget {
  const SayimGecmisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/sayim/gecmis',
      baslik: 'Sayım Geçmişi',
      ikon: Icons.history,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final sayimlar = liste(v['sayimlar']);
        final toplam = sayimlar.fold<double>(0, (s, x) => s + sayiOku(x['fark_maliyet']));
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Sayım', deger: '${sayimlar.length}', ikon: Icons.fact_check_outlined, renk: t.mavi),
            KKpi(etiket: 'Toplam fark', deger: '${toplam < 0 ? '−' : ''}${tl(toplam.abs(), kisa: true)}', ikon: Icons.balance, renk: toplam < 0 ? t.kirmizi : t.yesil),
          ]),
          const SizedBox(height: 8),
          if (sayimlar.isEmpty)
            KBos(
              baslik: 'Henüz sayım yapılmamış',
              ikon: Icons.fact_check_outlined,
              aciklama: 'Sayım ekranından takipli malzemeleri sayıp kaydedin; her sayım burada listelenir.',
              aksiyon: KButon('Yeni Sayım Başlat', ikon: Icons.add, onTap: () => stAc(ctx, '/sayim', 'Stok Sayımı')),
            )
          else
            for (final s in sayimlar)
              () {
                final fm = sayiOku(s['fark_maliyet']);
                final r = fm < 0 ? t.kirmizi : (fm > 0 ? t.amber : t.yesil);
                return KKart(
                  renk: r,
                  onTap: () => sayimDetayAc(ctx, tamOku(s['id'])),
                  child: Row(children: [
                    KIkon(Icons.fact_check_outlined, renk: r),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${s['tarih']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                        Text('${s['kalem']} kalem · ${s['eksik']} eksik · ${s['fazla']} fazla', style: TextStyle(color: t.sub, fontSize: 12.5)),
                      ]),
                    ),
                    Text(fm == 0 ? 'Fark yok' : '${fm < 0 ? '−' : '+'}${tl(fm.abs(), kisa: true)}', style: TextStyle(color: r, fontSize: 14, fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_right, color: t.sub),
                  ]),
                );
              }(),
        ]);
      },
    );
  }
}
