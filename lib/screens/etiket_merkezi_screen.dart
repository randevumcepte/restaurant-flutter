import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import '../services/etiket_yazici.dart';
import '../ui/masaustu_kit.dart';
import 'barkod_tarayici.dart';
import 'demirbas_screen.dart';
import '../moduller/stok/etiket_sablon_screen.dart';

/// BARKOD & ETİKET MERKEZİ — web /barkod-etiket ile aynı veri ve uçlar (/api/etiket-merkezi/*).
/// Etiketli ürünler (menüye bağlı ya da bağımsız) · paket etiketi (üretim/SKT/parti) · tartı etiketi
/// (terazi barkodu) · raf kartı (fiyat değişince yenilenecekler) · demirbaş (ayrı ekran) · ayarlar.
/// Uygulama ZPL/TSPL ağ yazıcısına doğrudan basar; yoksa fiş yazıcısına. A4 raf kartı ve kendi
/// tasarımlı etiket web'den (bilgisayardan yazdır) basılır.
class EtiketMerkeziScreen extends StatefulWidget {
  const EtiketMerkeziScreen({super.key});
  @override
  State<EtiketMerkeziScreen> createState() => _EtiketMerkeziScreenState();
}

const _emMor = Color(0xFF6366F1);
const _emYesil = Color(0xFF059669);
const _emKirmizi = Color(0xFFDC2626);
const _emAmber = Color(0xFFD97706);
const _emMavi = Color(0xFF0EA5E9);
const _emTurRenk = <String, Color>{'paket': Color(0xFF6366F1), 'tarti': Color(0xFF10B981), 'raf': Color(0xFFF59E0B)};
const _emTurAd = <String, String>{'paket': 'Paket etiketi', 'tarti': 'Tartılı', 'raf': 'Raf kartı'};

final _emFmt = NumberFormat('#,##0.00', 'tr');
num _emN(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
String _emS(dynamic v) => v?.toString() ?? '';
String _emTl(dynamic v) => '${_emFmt.format(_emN(v))} ₺';
bool _emOk(Map r) => r['ok'] == true || r['ok'] == 1;
String _emMesaj(Map r, String yedek) {
  final m = _emS(r['mesaj']).isNotEmpty ? _emS(r['mesaj']) : _emS(r['hata']);
  return m.isEmpty ? yedek : m;
}
String _emNorm(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
String _emSayi(dynamic v) {
  if (v == null || _emS(v).isEmpty) return '';
  final n = _emN(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString().replaceAll('.', ',');
}
List<String> _emTurler(Map u) => ((u['turler'] as List?) ?? const []).map((e) => e.toString()).toList();

void _emBildir(BuildContext context, String mesaj, {bool hata = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: hata ? _emKirmizi : _emYesil, behavior: SnackBarBehavior.floating));
}

Future<Map<String, dynamic>?> _emCagir(BuildContext context, Future<Map<String, dynamic>> Function(String token) f) async {
  final auth = context.read<AuthProvider>();
  try {
    return await f(auth.token ?? '');
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  } catch (_) {
    if (context.mounted) _emBildir(context, 'Bağlantı hatası. Tekrar deneyin.', hata: true);
    return null;
  }
}

InputDecoration _emDekor(TemaProvider t, String etiket, {String? ipucu, Widget? sonEk, String? yardim}) => InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      helperText: yardim,
      helperMaxLines: 3,
      isDense: true,
      suffixIcon: sonEk,
      labelStyle: TextStyle(color: t.sub),
      hintStyle: TextStyle(color: t.sub, fontSize: 12.5),
      helperStyle: TextStyle(color: t.sub, fontSize: 11.5),
      filled: true,
      fillColor: t.card2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
    );

/// Sunucunun hazırladığı basım cevabını yazıcıya gönderir: ZPL/TSPL → ağ yazıcısı, değilse fiş yazıcısı.
Future<String> _emYaziciyaGonder(Map r) async {
  final komut = _emS(r['komut']);
  final dil = _emS(r['dil']);
  if ((dil == 'zpl' || dil == 'tspl') && komut.isNotEmpty) {
    final port = _emN(r['port']).toInt();
    return EtiketYazici.hamGonder(_emS(r['ip']), port <= 0 ? 9100 : port, komut);
  }
  return EtiketYazici.fisYazicisinaBas((r['etiketler'] as List?) ?? const []);
}

String _emTarihStr(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String _emTarihGoster(String s) {
  final d = DateTime.tryParse(s);
  return d == null ? s : DateFormat('dd.MM.yyyy').format(d);
}

// =====================================================================================
class _EtiketMerkeziScreenState extends State<EtiketMerkeziScreen> {
  bool loading = true;
  String? hata;
  bool yetkisiz = false;
  Map<String, dynamic> v = {};
  String sekme = 'urunler'; // urunler | bas | tarti | raf
  final araC = TextEditingController();
  String ara = '';
  String turF = '';

  // paket bas
  int? basId;
  String basMod = 'tam';
  DateTime basUretim = DateTime.now();
  DateTime? basSkt;
  String? basBoyut;
  final basAdetC = TextEditingController(text: '1');
  // tartı
  int? tartiId;
  final gramC = TextEditingController();
  bool daraDus = true;
  final tartiAdetC = TextEditingController(text: '1');
  Map<String, dynamic>? cozSonuc;
  // raf
  final Set<int> rafSecili = {};
  bool rafSadeceBekleyen = true;
  bool islemde = false;

  List<Map<String, dynamic>> get _liste => ((v['liste'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  bool get duzenler => v['duzenler'] == true;
  Map get _ayar => (v['ayar'] as Map?) ?? const {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    araC.dispose();
    basAdetC.dispose();
    gramC.dispose();
    tartiAdetC.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => loading = true);
    final r = await _emCagir(context, (tok) => Api.etiketMerkeziListe(tok));
    if (!mounted) return;
    if (r == null) {
      setState(() { loading = false; hata ??= 'Bağlantı hatası.'; });
      return;
    }
    if (!_emOk(r)) {
      setState(() { loading = false; hata = _emMesaj(r, 'Yüklenemedi.'); yetkisiz = _emS(r['hata']).contains('yetki'); });
      return;
    }
    setState(() {
      v = r;
      loading = false;
      hata = null;
      final l = _liste;
      final paket = l.where((u) => _emTurler(u).contains('paket') && u['aktif'] == true).toList();
      final tarti = l.where((u) => _emTurler(u).contains('tarti') && u['aktif'] == true).toList();
      if (basId == null || !paket.any((u) => _emN(u['id']).toInt() == basId)) basId = paket.isEmpty ? null : _emN(paket.first['id']).toInt();
      if (tartiId == null || !tarti.any((u) => _emN(u['id']).toInt() == tartiId)) tartiId = tarti.isEmpty ? null : _emN(tarti.first['id']).toInt();
      basBoyut ??= _emS(_ayar['urun_boyut']).isEmpty ? '58x40' : _emS(_ayar['urun_boyut']);
      rafSecili
        ..clear()
        ..addAll(l.where((u) => u['raf_bekliyor'] == true).map((u) => _emN(u['id']).toInt()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);
    return MasaustuSayfa(
      baslik: 'Barkod & Etiket',
      ikon: Icons.qr_code_scanner,
      geri: true,
      altBaslik: 'Ürün etiketi · tartılı ürün · raf kartı · demirbaş',
      araclar: [
        if (duzenler) IconButton(onPressed: _ayarAc, tooltip: 'Ayarlar (yazıcı, terazi, raf kartı)', icon: Icon(Icons.settings_outlined, color: t.sub2)),
        IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: Icon(Icons.refresh, color: t.sub2)),
      ],
      govde: loading && v.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(padding: EdgeInsets.all(genis ? 20 : 12), children: _govde(t, genis)),
            ),
    );
  }

  List<Widget> _govde(TemaProvider t, bool genis) {
    if (hata != null) {
      return [
        _bosKutu(t, yetkisiz ? Icons.lock_outline : Icons.error_outline, yetkisiz ? _emAmber : _emKirmizi,
            yetkisiz ? 'Barkod & Etiket ekranını görme yetkin yok.' : hata!,
            alt: yetkisiz ? 'Patron veya müdür, Personel Yetkileri ekranından "Barkod & Etiket" yetkisini açabilir.' : null),
      ];
    }
    return [
      _sekmeCubugu(t),
      const SizedBox(height: 14),
      if (sekme == 'urunler') ..._urunler(t, genis),
      if (sekme == 'bas') ..._paketBas(t, genis),
      if (sekme == 'tarti') ..._tarti(t, genis),
      if (sekme == 'raf') ..._raf(t, genis),
      const SizedBox(height: 30),
    ];
  }

  Widget _bosKutu(TemaProvider t, IconData ikon, Color renk, String baslik, {String? alt, Widget? buton}) => MKart(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Icon(ikon, color: renk, size: 40),
          const SizedBox(height: 10),
          Text(baslik, textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          if (alt != null) ...[const SizedBox(height: 6), Text(alt, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5))],
          if (buton != null) ...[const SizedBox(height: 12), buton],
        ]),
      );

  Widget _sekmeCubugu(TemaProvider t) {
    final bekleyen = _emN(v['raf_bekleyen']).toInt();
    final sekmeler = [
      ('urunler', Icons.inventory_2_outlined, 'Ürünler', 0),
      ('bas', Icons.local_offer_outlined, 'Etiket Bas', 0),
      ('tarti', Icons.scale_outlined, 'Tartılı Ürün', 0),
      ('raf', Icons.style_outlined, 'Raf Kartı', bekleyen),
      ('tasarim', Icons.design_services_outlined, 'Tasarımlarım', 0),
      ('demirbas', Icons.handyman_outlined, 'Demirbaş', 0),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final s in sekmeler)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: sekme == s.$1 ? _emMor : t.card,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  if (s.$1 == 'demirbas') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DemirbasScreen()));
                    return;
                  }
                  if (s.$1 == 'tasarim') {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EtiketSablonScreen())).then((_) => _yukle());
                    return;
                  }
                  setState(() => sekme = s.$1);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: sekme == s.$1 ? _emMor : t.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.$2, size: 16, color: sekme == s.$1 ? Colors.white : t.sub2),
                    const SizedBox(width: 6),
                    Text(s.$3, style: TextStyle(color: sekme == s.$1 ? Colors.white : t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (s.$4 > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: _emKirmizi, borderRadius: BorderRadius.circular(9)),
                        child: Text('${s.$4}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _rozet(String metin, Color renk) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(metin, style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // =================== ÜRÜNLER ===================
  List<Widget> _urunler(TemaProvider t, bool genis) {
    final hepsi = _liste;
    final q = _emNorm(ara.trim());
    final l = hepsi.where((u) {
      if (turF.isNotEmpty && !_emTurler(u).contains(turF)) return false;
      if (q.isEmpty) return true;
      final s = _emNorm('${u['ad']} ${u['barkod'] ?? ''} ${u['plu'] != null ? 'plu${u['plu']} ${u['plu']}' : ''} ${u['kategori'] ?? ''} ${u['menu_ad'] ?? ''}');
      return s.contains(q);
    }).toList();
    return [
      Row(children: [
        Expanded(
          child: TextField(
            controller: araC,
            onChanged: (x) => setState(() => ara = x),
            style: TextStyle(color: t.ink),
            decoration: _emDekor(t, 'Ara', ipucu: 'Ürün adı, barkod ya da PLU',
                sonEk: IconButton(
                  tooltip: 'Barkod okut',
                  icon: Icon(Icons.qr_code_scanner, color: t.sub2),
                  onPressed: () async {
                    final k = await BarkodTarayici.oku(context, baslik: 'Ürün barkodu okut');
                    if (k == null || !mounted) return;
                    araC.text = k;
                    setState(() => ara = k);
                  },
                )),
          ),
        ),
        if (duzenler) ...[
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _emMor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
            onPressed: () => _formAc(null),
            icon: const Icon(Icons.add, size: 18),
            label: Text(genis ? 'Yeni Ürün' : 'Yeni'),
          ),
        ],
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final f in [('', 'Tümü'), ('paket', 'Paket etiketi'), ('tarti', 'Tartılı'), ('raf', 'Raf kartı')])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text('${f.$2} ${f.$1.isEmpty ? hepsi.length : hepsi.where((u) => _emTurler(u).contains(f.$1)).length}'),
                selected: turF == f.$1,
                onSelected: (_) => setState(() => turF = f.$1),
                selectedColor: _emMor.withValues(alpha: 0.18),
                labelStyle: TextStyle(color: turF == f.$1 ? _emMor : t.sub2, fontWeight: FontWeight.w700, fontSize: 12),
                backgroundColor: t.card,
                side: BorderSide(color: t.line),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      if (hepsi.isEmpty)
        _bosKutu(t, Icons.local_offer_outlined, _emMor, 'Henüz etiketli ürün yok',
            alt: 'Kasap köftesi, şarküteri peyniri, kendi ürettiğin şişelenmiş ürün… Ürünü bir kez tanımla; etiketi, raf kartı ve barkodu buradan basılır.',
            buton: duzenler ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: _emMor), onPressed: () => _formAc(null), icon: const Icon(Icons.add), label: const Text('İlk ürünü ekle')) : null)
      else if (l.isEmpty)
        _bosKutu(t, Icons.search_off, t.sub, 'Aramana uyan ürün yok')
      else
        for (final u in l) Padding(padding: const EdgeInsets.only(bottom: 8), child: _urunKart(t, u)),
    ];
  }

  Widget _urunKart(TemaProvider t, Map<String, dynamic> u) {
    final fb = (u['fb'] as Map?) ?? const {};
    final turler = _emTurler(u);
    final id = _emN(u['id']).toInt();
    final altlar = <String>[
      if (_emS(u['barkod']).isNotEmpty) '${u['barkod']} (${u['barkod_tip'] == 'resmi' ? 'resmi' : 'mağaza içi'})' else if (!turler.contains('tarti')) 'barkodsuz',
      if (u['plu'] != null) 'PLU ${u['plu']}',
      u['urun_id'] != null ? 'menü: ${u['menu_ad'] ?? '—'}' : 'menüde değil',
    ];
    return MKart(
      padding: const EdgeInsets.all(12),
      onTap: duzenler ? () => _formAc(u) : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: (u['urun_id'] != null ? _emMor : _emAmber).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(turler.contains('tarti') ? Icons.scale_outlined : (u['urun_id'] != null ? Icons.restaurant_menu : Icons.local_shipping_outlined),
              color: u['urun_id'] != null ? _emMor : _emAmber, size: 21),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_emS(u['ad']), style: TextStyle(color: u['aktif'] == true ? t.ink : t.sub, fontWeight: FontWeight.w800, fontSize: 14)),
            Text(altlar.join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5)),
            const SizedBox(height: 4),
            Row(children: [
              if (fb['indirimde'] == true) ...[
                Text(_emTl(fb['eski']), style: TextStyle(color: t.sub, fontSize: 11.5, decoration: TextDecoration.lineThrough)),
                const SizedBox(width: 6),
              ],
              Text(_emTl(fb['gecerli']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14.5)),
              if (u['birim'] != 'adet') Text(' / ${u['birim']}', style: TextStyle(color: t.sub, fontSize: 12)),
              if (fb['birim_fiyat'] != null && u['birim'] == 'adet')
                Flexible(child: Text('  · 1 ${fb['birim_ad']} ${_emTl(fb['birim_fiyat'])}', overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5))),
            ]),
            const SizedBox(height: 6),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final tr in turler) _rozet(_emTurAd[tr] ?? tr, _emTurRenk[tr] ?? t.sub),
              if (u['raf_bekliyor'] == true) _rozet('Raf kartı yenilenecek', _emKirmizi),
              if (fb['indirimde'] == true) _rozet('İndirimde', _emKirmizi),
              if (u['aktif'] != true) _rozet('Pasif', t.sub),
            ]),
          ]),
        ),
        Column(children: [
          if (turler.contains('paket'))
            IconButton(tooltip: 'Etiket bas', visualDensity: VisualDensity.compact, icon: Icon(Icons.local_offer_outlined, color: t.sub2, size: 20),
                onPressed: () => setState(() { basId = id; sekme = 'bas'; })),
          if (turler.contains('tarti'))
            IconButton(tooltip: 'Tartı etiketi', visualDensity: VisualDensity.compact, icon: Icon(Icons.scale_outlined, color: t.sub2, size: 20),
                onPressed: () => setState(() { tartiId = id; sekme = 'tarti'; })),
          if (turler.contains('raf'))
            IconButton(tooltip: 'Raf kartı bas', visualDensity: VisualDensity.compact, icon: Icon(Icons.style_outlined, color: t.sub2, size: 20), onPressed: () => _rafBas([id])),
        ]),
      ]),
    );
  }

  Future<void> _formAc(Map<String, dynamic>? u) async {
    final kaydedildi = await Navigator.of(context).push<bool>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _EtiketUrunForm(urun: u, menu: ((v['menu'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          sablonlar: ((v['sablonlar'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList()),
    ));
    if (kaydedildi == true) _yukle();
  }

  // =================== PAKET ETİKETİ BAS ===================
  List<Widget> _paketBas(TemaProvider t, bool genis) {
    final paket = _liste.where((u) => _emTurler(u).contains('paket') && u['aktif'] == true).toList();
    if (paket.isEmpty) {
      return [_bosKutu(t, Icons.inventory_2_outlined, _emMor, '"Paketli ürün etiketi" seçili ürün yok', alt: 'Ürünler sekmesinde ürün eklerken etiket türünü seç.')];
    }
    final u = paket.firstWhere((x) => _emN(x['id']).toInt() == basId, orElse: () => paket.first);
    final omur = _emN(u['raf_omru_gun']).toInt();
    final otoSkt = omur > 0 ? basUretim.add(Duration(days: omur)) : null;
    final boyutlar = ((v['urun_boyutlar'] as Map?) ?? const {'58x40': '58 × 40 mm'}).map((k, x) => MapEntry(k.toString(), x.toString()));
    final son = ((v['son_basimlar'] as List?) ?? const []).where((b) => (b as Map)['tur'] == 'paket').take(15).toList();
    final adlar = {for (final x in _liste) _emN(x['id']).toInt(): _emS(x['ad'])};
    return [
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Paketli ürün etiketi bas', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Üretim tarihini seç; SKT raf ömründen, parti numarası otomatik gelir. Her basım parti geçmişine yazılır.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _emN(u['id']).toInt(),
            isExpanded: true,
            dropdownColor: t.card,
            style: TextStyle(color: t.ink, fontSize: 13.5),
            decoration: _emDekor(t, 'Ürün'),
            items: [for (final x in paket) DropdownMenuItem(value: _emN(x['id']).toInt(), child: Text('${x['ad']} — ${_emTl((x['fb'] as Map?)?['gecerli'])}', overflow: TextOverflow.ellipsis))],
            onChanged: (x) => setState(() { basId = x; basSkt = null; }),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'tam', label: Text('Tam etiket'), icon: Icon(Icons.label_outline, size: 16)),
              ButtonSegment(value: 'kucuk', label: Text('Küçük tarih etiketi'), icon: Icon(Icons.event_outlined, size: 16)),
            ],
            selected: {basMod},
            onSelectionChanged: (s) => setState(() => basMod = s.first),
          ),
          const SizedBox(height: 4),
          Text(basMod == 'tam' ? 'Ad, net miktar, fiyat, tarih, parti ve barkod. Boş ambalaja yapıştırılır.' : 'Yalnız üretim, SKT ve parti. Matbaada basılmış etiketin üstüne yapıştırılır.',
              style: TextStyle(color: t.sub, fontSize: 11.5)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            _tarihKutu(t, 'Üretim tarihi', basUretim, (d) => setState(() => basUretim = d)),
            _tarihKutu(t, 'SKT', basSkt ?? otoSkt, (d) => setState(() => basSkt = d), bos: 'SKT yok', temizle: basSkt != null ? () => setState(() => basSkt = null) : null),
            SizedBox(width: 110, child: TextField(controller: basAdetC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Adet'))),
            SizedBox(
              width: 170,
              child: DropdownButtonFormField<String>(
                initialValue: boyutlar.containsKey(basBoyut) ? basBoyut : boyutlar.keys.first,
                isExpanded: true,
                dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 13),
                decoration: _emDekor(t, 'Boyut'),
                items: [for (final e in boyutlar.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (x) => setState(() => basBoyut = x),
              ),
            ),
          ]),
          if (omur <= 0) ...[
            const SizedBox(height: 6),
            Text('Bu üründe raf ömrü tanımlı değil; SKT basılacaksa tarih seç.', style: TextStyle(color: _emAmber, fontSize: 11.5)),
          ],
          if (u['sablon_id'] != null) ...[
            const SizedBox(height: 6),
            Text('Bu ürünün kendi tasarımı var; tasarımlı etiket bilgisayardan (web → Barkod & Etiket) basılır.', style: TextStyle(color: t.sub, fontSize: 11.5)),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _emMor, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
              onPressed: islemde ? null : () => _bas({
                    'tur': 'paket', 'id': '${u['id']}', 'mod': basMod, 'uretim': _emTarihStr(basUretim), if (basSkt != null) 'skt': _emTarihStr(basSkt!),
                    'adet': '${(int.tryParse(basAdetC.text.trim()) ?? 1).clamp(1, 500)}', 'boyut': basBoyut ?? '58x40',
                  }),
              icon: islemde ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, size: 18),
              label: const Text('Etiketi bas'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Basım geçmişi (parti)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          if (son.isEmpty)
            Text('Henüz paket etiketi basılmadı.', style: TextStyle(color: t.sub, fontSize: 12.5))
          else
            for (final b in son.cast<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(adlar[_emN(b['eu_id']).toInt()] ?? 'Silinmiş ürün', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('Parti ${b['parti_no']} · ÜT ${_emTarihGoster(_emS(b['uretim_tarih']))}${_emS(b['skt']).isNotEmpty ? ' · SKT ${_emTarihGoster(_emS(b['skt']))}' : ''}',
                          style: TextStyle(color: t.sub, fontSize: 11.5)),
                    ]),
                  ),
                  Text('${b['adet']} adet', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
        ]),
      ),
    ];
  }

  Widget _tarihKutu(TemaProvider t, String etiket, DateTime? d, ValueChanged<DateTime> sec, {String bos = '—', VoidCallback? temizle}) => SizedBox(
        width: 170,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final x = await showDatePicker(context: context, initialDate: d ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2040));
            if (x != null) sec(x);
          },
          child: InputDecorator(
            decoration: _emDekor(t, etiket, sonEk: temizle != null ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: temizle, tooltip: 'Otomatiğe dön') : const Icon(Icons.event, size: 18)),
            child: Text(d == null ? bos : DateFormat('dd.MM.yyyy').format(d), style: TextStyle(color: t.ink, fontSize: 13.5)),
          ),
        ),
      );

  Future<void> _bas(Map<String, String> body) async {
    setState(() => islemde = true);
    final r = await _emCagir(context, (tok) => Api.etiketMerkeziBas(tok, body));
    if (!mounted) return;
    if (r == null) {
      setState(() => islemde = false);
      return;
    }
    if (!_emOk(r)) {
      setState(() => islemde = false);
      _emBildir(context, _emMesaj(r, 'Etiket hazırlanamadı.'), hata: true);
      return;
    }
    final sonuc = await _emYaziciyaGonder(r);
    if (!mounted) return;
    setState(() => islemde = false);
    final parti = _emS(r['parti']);
    _emBildir(context, sonuc == 'ok' ? 'Etiket yazıcıya gönderildi ✓${parti.isNotEmpty ? ' · parti $parti' : ''}' : sonuc, hata: sonuc != 'ok');
    _yukle();
  }

  // =================== TARTI ===================
  List<Widget> _tarti(TemaProvider t, bool genis) {
    final tarti = _liste.where((u) => _emTurler(u).contains('tarti')).toList();
    final aktif = tarti.where((u) => u['aktif'] == true).toList();
    final a = _ayar;
    final ph = _emN(a['terazi_plu_hane']).toInt();
    final deger = _emS(a['terazi_deger']) == 'fiyat' ? 'tutar' : 'ağırlık';
    final duzen = MKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Terazi barkod düzeni', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15))),
          if (duzenler) TextButton.icon(onPressed: _ayarAc, icon: const Icon(Icons.tune, size: 16), label: const Text('Değiştir')),
        ]),
        const SizedBox(height: 6),
        Text('${a['terazi_onek']} + $ph haneli PLU + ${10 - ph} haneli $deger + kontrol hanesi',
            style: TextStyle(color: t.ink, fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 13.5)),
        const SizedBox(height: 4),
        Text('Etiketli terazi bu düzende barkod basar; kasada okutulunca ürün gramajıyla satışa düşer. PLU dosyasını web\'den (Barkod & Etiket → Tartılı Ürün) indirip teraziye yükle.',
            style: TextStyle(color: t.sub, fontSize: 12)),
      ]),
    );
    if (tarti.isEmpty) {
      return [duzen, const SizedBox(height: 12), _bosKutu(t, Icons.scale_outlined, _emYesil, 'Tartılı ürün yok', alt: 'Ürün eklerken "Tartılı" türünü seç; fiyat birimi kilogram olmalı.')];
    }
    final secili = aktif.firstWhere((x) => _emN(x['id']).toInt() == tartiId, orElse: () => aktif.isEmpty ? tarti.first : aktif.first);
    final cozK = cozSonuc;
    return [
      duzen,
      const SizedBox(height: 12),
      if (aktif.isNotEmpty)
        MKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Terazisiz tartı etiketi', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Ürünü normal terazide tart, gramı yaz; sistem aynı düzende barkodlu etiketi basar.', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _emN(secili['id']).toInt(),
              isExpanded: true,
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontSize: 13.5),
              decoration: _emDekor(t, 'Ürün'),
              items: [
                for (final x in aktif)
                  DropdownMenuItem(value: _emN(x['id']).toInt(), child: Text('${x['ad']} · PLU ${x['plu']} · ${_emTl((x['fb'] as Map?)?['gecerli'])}/kg', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (x) => setState(() => tartiId = x),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: gramC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Ağırlık (gram)', ipucu: 'örn. 452'))),
              const SizedBox(width: 10),
              SizedBox(width: 100, child: TextField(controller: tartiAdetC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Adet'))),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: daraDus,
              onChanged: (x) => setState(() => daraDus = x),
              title: Text('Darayı düş (${_emSayi(secili['dara_g']).isEmpty ? '0' : _emSayi(secili['dara_g'])} g)', style: TextStyle(color: t.ink, fontSize: 13.5)),
              subtitle: Text('Açık ürünün net ağırlığı darasız yazılır.', style: TextStyle(color: t.sub, fontSize: 11.5)),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _emYesil, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                onPressed: islemde
                    ? null
                    : () {
                        final g = gramC.text.trim().replaceAll(',', '.');
                        if ((double.tryParse(g) ?? 0) <= 0) {
                          _emBildir(context, 'Ağırlığı gram olarak yaz.', hata: true);
                          return;
                        }
                        _bas({'tur': 'tarti', 'id': '${secili['id']}', 'gram': g, if (daraDus) 'dara_dus': '1', 'adet': '${(int.tryParse(tartiAdetC.text.trim()) ?? 1).clamp(1, 50)}'});
                      },
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Tartı etiketi bas'),
              ),
            ),
          ]),
        ),
      const SizedBox(height: 12),
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Terazi barkodunu dene', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15))),
            OutlinedButton.icon(onPressed: _cozDene, icon: const Icon(Icons.qr_code_scanner, size: 18), label: const Text('Okut')),
          ]),
          const SizedBox(height: 4),
          Text('Teraziden çıkan etiketi okut; ürün, ağırlık ve tutar doğru çıkıyorsa kasada da doğru çalışır.', style: TextStyle(color: t.sub, fontSize: 12)),
          if (cozK != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (cozK['ok'] == 1 ? _emYesil : _emKirmizi).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: (cozK['ok'] == 1 ? _emYesil : _emKirmizi).withValues(alpha: 0.3)),
              ),
              child: Text(
                cozK['ok'] == 1 && cozK['tur'] == 'tarti'
                    ? '${cozK['ad']}\nTutar: ${_emTl(cozK['fiyat'])}'
                    : cozK['ok'] == 1
                        ? '${cozK['ad']} — normal ürün barkodu (terazi etiketi değil)'
                        : _emS(cozK['hata']).isEmpty ? 'Okunamadı' : _emS(cozK['hata']),
                style: TextStyle(color: t.ink, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ]),
      ),
      const SizedBox(height: 12),
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('PLU listesi', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          for (final u in tarti)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 56, child: Text('${u['plu'] ?? '—'}', style: TextStyle(color: t.ink, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
                Expanded(child: Text(_emS(u['ad']), style: TextStyle(color: u['aktif'] == true ? t.ink : t.sub, fontSize: 13))),
                Text(_emTl((u['fb'] as Map?)?['gecerli']), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                u['urun_id'] != null ? _rozet('Satılır', _emYesil) : _rozet('Menüye bağla', _emKirmizi),
              ]),
            ),
        ]),
      ),
    ];
  }

  Future<void> _cozDene() async {
    final k = await BarkodTarayici.oku(context, baslik: 'Terazi etiketini okut');
    if (k == null || !mounted) return;
    final r = await _emCagir(context, (tok) => Api.barkodCoz(tok, k));
    if (!mounted || r == null) return;
    setState(() => cozSonuc = r);
  }

  // =================== RAF KARTI ===================
  List<Widget> _raf(TemaProvider t, bool genis) {
    final raflar = _liste.where((u) => _emTurler(u).contains('raf') && u['aktif'] == true).toList();
    if (raflar.isEmpty) {
      return [_bosKutu(t, Icons.style_outlined, _emAmber, 'Raf kartı seçili ürün yok', alt: 'Ürün eklerken "Raf kartı" türünü seç; fiyatı değiştiğinde kartı yeniden basman gerektiğini sistem hatırlatır.')];
    }
    final bekleyen = raflar.where((u) => u['raf_bekliyor'] == true).toList();
    final gorunen = rafSadeceBekleyen && bekleyen.isNotEmpty ? bekleyen : raflar;
    final bicimAd = ((v['raf_bicimler'] as Map?) ?? const {})[_emS(_ayar['raf_bicim'])]?.toString() ?? 'Rulo 80 × 38 mm';
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _emMavi.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _emMavi.withValues(alpha: 0.25))),
        child: Text('Rafta KDV dahil fiyat, birim fiyat (kg/lt), üretim yeri ve tarih görünmeli. İndirimde eski fiyat olarak son 30 günün en düşük fiyatı basılır.',
            style: TextStyle(color: t.ink, fontSize: 12.5, height: 1.4)),
      ),
      const SizedBox(height: 12),
      Row(children: [
        ChoiceChip(label: Text('Yenilenecek ${bekleyen.length}'), selected: rafSadeceBekleyen, onSelected: (_) => setState(() => rafSadeceBekleyen = true),
            selectedColor: _emKirmizi.withValues(alpha: 0.15), backgroundColor: t.card, side: BorderSide(color: t.line),
            labelStyle: TextStyle(color: rafSadeceBekleyen ? _emKirmizi : t.sub2, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(width: 6),
        ChoiceChip(label: Text('Tümü ${raflar.length}'), selected: !rafSadeceBekleyen, onSelected: (_) => setState(() => rafSadeceBekleyen = false),
            selectedColor: _emMor.withValues(alpha: 0.15), backgroundColor: t.card, side: BorderSide(color: t.line),
            labelStyle: TextStyle(color: !rafSadeceBekleyen ? _emMor : t.sub2, fontWeight: FontWeight.w700, fontSize: 12)),
        const Spacer(),
        TextButton(
          onPressed: () => setState(() {
            final hepsi = gorunen.every((u) => rafSecili.contains(_emN(u['id']).toInt()));
            for (final u in gorunen) {
              hepsi ? rafSecili.remove(_emN(u['id']).toInt()) : rafSecili.add(_emN(u['id']).toInt());
            }
          }),
          child: const Text('Hepsini seç / bırak'),
        ),
      ]),
      const SizedBox(height: 6),
      MKart(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final u in gorunen)
            CheckboxListTile(
              value: rafSecili.contains(_emN(u['id']).toInt()),
              onChanged: (x) => setState(() => x == true ? rafSecili.add(_emN(u['id']).toInt()) : rafSecili.remove(_emN(u['id']).toInt())),
              activeColor: _emMor,
              title: Text(_emS(u['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
              subtitle: Text(
                  u['raf_bekliyor'] == true
                      ? (u['raf_fiyat'] == null ? 'Kartı hiç basılmadı' : 'Fiyat değişti → ${_emTl((u['fb'] as Map?)?['gecerli'])}')
                      : 'Raftaki kart güncel',
                  style: TextStyle(color: u['raf_bekliyor'] == true ? _emKirmizi : t.sub, fontSize: 11.5)),
              secondary: Text(_emTl((u['fb'] as Map?)?['gecerli']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: _emMor, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          onPressed: islemde || rafSecili.isEmpty ? null : () => _rafBas(rafSecili.toList()),
          icon: const Icon(Icons.print, size: 18),
          label: Text('Seçilenleri bas (${rafSecili.length})'),
        ),
        Text('Biçim: ${bicimAd.startsWith('A4') ? 'Rulo 80 × 38 mm (A4 yaprak web\'den basılır)' : bicimAd}', style: TextStyle(color: t.sub, fontSize: 12)),
      ]),
    ];
  }

  Future<void> _rafBas(List<int> ids) => _bas({'tur': 'raf', 'ids': ids.join(','), if (!_emS(_ayar['raf_bicim']).startsWith('a4')) 'bicim': _emS(_ayar['raf_bicim'])});

  // =================== AYARLAR ===================
  Future<void> _ayarAc() async {
    final a = Map<String, dynamic>.from(_ayar);
    final onekC = TextEditingController(text: _emS(a['terazi_onek']).isEmpty ? '27' : _emS(a['terazi_onek']));
    int pluHane = _emN(a['terazi_plu_hane']).toInt().clamp(4, 6);
    String deger = _emS(a['terazi_deger']) == 'fiyat' ? 'fiyat' : 'agirlik';
    int ondalik = _emN(a['terazi_ondalik']).toInt().clamp(0, 3);
    final rafBicimler = ((v['raf_bicimler'] as Map?) ?? const {'rulo_80x38': 'Rulo 80 × 38 mm'}).map((k, x) => MapEntry(k.toString(), x.toString()));
    final boyutlar = ((v['urun_boyutlar'] as Map?) ?? const {'58x40': '58 × 40 mm'}).map((k, x) => MapEntry(k.toString(), x.toString()));
    String rafBicim = rafBicimler.containsKey(_emS(a['raf_bicim'])) ? _emS(a['raf_bicim']) : rafBicimler.keys.first;
    String urunBoyut = boyutlar.containsKey(_emS(a['urun_boyut'])) ? _emS(a['urun_boyut']) : boyutlar.keys.first;
    String dil = ['tarayici', 'zpl', 'tspl', 'escpos'].contains(_emS(a['dil'])) ? _emS(a['dil']) : 'tarayici';
    int dpi = _emN(a['dpi']).toInt() == 300 ? 300 : 203;
    final ipC = TextEditingController(text: _emS(a['ip']));
    final portC = TextEditingController(text: _emN(a['port']) > 0 ? '${_emN(a['port']).toInt()}' : '9100');
    final ureticiC = TextEditingController(text: _emS(a['uretici_varsayilan']));
    bool kaydediyor = false;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return StatefulBuilder(builder: (ctx, setS) {
          Future<void> kaydet() async {
            setS(() => kaydediyor = true);
            final r = await _emCagir(ctx, (tok) => Api.etiketMerkeziAyar(tok, {
                  'terazi_onek': onekC.text.trim(), 'terazi_plu_hane': '$pluHane', 'terazi_deger': deger, 'terazi_ondalik': '$ondalik',
                  'raf_bicim': rafBicim, 'urun_boyut': urunBoyut, 'uretici_varsayilan': ureticiC.text.trim(),
                  'dil': dil, 'dpi': '$dpi', 'ip': ipC.text.trim(), 'port': portC.text.trim().isEmpty ? '9100' : portC.text.trim(),
                }));
            if (!ctx.mounted) return;
            setS(() => kaydediyor = false);
            if (r == null) return;
            if (_emOk(r)) {
              Navigator.pop(ctx);
              if (mounted) {
                _emBildir(context, _emMesaj(r, 'Ayarlar kaydedildi.'));
                _yukle();
              }
            } else {
              _emBildir(ctx, _emMesaj(r, 'Kaydedilemedi.'), hata: true);
            }
          }

          Widget baslik(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 8), child: Text(s, style: const TextStyle(color: _emMor, fontWeight: FontWeight.w800, fontSize: 12.5)));
          DropdownButtonFormField<T> secim<T>(String etiket, T deger0, Map<T, String> ogeler, ValueChanged<T> d) => DropdownButtonFormField<T>(
                initialValue: deger0,
                isExpanded: true,
                dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 13.5),
                decoration: _emDekor(t, etiket),
                items: [for (final e in ogeler.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                onChanged: (x) { if (x != null) setS(() => d(x)); },
              );
          return AlertDialog(
            backgroundColor: t.card,
            title: Text('Barkod & Etiket ayarları', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  baslik('ETİKET YAZICISI'),
                  secim<String>('Yazıcı dili', dil, const {'tarayici': 'Bilgisayardan yazdır (web)', 'zpl': 'Zebra (ZPL) — ağ yazıcısı', 'tspl': 'TSC / Godex / Xprinter (TSPL)', 'escpos': 'Fiş yazıcısı (ESC/POS)'}, (x) => dil = x),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(flex: 3, child: TextField(controller: ipC, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Yazıcı IP', ipucu: '192.168.1.50'))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(controller: portC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Port'))),
                  ]),
                  const SizedBox(height: 10),
                  secim<int>('Çözünürlük', dpi, const {203: '203 dpi (çoğu yazıcı)', 300: '300 dpi'}, (x) => dpi = x),
                  baslik('VARSAYILAN ÖLÇÜLER'),
                  secim<String>('Ürün etiketi boyutu', urunBoyut, boyutlar, (x) => urunBoyut = x),
                  const SizedBox(height: 10),
                  secim<String>('Raf kartı biçimi', rafBicim, rafBicimler, (x) => rafBicim = x),
                  const SizedBox(height: 10),
                  TextField(controller: ureticiC, maxLines: 2, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Üretici / firma bilgisi (etiketlerde)')),
                  baslik('TERAZİ BARKODU'),
                  Row(children: [
                    Expanded(child: TextField(controller: onekC, maxLength: 2, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _emDekor(t, 'Önek (20–29)').copyWith(counterText: ''))),
                    const SizedBox(width: 8),
                    Expanded(child: secim<int>('PLU hanesi', pluHane, const {4: '4 hane', 5: '5 hane', 6: '6 hane'}, (x) => pluHane = x)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: secim<String>('Barkodda ne var?', deger, const {'agirlik': 'Ağırlık', 'fiyat': 'Tutar'}, (x) { deger = x; ondalik = x == 'fiyat' ? 2 : 3; })),
                    const SizedBox(width: 8),
                    Expanded(child: secim<int>('Ondalık', ondalik, const {0: '0', 1: '1', 2: '2', 3: '3'}, (x) => ondalik = x)),
                  ]),
                  const SizedBox(height: 6),
                  Text('En yaygın: 27 · 5 hane PLU · ağırlık (3 ondalık = gram). Terazinin kurulum menüsündeki "barkod formatı" ile aynı olmalı.', style: TextStyle(color: t.sub, fontSize: 11.5)),
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: kaydediyor ? null : () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
              OutlinedButton.icon(
                onPressed: kaydediyor
                    ? null
                    : () async {
                        final s = await EtiketYazici.testBas(dil: dil, ip: ipC.text, port: int.tryParse(portC.text.trim()) ?? 9100);
                        if (ctx.mounted) _emBildir(ctx, s == 'ok' ? 'Test etiketi gönderildi ✓' : s, hata: s != 'ok');
                      },
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Test etiketi'),
              ),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: _emMor), onPressed: kaydediyor ? null : kaydet, child: const Text('Kaydet')),
            ],
          );
        });
      },
    );
    onekC.dispose();
    ipC.dispose();
    portC.dispose();
    ureticiC.dispose();
  }
}

// =====================================================================================
// ÜRÜN FORMU (ekle / düzenle)
// =====================================================================================
class _EtiketUrunForm extends StatefulWidget {
  final Map<String, dynamic>? urun;
  final List<Map<String, dynamic>> menu;
  final List<Map<String, dynamic>> sablonlar;
  const _EtiketUrunForm({required this.urun, required this.menu, required this.sablonlar});
  @override
  State<_EtiketUrunForm> createState() => _EtiketUrunFormState();
}

class _EtiketUrunFormState extends State<_EtiketUrunForm> {
  late final Map<String, TextEditingController> c;
  int? urunId;
  int? sablonId;
  String birim = 'adet';
  String netBirim = 'g';
  Set<String> turler = {'paket', 'raf'};
  bool yerli = false;
  bool aktif = true;
  bool icUret = false;
  DateTime? indBitis;
  bool kaydediyor = false;

  @override
  void initState() {
    super.initState();
    final u = widget.urun ?? const {};
    c = {
      for (final k in ['ad', 'kategori', 'fiyat', 'indirimli_fiyat', 'net_miktar', 'barkod', 'plu', 'raf_omru_gun', 'dara_g', 'uretim_yeri', 'icindekiler', 'alerjen', 'saklama', 'uretici'])
        k: TextEditingController(text: ['fiyat', 'indirimli_fiyat', 'net_miktar', 'dara_g'].contains(k) ? _emSayi(u[k]) : (u[k] == null ? '' : _emS(u[k]))),
    };
    if (_emN(u['dara_g']) == 0) c['dara_g']!.text = '';
    urunId = u['urun_id'] == null ? null : _emN(u['urun_id']).toInt();
    sablonId = u['sablon_id'] == null ? null : _emN(u['sablon_id']).toInt();
    birim = ['adet', 'kg', 'lt'].contains(_emS(u['birim'])) ? _emS(u['birim']) : 'adet';
    netBirim = ['g', 'kg', 'ml', 'lt', 'adet'].contains(_emS(u['net_birim'])) ? _emS(u['net_birim']) : 'g';
    if (widget.urun != null) turler = _emTurler(u).toSet();
    yerli = u['yerli'] == true;
    aktif = widget.urun == null ? true : u['aktif'] == true;
    indBitis = DateTime.tryParse(_emS(u['indirim_bitis']));
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    if (turler.isEmpty) {
      _emBildir(context, 'En az bir etiket türü seç.', hata: true);
      return;
    }
    setState(() => kaydediyor = true);
    final body = <String, String>{
      if (widget.urun != null) 'id': '${widget.urun!['id']}',
      'urun_id': urunId?.toString() ?? '',
      'sablon_id': sablonId?.toString() ?? '',
      'birim': birim,
      'net_birim': netBirim,
      'turler': turler.join(','),
      'yerli': yerli ? '1' : '0',
      'aktif': aktif ? '1' : '0',
      'indirim_bitis': indBitis == null ? '' : _emTarihStr(indBitis!),
      if (icUret && c['barkod']!.text.trim().isEmpty) 'barkod_islem': 'ic_uret',
      for (final e in c.entries) e.key: e.value.text.trim(),
    };
    final r = await _emCagir(context, (tok) => Api.etiketMerkeziKaydet(tok, body));
    if (!mounted) return;
    setState(() => kaydediyor = false);
    if (r == null) return;
    if (_emOk(r)) {
      _emBildir(context, _emMesaj(r, 'Kaydedildi.'));
      Navigator.pop(context, true);
    } else {
      _emBildir(context, _emMesaj(r, 'Kaydedilemedi.'), hata: true);
    }
  }

  Future<void> _sil() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: t.card,
          title: Text('Ürün silinsin mi?', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
          content: Text('Etiket listesinden silinir. Menüdeki ürün silinmez; basım geçmişi korunur.', style: TextStyle(color: t.sub2, fontSize: 13.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _emKirmizi), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    final r = await _emCagir(context, (tok) => Api.etiketMerkeziSil(tok, _emN(widget.urun!['id']).toInt()));
    if (!mounted || r == null) return;
    _emBildir(context, _emMesaj(r, 'Silindi.'), hata: !_emOk(r));
    if (_emOk(r)) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final menuSecili = widget.menu.where((m) => _emN(m['id']).toInt() == urunId).toList();
    final tarti = turler.contains('tarti');
    Widget alan(String k, String etiket, {String? ipucu, TextInputType? tip, int satir = 1, Widget? sonEk, String? yardim}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(controller: c[k], keyboardType: tip, maxLines: satir, style: TextStyle(color: t.ink), decoration: _emDekor(t, etiket, ipucu: ipucu, sonEk: sonEk, yardim: yardim)),
        );
    Widget bolum(String s) => Padding(padding: const EdgeInsets.only(top: 10, bottom: 8), child: Text(s, style: const TextStyle(color: _emMor, fontWeight: FontWeight.w800, fontSize: 12.5)));
    const sayi = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        foregroundColor: t.ink,
        title: Text(widget.urun == null ? 'Yeni Ürün' : '${widget.urun!['ad']}', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.w800)),
        actions: [
          if (widget.urun != null) IconButton(onPressed: kaydediyor ? null : _sil, tooltip: 'Sil', icon: const Icon(Icons.delete_outline, color: _emKirmizi)),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _emMor), onPressed: kaydediyor ? null : _kaydet, child: Text(kaydediyor ? 'Kaydediliyor…' : 'Kaydet')),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            bolum('ÜRÜN'),
            DropdownButtonFormField<int?>(
              initialValue: urunId,
              isExpanded: true,
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontSize: 13.5),
              decoration: _emDekor(t, 'Menüdeki ürüne bağla (kasada satılacaksa)',
                  yardim: urunId != null ? 'Fiyat boş kalırsa menü fiyatı kullanılır.' : 'Menüde olmayan ürün kasada satılamaz; yalnız etiketi basılır.'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— Menüde değil (markete giden ürün vb.) —')),
                for (final m in widget.menu) DropdownMenuItem<int?>(value: _emN(m['id']).toInt(), child: Text('${m['ad']} — ${_emTl(m['fiyat'])}', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (x) => setState(() {
                urunId = x;
                final m = widget.menu.where((e) => _emN(e['id']).toInt() == x).toList();
                if (m.isNotEmpty && c['ad']!.text.trim().isEmpty) c['ad']!.text = _emS(m.first['ad']);
              }),
            ),
            const SizedBox(height: 10),
            alan('ad', 'Etikette görünecek ad *', ipucu: 'Dana Kıyma / Ev Yapımı Nar Ekşisi'),
            alan('kategori', 'Kategori', ipucu: 'Kasap, şarküteri, konserve…'),
            bolum('ETİKET TÜRÜ'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in const {'paket': 'Paketli ürün etiketi', 'tarti': 'Tartılı ürün (terazi)', 'raf': 'Raf kartı'}.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: turler.contains(e.key),
                  onSelected: (x) => setState(() {
                    x ? turler.add(e.key) : turler.remove(e.key);
                    if (turler.contains('tarti')) birim = 'kg';
                  }),
                  selectedColor: (_emTurRenk[e.key] ?? _emMor).withValues(alpha: 0.16),
                  checkmarkColor: _emTurRenk[e.key],
                  backgroundColor: t.card,
                  side: BorderSide(color: t.line),
                  labelStyle: TextStyle(color: turler.contains(e.key) ? (_emTurRenk[e.key] ?? _emMor) : t.sub2, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
            ]),
            bolum('FİYAT'),
            DropdownButtonFormField<String>(
              initialValue: birim,
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontSize: 13.5),
              decoration: _emDekor(t, 'Fiyat neye göre?'),
              items: const [
                DropdownMenuItem(value: 'adet', child: Text('Adet / paket')),
                DropdownMenuItem(value: 'kg', child: Text('Kilogram')),
                DropdownMenuItem(value: 'lt', child: Text('Litre')),
              ],
              onChanged: tarti ? null : (x) => setState(() => birim = x ?? birim),
            ),
            const SizedBox(height: 10),
            alan('fiyat', birim == 'kg' ? 'Kilogram fiyatı (₺, KDV dahil)' : (birim == 'lt' ? 'Litre fiyatı (₺, KDV dahil)' : 'Satış fiyatı (₺, KDV dahil)'), tip: sayi,
                ipucu: menuSecili.isNotEmpty ? 'Boş = menü fiyatı (${_emTl(menuSecili.first['fiyat'])})' : 'Zorunlu'),
            Row(children: [
              Expanded(child: alan('indirimli_fiyat', 'İndirimli fiyat (₺)', tip: sayi, ipucu: 'Boş = indirim yok')),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    onTap: () async {
                      final x = await showDatePicker(context: context, initialDate: indBitis ?? DateTime.now().add(const Duration(days: 7)), firstDate: DateTime(2020), lastDate: DateTime(2040));
                      if (x != null) setState(() => indBitis = x);
                    },
                    child: InputDecorator(
                      decoration: _emDekor(t, 'İndirim bitişi', sonEk: indBitis != null ? IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => indBitis = null)) : null),
                      child: Text(indBitis == null ? 'Süresiz' : DateFormat('dd.MM.yyyy').format(indBitis!), style: TextStyle(color: t.ink, fontSize: 13.5)),
                    ),
                  ),
                ),
              ),
            ]),
            if (birim == 'adet')
              Row(children: [
                Expanded(child: alan('net_miktar', 'Paketteki net miktar', tip: sayi, ipucu: '500')),
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      initialValue: netBirim,
                      dropdownColor: t.card,
                      style: TextStyle(color: t.ink, fontSize: 13.5),
                      decoration: _emDekor(t, 'Birim'),
                      items: [for (final b in const ['g', 'kg', 'ml', 'lt', 'adet']) DropdownMenuItem(value: b, child: Text(b))],
                      onChanged: (x) => setState(() => netBirim = x ?? netBirim),
                    ),
                  ),
                ),
              ]),
            bolum('BARKOD'),
            alan('barkod', 'Barkod', ipucu: '869… resmi barkodu okut ya da boş bırak',
                yardim: 'Markete giden ürünün GS1 Türkiye\'den alınmış 869 barkodunu yaz. Mağaza içi barkod (2 ile başlar) yalnız kendi kasanda geçerlidir.',
                sonEk: IconButton(
                  icon: Icon(Icons.qr_code_scanner, color: t.sub2),
                  tooltip: 'Okut',
                  onPressed: () async {
                    final k = await BarkodTarayici.oku(context, baslik: 'Ürün barkodunu okut');
                    if (k != null && mounted) setState(() => c['barkod']!.text = k);
                  },
                )),
            if (c['barkod']!.text.trim().isEmpty)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: icUret,
                onChanged: (x) => setState(() => icUret = x == true),
                activeColor: _emMor,
                title: Text('Barkodu yok — mağaza içi barkod üret', style: TextStyle(color: t.ink, fontSize: 13.5)),
              ),
            if (tarti) alan('plu', 'PLU (terazideki ürün no)', tip: TextInputType.number, ipucu: 'Boş = sıradaki numara'),
            bolum('TARİH, İÇERİK, ÜRETİCİ'),
            Row(children: [
              Expanded(child: alan('raf_omru_gun', 'Raf ömrü (gün)', tip: TextInputType.number, ipucu: 'SKT = üretim + gün')),
              if (tarti || birim != 'adet') ...[const SizedBox(width: 10), Expanded(child: alan('dara_g', 'Dara (g)', tip: sayi, ipucu: 'Kap ağırlığı'))],
            ]),
            alan('uretim_yeri', 'Üretim yeri', ipucu: 'İzmir / Türkiye'),
            alan('icindekiler', 'İçindekiler', satir: 2),
            alan('alerjen', 'Alerjen uyarısı', ipucu: 'Gluten, süt içerir'),
            alan('saklama', 'Saklama koşulu', ipucu: '+4 °C\'de saklayınız'),
            alan('uretici', 'Üretici (firma ve adres)', ipucu: 'Boş = ayarlardaki firma bilgisi'),
            if (widget.sablonlar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<int?>(
                  initialValue: widget.sablonlar.any((s) => _emN(s['id']).toInt() == sablonId) ? sablonId : null,
                  isExpanded: true,
                  dropdownColor: t.card,
                  style: TextStyle(color: t.ink, fontSize: 13.5),
                  decoration: _emDekor(t, 'Kendi tasarımı (web\'den basılır)'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('— Yok —')),
                    for (final s in widget.sablonlar) DropdownMenuItem<int?>(value: _emN(s['id']).toInt(), child: Text(_emS(s['ad']))),
                  ],
                  onChanged: (x) => setState(() => sablonId = x),
                ),
              ),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: yerli, activeThumbColor: _emMor, onChanged: (x) => setState(() => yerli = x),
                title: Text('Yerli üretim', style: TextStyle(color: t.ink, fontSize: 13.5))),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: aktif, activeThumbColor: _emMor, onChanged: (x) => setState(() => aktif = x),
                title: Text('Aktif', style: TextStyle(color: t.ink, fontSize: 13.5)), subtitle: Text('Pasif ürün etiket ve raf listelerinde görünmez.', style: TextStyle(color: t.sub, fontSize: 11.5))),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
