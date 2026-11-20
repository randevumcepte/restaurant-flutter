import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/yazici_servisi.dart';
import '../../ui/kit.dart';

/// Web /yazici-ayarlari — ağ termal yazıcı ayarı (IP/port, kağıt, Türkçe, çekmece, mutfak çıktı modu, istasyon yazıcıları).
/// Baskı CİHAZDAN yapılır: ayar bu cihaza (YaziciServisi / SharedPreferences) yazılır VE web paneldeki şube kaydına
/// (POST /yazici-ayarlari/kaydet) gönderilir. Test fişi / mutfak fişi / çekmece yalnız uygulamadan tetiklenir.
class OpYaziciAyarlariScreen extends StatelessWidget {
  const OpYaziciAyarlariScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/yazici-ayarlari',
      baslik: 'Yazıcı Ayarları',
      ikon: Icons.print_outlined,
      govde: (ctx, v, yenile) => _YaziciForm(sunucu: harita(v['ayar']), yenile: yenile),
    );
  }
}

class _YaziciForm extends StatefulWidget {
  final Map<String, dynamic> sunucu;
  final Future<void> Function() yenile;
  const _YaziciForm({required this.sunucu, required this.yenile});

  @override
  State<_YaziciForm> createState() => _YaziciFormState();
}

class _YaziciFormState extends State<_YaziciForm> {
  final _srv = YaziciServisi();
  final _ipC = TextEditingController();
  final _portC = TextEditingController();
  final _kodC = TextEditingController();
  final _mutfakIpC = TextEditingController();
  final _barIpC = TextEditingController();
  final _izgaraIpC = TextEditingController();
  String _mutfakMod = 'ekran';
  bool _dar = false;
  bool _cekmece = true;
  bool _turkce = true;
  bool _qrFisBas = true;
  bool _yukleniyor = true;
  bool _kaydediliyor = false;
  bool _mesgul = false;
  bool _cihazdaVar = false;

  @override
  void initState() {
    super.initState();
    _srv.yukle().then((_) {
      if (!mounted) return;
      setState(() {
        _cihazdaVar = _srv.ip.trim().isNotEmpty;
        if (_cihazdaVar || widget.sunucu.isEmpty) {
          _cihazdanAl();
        } else {
          _sunucudanAl();
          _qrFisBas = _srv.qrFisBas;
        }
        _yukleniyor = false;
      });
    });
  }

  @override
  void dispose() {
    for (final c in [_ipC, _portC, _kodC, _mutfakIpC, _barIpC, _izgaraIpC]) {
      c.dispose();
    }
    super.dispose();
  }

  void _cihazdanAl() {
    _ipC.text = _srv.ip;
    _portC.text = '${_srv.port}';
    _kodC.text = '${_srv.kodSayfa}';
    _mutfakIpC.text = _srv.mutfakIp;
    _barIpC.text = _srv.istasyonIp['bar'] ?? '';
    _izgaraIpC.text = _srv.istasyonIp['izgara'] ?? '';
    _mutfakMod = _srv.mutfakMod;
    _dar = _srv.dar;
    _cekmece = _srv.cekmece;
    _turkce = _srv.turkce;
    _qrFisBas = _srv.qrFisBas;
  }

  void _sunucudanAl() {
    final s = widget.sunucu;
    _ipC.text = metinOku(s['ip']);
    _portC.text = metinOku(s['port'], '9100');
    _kodC.text = metinOku(s['kod'], '13');
    _mutfakIpC.text = metinOku(s['mutfak_ip']);
    _barIpC.text = metinOku(s['bar_ip']);
    _izgaraIpC.text = metinOku(s['izgara_ip']);
    final mm = metinOku(s['mutfak_mod'], 'ekran');
    _mutfakMod = ['ekran', 'yazici', 'ikisi'].contains(mm) ? mm : 'ekran';
    _dar = metinOku(s['dar']) == '1';
    _cekmece = metinOku(s['cekmece'], '1') == '1';
    _turkce = metinOku(s['turkce'], '1') != '0';
  }

  bool get _sunucuFarkli {
    final s = widget.sunucu;
    if (s.isEmpty) return false;
    return metinOku(s['ip']) != _ipC.text.trim() ||
        metinOku(s['port'], '9100') != _portC.text.trim() ||
        metinOku(s['mutfak_mod'], 'ekran') != _mutfakMod ||
        metinOku(s['mutfak_ip']) != _mutfakIpC.text.trim() ||
        metinOku(s['bar_ip']) != _barIpC.text.trim() ||
        metinOku(s['izgara_ip']) != _izgaraIpC.text.trim() ||
        (metinOku(s['dar']) == '1') != _dar ||
        (metinOku(s['cekmece'], '1') == '1') != _cekmece ||
        (metinOku(s['turkce'], '1') != '0') != _turkce;
  }

  /// Bu cihaza yaz (baskı buradan yapılır)
  Future<void> _cihazaYaz() async {
    _srv.ip = _ipC.text.trim();
    _srv.port = int.tryParse(_portC.text.trim()) ?? 9100;
    _srv.kodSayfa = int.tryParse(_kodC.text.trim()) ?? 13;
    _srv.dar = _dar;
    _srv.cekmece = _cekmece;
    _srv.turkce = _turkce;
    _srv.qrFisBas = _qrFisBas;
    _srv.mutfakMod = _mutfakMod;
    _srv.mutfakIp = _mutfakIpC.text.trim();
    final ist = Map<String, String>.from(_srv.istasyonIp)
      ..remove('bar')
      ..remove('izgara');
    if (_barIpC.text.trim().isNotEmpty) ist['bar'] = _barIpC.text.trim();
    if (_izgaraIpC.text.trim().isNotEmpty) ist['izgara'] = _izgaraIpC.text.trim();
    _srv.istasyonIp = ist;
    await _srv.kaydet();
    _cihazdaVar = _srv.ip.trim().isNotEmpty;
  }

  Future<void> _kaydet() async {
    FocusScope.of(context).unfocus();
    setState(() => _kaydediliyor = true);
    await _cihazaYaz();
    if (!mounted) return;
    final ok = await kopruGonder(
      context,
      '/yazici-ayarlari/kaydet',
      {
        'ip': _ipC.text.trim(),
        'port': _portC.text.trim().isEmpty ? '9100' : _portC.text.trim(),
        'dar': _dar ? '1' : '0',
        'turkce': _turkce ? '1' : '0',
        'kod': _kodC.text.trim().isEmpty ? '13' : _kodC.text.trim(),
        if (_cekmece) 'cekmece': '1',
        'mutfak_mod': _mutfakMod,
        'mutfak_ip': _mutfakIpC.text.trim(),
        'bar_ip': _barIpC.text.trim(),
        'izgara_ip': _izgaraIpC.text.trim(),
      },
      basariMesaji: 'Ayarlar bu cihaza ve şube kaydına kaydedildi.',
    );
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    if (ok) await widget.yenile();
  }

  Future<void> _test(Future<String> Function() f, String ne) async {
    if (_mesgul) return;
    FocusScope.of(context).unfocus();
    if (_ipC.text.trim().isEmpty) {
      kToast(context, 'Önce yazıcı IP adresini girin.', hata: true);
      return;
    }
    await _cihazaYaz();
    if (!mounted) return;
    setState(() => _mesgul = true);
    kToast(context, '$ne gönderiliyor…');
    final sonuc = await f();
    if (!mounted) return;
    setState(() => _mesgul = false);
    kToast(context, sonuc == 'ok' ? '$ne yazıcıya gönderildi.' : sonuc, hata: sonuc != 'ok');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (_yukleniyor) return const KYukleniyor();
    final genis = genisMi(context);
    final rakam = [FilteringTextInputFormatter.digitsOnly];

    Widget radyo<T>(String baslik, List<(T, String, String?)> secenekler, T secili, ValueChanged<T> sec) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (d, e, alt) in secenekler)
              ChoiceChip(
                label: Text(alt == null ? e : '$e · $alt', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: d == secili ? Colors.white : t.sub2)),
                selected: d == secili,
                showCheckmark: false,
                selectedColor: t.mor1,
                backgroundColor: t.card2,
                side: BorderSide(color: d == secili ? t.mor1 : t.line),
                onSelected: (_) => setState(() => sec(d)),
              ),
          ]),
          const SizedBox(height: 14),
        ]);

    TextField rakamAlan(TextEditingController c, String ipucu) => TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: rakam,
          style: TextStyle(color: t.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: ipucu,
            filled: true,
            fillColor: t.card2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
          ),
        );

    final ana = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Ana yazıcı (hesap fişi)', ikon: Icons.print_outlined),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: KAlan('Yazıcı IP adresi', _ipC, ipucu: 'örn. 192.168.1.50', klavye: TextInputType.url)),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Port', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                rakamAlan(_portC, '9100'),
              ]),
            ),
          ),
        ]),
        radyo<bool>('Kağıt genişliği', [(false, '80 mm', '48 karakter'), (true, '58 mm', '32 karakter')], _dar, (x) => _dar = x),
        radyo<bool>('Türkçe karakter', [(true, 'Türkçe (CP857)', null), (false, 'ASCII sadeleştir', null)], _turkce, (x) => _turkce = x),
        Text('Kod sayfası no', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          SizedBox(width: 90, child: rakamAlan(_kodC, '13')),
          const SizedBox(width: 10),
          Expanded(child: Text('Türkçe harfler bozuk çıkarsa değiştirin: 13 · 18 · 34…', style: TextStyle(color: t.sub, fontSize: 12.5))),
        ]),
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _cekmece,
          activeTrackColor: t.yesil,
          onChanged: (x) => setState(() => _cekmece = x),
          title: Text('Hesap fişi basınca çekmeceyi aç', style: TextStyle(color: t.ink, fontSize: 14.5)),
          subtitle: Text('Yazıcıya bağlı kasa çekmecesi (RJ11) tetiklenir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
      ]),
    );

    final mutfak = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Mutfak çıktısı', ikon: Icons.soup_kitchen_outlined),
        radyo<String>('Sipariş mutfağa nasıl gitsin?', [('ekran', 'Yalnız ekran (KDS)', null), ('yazici', 'Yalnız yazıcı', null), ('ikisi', 'Ekran + yazıcı', null)], _mutfakMod,
            (x) => _mutfakMod = x),
        if (_mutfakMod != 'ekran') ...[
          KAlan('Mutfak yazıcısı IP (boş = ana yazıcı)', _mutfakIpC, ipucu: 'örn. 192.168.1.51', klavye: TextInputType.url),
          Text('İstasyon yazıcıları (boş = mutfak yazıcısı). Bar / ızgara siparişi kendi fişine ve kendi yazıcısına gider.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: KAlan('Bar yazıcısı IP', _barIpC, ipucu: 'örn. 192.168.1.52', klavye: TextInputType.url)),
            const SizedBox(width: 10),
            Expanded(child: KAlan('Izgara yazıcısı IP', _izgaraIpC, ipucu: 'örn. 192.168.1.53', klavye: TextInputType.url)),
          ]),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _qrFisBas,
          activeTrackColor: t.yesil,
          onChanged: (x) => setState(() => _qrFisBas = x),
          title: Text('Bu cihaz QR siparişlerinin mutfak/bar fişini bassın', style: TextStyle(color: t.ink, fontSize: 14.5)),
          subtitle: Text('Yalnız bu cihaz için geçerlidir. Masa QR\'ından gelen siparişte garson cihazı yok; fişi bu cihaz basar. Birden çok cihaz açıksa aynı fiş iki kez basılmaz.',
              style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
      ]),
    );

    final test = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Test', ikon: Icons.fact_check_outlined, alt: 'Bu cihazdan yazıcıya gönderilir (önce ayarlar bu cihaza kaydedilir).'),
        Wrap(spacing: 10, runSpacing: 10, children: [
          KButon('Hesap fişi testi', ikon: Icons.receipt_long_outlined, renk: t.yesil, ikincil: true, yukleniyor: _mesgul, onTap: () => _test(_srv.testFisi, 'Hesap fişi')),
          KButon('Mutfak fişi testi', ikon: Icons.soup_kitchen_outlined, renk: t.mor1, ikincil: true, yukleniyor: _mesgul, onTap: () => _test(_srv.testMutfak, 'Mutfak fişi')),
          KButon('Çekmeceyi aç', ikon: Icons.point_of_sale, renk: t.amber, ikincil: true, yukleniyor: _mesgul, onTap: () => _test(_srv.cekmeceAcTest, 'Çekmece komutu')),
        ]),
      ]),
    );

    final bilgi = KKart(
      renk: t.mavi,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          _cihazdaVar
              ? 'Bu cihazda kayıtlı yazıcı: ${_srv.ip}:${_srv.port}. Kaydet, ayarı hem bu cihaza hem şube kaydına (web panel) yazar.'
              : 'Bu cihazda henüz yazıcı ayarı yok${widget.sunucu.isNotEmpty ? '; şube kaydındaki ayar yüklendi' : ''}. Kaydet ile bu cihaza ve şube kaydına yazılır.',
          style: TextStyle(color: t.sub2, fontSize: 13.5),
        ),
        if (_sunucuFarkli) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: KButon('Şube kaydındaki ayarı forma yükle', ikon: Icons.cloud_download_outlined, ikincil: true, onTap: () => setState(_sunucudanAl)),
          ),
        ],
      ]),
    );

    return KGovde(yenile: widget.yenile, maxGenislik: 1100, children: [
      bilgi,
      if (genis)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: ana),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [mutfak, test])),
        ])
      else ...[
        ana,
        mutfak,
        test,
      ],
      KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediliyor, onTap: _kaydet),
    ]);
  }
}
