import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../screens/barkod_tarayici.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /mal-kabul — gelen malı kontrol et → stok girer (lot/SKT). Siparişten (kalem kalem kontrol kilidi) ya da serbest;
/// barkod (kamera / okuyucu), irsaliye-fatura fotoğrafı (AI), yasal irsaliye bilgileri + VKN doğrulama.
class MalKabulScreen extends StatefulWidget {
  final String url;
  const MalKabulScreen({super.key, this.url = '/mal-kabul'});
  @override
  State<MalKabulScreen> createState() => _MalKabulScreenState();
}

class _MalKabulScreenState extends State<MalKabulScreen> {
  String? _siparisId;

  @override
  void initState() {
    super.initState();
    _siparisId = Uri.parse(widget.url).queryParameters['siparis_id'];
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: ValueKey(_siparisId),
      yol: '/mal-kabul',
      q: _siparisId == null ? null : {'siparis_id': _siparisId!},
      baslik: 'Mal Kabul / İrsaliye',
      ikon: Icons.inventory_outlined,
      govde: (ctx, v, yenile) => _MalKabulForm(
        key: ValueKey('form$_siparisId'),
        veri: v,
        siparisSec: (id) => setState(() => _siparisId = id),
      ),
    );
  }
}

const _kontrolDurum = [
  ('tam', 'Tam Geldi', Icons.check_circle_outline, Color(0xFF10B981)),
  ('eksik', 'Eksik', Icons.remove_circle_outline, Color(0xFFF59E0B)),
  ('fazla', 'Fazla', Icons.add_circle_outline, Color(0xFF4F46E5)),
  ('hasarli', 'Hasarlı', Icons.report_outlined, Color(0xFFF43F5E)),
];

class _MkSatir {
  final bool siparisten;
  int? mid;
  int birim = 0;
  int? skId;
  double? sipMik;
  String ad = '';
  String okunanAd = '';
  final gelen = TextEditingController();
  final kabul = TextEditingController();
  final fiyat = TextEditingController();
  final lot = TextEditingController();
  final sebep = TextEditingController();
  String skt = '';
  String? kontrol;
  _MkSatir({this.siparisten = false});
}

class _MalKabulForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  final ValueChanged<String?> siparisSec;
  const _MalKabulForm({super.key, required this.veri, required this.siparisSec});
  @override
  State<_MalKabulForm> createState() => _MalKabulFormState();
}

class _MalKabulFormState extends State<_MalKabulForm> {
  final _f = <String, TextEditingController>{};
  TextEditingController _c(String k) => _f.putIfAbsent(k, () => TextEditingController());
  int? _ted;
  String _tarih = bugunStr();
  String _sevk = '';
  final List<_MkSatir> _satirlar = [];
  Map<int, Map<String, dynamic>> _katalog = {};
  String _durum = '';
  bool? _durumOk;
  Uint8List? _foto;
  bool _onay = false;
  bool _gonderiyor = false;
  final _barkodK = TextEditingController();

  Map<String, dynamic> get v => widget.veri;
  Map<String, dynamic> get _siparis => harita(v['siparis']);
  List<Map<String, dynamic>> get _malz => liste(v['malzemeler']);
  List<Map<String, dynamic>> get _birim => liste(v['birimler']);

  @override
  void initState() {
    super.initState();
    if (_siparis.isNotEmpty) {
      _ted = _siparis['tedarikci_id'] == null ? null : tamOku(_siparis['tedarikci_id']);
      for (final k in liste(v['siparisKalem'])) {
        final s = _MkSatir(siparisten: true)
          ..mid = tamOku(k['malzeme_id'])
          ..birim = tamOku(k['alis_birim_id'])
          ..skId = tamOku(k['id'])
          ..sipMik = sayiOku(k['miktar'])
          ..ad = '${metinOku(k['malzeme'])} / ${metinOku(k['birim'])}';
        s.gelen.text = _sayi(k['kalan']);
        s.kabul.text = _sayi(k['kalan']);
        s.fiyat.text = _sayi(k['birim_fiyat']);
        _satirlar.add(s);
      }
    } else {
      _satirlar.add(_MkSatir());
    }
  }

  String _sayi(dynamic x) {
    final d = sayiOku(x);
    if (d == d.roundToDouble()) return '${d.round()}';
    return d.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  }

  void _durumYaz(String s, [bool? ok]) => setState(() {
        _durum = s;
        _durumOk = ok;
      });

  // ── tedarikçi seçilince: katalog fiyatları + satıcı bilgileri ──
  Future<void> _tedarikciSec(int? tid) async {
    setState(() {
      _ted = tid;
      _katalog = {};
    });
    if (tid == null) {
      for (final k in ['fb_satici_ad', 'fb_satici_vkn', 'fb_satici_vd', 'fb_satici_adres']) {
        _c(k).clear();
      }
      _durumYaz('');
      return;
    }
    final c = await saAl(context, '/mal-kabul/tedarikci-katalog', q: {'tedarikci_id': '$tid'});
    if (c == null || !mounted) return;
    final kat = <int, Map<String, dynamic>>{for (final k in liste(c.j['katalog'])) tamOku(k['malzeme_id']): k};
    final td = harita(c.j['tedarikci']);
    setState(() {
      _katalog = kat;
      _c('fb_satici_ad').text = metinOku(td['ad']);
      _c('fb_satici_vkn').text = metinOku(td['vkn']);
      _c('fb_satici_vd').text = metinOku(td['vergi_dairesi']);
      _c('fb_satici_adres').text = metinOku(td['adres']);
      for (final s in _satirlar) {
        _katalogDoldur(s);
      }
    });
    _durumYaz(kat.isNotEmpty ? 'Bu tedarikçiden ${kat.length} ürün biliniyor — malzeme seçince fiyatı otomatik gelir.' : 'Bu tedarikçiden henüz alış kaydı yok; fiyatları elle girin.', kat.isNotEmpty ? true : null);
  }

  void _katalogDoldur(_MkSatir s) {
    final k = _katalog[s.mid];
    if (k == null) return;
    if (s.fiyat.text.trim().isEmpty && sayiOku(k['fiyat']) > 0) s.fiyat.text = _sayi(k['fiyat']);
    if (tamOku(k['birim_id']) > 0) s.birim = tamOku(k['birim_id']);
  }

  void _malzemeSec(_MkSatir s, int? mid) {
    s.mid = mid;
    s.okunanAd = '';
    final m = _malz.firstWhere((x) => tamOku(x['id']) == mid, orElse: () => const {});
    if (tamOku(m['temel_birim_id']) > 0) s.birim = tamOku(m['temel_birim_id']);
    _katalogDoldur(s);
  }

  _MkSatir _bosSatirYaDaYeni() {
    for (final s in _satirlar) {
      if (!s.siparisten && s.mid == null) return s;
    }
    final s = _MkSatir();
    _satirlar.add(s);
    return s;
  }

  // ── barkod ──
  Future<void> _barkodKamera() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Mal Kabul — Barkod Okut');
    if (kod != null && kod.trim().isNotEmpty) await _barkodCoz(kod);
  }

  Future<void> _barkodCoz(String kod) async {
    kod = kod.trim();
    if (kod.isEmpty) return;
    _durumYaz('Barkod aranıyor…');
    final c = await saAl(context, '/mal-kabul/barkod-coz', q: {'kod': kod});
    if (c == null || !mounted) return;
    final j = c.j;
    if ((j['ok'] == 1 || j['ok'] == true) && tamOku(j['bulundu']) == 1) {
      _barkodEkle(j);
      _durumYaz('Eklendi: ${j['ad']}', true);
    } else if (j['bulundu'] == 0 && metinOku(j['barkod']).isNotEmpty) {
      await _barkodBagla(metinOku(j['barkod']));
    } else {
      _durumYaz(metinOku(j['hata'], 'Barkod bulunamadı'), false);
    }
  }

  void _barkodEkle(Map<String, dynamic> j) {
    setState(() {
      final s = _bosSatirYaDaYeni();
      _malzemeSec(s, tamOku(j['id']));
      if (sayiOku(j['maliyet']) > 0 && s.fiyat.text.trim().isEmpty) s.fiyat.text = _sayi(j['maliyet']);
    });
  }

  Future<void> _barkodBagla(String kod) async {
    _durumYaz('Yeni barkod — bu ürünün hangi malzeme olduğunu seçin.');
    final mid = await kAltSayfa<int>(context, baslik: 'Barkod $kod tanımlı değil — bu hangi malzeme?', icerik: (c) => _MalzemeListe(malzemeler: _malz));
    if (mid == null || !mounted) return;
    final c = await saGonder(context, '/mal-kabul/barkod-bagla', {'kod': kod, 'malzeme_id': mid}, sessiz: true);
    if (c?.ok == true && mounted) {
      _barkodEkle(c!.j);
      _durumYaz('Bağlandı ve eklendi: ${c.j['ad']} — bu barkod bundan sonra hep tanınır.', true);
    }
  }

  // ── fotoğraf → AI ──
  Future<void> _fotoCek(ImageSource kaynak) async {
    final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, maxHeight: 1600, imageQuality: 82);
    if (x == null || !mounted) return;
    final b = await x.readAsBytes();
    _durumYaz('Fotoğraf okunuyor (AI)… birkaç saniye');
    if (!mounted) return;
    final c = await saGonder(context, '/mal-kabul/foto-oku', {'resim': base64Encode(b), 'mime': 'image/jpeg'}, sessiz: true, hataSessiz: true);
    if (c == null || !mounted) return;
    final j = c.j;
    if (!c.ok) return _durumYaz(saHata(c), false);
    void yaz(String k, dynamic d) {
      if (metinOku(d).isNotEmpty) _c(k).text = metinOku(d);
    }

    setState(() {
      _foto = b;
      yaz('irsaliye_no', j['irsaliye_no']);
      if (metinOku(j['tarih']).length >= 10) _tarih = metinOku(j['tarih']).substring(0, 10);
      yaz('ara_toplam', j['ara_toplam']);
      yaz('kdv_tutar', j['kdv_tutar']);
      yaz('genel_toplam', j['genel_toplam']);
      yaz('fb_seri', j['seri']);
      yaz('fb_sira', metinOku(j['sira_no']).isNotEmpty ? j['sira_no'] : j['irsaliye_no']);
      if (metinOku(j['sevk_tarihi']).isNotEmpty) _sevk = metinOku(j['sevk_tarihi']);
      yaz('fb_saat', j['saat']);
      yaz('fb_teslim_eden', j['teslim_eden']);
      final sat = harita(j['satici']), ali = harita(j['alici']);
      yaz('fb_satici_ad', metinOku(sat['ad']).isNotEmpty ? sat['ad'] : j['tedarikci_ad']);
      yaz('fb_satici_vkn', sat['vkn']);
      yaz('fb_satici_vd', sat['vergi_dairesi']);
      yaz('fb_satici_adres', sat['adres']);
      yaz('fb_alici_ad', ali['ad']);
      yaz('fb_alici_vkn', ali['vkn']);
      yaz('fb_alici_vd', ali['vergi_dairesi']);
      yaz('fb_alici_adres', ali['adres']);
      _satirlar.removeWhere((s) => !s.siparisten && s.mid == null && s.gelen.text.trim().isEmpty);
      for (final k in liste(j['kalemler'])) {
        final s = _MkSatir();
        if (k['malzeme_id'] != null) _malzemeSec(s, tamOku(k['malzeme_id']));
        if (tamOku(k['birim_id']) > 0) s.birim = tamOku(k['birim_id']);
        if (k['miktar'] != null) {
          s.gelen.text = _sayi(k['miktar']);
          s.kabul.text = _sayi(k['miktar']);
        }
        if (k['birim_fiyat'] != null) s.fiyat.text = _sayi(k['birim_fiyat']);
        if (k['malzeme_id'] == null) s.okunanAd = metinOku(k['ad']);
        _satirlar.add(s);
      }
      if (!_satirlar.any((s) => !s.siparisten) && _siparis.isEmpty) _satirlar.add(_MkSatir());
    });
    if (j['tedarikci_id'] != null) await _tedarikciSec(tamOku(j['tedarikci_id']));
    final kal = liste(j['kalemler']);
    final eksik = kal.where((k) => k['malzeme_id'] == null).length;
    _durumYaz('${kal.length} kalem okundu${eksik > 0 ? ' · $eksik tanesi eşleşmedi (kırmızı, elle seçin)' : ''} — miktar/fiyatı kontrol edin.', eksik > 0 ? null : true);
  }

  // ── VKN / yasal kontrol (web ile aynı algoritma) ──
  bool _vknGecerli(String v) {
    v = v.replaceAll(RegExp(r'\D'), '');
    if (v.length == 10) {
      final son = int.parse(v[9]);
      var top = 0;
      for (var i = 0; i < 9; i++) {
        final d = int.parse(v[i]);
        final t = (d + (9 - i)) % 10;
        int us(int a, int b) {
          var r = 1;
          for (var j = 0; j < b; j++) {
            r *= a;
          }
          return r;
        }

        top += t == 9 ? t : (t * us(2, 9 - i)) % 9;
      }
      return ((10 - (top % 10)) % 10) == son;
    }
    if (v.length == 11) {
      if (v[0] == '0') return false;
      final d = v.split('').map(int.parse).toList();
      final tek = d[0] + d[2] + d[4] + d[6] + d[8], cift = d[1] + d[3] + d[5] + d[7];
      final h10 = ((tek * 7) - cift + 100) % 10;
      final h11 = d.sublist(0, 10).reduce((a, b) => a + b) % 10;
      return h10 == d[9] && h11 == d[10];
    }
    return false;
  }

  bool get _yasalVar =>
      ['ara_toplam', 'genel_toplam', 'kdv_tutar'].any((k) => sayiOku(_c(k).text) > 0) ||
      ['fb_satici_vkn', 'fb_alici_vkn', 'fb_satici_ad', 'fb_alici_ad', 'fb_sira'].any((k) => _c(k).text.trim().isNotEmpty);

  List<String> _yasalSorunlar() {
    final s = <String>[];
    for (final (k, ad) in [('fb_satici_vkn', 'Satıcı'), ('fb_alici_vkn', 'Alıcı')]) {
      final x = _c(k).text.trim();
      if (x.isNotEmpty && !_vknGecerli(x)) s.add('$ad VKN/TCKN geçersiz');
    }
    final ara = sayiOku(_c('ara_toplam').text), kdv = sayiOku(_c('kdv_tutar').text), gen = sayiOku(_c('genel_toplam').text);
    final esik = gen * 0.01 > 1 ? gen * 0.01 : 1;
    if (ara > 0 && gen > 0 && ((ara + kdv) - gen).abs() > esik) s.add('Ara toplam + KDV (${tl(ara + kdv)}) ≠ Genel toplam (${tl(gen)})');
    return s;
  }

  double get _kalemToplam => _satirlar.fold(0.0, (a, s) => a + sayiOku(s.gelen.text) * sayiOku(s.fiyat.text));

  Future<void> _kaydet() async {
    final sip = _satirlar.where((s) => s.siparisten).toList();
    if (_siparis.isNotEmpty) {
      final eksik = sip.where((s) => s.kontrol == null).length;
      if (eksik > 0) return kToast(context, '$eksik kalem henüz kontrol edilmedi. Her kalemi (Tam/Eksik/Fazla/Hasarlı) işaretleyin.', hata: true);
    }
    final kal = <Map<String, dynamic>>[];
    for (final s in _satirlar) {
      final gelen = sayiOku(s.gelen.text);
      final kabul = sayiOku(s.kabul.text) > 0 ? sayiOku(s.kabul.text) : gelen;
      if (s.mid == null || kabul <= 0) continue;
      var sebep = '';
      if (s.kontrol != null && s.kontrol != 'tam') {
        final ad = _kontrolDurum.firstWhere((x) => x.$1 == s.kontrol).$2;
        sebep = ad + (s.sebep.text.trim().isNotEmpty ? ': ${s.sebep.text.trim()}' : '');
      }
      kal.add({
        'malzeme_id': s.mid, 'alis_birim_id': s.birim, 'siparis_kalem_id': s.skId, 'siparis_miktar': s.sipMik, 'gelen': gelen, 'kabul': kabul,
        'red': gelen - kabul > 0 ? gelen - kabul : 0, 'red_sebep': sebep, 'birim_fiyat': sayiOku(s.fiyat.text), 'lot_no': s.lot.text.trim(), 'skt': s.skt,
      });
    }
    if (kal.isEmpty) return kToast(context, 'Kabul edilen en az bir kalem girin.', hata: true);
    if (_yasalVar) {
      final so = _yasalSorunlar();
      if (so.isNotEmpty) return kToast(context, 'Fatura bilgilerinde hata var: ${so.join(' · ')}. Düzeltmeden kaydedemezsiniz.', hata: true);
      if (!_onay) return kToast(context, 'Kaydetmeden önce "Kontrol ettim" kutusunu işaretleyin.', hata: true);
    }
    setState(() => _gonderiyor = true);
    final govde = <String, dynamic>{
      'kalemler': jsonEncode(kal),
      'irsaliye_no': _c('irsaliye_no').text.trim(),
      'tarih': _tarih,
      'fb_sevk_tarihi': _sevk,
      'ara_toplam': _c('ara_toplam').text.trim().isEmpty ? '' : sayiOku(_c('ara_toplam').text),
      'kdv_tutar': _c('kdv_tutar').text.trim().isEmpty ? '' : sayiOku(_c('kdv_tutar').text),
      'genel_toplam': _c('genel_toplam').text.trim().isEmpty ? '' : sayiOku(_c('genel_toplam').text),
      'notlar': _c('notlar').text.trim(),
      'tedarikci_id': _ted ?? '',
      if (_siparis.isNotEmpty) 'siparis_id': _siparis['id'],
      for (final k in ['fb_seri', 'fb_sira', 'fb_saat', 'fb_satici_ad', 'fb_satici_vkn', 'fb_satici_vd', 'fb_satici_adres', 'fb_alici_ad', 'fb_alici_vkn', 'fb_alici_vd', 'fb_alici_adres', 'fb_teslim_eden'])
        k: _c(k).text.trim(),
    };
    final c = await saGonder(context, '/mal-kabul/olustur', govde, json: false, sessiz: true);
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c == null || !c.ok) return;
    final y = metinOku(c.j['yonlendir']);
    if (!y.startsWith('/mal-kabul-detay')) {
      kToast(context, metinOku(c.j['hata'], 'Mal kabul kaydedilemedi.'), hata: true);
      return;
    }
    kToast(context, 'Mal kabul kaydedildi, stok güncellendi.');
    final id = int.tryParse(Uri.parse(y).queryParameters['id'] ?? '');
    if (id != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => MalKabulDetayScreen(id: id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kabuller = liste(v['kabuller']);
    final acik = liste(v['acikSiparisler']);
    final sp = _siparis;
    final sipSatir = _satirlar.where((s) => s.siparisten).toList();
    final isaretli = sipSatir.where((s) => s.kontrol != null).length;
    final sorun = _yasalSorunlar();
    final ara = sayiOku(_c('ara_toplam').text);
    final kt = _kalemToplam;
    return KGovde(maxGenislik: 1000, children: [
      KKart(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MalKabulListeScreen())),
        child: KSatir(
          cizgi: false,
          solIkon: KIkon(Icons.history, renk: t.mor1),
          baslik: 'Son Mal Kabuller',
          alt: kabuller.isEmpty ? 'Henüz mal kabul yok.' : '${kabuller.length} kayıt · en son ${tarihYaz(kabuller.first['tarih'], saat: false)}',
          sag: Text('Tümünü gör', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
        ),
      ),
      if (acik.isNotEmpty && sp.isEmpty)
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Teslim bekleyen siparişten mal kabul (${acik.length})', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
            Text('Bir siparişi seçin; kalemler ve kalan miktarlar hazır gelir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 8),
            KSecim<String>('Sipariş', deger: null, secenekler: [
              for (final s in acik)
                ('${s['id']}', '${metinOku(s['siparis_no'])} · ${metinOku(s['tedarikci'])}${metinOku(s['beklenen_teslim']).isNotEmpty ? ' · teslim ${tarihYaz(s['beklenen_teslim'], saat: false)}' : ''}'),
            ], onSec: (x) => widget.siparisSec(x)),
          ]),
        ),
      KBaslik(sp.isNotEmpty ? 'Mal Kabul · ${sp['siparis_no']}' : 'Yeni Mal Kabul', ikon: Icons.inventory_outlined, renk: t.yesil,
          sag: sp.isNotEmpty ? TextButton(onPressed: () => widget.siparisSec(null), child: const Text('Serbest Giriş')) : null),
      if (sp.isEmpty)
        KKart(
          renk: t.mor1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Hızlı Doldur', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
            Text('Barkod okutun (bedava, sınırsız) — en hızlısı. Barkodsuz faturada fotoğraf çekin (AI okur). İkisinde de siz kontrol edip onaylarsınız.', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              KButon('Kamerayla barkod', ikon: Icons.qr_code_scanner, onTap: _barkodKamera),
              KButon('İrsaliye/Fatura fotoğrafı', ikon: Icons.photo_camera_outlined, renk: t.mavi, onTap: () => _fotoCek(ImageSource.camera)),
              KButon('Galeriden seç', ikon: Icons.photo_library_outlined, ikincil: true, onTap: () => _fotoCek(ImageSource.gallery)),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _barkodK,
              decoration: const InputDecoration(hintText: 'Barkod okuyucu (USB/Bluetooth) ile okutun + Enter', prefixIcon: Icon(Icons.qr_code), isDense: true),
              onSubmitted: (s) {
                _barkodK.clear();
                _barkodCoz(s);
              },
            ),
            if (_durum.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_durum, style: TextStyle(color: _durumOk == true ? t.yesil : (_durumOk == false ? t.kirmizi : t.sub2), fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            if (_foto != null) ...[
              const SizedBox(height: 8),
              Text('Okunan fotoğraf — bilgileri bununla karşılaştırın (büyütmek için dokunun):', style: TextStyle(color: t.sub, fontSize: 12)),
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => showDialog(context: context, builder: (c) => Dialog(child: InteractiveViewer(child: Image.memory(_foto!)))),
                child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_foto!, height: 260, fit: BoxFit.contain)),
              ),
            ],
          ]),
        ),
      // Başlık alanları
      if (sp.isEmpty)
        KSecim<int>('Tedarikçi', deger: _ted, secenekler: [for (final x in liste(v['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: _tedarikciSec)
      else
        SaDeger('Sipariş', metinOku(sp['siparis_no']), kalin: true),
      Row(children: [
        Expanded(child: KAlan('İrsaliye No', _c('irsaliye_no'))),
        const SizedBox(width: 8),
        Expanded(
          child: KSatir(baslik: 'Tarih', alt: tarihYaz(_tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
            final s = await saTarihSec(context, ilk: _tarih);
            if (s != null) setState(() => _tarih = s);
          }),
        ),
      ]),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text('İrsaliye / Fatura Bilgileri', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
        subtitle: Text('Fotoğraftan otomatik gelir; yasal veri olduğu için MUTLAKA kontrol edin.', style: TextStyle(color: t.sub, fontSize: 12)),
        initiallyExpanded: _foto != null,
        children: [
          Row(children: [
            Expanded(child: KAlan('Seri', _c('fb_seri'), ipucu: 'A')),
            const SizedBox(width: 8),
            Expanded(child: KAlan('Sıra No', _c('fb_sira'), ipucu: '000123')),
          ]),
          Row(children: [
            Expanded(
              child: KSatir(baslik: 'Sevk Tarihi', alt: _sevk.isEmpty ? 'Seçilmedi' : tarihYaz(_sevk, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
                final s = await saTarihSec(context, ilk: _sevk);
                if (s != null) setState(() => _sevk = s);
              }),
            ),
            const SizedBox(width: 8),
            Expanded(child: KAlan('Saat', _c('fb_saat'), ipucu: '05:30')),
          ]),
          Text('Satıcı (Tedarikçi)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          KAlan('Ünvan / Ad Soyad', _c('fb_satici_ad')),
          Row(children: [
            Expanded(child: _vknAlan('VKN / TCKN', 'fb_satici_vkn', t)),
            const SizedBox(width: 8),
            Expanded(child: KAlan('Vergi Dairesi', _c('fb_satici_vd'))),
          ]),
          KAlan('Adres', _c('fb_satici_adres')),
          Text('Alıcı (Müşteri / İşletme)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          KAlan('Ünvan / Ad Soyad', _c('fb_alici_ad')),
          Row(children: [
            Expanded(child: _vknAlan('VKN / TCKN', 'fb_alici_vkn', t)),
            const SizedBox(width: 8),
            Expanded(child: KAlan('Vergi Dairesi', _c('fb_alici_vd'))),
          ]),
          KAlan('Adres', _c('fb_alici_adres')),
          KAlan('Malı Teslim Eden (Ad Soyad)', _c('fb_teslim_eden')),
        ],
      ),
      KBaslik('Gelen Kalemler', ikon: Icons.inventory_2_outlined, renk: t.yesil,
          sag: sp.isEmpty ? TextButton.icon(onPressed: () => setState(() => _satirlar.add(_MkSatir())), icon: const Icon(Icons.add), label: const Text('Kalem Ekle')) : null),
      if (sp.isNotEmpty)
        SaBilgi('Sipariş ile karşılaştırın — her kalemi işaretleyin. Hepsi işaretlenmeden kabul onaylanmaz.  $isaretli / ${sipSatir.length} işaretlendi',
            renk: isaretli >= sipSatir.length ? t.yesil : t.kirmizi, ikon: Icons.fact_check_outlined),
      if (sp.isNotEmpty && sipSatir.isEmpty) const KBos(baslik: 'Bu siparişte kalem yok', aciklama: 'Sipariş detayından kalem ekleyip tekrar deneyin.'),
      for (var i = 0; i < _satirlar.length; i++) _satirKart(i, t),
      // Toplamlar
      KKart(
        renk: t.mavi,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Fatura Toplamları', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          Text('İrsaliye/fatura fotoğrafından otomatik gelir; elle de düzeltebilirsiniz.', style: TextStyle(color: t.sub, fontSize: 12)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _tutarAlan('Ara Toplam (KDV hariç)', 'ara_toplam')),
            const SizedBox(width: 8),
            Expanded(child: _tutarAlan('KDV', 'kdv_tutar')),
            const SizedBox(width: 8),
            Expanded(child: _tutarAlan('Genel Toplam', 'genel_toplam')),
          ]),
          Builder(builder: (_) {
            String m;
            Color r = t.ink;
            if (ara > 0) {
              final fark = kt - ara;
              if (fark.abs() / ara * 100 <= 1) {
                m = 'Kalemlerin toplamı (miktar × fiyat) = ${tl(kt)} — faturadaki Ara Toplam ile uyuşuyor.';
                r = t.yesil;
              } else {
                m = 'Kalemlerin toplamı = ${tl(kt)}, ama faturada Ara Toplam ${tl(ara)} yazıyor. ${tl(fark.abs())} fark var — bir kalemin miktarı/fiyatı ya da fatura tutarı hatalı.';
                r = t.kirmizi;
              }
            } else {
              m = 'Kalemlerin toplamı (miktar × fiyat): ${tl(kt)}';
            }
            return Text(m, style: TextStyle(color: r, fontWeight: FontWeight.w700, fontSize: 13));
          }),
          if (sorun.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Dikkat: ${sorun.join(' · ')} — düzeltmeden kaydedemezsiniz', style: TextStyle(color: t.kirmizi, fontSize: 12.5, fontWeight: FontWeight.w700))),
        ]),
      ),
      KAlan('Not (opsiyonel)', _c('notlar'), ipucu: 'Mal kabul notu'),
      if (_yasalVar)
        CheckboxListTile(
          value: _onay,
          onChanged: (b) => setState(() => _onay = b == true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text('Kontrol ettim: fatura bilgileri (tutarlar, VKN, tarih, kalemler) fotoğrafla aynı ve doğru. Onaylıyorum.', style: TextStyle(color: t.ink, fontSize: 13)),
        ),
      const SizedBox(height: 6),
      KButon('Mal Kabulü Onayla (Stok Gir)', ikon: Icons.check_circle_outline, renk: t.yesil, genis: true, yukleniyor: _gonderiyor,
          onTap: sp.isNotEmpty && isaretli < sipSatir.length ? null : _kaydet),
    ]);
  }

  Widget _vknAlan(String etiket, String k, TemaProvider t) {
    final x = _c(k).text.trim();
    final hatali = x.isNotEmpty && !_vknGecerli(x);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Focus(onFocusChange: (_) => setState(() {}), child: KAlan(etiket, _c(k), klavye: TextInputType.number)),
      if (hatali) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Geçersiz VKN/TCKN', style: TextStyle(color: t.kirmizi, fontSize: 12))),
    ]);
  }

  Widget _tutarAlan(String etiket, String k) =>
      Focus(onFocusChange: (_) => setState(() {}), child: KAlan(etiket, _c(k), klavye: const TextInputType.numberWithOptions(decimal: true), ipucu: '0,00'));

  Widget _satirKart(int i, TemaProvider t) {
    final s = _satirlar[i];
    final sip = s.siparisten;
    final gelen = sayiOku(s.gelen.text);
    Widget? fark;
    if (sip) {
      final d = ((gelen - (s.sipMik ?? 0)) * 1000).round() / 1000;
      fark = KRozet(d == 0 ? 'Tam (${sayiYaz(s.sipMik)})' : (d < 0 ? 'Eksik ${sayiYaz(-d)}' : 'Fazla ${sayiYaz(d)}'), renk: d == 0 ? t.yesil : (d < 0 ? t.amber : t.mavi));
    }
    return KKart(
      renk: sip ? (s.kontrol == null ? t.kirmizi : _kontrolDurum.firstWhere((x) => x.$1 == s.kontrol).$4) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (sip)
          Row(children: [
            Expanded(child: Text(s.ad, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            Text('Sipariş: ${sayiYaz(s.sipMik)}', style: TextStyle(color: t.sub, fontSize: 12.5)),
          ])
        else
          Row(children: [
            Expanded(
              child: KSecim<int>(s.okunanAd.isNotEmpty ? 'Malzeme (fotoğrafta "${s.okunanAd}" okundu — elle seçin)' : 'Malzeme', deger: s.mid,
                  secenekler: [for (final m in _malz) (tamOku(m['id']), metinOku(m['ad']))], onSec: (x) => setState(() => _malzemeSec(s, x))),
            ),
            IconButton(tooltip: 'Satırı sil', onPressed: () => setState(() => _satirlar.removeAt(i)), icon: Icon(Icons.close, color: t.sub)),
          ]),
        if (!sip)
          KSecim<int>('Birim', deger: s.birim == 0 ? null : s.birim, secenekler: [for (final b in _birim) (tamOku(b['id']), metinOku(b['kisaltma'], metinOku(b['ad'])))], onSec: (x) => setState(() => s.birim = x ?? 0)),
        Row(children: [
          Expanded(child: Focus(onFocusChange: (_) => setState(() {}), child: KAlan('Gelen', s.gelen, klavye: const TextInputType.numberWithOptions(decimal: true)))),
          const SizedBox(width: 8),
          Expanded(child: KAlan('Kabul', s.kabul, klavye: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 8),
          Expanded(child: Focus(onFocusChange: (_) => setState(() {}), child: KAlan('Birim Fiyat ₺', s.fiyat, klavye: const TextInputType.numberWithOptions(decimal: true)))),
        ]),
        Row(children: [
          Expanded(child: KAlan('Lot / Parti No', s.lot, ipucu: 'boş geçebilirsiniz')),
          const SizedBox(width: 8),
          Expanded(
            child: KSatir(baslik: 'Son Kullanma', alt: s.skt.isEmpty ? 'boş geçebilirsiniz' : tarihYaz(s.skt, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final x = await saTarihSec(context, ilk: s.skt);
              if (x != null) setState(() => s.skt = x);
            }),
          ),
        ]),
        if (sip) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ?fark,
            Text('Kontrol:', style: TextStyle(color: t.sub, fontSize: 12.5)),
            for (final (k, ad, ik, r) in _kontrolDurum)
              ChoiceChip(
                avatar: Icon(ik, size: 16, color: s.kontrol == k ? Colors.white : r),
                label: Text(ad, style: TextStyle(color: s.kontrol == k ? Colors.white : t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                selected: s.kontrol == k,
                selectedColor: r,
                showCheckmark: false,
                onSelected: (_) => setState(() => s.kontrol = k),
              ),
          ]),
          if (s.kontrol != null && s.kontrol != 'tam') Padding(padding: const EdgeInsets.only(top: 8), child: KAlan('Açıklama (hasar/eksik nedeni)', s.sebep)),
        ],
      ]),
    );
  }
}

class _MalzemeListe extends StatefulWidget {
  final List<Map<String, dynamic>> malzemeler;
  const _MalzemeListe({required this.malzemeler});
  @override
  State<_MalzemeListe> createState() => _MalzemeListeState();
}

class _MalzemeListeState extends State<_MalzemeListe> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = widget.malzemeler.where((m) => saIcerir(metinOku(m['ad']), _q)).take(120).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SaBilgi('Bir kez bağlayın; bu ürünün barkodu bundan sonra hep otomatik tanınır.'),
      KAra(ipucu: 'Malzeme ara…', onDegis: (s) => setState(() => _q = s)),
      for (final m in l) KSatir(baslik: metinOku(m['ad']), onTap: () => Navigator.pop(context, tamOku(m['id']))),
    ]);
  }
}

// ───────────────────────── Son mal kabuller (/mal-kabul-liste) ─────────────────────────
class MalKabulListeScreen extends StatefulWidget {
  const MalKabulListeScreen({super.key});
  @override
  State<MalKabulListeScreen> createState() => _MalKabulListeScreenState();
}

class _MalKabulListeScreenState extends State<MalKabulListeScreen> {
  String _ara = '';
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/mal-kabul-liste',
      baslik: 'Son Mal Kabuller',
      ikon: Icons.history,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['kabuller']).where((m) => saIcerir('${m['irsaliye_no']} ${m['tedarikci']}', _ara)).toList();
        return KGovde(yenile: yenile, children: [
          KAra(ipucu: 'İrsaliye no veya tedarikçi ara…', onDegis: (s) => setState(() => _ara = s)),
          if (l.isEmpty)
            const KBos(baslik: 'Mal kabul kaydı yok', aciklama: 'Gelen malı Mal Kabul ekranından girin; kayıtlar burada listelenir ve stok otomatik işlenir.', ikon: Icons.inventory_outlined)
          else
            SaIzgara([
              for (final m in l)
                KKart(
                  renk: t.yesil,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MalKabulDetayScreen(id: tamOku(m['id'])))),
                  child: KSatir(
                    cizgi: false,
                    baslik: metinOku(m['tedarikci'], '—'),
                    alt: 'İrsaliye: ${metinOku(m['irsaliye_no'], '—')} · ${tarihYaz(m['tarih'], saat: false)}${m['siparis_id'] != null ? ' · siparişten' : ''}',
                    sag: sayiOku(m['genel_toplam']) > 0 ? Text(tl(m['genel_toplam']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)) : const Icon(Icons.chevron_right),
                  ),
                ),
            ], minGenislik: 420),
        ]);
      },
    );
  }
}

// ───────────────────────── Mal kabul detayı (/mal-kabul-detay) ─────────────────────────
class MalKabulDetayScreen extends StatelessWidget {
  final int id;
  const MalKabulDetayScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/mal-kabul-detay',
      q: {'id': '$id'},
      baslik: 'Mal Kabul Detayı',
      ikon: Icons.inventory_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final m = harita(v['m']);
        if (m.isEmpty) return const KBos(baslik: 'Mal kabul bulunamadı', aciklama: 'Kayıt silinmiş ya da başka şubeye ait olabilir.');
        final kal = liste(v['kalemler']);
        final ted = harita(v['tedarikci']);
        final sp = harita(v['siparis']);
        final redVar = kal.any((k) => sayiOku(k['red_miktar']) > 0);
        return KGovde(yenile: yenile, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            KRozet('Stok işlendi', renk: t.yesil, ikon: Icons.check),
            if (sp.isNotEmpty) KButon('Sipariş: ${sp['siparis_no']}', ikon: Icons.receipt_long_outlined, ikincil: true, onTap: () => saAc(ctx, '/satinalma-siparis-detay?id=${sp['id']}', 'Sipariş Detayı')),
          ]),
          const SizedBox(height: 10),
          KKpiIzgara([
            KKpi(etiket: 'Tedarikçi', deger: metinOku(ted['ad'], '—'), ikon: Icons.storefront_outlined, renk: t.mor1),
            KKpi(etiket: 'İrsaliye No / Tarih', deger: metinOku(m['irsaliye_no'], '—'), alt: tarihYaz(m['tarih'], saat: false), ikon: Icons.receipt_outlined, renk: t.mavi),
            KKpi(etiket: 'Kalem', deger: '${kal.length}', alt: redVar ? 'Reddedilen kalem var' : null, ikon: Icons.inventory_2_outlined, renk: redVar ? t.kirmizi : t.yesil),
          ]),
          KBaslik('Gelen Kalemler', ikon: Icons.inventory_2_outlined, renk: t.yesil),
          if (kal.isEmpty) const KBos(baslik: 'Kalem yok')
          else
            KKart(
              child: KTablo(
                basliklar: const ['Malzeme', 'Sipariş', 'Gelen', 'Kabul', 'Red', 'Birim Fiyat', 'Lot', 'SKT'],
                sagaYasla: const {1, 2, 3, 4, 5},
                satirlar: [
                  for (final k in kal)
                    [
                      '${metinOku(k['malzeme'])} / ${metinOku(k['birim'])}',
                      k['siparis_miktar'] != null ? sayiYaz(k['siparis_miktar']) : '—',
                      sayiYaz(k['gelen_miktar']),
                      sayiYaz(k['kabul_miktar']),
                      sayiOku(k['red_miktar']) > 0 ? '${sayiYaz(k['red_miktar'])}${metinOku(k['red_sebep']).isNotEmpty ? ' (${k['red_sebep']})' : ''}' : '—',
                      tl(k['birim_fiyat']),
                      metinOku(k['lot_no'], '—'),
                      metinOku(k['skt']).isEmpty ? '—' : tarihYaz(k['skt'], saat: false),
                    ],
                ],
              ),
            ),
          if (metinOku(m['notlar']).isNotEmpty) SaBilgi('Not: ${m['notlar']}', ikon: Icons.sticky_note_2_outlined),
          KKart(
            renk: t.amber,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Fatura geldiğinde', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
              Text('3\'lü eşleştirin: sipariş ↔ irsaliye ↔ fatura. Fiyat / miktar farkı varsa otomatik yakalanır.', style: TextStyle(color: t.sub, fontSize: 12.5)),
              const SizedBox(height: 8),
              KButon('Faturayı Eşleştir', ikon: Icons.fact_check_outlined, renk: t.amber, onTap: () => saAc(ctx, '/fatura-eslestir?mal_kabul_id=${m['id']}', 'Fatura Eşleştir')),
            ]),
          ),
        ]);
      },
    );
  }
}
