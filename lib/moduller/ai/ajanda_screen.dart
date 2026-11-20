import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// /ajanda — Ajanda & Hatırlatıcı (herkese açık; web ajanda ile aynı veri ve işlemler):
/// sayaçlar (bugün / yarın / 7 gün / gecikmiş), 14 günlük şerit, filtre + arama, gün gruplu liste + not panosu,
/// yeni ekle (tip, tarih/saat çipleri, hatırlatma, açıklama, işletme geneli — yalnız sahip/müdür),
/// tamamlandı / sil (yalnız kendi kaydı; yönetici hepsi), geçmiş + geri al, örnek kayıt yükle / sil.
class AjandaScreen extends StatefulWidget {
  const AjandaScreen({super.key});
  @override
  State<AjandaScreen> createState() => _AjandaScreenState();
}

const _tipler = <String, (IconData, String, Color)>{
  'hatirlatma': (Icons.alarm, 'Hatırlatma', Color(0xFF7C3AED)),
  'randevu': (Icons.event, 'Randevu', Color(0xFF0EA5E9)),
  'toplanti': (Icons.groups_outlined, 'Toplantı', Color(0xFF10B981)),
  'not': (Icons.sticky_note_2_outlined, 'Not', Color(0xFFF59E0B)),
  'dogumgunu': (Icons.cake_outlined, 'Doğum Günü', Color(0xFFEC4899)),
};

class _AjandaScreenState extends State<AjandaScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _filtre = 'tumu';
  String? _gun; // yyyy-mm-dd şerit seçimi
  String _ara = '';
  final Set<int> _gizli = {};
  Timer? _saat;

  @override
  void initState() {
    super.initState();
    // web gibi: göreli zaman ("2 sa sonra") ve sayaçlar her 30 sn güncellenir
    _saat = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _saat?.cancel();
    super.dispose();
  }

  static String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  static DateTime _gunBasi([int ek = 0]) {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + ek);
  }

  DateTime? _zaman(Map<String, dynamic> a) {
    final s = metinOku(a['baslar_at']);
    if (s.isEmpty) return null;
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
  }

  String _goreli(DateTime z) {
    final fark = z.difference(DateTime.now()).inMinutes;
    final m = fark.abs();
    if (m < 1) return 'şimdi';
    String s;
    if (m < 60) {
      s = '$m dk';
    } else if (m < 1440) {
      s = '${m ~/ 60} sa${(m % 60 != 0 && m < 600) ? ' ${m % 60} dk' : ''}';
    } else {
      s = '${(m / 1440).round()} gün';
    }
    return fark >= 0 ? '$s sonra' : '$s geçti';
  }

  /// sınıf: not / gecikmis / bugun / yarin / hafta
  Map<String, bool> _sinif(Map<String, dynamic> a) {
    final z = _zaman(a);
    if (z == null) return {'not': true};
    final simdi = DateTime.now();
    final g = _ymd(z);
    return {
      'gecikmis': z.isBefore(simdi),
      'bugun': g == _ymd(_gunBasi()) && !z.isBefore(simdi),
      'yarin': g == _ymd(_gunBasi(1)),
      'hafta': !z.isBefore(simdi) && z.isBefore(_gunBasi(7)),
    };
  }

  bool _gorunur(Map<String, dynamic> a) {
    final s = _sinif(a);
    bool ok;
    if (_gun != null) {
      final z = _zaman(a);
      ok = z != null && _ymd(z) == _gun;
    } else {
      ok = _filtre == 'tumu' || s[_filtre] == true;
    }
    if (ok && _ara.isNotEmpty) ok = '${metinOku(a['baslik'])} ${metinOku(a['aciklama'])}'.toLowerCase().contains(_ara);
    return ok;
  }

  Future<void> _islem(BuildContext c, Map<String, dynamic> a, String tur) async {
    if (tur == 'sil' && !await kOnay(c, 'Bu kayıt silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: metinOku(a['baslik']))) return;
    if (!c.mounted) return;
    final cv = await aiPost(c, tur == 'sil' ? '/ajanda/sil' : '/ajanda/durum', tur == 'sil' ? {'id': a['id']} : {'id': a['id'], 'durum': 'tamam'}, form: true);
    if (!mounted) return;
    if (cv.ok) {
      setState(() => _gizli.add(tamOku(a['id'])));
      if (c.mounted) kToast(c, tur == 'sil' ? 'Silindi' : 'Harika, tamamlandı! 🎉');
      _k.currentState?.yukle(sessiz: true);
    } else if (c.mounted) {
      kToast(c, cevapMesaj(cv, hata: 'Bu kaydı değiştirme yetkin yok ya da kayıt bulunamadı.'), hata: true);
    }
  }

  Future<void> _geriAl(BuildContext c, Map<String, dynamic> g) async {
    final cv = await aiPost(c, '/ajanda/durum', {'id': g['id'], 'durum': 'acik'}, form: true);
    if (!mounted) return;
    if (cv.ok) {
      _gizli.remove(tamOku(g['id']));
      if (c.mounted) kToast(c, 'Geri alındı.');
      _k.currentState?.yukle();
    } else if (c.mounted) {
      kToast(c, 'Geri alınamadı', hata: true);
    }
  }

  Future<void> _ornek(BuildContext c, {bool sil = false}) async {
    if (sil && !await kOnay(c, 'Örnek kayıtlar silinsin mi?', tehlikeli: true, evet: 'Sil')) return;
    if (!c.mounted) return;
    final ok = await kopruGonder(c, '/ajanda/ornek', sil ? {'islem': 'sil'} : {}, basariMesaji: sil ? 'Örnek kayıtlar silindi.' : 'Örnek kayıtlar yüklendi.');
    if (ok) _k.currentState?.yukle();
  }

  void _yeniEkle(BuildContext c, bool patronMu, [String? tarih]) {
    kAltSayfa(c, baslik: 'Yeni Ekle', icerik: (s) => _AjandaForm(patronMu: patronMu, tarih: tarih, kaydedildi: () {
          Navigator.of(s).maybePop();
          _k.currentState?.yukle();
        }));
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/ajanda',
      baslik: 'Ajanda & Hatırlatıcı',
      ikon: Icons.event_note_outlined,
      fab: (c, v, y) => genisMi(c)
          ? const SizedBox.shrink()
          : FloatingActionButton.extended(
              heroTag: 'ajanda_ekle',
              backgroundColor: c.read<TemaProvider>().mor1,
              foregroundColor: Colors.white,
              onPressed: () => _yeniEkle(c, _patronMu(v), _gun),
              icon: const Icon(Icons.add_task),
              label: const Text('Yeni ekle', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  bool _patronMu(Map<String, dynamic> v) => ['sahip', 'mudur'].contains(metinOku(harita(v['personel'])['rol']));

  Widget _govde(BuildContext c, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final per = harita(v['personel']);
    final patronMu = _patronMu(v);
    final benimId = tamOku(per['id']);
    bool duzenler(Map<String, dynamic> a) => patronMu || tamOku(a['personel_id']) == benimId;
    final tum = liste(v['liste']).where((a) => !_gizli.contains(tamOku(a['id']))).toList();
    final gecmis = liste(v['gecmis']);
    final ilkAd = metinOku(per['ad']).split(' ').first;
    final genis = genisMi(c);

    // sayaçlar
    final say = {'tumu': tum.length, 'bugun': 0, 'yarin': 0, 'hafta': 0, 'gecikmis': 0, 'not': 0};
    final gunSay = <String, int>{};
    Map<String, dynamic>? sirada;
    for (final a in tum) {
      final s = _sinif(a);
      for (final k in s.keys) {
        if (s[k] == true) say[k] = say[k]! + 1;
      }
      final z = _zaman(a);
      if (z != null) {
        gunSay[_ymd(z)] = (gunSay[_ymd(z)] ?? 0) + 1;
        if (!z.isBefore(DateTime.now()) && (sirada == null || z.isBefore(_zaman(sirada)!))) sirada = a;
      }
    }
    String ozet;
    if (tum.isEmpty) {
      ozet = 'Ajandan boş. Aklındakini hemen ekle, zamanı gelince **hatırlatalım**.';
    } else {
      ozet = say['bugun']! > 0 ? 'Bugün **${say['bugun']} işin** var.' : 'Bugün için planlanmış iş yok.';
      if (sirada != null) ozet += ' Sıradaki: **${metinOku(sirada['baslik'])}** — ${_goreli(_zaman(sirada)!)}.';
      if (say['gecikmis']! > 0) ozet += ' **${say['gecikmis']} gecikmiş** kayıt seni bekliyor.';
    }

    // gruplar
    final gorunen = tum.where(_gorunur).toList();
    final zamanli = gorunen.where((a) => _zaman(a) != null).toList()..sort((a, b) => _zaman(a)!.compareTo(_zaman(b)!));
    final notlar = gorunen.where((a) => _zaman(a) == null).toList();
    final gruplar = <String, List<Map<String, dynamic>>>{};
    final grupAd = <String, String>{};
    for (final a in zamanli) {
      final z = _zaman(a)!;
      String k, bas;
      if (z.isBefore(DateTime.now())) {
        k = '0gecikmis';
        bas = 'Gecikmiş';
      } else {
        k = _ymd(z);
        final fark = DateTime(z.year, z.month, z.day).difference(_gunBasi()).inDays;
        bas = fark == 0 ? 'Bugün' : (fark == 1 ? 'Yarın' : '${gunAdi(z.weekday)}, ${z.day} ${ayAdi(z.month)}');
      }
      (gruplar[k] ??= []).add(a);
      grupAd[k] = bas;
    }
    final grupAnahtar = gruplar.keys.toList()..sort();

    final simdi = DateTime.now();
    final hero = Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [t.mor1, t.mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: t.mor1.withValues(alpha: .25), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${gunAdi(simdi.weekday)} · ${simdi.day} ${ayAdi(simdi.month)} ${simdi.year}', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${selamMetni()}${ilkAd.isEmpty ? '' : ', $ilkAd'} 👋', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text.rich(TextSpan(children: zenginParcalar(ozet, const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.45)))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${simdi.hour.toString().padLeft(2, '0')}:${simdi.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('yerel saat', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          for (final (k, ik, ad) in [('bugun', Icons.today, 'Bugün'), ('yarin', Icons.wb_twilight, 'Yarın'), ('hafta', Icons.date_range, '7 Gün'), ('gecikmis', Icons.error_outline, 'Gecikmiş')])
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: (k == 'gecikmis' && say['gecikmis']! > 0) ? const Color(0xFFF43F5E).withValues(alpha: .85) : Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() {
                      _filtre = k;
                      _gun = null;
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(ik, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Flexible(child: Text(ad, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600))),
                        ]),
                        const SizedBox(height: 3),
                        Text('${say[k]}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );

    final serit = SizedBox(
      height: 70,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (var i = 0; i < 14; i++)
          Builder(builder: (_) {
            final d = _gunBasi(i);
            final k = _ymd(d);
            final n = gunSay[k] ?? 0;
            final sec = _gun == k;
            final hs = d.weekday >= 6;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Material(
                color: sec ? t.mor1 : t.card,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _gun = sec ? null : k),
                  child: Container(
                    width: 52,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: i == 0 && !sec ? t.mor1 : t.line)),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(i == 0 ? 'Bugün' : const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][d.weekday - 1],
                          style: TextStyle(color: sec ? Colors.white : (hs ? t.kirmizi : t.sub), fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('${d.day}', style: TextStyle(color: sec ? Colors.white : t.ink, fontSize: 17, fontWeight: FontWeight.w800)),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        for (var j = 0; j < (n > 3 ? 3 : n); j++)
                          Container(margin: const EdgeInsets.symmetric(horizontal: 1), width: 5, height: 5, decoration: BoxDecoration(color: sec ? Colors.white : t.mor1, shape: BoxShape.circle)),
                      ]),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ]),
    );

    Widget ogeKart(Map<String, dynamic> a, bool gecikti) {
      final z = _zaman(a)!;
      final tp = _tipler[metinOku(a['tip'])] ?? _tipler['randevu']!;
      final gor = _goreli(z);
      final fark = z.difference(DateTime.now()).inMinutes;
      final grRenk = fark < 0 ? t.kirmizi : (fark <= 60 ? t.amber : t.sub);
      final hat = tamOku(a['hatirlat_dk']);
      return KKart(
        renk: gecikti ? t.kirmizi : tp.$3,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(children: [
          SizedBox(
            width: 50,
            child: Column(children: [
              Text('${z.hour.toString().padLeft(2, '0')}:${z.minute.toString().padLeft(2, '0')}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800)),
              Text('${z.day} ${ayAdi(z.month).substring(0, 3)}', style: TextStyle(color: t.sub, fontSize: 11.5)),
            ]),
          ),
          const SizedBox(width: 8),
          KIkon(tp.$1, renk: tp.$3, boyut: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(a['baslik']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
              if (metinOku(a['aciklama']).isNotEmpty)
                Text(metinOku(a['aciklama']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5)),
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                KRozet(gor, renk: grRenk, ikon: Icons.schedule),
                KRozet(tp.$2, renk: tp.$3),
                if (hat > 0) KRozet('${hat >= 1440 ? '${hat ~/ 1440} gün' : (hat >= 60 ? '${hat ~/ 60} sa' : '$hat dk')} önce', renk: t.sub, ikon: Icons.notifications_none),
                if (a['personel_id'] == null) KRozet('İşletme geneli', renk: t.mor1, ikon: Icons.campaign_outlined),
              ]),
            ]),
          ),
          if (duzenler(a)) ...[
            IconButton(tooltip: 'Tamamlandı', onPressed: () => _islem(c, a, 'durum'), icon: Icon(Icons.check_circle_outline, color: t.yesil)),
            IconButton(tooltip: 'Sil', onPressed: () => _islem(c, a, 'sil'), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
          ] else
            Tooltip(message: 'İşletme geneli kayıt — yalnız yönetici değiştirebilir', child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.lock_outline, color: t.sub, size: 20))),
        ]),
      );
    }

    Widget notKart(Map<String, dynamic> a) {
      final tp = _tipler[metinOku(a['tip'])] ?? _tipler['not']!;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(tp.$3.withValues(alpha: t.koyu ? .14 : .09), t.card),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tp.$3.withValues(alpha: .35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(metinOku(a['baslik']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          if (metinOku(a['aciklama']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(metinOku(a['aciklama']), style: TextStyle(color: t.sub2, fontSize: 12.5))),
          if (a['personel_id'] == null) Padding(padding: const EdgeInsets.only(top: 6), child: KRozet('İşletme geneli', renk: t.mor1, ikon: Icons.campaign_outlined)),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (duzenler(a)) ...[
              IconButton(tooltip: 'Tamamlandı', onPressed: () => _islem(c, a, 'durum'), icon: Icon(Icons.check_circle_outline, color: t.yesil)),
              IconButton(tooltip: 'Sil', onPressed: () => _islem(c, a, 'sil'), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
            ] else
              Tooltip(message: 'Yalnız yönetici değiştirebilir', child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.lock_outline, color: t.sub, size: 20))),
          ]),
        ]),
      );
    }

    final listeBolum = <Widget>[
      serit,
      const SizedBox(height: 10),
      KCipler(
        secenekler: [
          ('tumu', 'Tümü (${say['tumu']})'),
          ('bugun', 'Bugün (${say['bugun']})'),
          ('hafta', '7 Gün (${say['hafta']})'),
          ('gecikmis', 'Gecikmiş (${say['gecikmis']})'),
          ('not', 'Notlar (${say['not']})'),
        ],
        secili: _gun == null ? _filtre : '',
        onSec: (k) => setState(() {
          _filtre = k;
          _gun = null;
        }),
      ),
      KAra(ipucu: 'Ajandada ara…', onDegis: (s) => setState(() => _ara = s.trim().toLowerCase())),
      if (_gun != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(Icons.filter_alt_outlined, size: 17, color: t.mor1),
            const SizedBox(width: 6),
            Expanded(child: Text('Seçili gün: ${tarihYaz(_gun, saat: false)}', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => _yeniEkle(c, patronMu, _gun), child: const Text('Bu güne ekle')),
            IconButton(tooltip: 'Gün seçimini kaldır', onPressed: () => setState(() => _gun = null), icon: const Icon(Icons.close, size: 18)),
          ]),
        ),
      for (final k in grupAnahtar) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          child: Row(children: [
            if (k == '0gecikmis') Padding(padding: const EdgeInsets.only(right: 5), child: Icon(Icons.warning_amber, size: 17, color: t.kirmizi)),
            Text(grupAd[k]!, style: TextStyle(color: k == '0gecikmis' ? t.kirmizi : t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            KRozet('${gruplar[k]!.length}', renk: k == '0gecikmis' ? t.kirmizi : t.sub),
          ]),
        ),
        for (final a in gruplar[k]!) ogeKart(a, k == '0gecikmis'),
      ],
      if (notlar.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
          child: Row(children: [
            Icon(Icons.sticky_note_2_outlined, size: 17, color: t.amber),
            const SizedBox(width: 6),
            Text('Not Panosu', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            KRozet('${notlar.length}', renk: t.sub),
          ]),
        ),
        AiIzgara(minGenislik: 240, ara: 8, cocuklar: [for (final a in notlar) notKart(a)]),
      ],
      if (gorunen.isEmpty)
        KBos(
          ikon: Icons.event_available_outlined,
          baslik: tum.isEmpty ? 'Ajandan tertemiz ✨' : 'Burada kayıt yok',
          aciklama: tum.isEmpty
              ? '${genis ? 'Soldaki formdan' : '"Yeni ekle" düğmesiyle'} bir hatırlatma, randevu ya da not ekleyerek başla. Zamanı gelince bildirim gelir.'
              : (_ara.isNotEmpty ? '“$_ara” için sonuç bulunamadı.' : 'Bu filtrede gösterilecek bir şey yok.'),
          aksiyon: tum.isEmpty ? KButon('Örnek kayıtları yükle', ikon: Icons.auto_awesome, ikincil: true, onTap: () => _ornek(c)) : null,
        ),
      if (tum.any((a) => metinOku(a['kaynak']) == 'ornek'))
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Center(child: KButon('Örnek kayıtları sil', ikon: Icons.delete_sweep_outlined, ikincil: true, renk: t.kirmizi, onTap: () => _ornek(c, sil: true))),
        ),
      if (gecmis.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: KKart(
            padding: EdgeInsets.zero,
            child: Theme(
              data: Theme.of(c).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                leading: Icon(Icons.history, color: t.sub),
                title: Text('Geçmiş (${gecmis.length})', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 8, 8),
                children: [
                  for (final g in gecmis)
                    KSatir(
                      solIkon: Icon(metinOku(g['durum']) == 'tamam' ? Icons.check_circle : Icons.cancel_outlined, size: 19, color: metinOku(g['durum']) == 'tamam' ? t.yesil : t.sub),
                      baslik: metinOku(g['baslik']),
                      alt: tarihYaz(g['updated_at']),
                      sag: duzenler(g)
                          ? TextButton.icon(onPressed: () => _geriAl(c, g), icon: const Icon(Icons.undo, size: 16), label: const Text('Geri al'))
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ),
    ];

    if (genis) {
      return KGovde(yenile: yenile, children: [
        hero,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 380,
            child: KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('Yeni Ekle', ikon: Icons.add_task, alt: 'Hızlıca planla, zamanı gelince hatırlatalım'),
                _AjandaForm(key: ValueKey('form_$_gun'), patronMu: patronMu, tarih: _gun, kaydedildi: () => _k.currentState?.yukle()),
              ]),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: listeBolum)),
        ]),
      ]);
    }
    return KGovde(yenile: yenile, children: [hero, ...listeBolum]);
  }
}

/// Ajanda ekleme formu (web /ajanda/ekle ile aynı alanlar)
class _AjandaForm extends StatefulWidget {
  final bool patronMu;
  final String? tarih;
  final VoidCallback kaydedildi;
  const _AjandaForm({super.key, required this.patronMu, required this.kaydedildi, this.tarih});
  @override
  State<_AjandaForm> createState() => _AjandaFormState();
}

class _AjandaFormState extends State<_AjandaForm> {
  String _tip = 'hatirlatma';
  late DateTime _tarih;
  String _saat = '09:00';
  int _hat = 30;
  bool _isletme = false;
  bool _gonderiyor = false;
  final _baslik = TextEditingController();
  final _aciklama = TextEditingController();

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _tarih = DateTime.tryParse(widget.tarih ?? '') ?? DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _baslik.dispose();
    _aciklama.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _onizle() {
    if (_tip == 'not') return 'Not panosuna eklenecek — zaman ve hatırlatma yok.${_isletme ? ' · tüm ekip görür' : ''}';
    final n = DateTime.now();
    final fark = _tarih.difference(DateTime(n.year, n.month, n.day)).inDays;
    final gun = fark == 0 ? 'Bugün' : (fark == 1 ? 'Yarın' : (fark == -1 ? 'Dün' : '${_tarih.day} ${ayAdi(_tarih.month).substring(0, 3)} ${const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][_tarih.weekday - 1]}'));
    final hm = _hat == 0 ? 'hatırlatma yok' : '${_hat >= 1440 ? '1 gün' : (_hat >= 60 ? '${_hat ~/ 60} saat' : '$_hat dk')} önce bildirim';
    return '${_tipler[_tip]!.$2} · $gun $_saat · $hm${fark < 0 ? ' (geçmiş tarih!)' : ''}${_isletme ? ' · tüm ekip görür' : ''}';
  }

  Future<void> _kaydet() async {
    if (_baslik.text.trim().isEmpty) {
      kToast(context, 'Başlık gerekli.', hata: true);
      return;
    }
    setState(() => _gonderiyor = true);
    final ok = await kopruGonder(context, '/ajanda/ekle', {
      'tip': _tip,
      'baslik': _baslik.text.trim(),
      if (_tip != 'not') 'tarih': _ymd(_tarih),
      if (_tip != 'not') 'saat': _saat,
      'hatirlat_dk': _tip == 'not' ? 0 : _hat,
      'aciklama': _aciklama.text.trim(),
      if (_isletme) 'isletme': 1,
    }, basariMesaji: 'Ajandaya eklendi.');
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (ok) {
      _baslik.clear();
      _aciklama.clear();
      widget.kaydedildi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget cip(String etiket, bool sec, VoidCallback f, {Color? renk}) => ChoiceChip(
          label: Text(etiket, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sec ? Colors.white : t.sub2)),
          selected: sec,
          onSelected: (_) => f(),
          selectedColor: renk ?? t.mor1,
          backgroundColor: t.card2,
          side: BorderSide(color: sec ? (renk ?? t.mor1) : t.line),
          showCheckmark: false,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        );
    Text lbl(String s) => Text(s, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700));
    final n = DateTime.now();
    final bugun = DateTime(n.year, n.month, n.day);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final e in _tipler.entries)
          ChoiceChip(
            avatar: Icon(e.value.$1, size: 17, color: _tip == e.key ? Colors.white : e.value.$3),
            label: Text(e.value.$2, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _tip == e.key ? Colors.white : t.sub2)),
            selected: _tip == e.key,
            onSelected: (_) => setState(() => _tip = e.key),
            selectedColor: e.value.$3,
            backgroundColor: t.card2,
            side: BorderSide(color: _tip == e.key ? e.value.$3 : t.line),
            showCheckmark: false,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          ),
      ]),
      const SizedBox(height: 12),
      KAlan('Başlık', _baslik, ipucu: 'Örn: Tedarikçi toplantısı, doktor randevusu…', zorunlu: true),
      if (_tip != 'not') ...[
        lbl('Ne zaman?'),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (ek, ad) in [(0, 'Bugün'), (1, 'Yarın'), (2, 'Öbür gün'), (7, '1 hafta sonra')])
            cip(ad, _ymd(_tarih) == _ymd(bugun.add(Duration(days: ek))), () => setState(() => _tarih = bugun.add(Duration(days: ek)))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 46)),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _tarih, firstDate: DateTime(2020), lastDate: DateTime(2100));
                if (d != null) setState(() => _tarih = d);
              },
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: Text(tarihYaz(_ymd(_tarih), saat: false)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(44, 46)),
              onPressed: () async {
                final p = _saat.split(':');
                final s = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p[1]) ?? 0));
                if (s != null) setState(() => _saat = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}');
              },
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_saat),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in ['09:00', '12:00', '14:00', '17:00', '19:00']) cip(s, _saat == s, () => setState(() => _saat = s)),
        ]),
        const SizedBox(height: 12),
        lbl('Hatırlatma'),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (v, l) in [(0, 'Yok'), (15, '15 dk'), (30, '30 dk'), (60, '1 saat'), (120, '2 saat'), (1440, '1 gün')]) cip(l, _hat == v, () => setState(() => _hat = v)),
        ]),
        const SizedBox(height: 12),
      ],
      KAlan('Açıklama (opsiyonel)', _aciklama, ipucu: 'Detay, adres, telefon… Örn: Eşimin doğum günü, gül almayı unutma 🌹', satir: 2),
      if (widget.patronMu)
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _isletme,
          activeThumbColor: t.mor1,
          onChanged: (v) => setState(() => _isletme = v),
          title: Text('İşletme geneli — tüm ekip görsün', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(Icons.notifications_active_outlined, size: 17, color: t.mor1),
          const SizedBox(width: 8),
          Expanded(child: Text(_onizle(), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      ),
      KButon('Ajandaya Ekle', ikon: Icons.add, genis: true, yukleniyor: _gonderiyor, onTap: _kaydet),
    ]);
  }
}
