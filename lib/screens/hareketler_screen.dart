import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// Hareketler / Aktivite Log — TÜM hareketler tek zaman akışında (satış, ödeme, iskonto/ikram/void,
/// stok, kasa, cari, personel, gider, fiş + her config değişikliği). Filtre/arama/sonsuz kaydırma.
class HareketlerScreen extends StatefulWidget {
  const HareketlerScreen({super.key});
  @override
  State<HareketlerScreen> createState() => _HareketlerScreenState();
}

class _HareketlerScreenState extends State<HareketlerScreen> {
  final _f = NumberFormat.decimalPattern('tr');
  final _kaydir = ScrollController();
  final _araC = TextEditingController();

  List hareketler = [];
  List personeller = [];
  Map ozet = {};
  int gun = 7;
  String kategori = 'hepsi';
  int? kim;
  String ara = '';
  int sayfa = 1;
  int toplam = 0;
  bool sonSayfa = false;
  bool loading = true;
  bool dahaYukleniyor = false;

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) => '${_f.format(v.round())}TL';

  // kategori -> [renk, ikon, etiket]
  static const Map<String, List<dynamic>> _kat = {
    'satis': [Color(0xFF10B981), Icons.receipt_long, 'Satış'],
    'odeme': [Color(0xFF10B981), Icons.payments_outlined, 'Ödeme'],
    'kayip': [Color(0xFFF43F5E), Icons.remove_circle_outline, 'Kayıp'],
    'stok': [Color(0xFF3B82F6), Icons.inventory_2_outlined, 'Stok'],
    'kasa': [Color(0xFF14B8A6), Icons.point_of_sale, 'Kasa'],
    'cari': [Color(0xFF6366F1), Icons.account_balance_wallet_outlined, 'Cari'],
    'personel': [Color(0xFFF59E0B), Icons.badge_outlined, 'Personel'],
    'gider': [Color(0xFFEA580C), Icons.money_off, 'Gider'],
    'fis': [Color(0xFF7C3AED), Icons.description_outlined, 'Fiş'],
    'menu': [Color(0xFF7C3AED), Icons.restaurant_menu, 'Menü'],
    'recete': [Color(0xFF7C3AED), Icons.menu_book_outlined, 'Reçete'],
    'ayar': [Color(0xFF94A3B8), Icons.settings_outlined, 'Ayar'],
    'giris': [Color(0xFF94A3B8), Icons.login, 'Giriş'],
    'mesai': [Color(0xFF14B8A6), Icons.schedule, 'Mesai'],
    'cagri': [Color(0xFFF43F5E), Icons.notifications_active_outlined, 'Çağrı'],
    'diger': [Color(0xFF94A3B8), Icons.bolt, 'Diğer'],
  };
  List<dynamic> _katBilgi(String k) => _kat[k] ?? _kat['diger']!;

  @override
  void initState() {
    super.initState();
    _yukle();
    _kaydir.addListener(() {
      if (_kaydir.position.pixels > _kaydir.position.maxScrollExtent - 400) _dahaYukle();
    });
  }

  @override
  void dispose() { _kaydir.dispose(); _araC.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() { loading = true; sayfa = 1; sonSayfa = false; });
    try {
      final res = await Api.hareketler(auth.token!, gun: gun, kategori: kategori == 'hepsi' ? null : kategori, kim: kim, ara: ara, sayfa: 1);
      if (!mounted) return;
      setState(() {
        hareketler = (res['hareketler'] as List?) ?? [];
        personeller = (res['personeller'] as List?) ?? [];
        ozet = (res['ozet'] as Map?) ?? {};
        toplam = _n(res['toplam']).toInt();
        sonSayfa = hareketler.length >= toplam;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _dahaYukle() async {
    if (dahaYukleniyor || sonSayfa || loading) return;
    setState(() => dahaYukleniyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.hareketler(auth.token!, gun: gun, kategori: kategori == 'hepsi' ? null : kategori, kim: kim, ara: ara, sayfa: sayfa + 1);
      if (!mounted) return;
      final yeni = (res['hareketler'] as List?) ?? [];
      setState(() {
        sayfa++;
        hareketler.addAll(yeni);
        sonSayfa = yeni.isEmpty || hareketler.length >= toplam;
        dahaYukleniyor = false;
      });
    } catch (_) {
      if (mounted) setState(() => dahaYukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Hareketler', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _yukle, icon: Icon(Icons.refresh, color: t.sub)), const MenuHamburger()],
      ),
      body: Column(children: [
        _filtreBar(t),
        if (!loading) _ozetSerit(t),
        Expanded(
          child: loading
              ? Center(child: CircularProgressIndicator(color: t.mor1))
              : hareketler.isEmpty
                  ? Center(child: Text('Bu filtrede hareket yok.', style: TextStyle(color: t.sub, fontSize: 14)))
                  : RefreshIndicator(
                      onRefresh: _yukle, color: t.mor1, backgroundColor: t.card,
                      child: ListView.builder(
                        controller: _kaydir,
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 24),
                        itemCount: hareketler.length + (dahaYukleniyor ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= hareketler.length) {
                            return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))));
                          }
                          final h = hareketler[i] as Map;
                          final oncekiGun = i > 0 ? (hareketler[i - 1] as Map)['gun_key'] : null;
                          final gunBasi = i == 0 || h['gun_key'] != oncekiGun;
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (gunBasi) _gunBaslik(t, h['tarih']?.toString() ?? ''),
                            _satir(t, h),
                          ]);
                        },
                      ),
                    ),
        ),
      ]),
    );
  }

  Widget _filtreBar(TemaProvider t) {
    final katlar = ['hepsi', ..._kat.keys];
    return Column(children: [
      // Gün seçici + arama + personel
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(children: [
          for (final g in const [[1, 'Bugün'], [7, 'Hafta'], [30, 'Ay']])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () { setState(() => gun = g[0] as int); _yukle(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: gun == g[0] ? t.mor1 : t.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: gun == g[0] ? t.mor1 : t.line)),
                  child: Text(g[1] as String, style: TextStyle(color: gun == g[0] ? Colors.white : t.sub2, fontWeight: FontWeight.w600, fontSize: 12)),
                ),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(child: SizedBox(
            height: 36,
            child: TextField(
              controller: _araC, style: TextStyle(color: t.ink, fontSize: 13),
              onSubmitted: (v) { setState(() => ara = v.trim()); _yukle(); },
              decoration: InputDecoration(
                hintText: 'Ara', hintStyle: TextStyle(color: t.sub), isDense: true,
                prefixIcon: Icon(Icons.search, color: t.sub, size: 18),
                suffixIcon: ara.isNotEmpty ? IconButton(icon: Icon(Icons.close, color: t.sub, size: 16), onPressed: () { _araC.clear(); setState(() => ara = ''); _yukle(); }) : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.line)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.mor1)),
              ),
            ),
          )),
          if (personeller.isNotEmpty) ...[const SizedBox(width: 6), _personelDrop(t)],
        ]),
      ),
      // Kategori çipleri
      SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          children: [
            for (final k in katlar)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () { setState(() => kategori = k); _yukle(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: kategori == k ? (k == 'hepsi' ? t.mor1 : (_katBilgi(k)[0] as Color)) : t.card,
                      borderRadius: BorderRadius.circular(20), border: Border.all(color: kategori == k ? Colors.transparent : t.line),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (k != 'hepsi') ...[Icon(_katBilgi(k)[1] as IconData, size: 13, color: kategori == k ? Colors.white : (_katBilgi(k)[0] as Color)), const SizedBox(width: 4)],
                      Text(k == 'hepsi' ? 'Hepsi' : _katBilgi(k)[2] as String, style: TextStyle(color: kategori == k ? Colors.white : t.sub2, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _personelDrop(TemaProvider t) => Container(
        height: 36, padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(9), border: Border.all(color: t.line)),
        child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
          value: kim, isDense: true, dropdownColor: t.card, icon: Icon(Icons.arrow_drop_down, color: t.sub, size: 18),
          hint: Icon(Icons.person_outline, color: t.sub, size: 18),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text('Herkes', style: TextStyle(color: t.ink, fontSize: 12))),
            for (final p in personeller) DropdownMenuItem<int?>(value: _n((p as Map)['id']).toInt(), child: Text(p['ad'].toString(), style: TextStyle(color: t.ink, fontSize: 12))),
          ],
          onChanged: (v) { setState(() => kim = v); _yukle(); },
        )),
      );

  Widget _ozetSerit(TemaProvider t) {
    final giris = _n(ozet['giris']);
    final cikis = _n(ozet['cikis']);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 2), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        Text('${_n(ozet['toplam']).toInt()} hareket', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.bold)),
        const Spacer(),
        if (giris > 0) ...[Icon(Icons.south_west, size: 14, color: t.yesil), const SizedBox(width: 2), Text(_tl(giris), style: TextStyle(color: t.yesil, fontSize: 12.5, fontWeight: FontWeight.w600)), const SizedBox(width: 12)],
        if (cikis > 0) ...[const Icon(Icons.north_east, size: 14, color: Color(0xFFF43F5E)), const SizedBox(width: 2), Text(_tl(cikis), style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 12.5, fontWeight: FontWeight.w600))],
      ]),
    );
  }

  Widget _gunBaslik(TemaProvider t, String tarih) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Text(tarih, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold)),
      );

  Widget _satir(TemaProvider t, Map h) {
    final bilgi = _katBilgi(h['kategori'].toString());
    final renk = bilgi[0] as Color;
    final tutar = h['tutar'] == null ? null : _n(h['tutar']).toDouble();
    final yon = h['yon']?.toString();
    final aciklama = h['aciklama']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)), child: Icon(bilgi[1] as IconData, color: renk, size: 20)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(h['baslik']?.toString() ?? '—', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
          if (aciklama.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(aciklama, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5, height: 1.25)),
          ],
          const SizedBox(height: 3),
          Row(children: [
            if (h['personel'] != null) ...[Icon(Icons.person, size: 11, color: t.sub2), const SizedBox(width: 2), Flexible(child: Text(h['personel'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 11))), const SizedBox(width: 8)],
            Text(h['saat']?.toString() ?? '', style: TextStyle(color: t.sub, fontSize: 11)),
          ]),
        ])),
        if (tutar != null && tutar != 0) ...[
          const SizedBox(width: 6),
          Text('${yon == 'cikis' ? '-' : (yon == 'giris' ? '+' : '')}${_tl(tutar)}',
              style: TextStyle(color: yon == 'cikis' ? const Color(0xFFF43F5E) : (yon == 'giris' ? t.yesil : t.sub2), fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ]),
    );
  }
}
