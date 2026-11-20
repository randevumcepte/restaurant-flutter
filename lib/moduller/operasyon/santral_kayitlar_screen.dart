import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /santral-kayitlar — AI santral çağrı kayıtları: liste + arama + istatistik, detayda konuşma dökümü,
/// ses kayıtları (dinle), adisyon/rezervasyon bağlantısı, dökümü kopyala.
/// Veri: /api/santral-kayit/liste + /api/santral-kayit/detay (web sayfasının kullandığı uçların aynısı).
class OpSantralKayitlarScreen extends StatefulWidget {
  const OpSantralKayitlarScreen({super.key});
  @override
  State<OpSantralKayitlarScreen> createState() => _OpSantralKayitlarScreenState();
}

const Map<String, String> _kSonucAd = {'siparis': 'Sipariş', 'rezervasyon': 'Rezervasyon', 'aktar': 'Aktarıldı', 'kufur': 'Küfür', 'bilgi': 'Bilgi'};
const Map<String, IconData> _kSonucIkon = {
  'siparis': Icons.shopping_cart_outlined,
  'rezervasyon': Icons.event_available_outlined,
  'aktar': Icons.phone_forwarded_outlined,
  'kufur': Icons.block,
  'bilgi': Icons.info_outline,
};
const Map<String, Color> _kSonucRenk = {
  'siparis': Color(0xFF059669),
  'rezervasyon': Color(0xFF2563EB),
  'aktar': Color(0xFFD97706),
  'kufur': Color(0xFFDC2626),
  'bilgi': Color(0xFF7C3AED),
};

String _sonucAd(dynamic s) => _kSonucAd[metinOku(s)] ?? 'Görüşme';
Color _sonucRenk(dynamic s) => _kSonucRenk[metinOku(s)] ?? const Color(0xFF64748B);
IconData _sonucIkon(dynamic s) => _kSonucIkon[metinOku(s)] ?? Icons.call_outlined;

class _OpSantralKayitlarScreenState extends State<OpSantralKayitlarScreen> {
  String _ara = '';
  String _filtre = 'hepsi';
  int? _seciliId;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/api/santral-kayit/liste',
      baslik: 'Çağrı Kayıtları',
      ikon: Icons.phone_in_talk_outlined,
      altBaslik: 'AI santralin karşıladığı çağrılar, konuşma dökümü ve ses kayıtları',
      govde: (ctx, veri, yenile) {
        final t = context.watch<TemaProvider>();
        final hepsi = liste(veri['liste']);
        final q = _ara.toLowerCase().trim();
        final gorunen = hepsi.where((x) {
          if (_filtre != 'hepsi' && metinOku(x['sonuc']) != _filtre) return false;
          if (q.isEmpty) return true;
          return metinOku(x['telefon']).toLowerCase().contains(q) || metinOku(x['son_musteri']).toLowerCase().contains(q);
        }).toList();
        int say(String s) => hepsi.where((x) => metinOku(x['sonuc']) == s).length;

        final ust = <Widget>[
          KKpiIzgara([
            KKpi(etiket: 'Toplam çağrı', deger: sayiYaz(hepsi.length), ikon: Icons.call_outlined, renk: const Color(0xFF64748B), alt: 'son 80 kayıt'),
            KKpi(etiket: 'Sipariş', deger: sayiYaz(say('siparis')), ikon: Icons.shopping_cart_outlined, renk: _kSonucRenk['siparis'], onTap: () => setState(() => _filtre = 'siparis')),
            KKpi(etiket: 'Rezervasyon', deger: sayiYaz(say('rezervasyon')), ikon: Icons.event_available_outlined, renk: _kSonucRenk['rezervasyon'], onTap: () => setState(() => _filtre = 'rezervasyon')),
            KKpi(etiket: 'Aktarılan', deger: sayiYaz(say('aktar')), ikon: Icons.phone_forwarded_outlined, renk: _kSonucRenk['aktar'], onTap: () => setState(() => _filtre = 'aktar')),
          ]),
          KAra(ipucu: 'Telefon veya içerik ara…', onDegis: (v) => setState(() => _ara = v)),
          KCipler(
            secenekler: const [('hepsi', 'Tümü'), ('siparis', 'Sipariş'), ('rezervasyon', 'Rezervasyon'), ('aktar', 'Aktarılan'), ('bilgi', 'Bilgi'), ('kufur', 'Küfür')],
            secili: _filtre,
            onSec: (k) => setState(() => _filtre = k),
          ),
        ];

        Widget listeKart() {
          if (gorunen.isEmpty) {
            return KKart(
              child: KBos(
                ikon: Icons.phone_disabled_outlined,
                baslik: hepsi.isEmpty ? 'Henüz çağrı kaydı yok' : 'Aramaya uyan çağrı yok',
                aciklama: hepsi.isEmpty
                    ? 'AI santral bir çağrıyı karşıladığında burada görünür. Santral hattı bağlı değilse AI Santral > Aktarma & Teslimat ayarlarını ve santral kurulumunu kontrol edin.'
                    : 'Filtreyi "Tümü" yapın ya da arama metnini değiştirin.',
              ),
            );
          }
          return KKart(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (final x in gorunen)
                KSatir(
                  solIkon: KIkon(_sonucIkon(x['sonuc']), renk: _sonucRenk(x['sonuc'])),
                  baslik: metinOku(x['telefon'], 'Numara yok'),
                  alt: '${metinOku(x['son_musteri'], '—')}\n${tarihYaz(x['created_at'])} · ${tamOku(x['tur'])} tur',
                  sag: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    KRozet(_sonucAd(x['sonuc']), renk: _sonucRenk(x['sonuc'])),
                    if (_seciliId == tamOku(x['id']) && genisMi(context)) Padding(padding: const EdgeInsets.only(top: 4), child: Icon(Icons.chevron_right, color: t.mor1)),
                  ]),
                  onTap: () {
                    final id = tamOku(x['id']);
                    if (genisMi(context)) {
                      setState(() => _seciliId = id);
                    } else {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => KSayfa(baslik: 'Çağrı #$id', ikon: Icons.phone_in_talk_outlined, govde: KGovde(children: [_OpSantralDetay(id: id)])),
                      ));
                    }
                  },
                ),
            ]),
          );
        }

        if (genisMi(context)) {
          final secili = _seciliId ?? (hepsi.isNotEmpty ? tamOku(hepsi.first['id']) : null);
          return RefreshIndicator(
            onRefresh: yenile,
            child: ListView(padding: const EdgeInsets.fromLTRB(22, 14, 22, 40), children: [
              ...ust,
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: listeKart()),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: secili == null
                      ? const KKart(child: KBos(baslik: 'Soldan bir çağrı seçin', ikon: Icons.touch_app_outlined))
                      : _OpSantralDetay(key: ValueKey(secili), id: secili),
                ),
              ]),
            ]),
          );
        }
        return KGovde(yenile: yenile, children: [...ust, listeKart()]);
      },
    );
  }
}

/// Tek çağrının detayı: üst bilgi, bağlantılar, ses kayıtları, konuşma.
class _OpSantralDetay extends StatefulWidget {
  final int id;
  const _OpSantralDetay({super.key, required this.id});
  @override
  State<_OpSantralDetay> createState() => _OpSantralDetayState();
}

class _OpSantralDetayState extends State<_OpSantralDetay> {
  Map<String, dynamic>? _k;
  String? _hata;
  bool _yuk = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() { _yuk = true; _hata = null; });
    final c = await KopruApi.al(tok, '/api/santral-kayit/detay', q: {'id': '${widget.id}'});
    if (!mounted) return;
    setState(() {
      _yuk = false;
      if (c.ok) {
        _k = harita(c.j['kayit']);
      } else {
        _hata = c.hata ?? 'Kayıt yüklenemedi.';
      }
    });
  }

  String _dokum(Map<String, dynamic> r) {
    final b = StringBuffer('Çağrı #${r['id']} | tel:${metinOku(r['telefon'], '-')} | sonuç:${metinOku(r['sonuc'], '-')} | durum:${metinOku(r['durum'], '-')}');
    if (r['adisyon_id'] != null) b.write(' | adisyon:${r['adisyon_id']}');
    if (r['rezervasyon_id'] != null) b.write(' | rezervasyon:${r['rezervasyon_id']}');
    b.write('\n');
    for (final m in liste(r['gecmis'])) {
      b.write('\n${m['role'] == 'user' ? 'MÜŞTERİ' : 'AI'}: ${metinOku(m['content'])}');
    }
    if (r['siparis_veri'] != null) b.write('\n\nSİPARİŞ_VERİ: ${jsonEncode(r['siparis_veri'])}');
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (_yuk) return const KKart(child: SizedBox(height: 160, child: KYukleniyor()));
    if (_k == null) return KKart(child: KHata(_hata ?? 'Hata', tekrar: _yukle));
    final r = _k!;
    final sesler = liste(r['sesler']);
    final gecmis = liste(r['gecmis']);
    final sp = harita(r['siparis_veri']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KKart(
        renk: _sonucRenk(r['sonuc']),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            KIkon(_sonucIkon(r['sonuc']), renk: _sonucRenk(r['sonuc'])),
            const SizedBox(width: 10),
            Expanded(child: Text(metinOku(r['telefon'], 'Numara yok'), style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold))),
            KRozet(_sonucAd(r['sonuc']), renk: _sonucRenk(r['sonuc'])),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KRozet(tarihYaz(r['created_at']), renk: t.sub, ikon: Icons.schedule),
            if (r['adisyon_id'] != null) KRozet('Adisyon #${r['adisyon_id']}', renk: const Color(0xFF059669), ikon: Icons.receipt_long_outlined),
            if (r['rezervasyon_id'] != null) KRozet('Rezervasyon #${r['rezervasyon_id']}', renk: const Color(0xFF2563EB), ikon: Icons.event_available_outlined),
            KRozet('Durum: ${metinOku(r['durum'], '-')}', renk: t.sub2),
          ]),
          const SizedBox(height: 12),
          if (sesler.isEmpty)
            Text('Ses kaydı yok', style: TextStyle(color: t.sub, fontSize: 12.5))
          else
            for (final s in sesler)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OpSesOynatici(
                  url: '${AppConfig.baseUrl}${metinOku(s['url'])}',
                  etiket: s['tur'] == 'aktarma' ? 'Yetkiliye aktarılan görüşme' : 'AI görüşmesi',
                  boyutKb: (tamOku(s['boyut']) / 1024).round(),
                ),
              ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: KButon('Dökümü kopyala', ikon: Icons.copy_all_outlined, ikincil: true, onTap: () async {
              await Clipboard.setData(ClipboardData(text: _dokum(r)));
              if (context.mounted) kToast(context, 'Döküm kopyalandı.');
            }),
          ),
        ]),
      ),
      if (sp.isNotEmpty)
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const KBaslik('Sipariş verisi', ikon: Icons.shopping_bag_outlined),
            for (final e in sp.entries)
              if (e.value is! List && e.value is! Map)
                Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('${e.key}: ${metinOku(e.value, '—')}', style: TextStyle(color: t.sub2, fontSize: 13))),
            for (final k in liste(sp['kalemler'] ?? sp['urunler']))
              Text('• ${metinOku(k['adet'] ?? k['miktar'], '1')} × ${metinOku(k['ad'] ?? k['urun'] ?? k['urun_adi'])}', style: TextStyle(color: t.ink, fontSize: 13.5)),
          ]),
        ),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Konuşma', ikon: Icons.forum_outlined, alt: '${gecmis.length} mesaj'),
          if (gecmis.isEmpty) const KBos(baslik: 'Konuşma boş', aciklama: 'Arayan konuşmadan kapatmış ya da çağrı santrale kaydedilmeden düşmüş olabilir.', ikon: Icons.voice_over_off),
          for (final m in gecmis) _balon(t, m['role'] == 'user', metinOku(m['content'])),
        ]),
      ),
    ]);
  }

  Widget _balon(TemaProvider t, bool musteri, String metin) {
    final r = musteri ? t.mavi : t.mor1;
    return Align(
      alignment: musteri ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: r.withValues(alpha: .10), borderRadius: BorderRadius.circular(12), border: Border.all(color: r.withValues(alpha: .25))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(musteri ? 'MÜŞTERİ' : 'AI', style: TextStyle(color: r, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          SelectableText(metin, style: TextStyle(color: t.ink, fontSize: 14, height: 1.35)),
        ]),
      ),
    );
  }
}

/// Basit ses oynatıcı (imzalı /santral-ses-dinle adresi).
class _OpSesOynatici extends StatefulWidget {
  final String url;
  final String etiket;
  final int boyutKb;
  const _OpSesOynatici({required this.url, required this.etiket, required this.boyutKb});
  @override
  State<_OpSesOynatici> createState() => _OpSesOynaticiState();
}

class _OpSesOynaticiState extends State<_OpSesOynatici> {
  final _p = AudioPlayer();
  Duration _poz = Duration.zero;
  Duration _sure = Duration.zero;
  bool _caliyor = false;

  @override
  void initState() {
    super.initState();
    _p.onPositionChanged.listen((d) { if (mounted) setState(() => _poz = d); });
    _p.onDurationChanged.listen((d) { if (mounted) setState(() => _sure = d); });
    _p.onPlayerComplete.listen((_) { if (mounted) setState(() { _caliyor = false; _poz = Duration.zero; }); });
    _p.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _caliyor = s == PlayerState.playing); });
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  Future<void> _calDurdur() async {
    try {
      if (_caliyor) {
        await _p.pause();
      } else {
        await _p.play(UrlSource(widget.url));
      }
    } catch (_) {
      if (mounted) kToast(context, 'Ses kaydı çalınamadı.', hata: true);
    }
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final max = _sure.inMilliseconds.toDouble();
    final val = _poz.inMilliseconds.clamp(0, _sure.inMilliseconds).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        IconButton(
          iconSize: 34,
          onPressed: _calDurdur,
          icon: Icon(_caliyor ? Icons.pause_circle_filled : Icons.play_circle_fill, color: t.mor1),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.etiket}${widget.boyutKb > 0 ? ' · ${widget.boyutKb} KB' : ''}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(
                min: 0,
                max: max <= 0 ? 1 : max,
                value: max <= 0 ? 0 : val,
                activeColor: t.mor1,
                inactiveColor: t.line,
                onChanged: max <= 0 ? null : (v) => _p.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ]),
        ),
        Text('${_fmt(_poz)} / ${_fmt(_sure)}', style: TextStyle(color: t.sub, fontSize: 11.5)),
      ]),
    );
  }
}
