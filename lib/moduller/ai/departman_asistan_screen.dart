import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// AI departman asistanı — TEK sohbet ekranı (web departman_asistan görünümü):
/// /departman-asistan?dep=…, /muhasebe-sohbet, /pazarlama-sohbet, /satis-sohbet, /crm-sohbet, /kalite-sohbet,
/// /it-sohbet, /ik-asistan, /patron-ai-sohbet. Sayfa verisi: baslik, selam, hizli (öneri soruları), sorUrl, uygulaUrl, ekParam.
/// Mesaj: POST sorUrl {…ekParam, metin, gecmis:[{rol,metin}] (son 8)} → {tip:'cevap', cevap, link?, aksiyon?} | {tip:'eylem', ozet, eylem, params, log_id}
/// Eylem onayı: POST uygulaUrl {…ekParam, eylem, params, log_id} → {sonuc:{ok, mesaj}}. Vazgeç: web'deki gibi yalnız yerelde kapanır.
class DepartmanAsistanScreen extends StatefulWidget {
  final String url;
  final String baslik;
  const DepartmanAsistanScreen({super.key, required this.url, this.baslik = ''});
  @override
  State<DepartmanAsistanScreen> createState() => _DepartmanAsistanScreenState();
}

class _Mesaj {
  final String rol; // ben | ai | eylem
  final String metin;
  final Map<String, dynamic> link;
  Map<String, dynamic> aksiyon;
  // eylem balonu
  final String eylem;
  final dynamic params;
  final int logId;
  String durum; // bekliyor | calisiyor | ok | hata | vazgec
  String sonuc;
  _Mesaj(this.rol, this.metin, {this.link = const {}, this.aksiyon = const {}, this.eylem = '', this.params, this.logId = 0}) : durum = 'bekliyor', sonuc = '';
}

class _DepartmanAsistanScreenState extends State<DepartmanAsistanScreen> {
  final List<_Mesaj> _mesajlar = [];
  final _giris = TextEditingController();
  final _kaydir = ScrollController();
  final _odak = FocusNode();
  bool _mesgul = false;

  @override
  void dispose() {
    _giris.dispose();
    _kaydir.dispose();
    _odak.dispose();
    super.dispose();
  }

  String get _yol => Uri.parse(widget.url).path;
  Map<String, String> get _q => Map<String, String>.from(Uri.parse(widget.url).queryParameters);

  void _asagi() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_kaydir.hasClients) _kaydir.animateTo(_kaydir.position.maxScrollExtent + 200, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _sor(Map<String, dynamic> v, [String? hazir]) async {
    if (_mesgul) return;
    final soru = (hazir ?? _giris.text).trim();
    if (soru.isEmpty) return;
    _giris.clear();
    final gecmis = [
      for (final m in _mesajlar)
        if (m.rol != 'eylem' && m.metin.isNotEmpty) {'rol': m.rol == 'ben' ? 'user' : 'ai', 'metin': m.metin},
    ];
    setState(() {
      _mesajlar.add(_Mesaj('ben', soru));
      _mesgul = true;
    });
    _asagi();
    final sorUrl = metinOku(v['sorUrl']);
    final govde = <String, dynamic>{...harita(v['ekParam']), 'metin': soru, 'gecmis': gecmis.length > 8 ? gecmis.sublist(gecmis.length - 8) : gecmis};
    final c = await aiPost(context, sorUrl, govde);
    if (!mounted) return;
    setState(() {
      _mesgul = false;
      final j = c.j;
      if (!c.ok) {
        _mesajlar.add(_Mesaj('ai', metinOku(j['hata'], 'Bir sorun oldu, tekrar dener misin?')));
      } else if (j['tip'] == 'eylem') {
        _mesajlar.add(_Mesaj('eylem', metinOku(j['ozet']), eylem: metinOku(j['eylem']), params: j['params'] ?? const {}, logId: tamOku(j['log_id'])));
      } else {
        _mesajlar.add(_Mesaj('ai', metinOku(j['cevap'], '…'), link: harita(j['link']), aksiyon: harita(j['aksiyon'])));
      }
    });
    _asagi();
  }

  Future<void> _uygula(Map<String, dynamic> v, _Mesaj m) async {
    setState(() => m.durum = 'calisiyor');
    final govde = <String, dynamic>{...harita(v['ekParam']), 'eylem': m.eylem, 'params': m.params is Map ? m.params : <String, dynamic>{}, 'log_id': m.logId};
    final c = await aiPost(context, metinOku(v['uygulaUrl']), govde);
    if (!mounted) return;
    final s = harita(c.j['sonuc']);
    setState(() {
      if (!c.ok && s.isEmpty) {
        m.durum = 'bekliyor';
        m.sonuc = metinOku(c.j['hata'], 'Bağlantı hatası');
        kToast(context, m.sonuc, hata: true);
        return;
      }
      final ok = s['ok'] == true || s['ok'] == 1;
      m.durum = ok ? 'ok' : 'hata';
      m.sonuc = metinOku(s['mesaj'], 'Sonuç alınamadı.');
    });
    _asagi();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: _yol,
      q: _q.isEmpty ? null : _q,
      baslik: widget.baslik.isEmpty ? 'AI Asistan' : widget.baslik,
      ikon: Icons.smart_toy_outlined,
      araclar: (c, v, y) => [
        if (_mesajlar.isNotEmpty)
          IconButton(tooltip: 'Yeni sohbet', onPressed: () => setState(_mesajlar.clear), icon: const Icon(Icons.add_comment_outlined)),
      ],
      govde: (c, v, yenile) => _govde(c, v),
    );
  }

  Widget _govde(BuildContext c, Map<String, dynamic> v) {
    final t = c.watch<TemaProvider>();
    final hizli = dizi(v['hizli']);
    return Column(children: [
      Expanded(
        child: ListView(
          controller: _kaydir,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (_mesajlar.isEmpty) ...[
                    _hero(c, v),
                    const SizedBox(height: 18),
                    AiIzgara(minGenislik: 250, cocuklar: [for (final h in hizli) _oneri(c, v, h)]),
                  ],
                  for (final m in _mesajlar) _balon(c, v, m),
                  if (_mesgul) _yaziyor(t),
                ]),
              ),
            ),
          ],
        ),
      ),
      _girisCubugu(c, v),
    ]);
  }

  Widget _hero(BuildContext c, Map<String, dynamic> v) {
    final t = c.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(center: Alignment(-.4, -.5), colors: [Color(0xFF312E81), Color(0xFF0A0520)]),
            boxShadow: [
              BoxShadow(color: const Color(0xFFA855F7).withValues(alpha: .45), blurRadius: 34, spreadRadius: 2),
              BoxShadow(color: const Color(0xFFEC4899).withValues(alpha: .25), blurRadius: 40, offset: const Offset(10, 10)),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < 2; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 18,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0A0520), shape: BoxShape.circle)),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(metinOku(v['baslik'], 'AI Asistan'), textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.5)),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(metinOku(v['selam']), textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 14, height: 1.5)),
        ),
      ]),
    );
  }

  Widget _oneri(BuildContext c, Map<String, dynamic> v, dynamic h) {
    final t = c.watch<TemaProvider>();
    final d = dizi(h);
    String al(int i) => i < d.length ? metinOku(d[i]) : '';
    final renk = al(3).startsWith('#') ? renkOku(al(3)) : t.mor1;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _sor(v, al(1).isEmpty ? al(0) : al(1)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(10)),
              child: Icon(ikonAdi(al(2), Icons.chat_bubble_outline), color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(al(0), style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (al(4).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(al(4), style: TextStyle(color: t.sub, fontSize: 12, height: 1.35))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _balon(BuildContext c, Map<String, dynamic> v, _Mesaj m) {
    final t = c.watch<TemaProvider>();
    if (m.rol == 'eylem') return _eylemBalon(c, v, m);
    final ben = m.rol == 'ben';
    final avatar = Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.only(top: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ben ? LinearGradient(colors: [t.sub, t.sub2]) : const RadialGradient(colors: [Color(0xFF6D28D9), Color(0xFF0A0520)]),
      ),
      child: Icon(ben ? Icons.person : Icons.auto_awesome, size: 16, color: Colors.white),
    );
    final govde = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: ben ? LinearGradient(colors: [t.mor1, t.mavi]) : null,
        color: ben ? null : t.card,
        border: ben ? null : Border.all(color: t.line),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(ben ? 16 : 6),
          bottomRight: Radius.circular(ben ? 6 : 16),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (ben)
          SelectableText(m.metin, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5))
        else
          SelectableText.rich(TextSpan(children: zenginParcalar(m.metin, TextStyle(color: t.ink, fontSize: 14, height: 1.55), vurgu: t.ink))),
        if (m.link.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: InkWell(
              onTap: () => aiGit(c, metinOku(m.link['url']), baslik: metinOku(m.link['lbl'])),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.link, size: 17, color: t.mavi),
                  const SizedBox(width: 5),
                  Flexible(child: Text(metinOku(m.link['lbl'], 'Aç'), style: TextStyle(color: t.mavi, fontSize: 13.5, fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          ),
        if (m.aksiyon.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: KButon(
              metinOku(m.aksiyon['lbl'], 'Yap'),
              ikon: Icons.bolt,
              renk: const Color(0xFFF59E0B),
              onTap: _mesgul
                  ? null
                  : () {
                      final soru = metinOku(m.aksiyon['soru'], metinOku(m.aksiyon['intent']));
                      setState(() => m.aksiyon = const {});
                      _sor(v, soru);
                    },
            ),
          ),
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: ben ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!ben) ...[avatar, const SizedBox(width: 8)],
          Flexible(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 700), child: govde)),
          if (ben) ...[const SizedBox(width: 8), avatar],
        ],
      ),
    );
  }

  Widget _eylemBalon(BuildContext c, Map<String, dynamic> v, _Mesaj m) {
    final t = c.watch<TemaProvider>();
    final sonRenk = m.durum == 'ok' ? t.yesil : (m.durum == 'hata' ? t.kirmizi : t.sub);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 30),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(t.mor1.withValues(alpha: .07), t.card),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.mor1.withValues(alpha: .35), width: 1.4),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: t.mor1),
            const SizedBox(width: 6),
            Text('ONAYINA SUNUYORUM', style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .3)),
          ]),
          const SizedBox(height: 8),
          ZenginMetin(m.metin, stil: TextStyle(color: t.ink, fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock_outline, size: 14, color: t.yesil),
            const SizedBox(width: 5),
            Expanded(child: Text('Onaylamadan hiçbir şey değişmez. Onay kaydedilir.', style: TextStyle(color: t.sub, fontSize: 12))),
          ]),
          if (m.durum == 'bekliyor' || m.durum == 'calisiyor') ...[
            if (m.sonuc.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(m.sonuc, style: TextStyle(color: t.kirmizi, fontSize: 12.5))),
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.end, spacing: 9, runSpacing: 8, children: [
              KButon('Vazgeç', ikincil: true, renk: t.sub2, onTap: m.durum == 'calisiyor' ? null : () => setState(() {
                    m.durum = 'vazgec';
                    m.sonuc = 'Tamam, vazgeçtim.';
                  })),
              KButon(m.durum == 'calisiyor' ? 'Yürütülüyor' : 'Onayla, yap',
                  ikon: Icons.check, renk: t.yesil, yukleniyor: m.durum == 'calisiyor', onTap: () => _uygula(v, m)),
            ]),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(9), border: Border(left: BorderSide(color: sonRenk, width: 3))),
              child: Text(m.sonuc, style: TextStyle(color: m.durum == 'vazgec' ? t.sub : sonRenk, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.45)),
            ),
        ]),
      ),
    );
  }

  Widget _yaziyor(TemaProvider t) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: t.mor1)),
            const SizedBox(width: 10),
            Text('AI düşünüyor…', style: TextStyle(color: t.mor1, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _girisCubugu(BuildContext c, Map<String, dynamic> v) {
    final t = c.watch<TemaProvider>();
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(c).padding.bottom),
      decoration: BoxDecoration(color: t.bg, border: Border(top: BorderSide(color: t.line))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 4, 5, 4),
              decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line), boxShadow: t.golge),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _giris,
                    focusNode: _odak,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sor(v),
                    style: TextStyle(color: t.ink, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: metinOku(v['placeholder'], 'Sorunu yaz…'),
                      hintStyle: TextStyle(color: t.sub),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Material(
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Ink(
                      decoration: BoxDecoration(gradient: LinearGradient(colors: _mesgul ? [t.sub, t.sub] : [t.mor1, t.mavi])),
                      child: InkWell(
                        onTap: _mesgul ? null : () => _sor(v),
                        child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 5),
            Text('Değiştiren işlemler önce onayına sunulur', style: TextStyle(color: t.sub, fontSize: 11.5)),
          ]),
        ),
      ),
    );
  }
}
