import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';
import '../services/api.dart';
import 'personel_yetki_duzenle_screen.dart';

/// Personel & Maaş — kart, maaş/prim konfigu, otomatik prim (ciro), avans/ödeme/
/// prim/kesinti defteri. Aylık özet. Para işlemleri SADECE sahip.
class PersonelScreen extends StatefulWidget {
  const PersonelScreen({super.key});
  @override
  State<PersonelScreen> createState() => _PersonelScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _turuncu = Color(0xFFD97706);
const _gri = Color(0xFF94A3B8);

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

Color _rolRenk(String rol) {
  switch (rol) {
    case 'sahip': return _mor1;
    case 'mudur': return _mavi;
    case 'kasa': return _turuncu;
    case 'garson': return _yesil;
    default: return const Color(0xFF64748B);
  }
}

String _rolAd(String rol) => {'sahip': 'Sahip', 'mudur': 'Müdür', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak'}[rol] ?? rol;

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';

class _PersonelScreenState extends State<PersonelScreen> {
  List personeller = [];
  Map ozet = {};
  bool loading = true;
  bool duzenleyebilir = false;
  String? hata;
  DateTime _ay = DateTime.now();

  String get _ayParam => '${_ay.year}-${_ay.month.toString().padLeft(2, '0')}';
  String get _ayMetin => '${_aylar[_ay.month]} ${_ay.year}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() { loading = true; hata = null; });
    try {
      final res = await Api.personelList(auth.token!, ay: _ayParam);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          personeller = (res['personeller'] as List?) ?? [];
          ozet = (res['ozet'] as Map?) ?? {};
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() { hata = res['hata']?.toString() ?? 'Alınamadı'; loading = false; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  void _ayDegis(int delta) {
    final yeni = DateTime(_ay.year, _ay.month + delta);
    if (yeni.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) return;
    setState(() => _ay = yeni);
    _yukle();
  }

  Future<void> _ekle() async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => const PersonelDetayScreen(id: 0),
    ));
    if (degisti == true) _yukle();
  }

  Future<void> _ac(Map p) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => PersonelDetayScreen(id: _n(p['id']).toInt(), ay: _ayParam),
    ));
    if (degisti == true) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final aktifler = personeller.where((p) => _n((p as Map)['aktif']) == 1).toList();
    final pasifler = personeller.where((p) => _n((p as Map)['aktif']) != 1).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Personel & Maaş', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: duzenleyebilir
          ? FloatingActionButton.extended(
              backgroundColor: _mor1,
              onPressed: _ekle,
              icon: const Icon(Icons.person_add_alt, color: Colors.white),
              label: const Text('Personel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: _kirmizi)))
              : Column(children: [
                  _aySecici(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _yukle,
                      color: _mor1,
                      backgroundColor: _card,
                      child: ListView(
                        padding: const EdgeInsets.all(14),
                        children: [
                          _ozetKart(),
                          const SizedBox(height: 8),
                          for (final p in aktifler) _personelKart(p as Map),
                          if (pasifler.isNotEmpty) ...[
                            const Padding(padding: EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text('Pasif', style: TextStyle(color: _gri, fontSize: 12, fontWeight: FontWeight.bold))),
                            for (final p in pasifler) _personelKart(p as Map),
                          ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ]),
    );
  }

  // ==========================================================================
  // MASAÜSTÜ (PC/tablet) — role göre gruplu kart ızgarası, gece/gündüz temalı
  // ==========================================================================

  // rol -> (grup adı, grup sırası)
  static const Map<String, String> _rolGrup = {
    'sahip': 'Yöneticiler',
    'mudur': 'Yöneticiler',
    'garson': 'Garsonlar',
    'mutfak': 'Mutfak / Ustalar',
    'usta': 'Mutfak / Ustalar',
    'kasa': 'Kasiyerler',
  };
  static const List<String> _grupSira = ['Yöneticiler', 'Garsonlar', 'Mutfak / Ustalar', 'Kasiyerler', 'Diğer'];

  String _grupAd(String rol) => _rolGrup[rol] ?? 'Diğer';

  Color _grupRenk(String grup) {
    switch (grup) {
      case 'Yöneticiler': return _mor1;
      case 'Garsonlar': return _yesil;
      case 'Mutfak / Ustalar': return _turuncu;
      case 'Kasiyerler': return _mavi;
      default: return const Color(0xFF64748B);
    }
  }

  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Personel & Maaş',
      ikon: Icons.badge_outlined,
      araclar: [
        IconButton(onPressed: () => _ayDegis(-1), icon: Icon(Icons.chevron_left, color: t.sub2), tooltip: 'Önceki ay'),
        Text(_ayMetin, style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 14)),
        IconButton(onPressed: () => _ayDegis(1), icon: Icon(Icons.chevron_right, color: t.sub2), tooltip: 'Sonraki ay'),
        if (duzenleyebilir) ...[
          const SizedBox(width: 8),
          MButon('Personel Ekle', t.mor1, _ekle, ikon: Icons.person_add_alt),
        ],
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : hata != null
              ? Center(child: Text(hata!, style: TextStyle(color: t.kirmizi)))
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: t.mor1,
                  backgroundColor: t.card,
                  child: _masaustuGovde(context, t),
                ),
    );
  }

  Widget _masaustuGovde(BuildContext context, TemaProvider t) {
    // rol'e göre grupla, grupları sabit sırayla göster
    final Map<String, List<Map>> gruplar = {};
    for (final p in personeller) {
      final m = p as Map;
      gruplar.putIfAbsent(_grupAd(m['rol'].toString()), () => []).add(m);
    }
    final siraliGruplar = _grupSira.where((g) => gruplar.containsKey(g)).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _masaustuOzet(t),
        const SizedBox(height: 20),
        if (personeller.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Personel yok.', style: TextStyle(color: t.sub, fontSize: 14))),
          ),
        for (final g in siraliGruplar) ...[
          MBolumBaslik(g, renk: _grupRenk(g), sayi: gruplar[g]!.length),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (ctx, box) {
            final sutun = box.maxWidth >= 1400 ? 4 : 3;
            return GridView.count(
              crossAxisCount: sutun,
              childAspectRatio: 2.4,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (final p in gruplar[g]!) _masaustuKart(t, p)],
            );
          }),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _masaustuOzet(TemaProvider t) => MIstatKart(
        baslik: 'Bu Ay Personel Gideri',
        renk: t.mor1,
        buyukDeger: _tl(_n(ozet['maas']) + _n(ozet['prim'])),
        satirlar: [
          MIstatSatir('Maaş', _tl(ozet['maas'])),
          MIstatSatir('Prim', _tl(ozet['prim']), renk: t.yesil),
          MIstatSatir('Ödenen', _tl(ozet['odenen'])),
          MIstatSatir('Kalan', _tl(ozet['net_kalan']), renk: t.amber),
        ],
      );

  Widget _masaustuKart(TemaProvider t, Map p) {
    final rol = p['rol'].toString();
    final renk = _rolRenk(rol);
    final net = _n(p['net']);
    final aktif = _n(p['aktif']) == 1;
    final ad = p['ad'].toString();
    return Opacity(
      opacity: aktif ? 1 : 0.55,
      child: MKart(
        onTap: () => _ac(p),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: renk.withValues(alpha: 0.18),
            child: Text(ad.characters.first.toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 6),
              Row(children: [
                MRozet(_rolAd(rol), renk),
                if (!aktif) ...[const SizedBox(width: 6), MRozet('Pasif', t.sub)],
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Text('Maaş ${_tl(p['maas'])}', style: TextStyle(color: t.sub, fontSize: 12)),
                if (_n(p['prim_hesap']) > 0) ...[
                  const SizedBox(width: 8),
                  Text('+prim ${_tl(p['prim_hesap'])}', style: TextStyle(color: t.yesil, fontSize: 12)),
                ],
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_tl(net), style: TextStyle(color: net > 0 ? t.ink : t.sub, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('kalan', style: TextStyle(color: t.sub, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }

  Widget _aySecici() => Container(
        color: _bg,
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(onPressed: () => _ayDegis(-1), icon: const Icon(Icons.chevron_left, color: _mor1)),
          Text(_ayMetin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          IconButton(onPressed: () => _ayDegis(1), icon: const Icon(Icons.chevron_right, color: _mor1)),
        ]),
      );

  Widget _ozetKart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bu Ay Personel Gideri', style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text(_tl(_n(ozet['maas']) + _n(ozet['prim'])), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Row(children: [
          _ozetMini('Maaş', _tl(ozet['maas'])),
          _ozetMini('Prim', _tl(ozet['prim'])),
          _ozetMini('Ödenen', _tl(ozet['odenen'])),
          _ozetMini('Kalan', _tl(ozet['net_kalan'])),
        ]),
      ]),
    );
  }

  Widget _ozetMini(String e, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
          Text(e, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      );

  Widget _personelKart(Map p) {
    final rol = p['rol'].toString();
    final renk = _rolRenk(rol);
    final net = _n(p['net']);
    final aktif = _n(p['aktif']) == 1;
    return GestureDetector(
      onTap: () => _ac(p),
      child: Opacity(
        opacity: aktif ? 1 : 0.55,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF232B42))),
          child: Row(children: [
            CircleAvatar(radius: 22, backgroundColor: renk.withValues(alpha: 0.18), child: Text(p['ad'].toString().characters.first.toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 18))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['ad'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)), child: Text(_rolAd(rol), style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Text('Maaş ${_tl(p['maas'])}', style: const TextStyle(color: _gri, fontSize: 12)),
                  if (_n(p['prim_hesap']) > 0) ...[
                    const SizedBox(width: 8),
                    Text('+prim ${_tl(p['prim_hesap'])}', style: const TextStyle(color: _yesil, fontSize: 12)),
                  ],
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_tl(net), style: TextStyle(color: net > 0 ? Colors.white : _gri, fontWeight: FontWeight.bold, fontSize: 16)),
              const Text('kalan', style: TextStyle(color: _gri, fontSize: 10)),
            ]),
            const Icon(Icons.chevron_right, color: _gri, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// PERSONEL DETAY: config + aylık hesap + hareket defteri + işlemler
// ============================================================================
class PersonelDetayScreen extends StatefulWidget {
  final int id; // 0 = yeni personel
  final String? ay;
  const PersonelDetayScreen({super.key, required this.id, this.ay});
  @override
  State<PersonelDetayScreen> createState() => _PersonelDetayScreenState();
}

class _PersonelDetayScreenState extends State<PersonelDetayScreen> {
  Map ozet = {};
  List hareketler = [];
  bool loading = true;
  bool duzenleyebilir = false;
  bool _degisti = false;

  bool get _yeni => widget.id == 0;

  @override
  void initState() {
    super.initState();
    if (_yeni) {
      loading = false;
      duzenleyebilir = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _formAc());
    } else {
      _yukle();
    }
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.personelDetay(auth.token!, widget.id, ay: widget.ay);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          ozet = (res['ozet'] as Map?) ?? {};
          hareketler = (res['hareketler'] as List?) ?? [];
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop) Navigator.of(context).pop(_degisti); },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).pop(_degisti)),
          title: Text(_yeni ? 'Yeni Personel' : (ozet['ad']?.toString() ?? 'Personel'), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          actions: [
            if (!_yeni && duzenleyebilir) IconButton(onPressed: _formAc, icon: const Icon(Icons.edit, color: _mavi)),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: _mor1))
            : ozet.isEmpty
                ? const Center(child: Text('—', style: TextStyle(color: _gri)))
                : ListView(padding: const EdgeInsets.all(14), children: [
                    _bilgiKart(),
                    const SizedBox(height: 12),
                    _yetkiKart(),
                    const SizedBox(height: 12),
                    _hesapKart(),
                    const SizedBox(height: 12),
                    if (duzenleyebilir) _islemler(),
                    const SizedBox(height: 12),
                    _hareketDefteri(),
                    const SizedBox(height: 30),
                  ]),
      ),
    );
  }

  Widget _bilgiKart() {
    final rol = ozet['rol'].toString();
    final renk = _rolRenk(rol);
    final primTipi = ozet['prim_tipi']?.toString() ?? 'yok';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF232B42))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 24, backgroundColor: renk.withValues(alpha: 0.18), child: Text(ozet['ad'].toString().characters.first.toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 20))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ozet['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)), child: Text(_rolAd(rol), style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold))),
              if ((ozet['telefon']?.toString() ?? '').isNotEmpty) ...[const SizedBox(width: 8), Text(ozet['telefon'].toString(), style: const TextStyle(color: _gri, fontSize: 12))],
            ]),
          ])),
        ]),
        const Divider(color: Color(0xFF232B42), height: 22),
        _satir('Maaş', '${_tl(ozet['maas'])} / ${_maasTipiAd(ozet['maas_tipi']?.toString())}'),
        _satir('Prim', primTipi == 'ciro' ? 'Ciro %${_fmt.format(_n(ozet['prim_oran']))}' : 'Yok', renk: primTipi == 'ciro' ? _yesil : _gri),
        if ((ozet['pin']?.toString() ?? '').isNotEmpty) _satir('PIN', ozet['pin'].toString()),
        if ((ozet['iban']?.toString() ?? '').isNotEmpty) _satir('IBAN', ozet['iban'].toString()),
      ]),
    );
  }

  Widget _yetkiKart() => GestureDetector(
        onTap: _yetkiler,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF232B42))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: _mavi.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shield_outlined, color: _mavi, size: 22)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yetkiler & Limitler', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              SizedBox(height: 2),
              Text('Adisyon, para, yönetim yetkileri + iskonto/ikram limiti', style: TextStyle(color: _gri, fontSize: 12)),
            ])),
            Icon(duzenleyebilir ? Icons.chevron_right : Icons.visibility_outlined, color: _gri, size: 20),
          ]),
        ),
      );

  Widget _hesapKart() {
    final net = _n(ozet['net']);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF232B42))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bu Ay Hesap', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (_n(ozet['ciro']) > 0) _satir('Ciro (prim tabanı)', _tl(ozet['ciro'])),
        _satir('Maaş tahakkuk', _tl(ozet['maas'])),
        if (_n(ozet['prim_hesap']) > 0) _satir('Hesaplanan prim', '+${_tl(ozet['prim_hesap'])}', renk: _yesil),
        if (_n(ozet['prim_manuel']) > 0) _satir('Manuel prim', '+${_tl(ozet['prim_manuel'])}', renk: _yesil),
        if (_n(ozet['ek_odeme']) > 0) _satir('Ek ödeme', '+${_tl(ozet['ek_odeme'])}', renk: _yesil),
        if (_n(ozet['kesinti']) > 0) _satir('Kesinti', '-${_tl(ozet['kesinti'])}', renk: _kirmizi),
        const Divider(color: Color(0xFF232B42), height: 20),
        _satir('Hakediş', _tl(ozet['hakedis']), kalin: true),
        if (_n(ozet['avans']) > 0) _satir('Avans', '-${_tl(ozet['avans'])}', renk: _turuncu),
        if (_n(ozet['odenen']) > 0) _satir('Ödenen', '-${_tl(ozet['odenen'])}', renk: _turuncu),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: (net > 0 ? _yesil : _gri).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Net Ödenecek', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text(_tl(net), style: TextStyle(color: net > 0 ? _yesil : _gri, fontWeight: FontWeight.bold, fontSize: 18)),
          ]),
        ),
      ]),
    );
  }

  Widget _islemler() => Wrap(spacing: 8, runSpacing: 8, children: [
        _islemBtn('Avans Ver', Icons.south_west, _turuncu, () => _hareketDialog('avans', 'Avans Ver')),
        _islemBtn('Ödeme Yap', Icons.check_circle_outline, _yesil, () => _hareketDialog('odeme', 'Maaş/Ödeme Yap')),
        _islemBtn('Prim Ekle', Icons.star_outline, _mor1, () => _hareketDialog('prim', 'Manuel Prim')),
        _islemBtn('Kesinti', Icons.remove_circle_outline, _kirmizi, () => _hareketDialog('kesinti', 'Kesinti')),
        _islemBtn('Ek Ödeme', Icons.add, _mavi, () => _hareketDialog('ek_odeme', 'Ek Ödeme')),
      ]);

  Widget _islemBtn(String s, IconData ic, Color c, VoidCallback f) => GestureDetector(
        onTap: f,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: c.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(ic, color: c, size: 18), const SizedBox(width: 6), Text(s, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 13))]),
        ),
      );

  Widget _hareketDefteri() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF232B42))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Hareket Defteri', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (hareketler.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('Bu ay hareket yok.', style: TextStyle(color: _gri, fontSize: 13)))
        else
          for (final h in hareketler) _hareketSatir(h as Map),
      ]),
    );
  }

  Widget _hareketSatir(Map h) {
    final tur = h['tur'].toString();
    final meta = _turMeta(tur);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(meta.$2, color: meta.$3, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(meta.$1, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          Text('${h['tarih']}${(h['aciklama']?.toString() ?? '').isNotEmpty ? ' · ${h['aciklama']}' : ''}', style: const TextStyle(color: _gri, fontSize: 11)),
        ])),
        Text(_tl(h['tutar']), style: TextStyle(color: meta.$3, fontWeight: FontWeight.bold, fontSize: 14)),
        if (duzenleyebilir)
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => _hareketSil(_n(h['id']).toInt()), icon: const Icon(Icons.close, color: _gri, size: 16)),
      ]),
    );
  }

  // (etiket, ikon, renk)
  (String, IconData, Color) _turMeta(String tur) {
    switch (tur) {
      case 'avans': return ('Avans', Icons.south_west, _turuncu);
      case 'odeme': return ('Maaş/Ödeme', Icons.check_circle, _yesil);
      case 'prim': return ('Manuel Prim', Icons.star, _mor1);
      case 'kesinti': return ('Kesinti', Icons.remove_circle, _kirmizi);
      case 'ek_odeme': return ('Ek Ödeme', Icons.add_circle, _mavi);
      default: return (tur, Icons.circle, _gri);
    }
  }

  String _maasTipiAd(String? t) => {'aylik': 'ay', 'gunluk': 'gün', 'saatlik': 'saat'}[t] ?? 'ay';

  Widget _satir(String s, String v, {Color? renk, bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s, style: const TextStyle(color: _gri, fontSize: 13)),
          Text(v, style: TextStyle(color: renk ?? Colors.white, fontSize: 13, fontWeight: kalin ? FontWeight.bold : FontWeight.w600)),
        ]),
      );

  Future<void> _hareketSil(int id) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.personelHareketSil(auth.token!, id);
      if (!mounted) return;
      if (res['ok'] == 1) { _degisti = true; _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Silinemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _hareketDialog(String tur, String baslik) async {
    final tutarC = TextEditingController();
    final aciklamaC = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: tutarC, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white),
            decoration: _dec('Tutar (TL)')),
          const SizedBox(height: 10),
          TextField(controller: aciklamaC, style: const TextStyle(color: Colors.white), decoration: _dec('Açıklama (opsiyonel)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç', style: TextStyle(color: _gri))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1), onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;
    final tutar = double.tryParse(tutarC.text.replaceAll(',', '.')) ?? 0;
    if (tutar <= 0) { _uyar('Geçerli bir tutar girin'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.personelHareket(auth.token!, widget.id, tur, tutar, aciklama: aciklamaC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) { _degisti = true; _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Kaydedilemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _gri),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
      );

  void _yetkiler() {
    // Koyu zeminli slide geçiş -> varsayılan Android geçişindeki gri flaş olmaz
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      opaque: true,
      barrierColor: _bg,
      pageBuilder: (_, _, _) => PersonelYetkiDuzenleScreen(personelId: widget.id, personelAd: ozet['ad']?.toString() ?? 'Personel'),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  // ---- Personel ekle/düzenle formu ----
  Future<void> _formAc() async {
    final adC = TextEditingController(text: _yeni ? '' : ozet['ad']?.toString() ?? '');
    final telC = TextEditingController(text: _yeni ? '' : ozet['telefon']?.toString() ?? '');
    final pinC = TextEditingController(text: _yeni ? '' : ozet['pin']?.toString() ?? '');
    final maasC = TextEditingController(text: _yeni ? '' : (_n(ozet['maas']) > 0 ? _n(ozet['maas']).toStringAsFixed(0) : ''));
    final oranC = TextEditingController(text: _yeni ? '' : (_n(ozet['prim_oran']) > 0 ? _n(ozet['prim_oran']).toString() : ''));
    final ibanC = TextEditingController(text: _yeni ? '' : ozet['iban']?.toString() ?? '');
    String rol = _yeni ? 'garson' : (ozet['rol']?.toString() ?? 'garson');
    String maasTipi = _yeni ? 'aylik' : (ozet['maas_tipi']?.toString() ?? 'aylik');
    String primTipi = _yeni ? 'yok' : (ozet['prim_tipi']?.toString() ?? 'yok');
    bool aktif = _yeni ? true : _n(ozet['aktif']) == 1;

    final kaydet = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
              Text(_yeni ? 'Yeni Personel' : 'Personeli Düzenle', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              TextField(controller: adC, style: const TextStyle(color: Colors.white), decoration: _dec('Ad Soyad')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: telC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _dec('Telefon'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: pinC, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: _dec('PIN'))),
              ]),
              const SizedBox(height: 10),
              _dropdown('Rol', rol, const {'sahip': 'Sahip', 'mudur': 'Müdür', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak'}, (v) => setS(() => rol = v)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 2, child: TextField(controller: maasC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Maaş (TL)'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _dropdown('Tip', maasTipi, const {'aylik': 'Aylık', 'gunluk': 'Günlük', 'saatlik': 'Saatlik'}, (v) => setS(() => maasTipi = v))),
              ]),
              const SizedBox(height: 10),
              _dropdown('Prim', primTipi, const {'yok': 'Prim Yok', 'ciro': 'Ciro Yüzdesi'}, (v) => setS(() => primTipi = v)),
              if (primTipi == 'ciro') ...[
                const SizedBox(height: 10),
                TextField(controller: oranC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Prim Oranı (% ciro)')),
              ],
              const SizedBox(height: 10),
              TextField(controller: ibanC, style: const TextStyle(color: Colors.white), decoration: _dec('IBAN (opsiyonel)')),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: _yesil,
                title: const Text('Aktif', style: TextStyle(color: Colors.white)),
                value: aktif,
                onChanged: (v) => setS(() => aktif = v),
              ),
              const SizedBox(height: 6),
              SizedBox(width: double.infinity, child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
              )),
            ]),
          ),
        ),
      ),
    );

    if (kaydet != true) {
      if (_yeni && mounted) Navigator.of(context).pop(_degisti); // yeni iptal -> geri
      return;
    }
    if (adC.text.trim().isEmpty) { _uyar('İsim boş olamaz'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.personelKaydet(auth.token!,
        id: _yeni ? null : widget.id,
        ad: adC.text.trim(), telefon: telC.text.trim(), rol: rol, aktif: aktif,
        pin: pinC.text.trim(), maas: double.tryParse(maasC.text.replaceAll(',', '.')) ?? 0,
        maasTipi: maasTipi, primTipi: primTipi, primOran: double.tryParse(oranC.text.replaceAll(',', '.')) ?? 0,
        iban: ibanC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) {
        _degisti = true;
        if (_yeni) {
          Navigator.of(context).pop(true); // listeye don, yenile
        } else {
          _yukle();
        }
      } else {
        _uyar(res['hata']?.toString() ?? 'Kaydedilemedi');
      }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Widget _dropdown(String label, String value, Map<String, String> items, ValueChanged<String> onChanged) => InputDecorator(
        decoration: _dec(label),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isDense: true,
            dropdownColor: _card,
            isExpanded: true,
            style: const TextStyle(color: Colors.white),
            items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      );
}
