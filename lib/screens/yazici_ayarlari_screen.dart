import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../services/yazici_servisi.dart';
import 'menu_hamburger.dart';

/// AĞ YAZICISI AYARLARI — IP/port + kağıt genişliği + çekmece + Türkçe/ASCII + test baskıları.
/// Ayarlar cihazda saklanır (YaziciServisi.kaydet). Restoranda IP girilir → Test Fişi ile doğrulanır.
class YaziciAyarlariScreen extends StatefulWidget {
  const YaziciAyarlariScreen({super.key});
  @override
  State<YaziciAyarlariScreen> createState() => _YaziciAyarlariScreenState();
}

class _YaziciAyarlariScreenState extends State<YaziciAyarlariScreen> {
  final _srv = YaziciServisi();
  final _ipC = TextEditingController();
  final _portC = TextEditingController();
  final _kodC = TextEditingController();
  bool dar = false;
  bool cekmece = true;
  bool turkce = true;
  bool yukleniyor = true;
  bool mesgul = false;

  @override
  void initState() {
    super.initState();
    _srv.yukle().then((_) {
      if (!mounted) return;
      setState(() {
        _ipC.text = _srv.ip;
        _portC.text = _srv.port.toString();
        _kodC.text = _srv.kodSayfa.toString();
        dar = _srv.dar;
        cekmece = _srv.cekmece;
        turkce = _srv.turkce;
        yukleniyor = false;
      });
    });
  }

  @override
  void dispose() { _ipC.dispose(); _portC.dispose(); _kodC.dispose(); super.dispose(); }

  Future<void> _kaydet({bool sessiz = false}) async {
    _srv.ip = _ipC.text.trim();
    _srv.port = int.tryParse(_portC.text.trim()) ?? 9100;
    _srv.kodSayfa = int.tryParse(_kodC.text.trim()) ?? 13;
    _srv.dar = dar;
    _srv.cekmece = cekmece;
    _srv.turkce = turkce;
    await _srv.kaydet();
    if (!sessiz && mounted) _snack('Ayarlar kaydedildi', const Color(0xFF10B981));
  }

  Future<void> _test(Future<String> Function() f, String ne) async {
    if (mesgul) return;
    FocusScope.of(context).unfocus();
    await _kaydet(sessiz: true);
    if (_ipC.text.trim().isEmpty) { _snack('Önce yazıcı IP adresi gir', const Color(0xFFF43F5E)); return; }
    setState(() => mesgul = true);
    _snack('$ne gönderiliyor…', const Color(0xFF6366F1));
    final sonuc = await f();
    if (!mounted) return;
    setState(() => mesgul = false);
    if (sonuc == 'ok') {
      _snack('✓ $ne yazıcıya gönderildi', const Color(0xFF10B981));
    } else {
      _snack(sonuc, const Color(0xFFF43F5E), uzun: true);
    }
  }

  void _snack(String m, Color c, {bool uzun = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, duration: Duration(seconds: uzun ? 5 : 2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Yazıcı Ayarları', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      body: yukleniyor
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : ListView(padding: const EdgeInsets.all(16), children: [
              _bilgiKart(t),
              const SizedBox(height: 14),
              _kartBaslik(t, 'Bağlantı'),
              _kutu(t, child: Column(children: [
                _alan(t, 'Yazıcı IP adresi', _ipC, ipuc: 'örn. 192.168.1.50', klavye: TextInputType.number),
                const SizedBox(height: 12),
                _alan(t, 'Port', _portC, ipuc: '9100', klavye: TextInputType.number, kisa: true),
              ])),
              const SizedBox(height: 14),
              _kartBaslik(t, 'Kağıt Genişliği'),
              _kutu(t, child: Row(children: [
                _secim(t, '80 mm (geniş)', !dar, () => setState(() => dar = false)),
                const SizedBox(width: 10),
                _secim(t, '58 mm (dar)', dar, () => setState(() => dar = true)),
              ])),
              const SizedBox(height: 14),
              _kartBaslik(t, 'Karakter'),
              _kutu(t, child: Column(children: [
                Row(children: [
                  _secim(t, 'Türkçe (CP857)', turkce, () => setState(() => turkce = true)),
                  const SizedBox(width: 10),
                  _secim(t, 'ASCII (sade)', !turkce, () => setState(() => turkce = false)),
                ]),
                if (turkce) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: Text('Kod sayfası no (Türkçe bozuk çıkarsa değiştir: 13 · 18 · 34…)', style: TextStyle(color: t.sub, fontSize: 11.5))),
                    const SizedBox(width: 10),
                    SizedBox(width: 64, child: _alan(t, '', _kodC, ipuc: '13', klavye: TextInputType.number, kisa: true)),
                  ]),
                ],
              ])),
              const SizedBox(height: 14),
              _kartBaslik(t, 'Çekmece'),
              _kutu(t, child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: t.mor1,
                title: Text('Hesap fişi basınca çekmeceyi aç', style: TextStyle(color: t.ink, fontSize: 14)),
                subtitle: Text('Yazıcıya bağlı kasa çekmecesi (RJ11) tetiklenir', style: TextStyle(color: t.sub, fontSize: 11.5)),
                value: cekmece, onChanged: (v) => setState(() => cekmece = v),
              )),
              const SizedBox(height: 20),
              _anaButon(t, Icons.save_outlined, 'Kaydet', t.mor1, () => _kaydet()),
              const SizedBox(height: 22),
              _kartBaslik(t, 'Test'),
              _testButon(t, Icons.receipt_long, 'Hesap Fişi Testi', const Color(0xFF10B981), () => _test(_srv.testFisi, 'Hesap fişi')),
              const SizedBox(height: 10),
              _testButon(t, Icons.soup_kitchen_outlined, 'Mutfak Fişi Testi', const Color(0xFF7C3AED), () => _test(_srv.testMutfak, 'Mutfak fişi')),
              const SizedBox(height: 10),
              _testButon(t, Icons.point_of_sale, 'Çekmeceyi Aç', const Color(0xFFF59E0B), () => _test(_srv.cekmeceAcTest, 'Çekmece komutu')),
              const SizedBox(height: 30),
            ]),
    );
  }

  Widget _bilgiKart(TemaProvider t) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mor1.withValues(alpha: 0.3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: t.mor1, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Ağ (LAN) yazıcısına doğrudan basar; mevcut Kerzz/POS sistemine dokunmaz. Yazıcının IP adresini gir, "Hesap Fişi Testi" ile dene. Mali fiş DEĞİLDİR — yasal fiş POS cihazından kesilmeye devam eder.',
            style: TextStyle(color: t.sub2, fontSize: 12, height: 1.35),
          )),
        ]),
      );

  Widget _kartBaslik(TemaProvider t, String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(s, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
      );

  Widget _kutu(TemaProvider t, {required Widget child}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: child,
      );

  Widget _alan(TemaProvider t, String etiket, TextEditingController c, {String? ipuc, TextInputType? klavye, bool kisa = false}) {
    final field = TextField(
      controller: c, keyboardType: klavye, style: TextStyle(color: t.ink, fontSize: 15),
      inputFormatters: klavye == TextInputType.number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
      decoration: InputDecoration(
        hintText: ipuc, hintStyle: TextStyle(color: t.sub), isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)),
      ),
    );
    if (etiket.isEmpty) return field;
    final w = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(etiket, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      field,
    ]);
    return kisa ? SizedBox(width: 120, child: Align(alignment: Alignment.centerLeft, child: w)) : w;
  }

  Widget _secim(TemaProvider t, String s, bool sec, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sec ? t.mor1 : t.bg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sec ? t.mor1 : t.line),
            ),
            child: Text(s, style: TextStyle(color: sec ? Colors.white : t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      );

  Widget _anaButon(TemaProvider t, IconData i, String s, Color c, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15), alignment: Alignment.center,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(13)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(i, color: Colors.white, size: 19), const SizedBox(width: 8),
            Text(s, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _testButon(TemaProvider t, IconData i, String s, Color c, VoidCallback onTap) => GestureDetector(
        onTap: mesgul ? null : onTap,
        child: Opacity(
          opacity: mesgul ? 0.5 : 1,
          child: Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(13), border: Border.all(color: c.withValues(alpha: 0.5))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, color: c, size: 19), const SizedBox(width: 8),
              Text(s, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );
}
