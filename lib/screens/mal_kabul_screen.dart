import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';
import 'barkod_tarayici.dart';

/// Mal Kabul (GRN) — açık sipariş veya serbest; gelen/kabul/red + lot/SKT + barkod.
/// Kabul edilen miktar anında stoğa + partiye (FEFO) işlenir. Veri /api/patron/mal-kabul-*.
class MalKabulScreen extends StatefulWidget {
  const MalKabulScreen({super.key});
  @override
  State<MalKabulScreen> createState() => _MalKabulScreenState();
}

const _mavi = Color(0xFF0EA5E9);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _turuncu = Color(0xFFF59E0B);
const _mor = Color(0xFF7C3AED);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';
String _mik(dynamic v) => NumberFormat('#,##0.###', 'tr').format(_n(v));

class _MalKabulScreenState extends State<MalKabulScreen> {
  bool loading = true;
  List kabuller = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.malKabulListe(auth.token!);
      if (!mounted) return;
      setState(() {
        kabuller = res['ok'] == 1 ? ((res['kabuller'] as List?) ?? []) : [];
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _yeni() async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const _YeniMalKabulScreen()));
    if (degisti == true) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Mal Kabul',
      ikon: Icons.inventory_outlined,
      geri: true,
      altBaslik: 'İrsaliye · gelen/kabul/red',
      araclar: [MButon('Yeni', _mavi, _yeni, ikon: Icons.add)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : kabuller.isEmpty
              ? ListView(children: [
                  const SizedBox(height: 90),
                  const Icon(Icons.inventory_outlined, size: 54, color: _mavi),
                  const SizedBox(height: 10),
                  Center(child: Text('Henüz mal kabul yok', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 6),
                  Center(child: Text('Gelen irsaliyeyi “Yeni Mal Kabul” ile kaydet.', style: TextStyle(color: t.sub))),
                ])
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(padding: const EdgeInsets.all(14), children: [for (final m in kabuller) _kart(t, m)]),
                ),
    );
  }

  Widget _kart(TemaProvider t, dynamic m) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _MalKabulDetayScreen(id: _n(m['id']).toInt()))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _mavi.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_outlined, color: _mavi, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${m['tedarikci']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text('${m['tarih']}${(m['irsaliye_no']?.toString().isNotEmpty ?? false) ? ' · İrs. ${m['irsaliye_no']}' : ''}', style: TextStyle(color: t.sub2, fontSize: 11.5)),
            ]),
          ),
          if (m['genel_toplam'] != null)
            Text(_p(m['genel_toplam']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}

// ======================= DETAY =======================
class _MalKabulDetayScreen extends StatefulWidget {
  final int id;
  const _MalKabulDetayScreen({required this.id});
  @override
  State<_MalKabulDetayScreen> createState() => _MalKabulDetayScreenState();
}

class _MalKabulDetayScreenState extends State<_MalKabulDetayScreen> {
  bool loading = true;
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malKabulDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        data = res['ok'] == 1 ? res : null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final mk = (data?['mk'] as Map?) ?? {};
    final kalemler = (data?['kalemler'] as List?) ?? [];
    return MasaustuSayfa(
      baslik: 'Mal Kabul #${widget.id}',
      ikon: Icons.inventory_outlined,
      geri: true,
      altBaslik: loading ? '' : '${mk['tedarikci']} · ${mk['tarih']}',
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : data == null
              ? Center(child: Text('Yüklenemedi', style: TextStyle(color: t.sub)))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _satir(t, 'Tedarikçi', '${mk['tedarikci']}'),
                      if ((mk['irsaliye_no']?.toString().isNotEmpty ?? false)) _satir(t, 'İrsaliye No', '${mk['irsaliye_no']}'),
                      _satir(t, 'Tarih', '${mk['tarih']}'),
                      if (mk['genel_toplam'] != null) _satir(t, 'Genel Toplam', _p(mk['genel_toplam'])),
                      if ((mk['notlar']?.toString().isNotEmpty ?? false)) _satir(t, 'Not', '${mk['notlar']}'),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text('Kalemler (${kalemler.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  for (final k in kalemler) _kalemKart(t, k),
                  const SizedBox(height: 24),
                ]),
    );
  }

  Widget _satir(TemaProvider t, String b, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 110, child: Text(b, style: TextStyle(color: t.sub2, fontSize: 12.5))),
          Expanded(child: Text(v, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _kalemKart(TemaProvider t, dynamic k) {
    final red = _n(k['red']).toDouble();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: red > 0 ? _kirmizi.withValues(alpha: 0.3) : t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${k['malzeme']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
          Text('${_p(k['birim_fiyat'])}/${k['birim']}', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          MRozet('Gelen ${_mik(k['gelen'])}', _mavi),
          MRozet('Kabul ${_mik(k['kabul'])}', _yesil),
          if (red > 0) MRozet('Red ${_mik(k['red'])}', _kirmizi),
          if ((k['lot_no']?.toString().isNotEmpty ?? false)) MRozet('Lot ${k['lot_no']}', _mor),
          if ((k['skt']?.toString().isNotEmpty ?? false)) MRozet('SKT ${k['skt']}', _turuncu),
        ]),
        if ((k['red_sebep']?.toString().isNotEmpty ?? false)) ...[
          const SizedBox(height: 4),
          Text('Red: ${k['red_sebep']}', style: const TextStyle(color: _kirmizi, fontSize: 11)),
        ],
      ]),
    );
  }
}

// ======================= YENİ MAL KABUL =======================
class _YeniMalKabulScreen extends StatefulWidget {
  const _YeniMalKabulScreen();
  @override
  State<_YeniMalKabulScreen> createState() => _YeniMalKabulScreenState();
}

class _Kalem {
  int malzemeId;
  int birimId;
  final gelen = TextEditingController();
  final kabul = TextEditingController();
  final red = TextEditingController();
  final fiyat = TextEditingController();
  final lot = TextEditingController();
  final redSebep = TextEditingController();
  String? skt;
  int? siparisKalemId;
  double? siparisMiktar;
  _Kalem(this.malzemeId, this.birimId);
  void dispose() {
    gelen.dispose();
    kabul.dispose();
    red.dispose();
    fiyat.dispose();
    lot.dispose();
    redSebep.dispose();
  }
}

class _YeniMalKabulScreenState extends State<_YeniMalKabulScreen> {
  bool loading = true, kaydediliyor = false, fotoOkunuyor = false, faturaAcik = false;
  List acikSiparisler = [], malzemeler = [], birimler = [], tedarikciler = [];
  int? siparisId, tedarikciId;
  final Map<int, Map> _katalog = {}; // malzeme_id -> {fiyat, birim_id} (secili tedarikciden)
  final _irsaliye = TextEditingController();
  final _notlar = TextEditingController();
  String _tarih = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final List<_Kalem> kalemler = [];
  // İrsaliye / Fatura Bilgileri (foto-OCR ile dolar, elle düzeltilir)
  final _seri = TextEditingController(), _sira = TextEditingController(), _sevkTarihi = TextEditingController(), _saat = TextEditingController();
  final _saticiAd = TextEditingController(), _saticiVkn = TextEditingController(), _saticiVd = TextEditingController(), _saticiAdres = TextEditingController();
  final _aliciAd = TextEditingController(), _aliciVkn = TextEditingController(), _aliciVd = TextEditingController(), _aliciAdres = TextEditingController();
  final _teslimEden = TextEditingController();
  final _araToplam = TextEditingController(), _kdvTutar = TextEditingController(), _genelToplam = TextEditingController();

  @override
  void initState() {
    super.initState();
    _meta();
  }

  Future<void> _meta({int? spid}) async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.malKabulListe(auth.token!, siparisId: spid);
      if (!mounted) return;
      if (res['ok'] == 1) {
        acikSiparisler = (res['acik_siparisler'] as List?) ?? [];
        malzemeler = (res['malzemeler'] as List?) ?? [];
        birimler = (res['birimler'] as List?) ?? [];
        tedarikciler = (res['tedarikciler'] as List?) ?? [];
        if (spid != null) {
          final sk = (res['siparis_kalem'] as List?) ?? [];
          for (final c in kalemler) {
            c.dispose();
          }
          kalemler.clear();
          for (final k in sk) {
            final kalem = _Kalem(_n(k['malzeme_id']).toInt(), _n(k['alis_birim_id']).toInt());
            kalem.siparisKalemId = _n(k['siparis_kalem_id']).toInt();
            kalem.siparisMiktar = _n(k['siparis_miktar']).toDouble();
            kalem.gelen.text = _mik(k['kalan']);
            kalem.kabul.text = _mik(k['kalan']);
            kalem.fiyat.text = '${_n(k['birim_fiyat'])}';
            kalemler.add(kalem);
          }
        }
      }
      setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _birimKis(int id) {
    final b = birimler.cast<Map>().where((x) => _n(x['id']).toInt() == id);
    return b.isEmpty ? '' : '${b.first['ad']}';
  }

  void _kalemEkle({int? malzemeId}) {
    if (malzemeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce Stok ekranından malzeme ekleyin.')));
      return;
    }
    final id = malzemeId ?? _n((malzemeler.first as Map)['id']).toInt();
    final bid = _n((malzemeler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == id, orElse: () => malzemeler.first as Map))['birim_id']).toInt();
    final k = _Kalem(id, bid);
    _katalogUygula(k);
    setState(() => kalemler.add(k));
  }

  // Secili tedarikcinin bilinen fiyatini bir kaleme uygula (fiyat bossa doldur, alis birimini getir).
  void _katalogUygula(_Kalem k) {
    final c = _katalog[k.malzemeId];
    if (c == null) return;
    if (k.fiyat.text.trim().isEmpty && _n(c['fiyat']) > 0) k.fiyat.text = '${_n(c['fiyat'])}';
    final bid = _n(c['birim_id']).toInt();
    if (bid > 0) k.birimId = bid;
  }

  // Tedarikci secilince o tedarikcinin bilinen malzeme fiyatlarini cek.
  Future<void> _katalogCek(int? tid) async {
    _katalog.clear();
    if (tid == null || tid == 0) return;
    try {
      final r = await Api.tedarikciKatalog(context.read<AuthProvider>().token!, tid);
      if (!mounted) return;
      if (r['ok'] == 1) {
        for (final k in (r['katalog'] as List? ?? [])) {
          _katalog[_n((k as Map)['malzeme_id']).toInt()] = {'fiyat': _n(k['fiyat']), 'birim_id': _n(k['birim_id']).toInt()};
        }
        // Satici (tedarikci) bilgilerini doldur (bossa)
        final td = r['tedarikci'] as Map?;
        if (td != null) {
          void dl(TextEditingController c, dynamic v) { if (c.text.trim().isEmpty && v != null && '$v'.isNotEmpty) c.text = '$v'; }
          dl(_saticiAd, td['ad']); dl(_saticiVkn, td['vkn']); dl(_saticiVd, td['vergi_dairesi']); dl(_saticiAdres, td['adres']);
        }
        for (final k in kalemler) { _katalogUygula(k); }
        setState(() {});
        final n = _katalog.length;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          n > 0 ? 'Bu tedarikçiden $n ürün biliniyor — malzeme seçince fiyat otomatik gelir.' : 'Bu tedarikçiden henüz alış kaydı yok; fiyatları elle gir.')));
      }
    } catch (_) {}
  }

  Future<void> _barkod() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Mal Kabul — Barkod Okut');
    if (kod == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    final r = await Api.malKabulBarkod(auth.token!, kod);
    if (!mounted) return;
    if (r['ok'] == 1) {
      final id = _n(r['id']).toInt();
      if (!malzemeler.any((m) => _n((m as Map)['id']).toInt() == id)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['ad']} malzeme listesinde yok — Stok\'tan ekleyin')));
        return;
      }
      _kalemEkle(malzemeId: id);
    } else if (_n(r['bulundu']).toInt() == 0 && r['barkod'] != null) {
      _barkodBagla('${r['barkod']}'); // tanimsiz -> oracikta malzemeye bagla
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['hata'] ?? 'Barkod tanımlı değil'}')));
    }
  }

  // Bilinmeyen barkodu malzemeye bagla (ekran degistirmeden) -> bir kez bagla, hep taninir.
  Future<void> _barkodBagla(String kod) async {
    if (malzemeler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Önce Stok ekranından malzeme ekleyin.')));
      return;
    }
    final t = context.read<TemaProvider>();
    int sec = _n((malzemeler.first as Map)['id']).toInt();
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Barkod tanımlı değil', style: TextStyle(color: t.ink, fontSize: 16)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('"$kod" — bu hangi malzeme? Bir kez bağla, bundan sonra hep otomatik tanınır.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 12),
          DropdownButton<int>(
            value: sec, isExpanded: true, dropdownColor: t.card, style: TextStyle(color: t.ink, fontSize: 13.5),
            items: [for (final m in malzemeler) DropdownMenuItem(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) { if (v != null) setD(() => sec = v); },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('İptal', style: TextStyle(color: t.sub))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Bağla ve Ekle')),
        ],
      )),
    );
    if (onay != true || !mounted) return;
    final r = await Api.malKabulBarkodBagla(context.read<AuthProvider>().token!, kod, sec);
    if (!mounted) return;
    if (r['ok'] == 1) {
      _kalemEkle(malzemeId: _n(r['id']).toInt());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bağlandı: ${r['ad']} — bundan sonra hep tanınır.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['hata'] ?? 'Bağlanamadı'}')));
    }
  }

  // İrsaliye/fatura FOTOĞRAFI -> AI okur -> tüm alanları doldurur (web ile birebir).
  Future<void> _foto() async {
    final t = context.read<TemaProvider>();
    final kaynak = await showModalBottomSheet<ImageSource>(
      useRootNavigator: true,
      context: context,
      backgroundColor: t.card,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: Icon(Icons.photo_camera, color: t.ink), title: Text('Kamera', style: TextStyle(color: t.ink)), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(leading: Icon(Icons.photo_library, color: t.ink), title: Text('Galeri', style: TextStyle(color: t.ink)), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (kaynak == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, imageQuality: 82);
      if (x == null || !mounted) return;
      setState(() => fotoOkunuyor = true);
      final bytes = await x.readAsBytes();
      final b64 = base64Encode(bytes);
      final mime = x.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      final r = await Api.malKabulFotoOku(auth.token!, resim: b64, mime: mime);
      if (!mounted) return;
      setState(() => fotoOkunuyor = false);
      if (r['ok'] != 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['hata'] ?? 'Okunamadı'}')));
        return;
      }
      _ocrDoldur(r);
      final say = ((r['kalemler'] as List?) ?? []).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Foto okundu: $say kalem geldi. Kontrol et.')));
    } catch (e) {
      if (mounted) {
        setState(() => fotoOkunuyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf işlenemedi / zaman aşımı.')));
      }
    }
  }

  void _ocrDoldur(Map r) {
    String s(dynamic v) => (v == null) ? '' : v.toString();
    final satici = (r['satici'] as Map?) ?? {};
    final alici = (r['alici'] as Map?) ?? {};
    setState(() {
      faturaAcik = true;
      // Tedarikçi eşleştiyse seç
      final tid = r['tedarikci_id'];
      if (tid != null && tedarikciler.any((x) => _n((x as Map)['id']).toInt() == _n(tid).toInt())) {
        tedarikciId = _n(tid).toInt();
        siparisId = null;
      }
      if (s(r['irsaliye_no']).isNotEmpty) _irsaliye.text = s(r['irsaliye_no']);
      if (s(r['tarih']).isNotEmpty) _tarih = s(r['tarih']);
      _seri.text = s(r['seri']);
      _sira.text = s(r['sira_no']);
      _sevkTarihi.text = s(r['sevk_tarihi']);
      _saat.text = s(r['saat']);
      _saticiAd.text = s(satici['ad']);
      _saticiVkn.text = s(satici['vkn']);
      _saticiVd.text = s(satici['vergi_dairesi']);
      _saticiAdres.text = s(satici['adres']);
      _aliciAd.text = s(alici['ad']);
      _aliciVkn.text = s(alici['vkn']);
      _aliciVd.text = s(alici['vergi_dairesi']);
      _aliciAdres.text = s(alici['adres']);
      _teslimEden.text = s(r['teslim_eden']);
      if (r['ara_toplam'] != null) _araToplam.text = '${r['ara_toplam']}';
      if (r['kdv_tutar'] != null) _kdvTutar.text = '${r['kdv_tutar']}';
      if (r['genel_toplam'] != null) _genelToplam.text = '${r['genel_toplam']}';
      // Kalemler: eşleşen malzemeleri ekle (eşleşmeyenler uyarıyla atlanır)
      final kal = (r['kalemler'] as List?) ?? [];
      int atlanan = 0;
      for (final k in kal) {
        final mid = k['malzeme_id'];
        if (mid == null || !malzemeler.any((m) => _n((m as Map)['id']).toInt() == _n(mid).toInt())) {
          atlanan++;
          continue;
        }
        final id = _n(mid).toInt();
        final bid = (k['birim_id'] != null)
            ? _n(k['birim_id']).toInt()
            : _n((malzemeler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == id))['birim_id']).toInt();
        final kalem = _Kalem(id, bid);
        if (k['miktar'] != null) {
          kalem.gelen.text = _mik(k['miktar']);
          kalem.kabul.text = _mik(k['miktar']);
        }
        if (k['birim_fiyat'] != null) kalem.fiyat.text = '${k['birim_fiyat']}';
        kalemler.add(kalem);
      }
      if (atlanan > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$atlanan kalem stokta bulunamadı, atlandı (Stok\'tan ekleyip tekrar deneyebilirsin).')));
        });
      }
    });
  }

  double get _toplam {
    double t = 0;
    for (final k in kalemler) {
      final kabul = double.tryParse(k.kabul.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0;
      t += kabul * f;
    }
    return t;
  }

  // VKN (10 hane) / TCKN (11 hane) checksum — web ile ayni.
  bool _vknGecerli(String v) {
    v = v.replaceAll(RegExp(r'\D'), '');
    if (v.length == 10) {
      int son = int.parse(v[9]), top = 0;
      for (int i = 0; i < 9; i++) { int d = int.parse(v[i]); int tt = (d + (9 - i)) % 10; top += (tt == 9) ? tt : (tt * (1 << (9 - i))) % 9; }
      return ((10 - (top % 10)) % 10) == son;
    }
    if (v.length == 11) {
      if (v[0] == '0') return false;
      final d = v.split('').map(int.parse).toList();
      final tek = d[0] + d[2] + d[4] + d[6] + d[8], cift = d[1] + d[3] + d[5] + d[7];
      final h10 = ((tek * 7) - cift + 100) % 10;
      final h11 = (d.sublist(0, 10).reduce((a, b) => a + b)) % 10;
      return h10 == d[9] && h11 == d[10];
    }
    return false;
  }

  Future<void> _kaydet() async {
    if (kalemler.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('En az bir kalem ekleyin.')));
      return;
    }
    // Yasal veri: VKN girilmisse ve gecersizse kaydettirme (en ufak hata olmasin).
    for (final e in {'Satıcı': _saticiVkn.text, 'Alıcı': _aliciVkn.text}.entries) {
      final v = e.value.trim();
      if (v.isNotEmpty && !_vknGecerli(v)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.key} VKN/TCKN geçersiz — düzeltmeden kaydedemezsin.'), backgroundColor: _kirmizi));
        return;
      }
    }
    final liste = <Map<String, dynamic>>[];
    for (final k in kalemler) {
      final gelen = double.tryParse(k.gelen.text.replaceAll(',', '.')) ?? 0;
      final kabul = double.tryParse(k.kabul.text.replaceAll(',', '.')) ?? gelen;
      final red = double.tryParse(k.red.text.replaceAll(',', '.')) ?? 0;
      final f = double.tryParse(k.fiyat.text.replaceAll(',', '.')) ?? 0;
      if (gelen <= 0 && kabul <= 0) continue;
      liste.add({
        'malzeme_id': k.malzemeId,
        'alis_birim_id': k.birimId,
        'gelen': gelen,
        'kabul': kabul,
        'red': red,
        'red_sebep': k.redSebep.text.trim(),
        'birim_fiyat': f,
        'lot_no': k.lot.text.trim(),
        'skt': k.skt ?? '',
        'siparis_kalem_id': k.siparisKalemId ?? 0,
        'siparis_miktar': k.siparisMiktar ?? 0,
      });
    }
    if (liste.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli miktar girin.')));
      return;
    }
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.malKabulOlustur(auth.token!, {
        'tedarikci_id': '${tedarikciId ?? ''}',
        'siparis_id': '${siparisId ?? ''}',
        'irsaliye_no': _irsaliye.text.trim(),
        'tarih': _tarih,
        'notlar': _notlar.text.trim(),
        'kalemler': jsonEncode(liste),
        // İrsaliye / Fatura Bilgileri (web ile birebir alan adları)
        'fb_seri': _seri.text.trim(),
        'fb_sira': _sira.text.trim(),
        'fb_sevk_tarihi': _sevkTarihi.text.trim(),
        'fb_saat': _saat.text.trim(),
        'fb_satici_ad': _saticiAd.text.trim(),
        'fb_satici_vkn': _saticiVkn.text.trim(),
        'fb_satici_vd': _saticiVd.text.trim(),
        'fb_satici_adres': _saticiAdres.text.trim(),
        'fb_alici_ad': _aliciAd.text.trim(),
        'fb_alici_vkn': _aliciVkn.text.trim(),
        'fb_alici_vd': _aliciVd.text.trim(),
        'fb_alici_adres': _aliciAdres.text.trim(),
        'fb_teslim_eden': _teslimEden.text.trim(),
        'ara_toplam': _araToplam.text.trim(),
        'kdv_tutar': _kdvTutar.text.trim(),
        'genel_toplam': _genelToplam.text.trim(),
      });
      if (!mounted) return;
      setState(() => kaydediliyor = false);
      if (res['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mal kabul kaydedildi, stok güncellendi.')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${res['hata'] ?? 'Hata'}')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => kaydediliyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası.')));
      }
    }
  }

  @override
  void dispose() {
    for (final c in kalemler) {
      c.dispose();
    }
    _irsaliye.dispose();
    _notlar.dispose();
    for (final c in [_seri, _sira, _sevkTarihi, _saat, _saticiAd, _saticiVkn, _saticiVd, _saticiAdres, _aliciAd, _aliciVkn, _aliciVd, _aliciAdres, _teslimEden, _araToplam, _kdvTutar, _genelToplam]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Yeni Mal Kabul',
      ikon: Icons.add_box_outlined,
      geri: true,
      altBaslik: 'İrsaliye gir · gelen/kabul/red',
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: ListView(padding: const EdgeInsets.all(14), children: [
                  // Hızlı doldur: Foto (AI) + Barkod
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _mor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _mor.withValues(alpha: 0.3)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.bolt, color: _mor, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Hızlı doldur', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.bold))),
                      ]),
                      const SizedBox(height: 3),
                      Text('İrsaliye/fatura fotoğrafını çek → AI okur, alanları doldurur. Barkod bedava/sınırsız.', style: TextStyle(color: t.sub2, fontSize: 11)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: fotoOkunuyor
                              ? Container(
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: _mor.withValues(alpha: 0.4))),
                                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _mor)),
                                    SizedBox(width: 8), Text('AI okuyor…', style: TextStyle(color: _mor, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                  ]),
                                )
                              : _hizliBtn(t, Icons.photo_camera, 'Fotoğraf Oku', _mor, _foto),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _hizliBtn(t, Icons.qr_code_scanner, 'Barkod Okut', _mavi, _barkod)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // Açık sipariş seç
                  if (acikSiparisler.isNotEmpty) ...[
                    _etiket(t, 'Açık Siparişten Doldur (opsiyonel)'),
                    _kutu(t, DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: siparisId,
                        isExpanded: true,
                        dropdownColor: t.card,
                        hint: Text('Sipariş seçin', style: TextStyle(color: t.sub)),
                        style: TextStyle(color: t.ink, fontSize: 13.5),
                        items: [
                          DropdownMenuItem(value: null, child: Text('— Serbest (siparişsiz) —', style: TextStyle(color: t.sub))),
                          for (final s in acikSiparisler)
                            DropdownMenuItem(value: _n(s['id']).toInt(), child: Text('${s['siparis_no'] ?? s['id']} · ${s['tedarikci']}', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) {
                          setState(() {
                            siparisId = v;
                            if (v != null) {
                              final s = acikSiparisler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == v);
                              tedarikciId = _n(s['tedarikci_id']).toInt();
                            }
                          });
                          if (v != null) _meta(spid: v);
                        },
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],
                  // Tedarikçi (sipariş yoksa)
                  if (siparisId == null) ...[
                    _etiket(t, 'Tedarikçi'),
                    _kutu(t, DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: tedarikciId,
                        isExpanded: true,
                        dropdownColor: t.card,
                        hint: Text('Tedarikçi seçin (opsiyonel)', style: TextStyle(color: t.sub)),
                        style: TextStyle(color: t.ink, fontSize: 13.5),
                        items: [
                          DropdownMenuItem(value: null, child: Text('— Seçilmedi —', style: TextStyle(color: t.sub))),
                          for (final s in tedarikciler) DropdownMenuItem(value: _n(s['id']).toInt(), child: Text('${s['ad']}', overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) { setState(() => tedarikciId = v); _katalogCek(v); },
                      ),
                    )),
                    const SizedBox(height: 10),
                  ],
                  Row(children: [
                    Expanded(child: _alan(t, _irsaliye, 'İrsaliye No')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(_tarih) ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                          if (d != null) setState(() => _tarih = DateFormat('yyyy-MM-dd').format(d));
                        },
                        child: _kutu(t, Row(children: [
                          Icon(Icons.calendar_today, size: 16, color: t.sub),
                          const SizedBox(width: 8),
                          Text(_tarih, style: TextStyle(color: t.ink, fontSize: 13.5)),
                        ])),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  // İrsaliye / Fatura Bilgileri (katlanır) — foto-OCR doldurur, yasal veri
                  _faturaBolumu(t),
                  const SizedBox(height: 14),
                  Row(children: [
                    Text('Kalemler (${kalemler.length})', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(onPressed: () => _kalemEkle(), icon: const Icon(Icons.add, size: 18, color: _mavi), label: const Text('Kalem', style: TextStyle(color: _mavi))),
                  ]),
                  const SizedBox(height: 4),
                  for (int i = 0; i < kalemler.length; i++) _kalemKart(t, i),
                  const SizedBox(height: 10),
                  _alan(t, _notlar, 'Not (opsiyonel)', satir: 2),
                  const SizedBox(height: 70),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
                child: Row(children: [
                  Expanded(child: Text('Kabul tutarı: ${_p(_toplam)}', style: const TextStyle(color: _mavi, fontSize: 15, fontWeight: FontWeight.bold))),
                  if (kaydediliyor)
                    const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    MButon('Kaydet & Stoğa Al', _yesil, _kaydet, ikon: Icons.check),
                ]),
              ),
            ]),
    );
  }

  Widget _etiket(TemaProvider t, String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600)));

  Widget _hizliBtn(TemaProvider t, IconData ikon, String yazi, Color renk, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: renk.withValues(alpha: 0.4))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ikon, color: renk, size: 17),
            const SizedBox(width: 6),
            Flexible(child: Text(yazi, overflow: TextOverflow.ellipsis, style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.w600))),
          ]),
        ),
      );

  Widget _faturaBolumu(TemaProvider t) {
    final dolu = [_seri, _sira, _sevkTarihi, _saat, _saticiAd, _saticiVkn, _aliciAd, _teslimEden, _genelToplam].any((c) => c.text.trim().isNotEmpty);
    return Container(
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => faturaAcik = !faturaAcik),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.receipt_long_outlined, size: 18, color: t.sub),
              const SizedBox(width: 8),
              Expanded(child: Text('İrsaliye / Fatura Bilgileri', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
              if (dolu && !faturaAcik) const Padding(padding: EdgeInsets.only(right: 6), child: MRozet('dolu', _yesil)),
              Icon(faturaAcik ? Icons.expand_less : Icons.expand_more, color: t.sub),
            ]),
          ),
        ),
        if (faturaAcik)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(children: [
              Row(children: [
                Expanded(child: _alan(t, _seri, 'Seri')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _sira, 'Sıra No')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _alan(t, _sevkTarihi, 'Sevk Tarihi (YYYY-AA-GG)')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _saat, 'Saat')),
              ]),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Satıcı (Tedarikçi)', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              _alan(t, _saticiAd, 'Ünvan / Ad Soyad'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _alan(t, _saticiVkn, 'VKN / TCKN')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _saticiVd, 'Vergi Dairesi')),
              ]),
              const SizedBox(height: 8),
              _alan(t, _saticiAdres, 'Adres'),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Alıcı (İşletme)', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              _alan(t, _aliciAd, 'Ünvan / Ad Soyad'),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _alan(t, _aliciVkn, 'VKN / TCKN')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _aliciVd, 'Vergi Dairesi')),
              ]),
              const SizedBox(height: 8),
              _alan(t, _aliciAdres, 'Adres'),
              const SizedBox(height: 8),
              _alan(t, _teslimEden, 'Malı Teslim Eden (Ad Soyad)'),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Tutarlar', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: _alan(t, _araToplam, 'Ara Toplam')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _kdvTutar, 'KDV')),
                const SizedBox(width: 8),
                Expanded(child: _alan(t, _genelToplam, 'Genel Toplam')),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _kutu(TemaProvider t, Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
        child: child,
      );

  Widget _alan(TemaProvider t, TextEditingController c, String label, {int satir = 1}) => TextField(
        controller: c,
        maxLines: satir,
        style: TextStyle(color: t.ink, fontSize: 13.5),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.sub, fontSize: 12),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mavi)),
        ),
      );

  Widget _kalemKart(TemaProvider t, int i) {
    final k = kalemler[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: k.malzemeId,
                isExpanded: true,
                dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600),
                items: [for (final m in malzemeler) DropdownMenuItem(value: _n(m['id']).toInt(), child: Text('${m['ad']}', overflow: TextOverflow.ellipsis))],
                onChanged: k.siparisKalemId != null ? null : (v) {
                  if (v == null) return;
                  setState(() {
                    k.malzemeId = v;
                    k.birimId = _n((malzemeler.cast<Map>().firstWhere((x) => _n(x['id']).toInt() == v))['birim_id']).toInt();
                    _katalogUygula(k); // secili tedarikci fiyatini otomatik getir
                  });
                },
              ),
            ),
          ),
          Text(_birimKis(k.birimId), style: TextStyle(color: t.sub, fontSize: 12)),
          IconButton(icon: const Icon(Icons.close, size: 18, color: _kirmizi), onPressed: () => setState(() => kalemler.removeAt(i))),
        ]),
        if (k.siparisMiktar != null && k.siparisMiktar! > 0)
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Sipariş: ${_mik(k.siparisMiktar)} ${_birimKis(k.birimId)}', style: TextStyle(color: t.sub2, fontSize: 11))),
        Row(children: [
          Expanded(child: _mini(t, k.gelen, 'Gelen', onChanged: () {
            if (k.kabul.text.isEmpty) k.kabul.text = k.gelen.text;
          })),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.kabul, 'Kabul', onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.red, 'Red')),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _mini(t, k.fiyat, 'Birim Fiyat', onChanged: () => setState(() {}))),
          const SizedBox(width: 8),
          Expanded(child: _mini(t, k.lot, 'Lot No', sayi: false)),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.tryParse(k.skt ?? '') ?? DateTime.now().add(const Duration(days: 30)), firstDate: DateTime(2020), lastDate: DateTime(2040));
                if (d != null) setState(() => k.skt = DateFormat('yyyy-MM-dd').format(d));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                child: Row(children: [
                  Icon(Icons.event_busy, size: 14, color: k.skt != null ? _turuncu : t.sub2),
                  const SizedBox(width: 6),
                  Expanded(child: Text(k.skt ?? 'SKT', style: TextStyle(color: k.skt != null ? t.ink : t.sub2, fontSize: 12), overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ),
          ),
        ]),
        if ((double.tryParse(k.red.text.replaceAll(',', '.')) ?? 0) > 0) ...[
          const SizedBox(height: 8),
          _mini(t, k.redSebep, 'Red sebebi', sayi: false),
        ],
      ]),
    );
  }

  Widget _mini(TemaProvider t, TextEditingController c, String label, {bool sayi = true, VoidCallback? onChanged}) => TextField(
        controller: c,
        keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: t.ink, fontSize: 13),
        onChanged: onChanged == null ? null : (_) => onChanged(),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: t.sub2, fontSize: 11),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mavi)),
        ),
      );
}
