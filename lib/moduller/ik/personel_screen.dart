import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';
import 'yetki_duzenle_screen.dart';

/// /personel — Personel & Maaş (web personel.blade.php ile aynı veri ve işlemler):
/// liste (rol grupları, arama, rol/durum/departman filtresi), ay seçici + maaş özeti, personel ekle/düzenle
/// (rol, PIN, durum + ayrılış, maaş/prim, IBAN, özlük), detay (hesap, avans/ödeme/prim/kesinti/ek ödeme,
/// hareket defteri), PERSONEL YETKİLERİ (sayfa + işlem + departman/ünvan/sorumlu, "tam yetki").
class IkPersonelScreen extends StatefulWidget {
  const IkPersonelScreen({super.key});
  @override
  State<IkPersonelScreen> createState() => _IkPersonelScreenState();
}

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _rolGrup = {'sahip': 'Yöneticiler', 'mudur': 'Yöneticiler', 'satinalmaci': 'Yöneticiler', 'garson': 'Garsonlar', 'mutfak': 'Mutfak / Ustalar', 'usta': 'Mutfak / Ustalar', 'kasa': 'Kasiyerler'};
const _grupSira = ['Yöneticiler', 'Garsonlar', 'Mutfak / Ustalar', 'Kasiyerler', 'Diğer'];
const _ayrilisSebep = {
  'istifa': 'İstifa (kendi isteğiyle)', 'cikarma': 'İşten çıkarma', 'deneme': 'Deneme süresinde ayrıldı', 'devamsizlik': 'Devamsızlık / haber vermeden bıraktı',
  'sezon': 'Sezon / sözleşme bitti', 'emeklilik': 'Emeklilik', 'nakil': 'Başka şubeye geçti', 'diger': 'Diğer',
};
const _maasTipAd = {'aylik': 'ay', 'gunluk': 'gün', 'saatlik': 'saat'};

String _ayKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
String _ayMetin(String key) {
  final p = key.split('-');
  if (p.length != 2) return key;
  return '${_aylar[int.tryParse(p[1]) ?? 0]} ${p[0]}';
}

/// /api/patron/personel-list|detay: yalnız sahip/müdür. 401'de oturumu kapatmadan null döner.
Future<Map<String, dynamic>?> _apiAl(BuildContext context, String yol, Map<String, String> q) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    final c = await KopruApi.al(tok, yol, q: q);
    return c.ok ? c.j : null;
  } on ApiYetkiHatasi {
    return null;
  }
}

class _IkPersonelScreenState extends State<IkPersonelScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _ay = _ayKey(DateTime.now());
  Map<int, Map<String, dynamic>> _hesap = {};
  Map<String, dynamic> _ozet = {};
  bool _hesapVar = false;
  String _ara = '';
  String _rolF = 'hepsi';
  String _aktifF = 'all';
  int _depF = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _hesapYukle());
  }

  Future<void> _hesapYukle() async {
    final j = await _apiAl(context, '/api/patron/personel-list', {'ay': _ay});
    if (!mounted) return;
    setState(() {
      _hesapVar = j != null;
      _ozet = harita(j?['ozet']);
      _hesap = {for (final p in liste(j?['personeller'])) tamOku(p['id']): p};
    });
  }

  Future<void> _yenile() async {
    await Future.wait([_k.currentState?.yukle() ?? Future.value(), _hesapYukle()]);
  }

  void _ayDegis(int fark) {
    final p = _ay.split('-');
    final d = DateTime(int.parse(p[0]), int.parse(p[1]) + fark, 1);
    final simdi = DateTime.now();
    if (d.isAfter(DateTime(simdi.year, simdi.month, 1))) return;
    setState(() => _ay = _ayKey(d));
    _hesapYukle();
  }

  Future<void> _detayAc(Map<String, dynamic> p, Map<String, dynamic> veri) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => IkPersonelDetayScreen(personel: p, sayfaVeri: veri, ay: _ay),
    ));
    if (r == true || mounted) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/personel',
      baslik: 'Personel & Maaş',
      ikon: Icons.badge_outlined,
      araclar: (ctx, v, y) => [
        IconButton(
          tooltip: 'Departman & Yetki',
          icon: const Icon(Icons.groups_outlined),
          onPressed: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/departman-yonetim', 'Departman & Yetki'))),
        ),
      ],
      fab: (ctx, v, y) => (v['duzenleyebilir'] == true)
          ? FloatingActionButton.extended(
              heroTag: 'ik_personel_ekle',
              onPressed: () async {
                if (await ikPersonelFormAc(ctx, null, v)) _yenile();
              },
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Personel Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
      govde: (ctx, v, y) => _govde(ctx, v),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v) {
    final t = context.watch<TemaProvider>();
    final tum = liste(v['personeller']);
    final deps = liste(v['departmanlar']);
    final depMap = {for (final d in deps) tamOku(d['id']): d};

    final rolSay = <String, int>{};
    for (final p in tum) {
      final r = metinOku(p['rol'], 'diger');
      rolSay[r] = (rolSay[r] ?? 0) + 1;
    }

    final suzulmus = tum.where((p) {
      final dep = depMap[tamOku(p['departman_id'])];
      final metin = '${metinOku(p['ad'])} ${metinOku(dep?['ad'])} ${metinOku(p['departman_unvan'])} ${kIkRolAd[p['rol']] ?? ''}'.toLowerCase();
      if (_ara.isNotEmpty && !metin.contains(_ara)) return false;
      if (_rolF != 'hepsi' && p['rol'] != _rolF) return false;
      if (_aktifF != 'all' && '${tamOku(p['aktif'])}' != _aktifF) return false;
      if (_depF != 0 && tamOku(p['departman_id']) != _depF) return false;
      return true;
    }).toList();

    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final p in suzulmus) {
      gruplar.putIfAbsent(_rolGrup[p['rol']] ?? 'Diğer', () => []).add(p);
    }
    for (final l in gruplar.values) {
      l.sort((a, b) => tamOku(b['aktif']).compareTo(tamOku(a['aktif'])));
    }

    final aktifSay = tum.where((p) => tamOku(p['aktif']) == 1).length;
    final cocuklar = <Widget>[
      // Ay seçici + özet
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(children: [
          IconButton(onPressed: () => _ayDegis(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Önceki ay'),
          Expanded(
            child: Column(children: [
              Text(_ayMetin(_ay), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('Maaş / prim hesap dönemi', style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
          IconButton(
            onPressed: _ay == _ayKey(DateTime.now()) ? null : () => _ayDegis(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Sonraki ay',
          ),
        ]),
      ),
      KKpiIzgara([
        KKpi(etiket: 'Personel', deger: '$aktifSay', alt: '${tum.length - aktifSay} pasif', ikon: Icons.groups_outlined, renk: t.mor1),
        if (_hesapVar) ...[
          KKpi(etiket: 'Toplam Maaş', deger: tl(_ozet['maas'], kisa: true), ikon: Icons.payments_outlined, renk: t.mavi),
          KKpi(etiket: 'Prim', deger: tl(_ozet['prim'], kisa: true), ikon: Icons.star_outline, renk: t.yesil),
          KKpi(etiket: 'Ödenen', deger: tl(_ozet['odenen'], kisa: true), ikon: Icons.check_circle_outline, renk: t.amber),
          KKpi(etiket: 'Net Kalan', deger: tl(_ozet['net_kalan'], kisa: true), alt: 'ödenecek', ikon: Icons.account_balance_wallet_outlined, renk: t.kirmizi),
        ],
      ]),
      KAra(ipucu: 'İsim, departman veya ünvana göre ara…', onDegis: (s) => setState(() => _ara = s.toLowerCase().trim())),
      KCipler(
        secenekler: [
          ('hepsi', 'Tümü ${tum.length}'),
          for (final r in ['sahip', 'mudur', 'satinalmaci', 'garson', 'mutfak', 'kasa'])
            if ((rolSay[r] ?? 0) > 0) (r, '${kIkRolAd[r]} ${rolSay[r]}'),
        ],
        secili: _rolF,
        onSec: (k) => setState(() => _rolF = k),
      ),
      Row(children: [
        Expanded(
          child: KCipler(
            secenekler: const [('all', 'Hepsi'), ('1', 'Aktif'), ('0', 'Pasif')],
            secili: _aktifF,
            onSec: (k) => setState(() => _aktifF = k),
          ),
        ),
      ]),
      if (deps.isNotEmpty)
        KSecim<int>('Departman',
            deger: _depF,
            secenekler: [(0, 'Tüm departmanlar'), for (final d in deps) (tamOku(d['id']), metinOku(d['ad']))],
            onSec: (x) => setState(() => _depF = x ?? 0)),
    ];

    if (tum.isEmpty) {
      cocuklar.add(KBos(
        ikon: Icons.group_off_outlined,
        baslik: 'Henüz personel yok',
        aciklama: v['duzenleyebilir'] == true
            ? 'Sağ alttaki "Personel Ekle" ile ilk personeli ekleyin (ad, rol ve en az 4 haneli PIN yeterli).'
            : 'Personeli işletme sahibi ekler. Personel eklendiğinde burada listelenir.',
      ));
    } else if (suzulmus.isEmpty) {
      cocuklar.add(const KBos(ikon: Icons.search_off, baslik: 'Eşleşen personel yok', aciklama: 'Arama veya filtreyi temizleyin.'));
    } else {
      for (final g in _grupSira) {
        final l = gruplar[g];
        if (l == null || l.isEmpty) continue;
        cocuklar.add(KBaslik(g, ikon: Icons.groups_outlined, sag: KRozet('${l.length}', renk: t.sub2)));
        cocuklar.add(LayoutBuilder(builder: (ctx, c) {
          final n = c.maxWidth >= 1000 ? 3 : (c.maxWidth >= 640 ? 2 : 1);
          final w = (c.maxWidth - (n - 1) * 12) / n;
          return Wrap(spacing: 12, children: [
            for (final p in l) SizedBox(width: w, child: _kart(t, p, depMap, v)),
          ]);
        }));
      }
    }
    return KGovde(yenile: _yenile, children: cocuklar);
  }

  Widget _kart(TemaProvider t, Map<String, dynamic> p, Map<int, Map<String, dynamic>> depMap, Map<String, dynamic> v) {
    final rol = metinOku(p['rol'], 'garson');
    final renk = ikRolRenk(rol);
    final aktif = tamOku(p['aktif']) == 1;
    final dep = depMap[tamOku(p['departman_id'])];
    final unvan = metinOku(p['departman_unvan']);
    final h = _hesap[tamOku(p['id'])];
    final net = sayiOku(h?['net']);
    return Opacity(
      opacity: aktif ? 1 : .6,
      child: KKart(
        renk: renk,
        onTap: () => _detayAc(p, v),
        child: Row(children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: renk.withValues(alpha: .16),
            child: Text(metinOku(p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 17)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(p['ad'], '—'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Wrap(spacing: 5, runSpacing: 4, children: [
                KRozet(kIkRolAd[rol] ?? rol, renk: renk),
                if (dep != null) KRozet('${metinOku(dep['ad'])}${unvan.isNotEmpty ? ' · $unvan' : ''}', renk: renkOku(dep['renk'], const Color(0xFF64748B))),
                if (dep != null && tamOku(p['departman_sorumlu']) == 1) KRozet('★ Sorumlu', renk: const Color(0xFFB45309)),
                if (!aktif) KRozet('Pasif', renk: t.sub),
              ]),
            ]),
          ),
          if (h != null) ...[
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tl(net, kisa: true), style: TextStyle(color: net > 0 ? t.kirmizi : t.yesil, fontWeight: FontWeight.w800, fontSize: 15)),
              Text(net > 0 ? 'ödenmedi' : 'kapandı', style: TextStyle(color: t.sub, fontSize: 11.5)),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ═════════════════════════════ DETAY ═════════════════════════════
class IkPersonelDetayScreen extends StatefulWidget {
  final Map<String, dynamic> personel;
  final Map<String, dynamic> sayfaVeri;
  final String ay;
  const IkPersonelDetayScreen({super.key, required this.personel, required this.sayfaVeri, required this.ay});
  @override
  State<IkPersonelDetayScreen> createState() => _IkPersonelDetayScreenState();
}

class _IkPersonelDetayScreenState extends State<IkPersonelDetayScreen> {
  late Map<String, dynamic> _p;
  late Map<String, dynamic> _v;
  Map<String, dynamic>? _ozet;
  List<Map<String, dynamic>> _hareketler = [];
  bool _yukleniyor = true;
  bool _degisti = false;

  bool get _duzenleyebilir => _v['duzenleyebilir'] == true;
  int get _id => tamOku(_p['id']);

  @override
  void initState() {
    super.initState();
    _p = widget.personel;
    _v = widget.sayfaVeri;
    WidgetsBinding.instance.addPostFrameCallback((_) => _detayYukle());
  }

  Future<void> _detayYukle() async {
    final j = await _apiAl(context, '/api/patron/personel-detay', {'id': '$_id', 'ay': widget.ay});
    if (!mounted) return;
    setState(() {
      _yukleniyor = false;
      _ozet = j == null ? null : harita(j['ozet']);
      _hareketler = liste(j?['hareketler']);
    });
  }

  /// Düzenleme / yetki sonrası kişinin güncel halini /personel'den tekrar al
  Future<void> _personelYenile() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/personel');
      if (!mounted || !c.ok) return;
      final yeni = liste(c.veri['personeller']).where((x) => tamOku(x['id']) == _id).toList();
      setState(() {
        _v = c.veri;
        if (yeni.isNotEmpty) _p = yeni.first;
      });
    } on ApiYetkiHatasi {
      return;
    }
    await _detayYukle();
  }

  Future<void> _yetkiAc() async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => IkYetkiDuzenleScreen(personel: _p, sayfaVeri: _v)));
    if (r == true) {
      _degisti = true;
      _personelYenile();
    }
  }

  Future<void> _duzenle() async {
    if (await ikPersonelFormAc(context, _p, _v)) {
      _degisti = true;
      _personelYenile();
    }
  }

  Future<void> _hareket(String tur, String baslik) async {
    final tutarC = TextEditingController();
    final acikC = TextEditingController();
    final ok = await kAltSayfa<bool>(context, baslik: baslik, icerik: (c) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(metinOku(_p['ad']), style: TextStyle(color: c.read<TemaProvider>().sub, fontSize: 13)),
        const SizedBox(height: 10),
        KAlan('Tutar (TL)', tutarC, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true, ipucu: '0'),
        KAlan('Açıklama (opsiyonel)', acikC),
        KButon('Kaydet', ikon: Icons.check, genis: true, onTap: () {
          if (sayiOku(tutarC.text) <= 0) {
            kToast(c, 'Geçerli bir tutar girin.', hata: true);
            return;
          }
          Navigator.pop(c, true);
        }),
      ]);
    });
    if (ok != true || !mounted) return;
    final b = await kopruGonder(context, '/api/patron/personel-hareket',
        {'personel_id': _id, 'tur': tur, 'tutar': sayiOku(tutarC.text).toString(), 'aciklama': acikC.text.trim()},
        basariMesaji: '$baslik kaydedildi.');
    if (b) {
      _degisti = true;
      _detayYukle();
    }
  }

  Future<void> _hareketSil(Map<String, dynamic> h) async {
    if (!await kOnay(context, 'Bu hareket silinsin mi?', evet: 'Sil', tehlikeli: true, aciklama: '${_tur(h['tur']).$1} · ${tl(h['tutar'])}')) return;
    if (!mounted) return;
    final b = await kopruGonder(context, '/api/patron/personel-hareket-sil', {'id': h['id']}, basariMesaji: 'Hareket silindi.');
    if (b) {
      _degisti = true;
      _detayYukle();
    }
  }

  Future<void> _durumDegis() async {
    final aktif = tamOku(_p['aktif']) == 1;
    if (aktif) {
      // Pasife alma = işten ayrılış: tarih + sebep formda sorulur
      await _duzenle();
      return;
    }
    if (!await kOnay(context, '${metinOku(_p['ad'])} tekrar aktif yapılsın mı?', evet: 'Aktif yap')) return;
    if (!mounted) return;
    final b = await kopruGonder(context, '/personel/kaydet', {'id': _id, 'aktif': '1'});
    if (b) {
      _degisti = true;
      _personelYenile();
    }
  }

  (String, IconData, Color) _tur(dynamic tur) {
    switch ('$tur') {
      case 'avans':
        return ('Avans', Icons.south_west, const Color(0xFFD97706));
      case 'odeme':
        return ('Maaş/Ödeme', Icons.check_circle_outline, const Color(0xFF10B981));
      case 'prim':
        return ('Manuel Prim', Icons.star_outline, const Color(0xFF7C3AED));
      case 'kesinti':
        return ('Kesinti', Icons.remove_circle_outline, const Color(0xFFDC2626));
      case 'ek_odeme':
        return ('Ek Ödeme', Icons.add_circle_outline, const Color(0xFF2563EB));
    }
    return ('$tur', Icons.circle_outlined, const Color(0xFF64748B));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final rol = metinOku(_p['rol'], 'garson');
    final renk = ikRolRenk(rol);
    final aktif = tamOku(_p['aktif']) == 1;
    final dep = liste(_v['departmanlar']).where((d) => tamOku(d['id']) == tamOku(_p['departman_id'])).firstOrNull;
    final unvan = metinOku(_p['departman_unvan']);
    final sayfaAcik = harita(_p['sayfa']).values.where((x) => x == true).length;
    final yetkiAcik = harita(_p['yetkiler']).values.where((x) => x == true).length;
    final tel = metinOku(_p['telefon']);
    final genis = genisMi(context);

    final sol = <Widget>[
      KKart(
        renk: renk,
        child: Row(children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: renk.withValues(alpha: .16),
            child: Text(metinOku(_p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 21)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(_p['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: [
                KRozet(kIkRolAd[rol] ?? rol, renk: renk),
                if (!aktif) KRozet('Pasif', renk: t.sub),
                if (dep != null) KRozet('${metinOku(dep['ad'])}${unvan.isNotEmpty ? ' · $unvan' : ''}', renk: renkOku(dep['renk'], t.mavi), ikon: Icons.groups_outlined),
                if (dep != null && tamOku(_p['departman_sorumlu']) == 1) KRozet('★ Sorumlu', renk: const Color(0xFFB45309)),
              ]),
              if (tel.isNotEmpty)
                InkWell(
                  onTap: () => launchUrl(Uri.parse('tel:$tel')),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.call_outlined, size: 15, color: t.mavi),
                      const SizedBox(width: 4),
                      Text(tel, style: TextStyle(color: t.mavi, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
      // Yetkiler & Limitler
      KKart(
        onTap: _yetkiAc,
        child: Row(children: [
          KIkon(Icons.shield_outlined, renk: t.mavi),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Yetkiler & Limitler', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text('Seviye: ${metinOku(harita(harita(_v['kademeler'])[_p['kademe']])['ad'], metinOku(_p['kademe']))} · $sayfaAcik sayfa · $yetkiAcik işlem yetkisi',
                  style: TextStyle(color: t.sub, fontSize: 12.5)),
              Text(_duzenleyebilir ? 'Sayfa yetkileri, departman/ünvan/sorumlu, POS yetkileri, tam yetki' : 'Yalnız görüntüleme (düzenleme işletme sahibinde)',
                  style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
          Icon(_duzenleyebilir ? Icons.chevron_right : Icons.visibility_outlined, color: t.sub),
        ]),
      ),
      // Bilgi
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KBaslik('Bilgiler', ikon: Icons.info_outline),
          _satir(t, 'Maaş', '${tl(_p['maas'], kisa: true)} / ${_maasTipAd[_p['maas_tipi']] ?? 'ay'}'),
          _satir(t, 'Prim', _p['prim_tipi'] == 'ciro' ? 'Ciro %${sayiYaz(_p['prim_oran'])}' : 'Yok', renk: _p['prim_tipi'] == 'ciro' ? t.yesil : null),
          if (metinOku(_p['pin']).isNotEmpty) _satir(t, 'PIN', metinOku(_p['pin'])),
          if (metinOku(_p['iban']).isNotEmpty) _satir(t, 'IBAN', metinOku(_p['iban'])),
          if (metinOku(_p['ise_baslama']).isNotEmpty) _satir(t, 'İşe başlama', tarihYaz(_p['ise_baslama'], saat: false)),
          if (metinOku(_p['dogum_tarihi']).isNotEmpty) _satir(t, 'Doğum tarihi', tarihYaz(_p['dogum_tarihi'], saat: false)),
          if (metinOku(_p['tc']).isNotEmpty) _satir(t, 'TC Kimlik', metinOku(_p['tc'])),
          if (metinOku(_p['acil_kisi']).isNotEmpty || metinOku(_p['acil_tel']).isNotEmpty)
            _satir(t, 'Acil durum', '${metinOku(_p['acil_kisi'])} ${metinOku(_p['acil_tel'])}'.trim()),
          if (!aktif && metinOku(_p['ise_cikis']).isNotEmpty)
            _satir(t, 'Ayrılış', '${tarihYaz(_p['ise_cikis'], saat: false)}${_ayrilisSebep[_p['ayrilis_sebep']] != null ? ' · ${_ayrilisSebep[_p['ayrilis_sebep']]}' : ''}', renk: t.kirmizi),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Sicil Kartı', ikon: Icons.folder_shared_outlined, ikincil: true, renk: t.mavi,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/ik-sicil?id=$_id', 'Sicil Kartı')))),
            if (_duzenleyebilir) KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: _duzenle),
            if (_duzenleyebilir)
              KButon(aktif ? 'Pasife al (ayrıldı)' : 'Tekrar aktif yap', ikon: aktif ? Icons.person_off_outlined : Icons.person_outline, ikincil: true, renk: aktif ? t.kirmizi : t.yesil, onTap: _durumDegis),
          ]),
        ]),
      ),
    ];

    final sag = <Widget>[
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Hesap — ${_ayMetin(widget.ay)}', ikon: Icons.account_balance_wallet_outlined),
          if (_yukleniyor)
            const Padding(padding: EdgeInsets.all(16), child: KYukleniyor())
          else if (_ozet == null)
            Text('Maaş hesabını yalnız işletme sahibi ve müdür görebilir.', style: TextStyle(color: t.sub, fontSize: 13.5))
          else ...[
            if (sayiOku(_ozet!['ciro']) > 0) _satir(t, 'Ciro (prim tabanı)', tl(_ozet!['ciro'])),
            _satir(t, 'Maaş tahakkuk', tl(_ozet!['maas'])),
            if (sayiOku(_ozet!['prim_hesap']) > 0) _satir(t, 'Hesaplanan prim', '+${tl(_ozet!['prim_hesap'])}', renk: t.yesil),
            if (sayiOku(_ozet!['prim_manuel']) > 0) _satir(t, 'Manuel prim', '+${tl(_ozet!['prim_manuel'])}', renk: t.yesil),
            if (sayiOku(_ozet!['ek_odeme']) > 0) _satir(t, 'Ek ödeme', '+${tl(_ozet!['ek_odeme'])}', renk: t.yesil),
            if (sayiOku(_ozet!['kesinti']) > 0) _satir(t, 'Kesinti', '-${tl(_ozet!['kesinti'])}', renk: t.kirmizi),
            Divider(color: t.line),
            _satir(t, 'Hakediş', tl(_ozet!['hakedis']), kalin: true),
            if (sayiOku(_ozet!['avans']) > 0) _satir(t, 'Avans', '-${tl(_ozet!['avans'])}', renk: const Color(0xFFD97706)),
            if (sayiOku(_ozet!['odenen']) > 0) _satir(t, 'Ödenen', '-${tl(_ozet!['odenen'])}', renk: const Color(0xFFD97706)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (sayiOku(_ozet!['net']) > 0 ? t.kirmizi : t.yesil).withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: Text('Net Ödenecek', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14))),
                Text(tl(_ozet!['net']), style: TextStyle(color: sayiOku(_ozet!['net']) > 0 ? t.kirmizi : t.yesil, fontWeight: FontWeight.w800, fontSize: 18)),
              ]),
            ),
          ],
        ]),
      ),
      if (_duzenleyebilir && _ozet != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (tur, et) in const [('avans', 'Avans Ver'), ('odeme', 'Ödeme Yap'), ('prim', 'Prim Ekle'), ('kesinti', 'Kesinti'), ('ek_odeme', 'Ek Ödeme')])
              KButon(et, ikon: _tur(tur).$2, renk: _tur(tur).$3, ikincil: true, onTap: () => _hareket(tur, et == 'Ödeme Yap' ? 'Maaş/Ödeme Yap' : et)),
          ]),
        ),
      if (_ozet != null)
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('Hareket Defteri', ikon: Icons.history),
            if (_hareketler.isEmpty)
              Text('Bu ay hareket yok. Avans, ödeme, prim, kesinti veya ek ödeme girildiğinde burada listelenir.', style: TextStyle(color: t.sub, fontSize: 13))
            else
              for (final h in _hareketler)
                KSatir(
                  solIkon: KIkon(_tur(h['tur']).$2, renk: _tur(h['tur']).$3, boyut: 34),
                  baslik: _tur(h['tur']).$1,
                  alt: '${tarihYaz(h['tarih'], saat: false)}${metinOku(h['aciklama']).isNotEmpty ? ' · ${metinOku(h['aciklama'])}' : ''}',
                  sag: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(tl(h['tutar']), style: TextStyle(color: _tur(h['tur']).$3, fontWeight: FontWeight.w700, fontSize: 14)),
                    if (_duzenleyebilir)
                      IconButton(tooltip: 'Sil', icon: Icon(Icons.close, size: 18, color: t.sub), onPressed: () => _hareketSil(h)),
                  ]),
                ),
          ]),
        ),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _degisti);
      },
      child: KSayfa(
        baslik: metinOku(_p['ad'], 'Personel'),
        ikon: Icons.badge_outlined,
        araclar: [
          if (_duzenleyebilir) IconButton(tooltip: 'Düzenle', onPressed: _duzenle, icon: const Icon(Icons.edit_outlined)),
          IconButton(tooltip: 'Yenile', onPressed: _personelYenile, icon: const Icon(Icons.refresh)),
        ],
        govde: genis
            ? KGovde(yenile: _personelYenile, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sol)),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: sag)),
                ]),
              ])
            : KGovde(yenile: _personelYenile, children: [...sol, ...sag]),
      ),
    );
  }

  Widget _satir(TemaProvider t, String s, String v, {Color? renk, bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(s, style: TextStyle(color: t.sub, fontSize: 13.5))),
          Expanded(
            child: Text(v, textAlign: TextAlign.right, style: TextStyle(color: renk ?? t.ink, fontSize: kalin ? 15 : 14, fontWeight: kalin ? FontWeight.w800 : FontWeight.w600)),
          ),
        ]),
      );
}

// ═════════════════════════════ EKLE / DÜZENLE FORMU ═════════════════════════════
/// Web "Yeni Personel / Personeli Düzenle" penceresi. Kaydedildiyse true.
/// Özlük + rol/PIN/durum → POST /personel/kaydet ; maaş/prim → POST /api/patron/personel-kaydet
/// (web'de de maaş/prim bu uçtan yönetilir; /personel/kaydet maaşa dokunmaz).
Future<bool> ikPersonelFormAc(BuildContext context, Map<String, dynamic>? p, Map<String, dynamic> veri) async {
  final r = await kAltSayfa<bool>(context, baslik: p == null ? 'Yeni Personel' : 'Personeli Düzenle', icerik: (c) => _PersonelForm(p: p));
  return r == true;
}

class _PersonelForm extends StatefulWidget {
  final Map<String, dynamic>? p;
  const _PersonelForm({this.p});
  @override
  State<_PersonelForm> createState() => _PersonelFormState();
}

class _PersonelFormState extends State<_PersonelForm> {
  late final TextEditingController _ad, _tel, _pin, _maas, _primOran, _iban, _tc, _acilKisi, _acilTel;
  String _rol = 'garson';
  String _aktif = '1';
  String _maasTipi = 'aylik';
  String _primTipi = 'yok';
  String _iseBaslama = '';
  String _dogum = '';
  String _iseCikis = '';
  String _sebep = '';
  bool _kaydediliyor = false;

  @override
  void initState() {
    super.initState();
    final p = widget.p ?? const {};
    String m(String k) => metinOku(p[k]);
    _ad = TextEditingController(text: m('ad'));
    _tel = TextEditingController(text: m('telefon'));
    _pin = TextEditingController(text: m('pin'));
    _maas = TextEditingController(text: widget.p == null ? '' : sayiOku(p['maas']).round().toString());
    _primOran = TextEditingController(text: widget.p == null ? '' : sayiYaz(p['prim_oran']));
    _iban = TextEditingController(text: m('iban'));
    _tc = TextEditingController(text: m('tc'));
    _acilKisi = TextEditingController(text: m('acil_kisi'));
    _acilTel = TextEditingController(text: m('acil_tel'));
    _rol = kIkRolAd.containsKey(m('rol')) ? m('rol') : 'garson';
    _aktif = widget.p == null ? '1' : '${tamOku(p['aktif'])}';
    _maasTipi = ['aylik', 'gunluk', 'saatlik'].contains(m('maas_tipi')) ? m('maas_tipi') : 'aylik';
    _primTipi = m('prim_tipi') == 'ciro' ? 'ciro' : 'yok';
    _iseBaslama = _gun(m('ise_baslama'));
    _dogum = _gun(m('dogum_tarihi'));
    _iseCikis = _gun(m('ise_cikis'));
    _sebep = m('ayrilis_sebep');
  }

  String _gun(String s) => s.length >= 10 ? s.substring(0, 10) : s;

  @override
  void dispose() {
    for (final c in [_ad, _tel, _pin, _maas, _primOran, _iban, _tc, _acilKisi, _acilTel]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _tarihSec(String mevcut, ValueChanged<String> sec, {bool gelecekYok = false}) async {
    final simdi = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(mevcut) ?? simdi,
      firstDate: DateTime(1940),
      lastDate: gelecekYok ? simdi : DateTime(simdi.year + 2),
    );
    if (d != null) setState(() => sec('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'));
  }

  Widget _tarihAlan(TemaProvider t, String etiket, String deger, ValueChanged<String> sec, {bool gelecekYok = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _tarihSec(deger, sec, gelecekYok: gelecekYok),
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
            child: Row(children: [
              Icon(Icons.calendar_today_outlined, size: 17, color: t.sub),
              const SizedBox(width: 8),
              Expanded(child: Text(deger.isEmpty ? 'Seçin' : tarihYaz(deger, saat: false), style: TextStyle(color: deger.isEmpty ? t.sub : t.ink, fontSize: 15))),
              if (deger.isNotEmpty)
                InkWell(onTap: () => setState(() => sec('')), child: Icon(Icons.close, size: 18, color: t.sub)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _ikili(Widget a, Widget b) => genisMi(context) || MediaQuery.of(context).size.width >= 480
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)])
      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a, b]);

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    final pin = _pin.text.replaceAll(RegExp(r'\D'), '');
    if (ad.isEmpty) return kToast(context, 'İsim boş olamaz.', hata: true);
    if (widget.p == null && pin.length < 4) return kToast(context, 'Yeni personel için en az 4 haneli PIN zorunlu.', hata: true);
    if (pin.isNotEmpty && pin.length < 4) return kToast(context, 'PIN en az 4 haneli olmalı.', hata: true);
    setState(() => _kaydediliyor = true);
    final pasif = _aktif == '0';
    final ozluk = <String, dynamic>{
      'ad': ad, 'telefon': _tel.text.trim(), 'rol': _rol, 'aktif': _aktif,
      'iban': _iban.text.trim(), 'tc': _tc.text.replaceAll(RegExp(r'\D'), ''), 'dogum_tarihi': _dogum, 'ise_baslama': _iseBaslama,
      'acil_kisi': _acilKisi.text.trim(), 'acil_tel': _acilTel.text.trim(),
      if (pasif) 'ise_cikis': _iseCikis.isEmpty ? _bugun() : _iseCikis,
      if (pasif) 'ayrilis_sebep': _sebep,
    };
    final maasGovde = <String, dynamic>{
      'ad': ad, 'telefon': _tel.text.trim(), 'rol': _rol, 'aktif': _aktif,
      'maas': sayiOku(_maas.text).toString(), 'maas_tipi': _maasTipi, 'prim_tipi': _primTipi,
      'prim_oran': _primTipi == 'ciro' ? sayiOku(_primOran.text).toString() : '0',
      'iban': _iban.text.trim(), 'ise_baslama': _iseBaslama,
      if (pasif) 'ise_cikis': _iseCikis.isEmpty ? _bugun() : _iseCikis,
      if (pasif) 'ayrilis_sebep': _sebep,
    };
    bool ok;
    if (widget.p == null) {
      // 1) maaş ucuyla oluştur (id döner)  2) özlük alanlarını aynı kayda yaz
      final c = await kopruGonderCevap(context, '/api/patron/personel-kaydet', {...maasGovde, 'pin': pin});
      ok = c != null && c.ok;
      final yeniId = tamOku(c?.j['id']);
      if (ok && yeniId > 0 && mounted) {
        await kopruGonderCevap(context, '/personel/kaydet', {...ozluk, 'id': yeniId});
      }
      if (ok && mounted) kToast(context, 'Personel eklendi.');
    } else {
      final id = tamOku(widget.p!['id']);
      final c1 = await kopruGonderCevap(context, '/personel/kaydet', {...ozluk, 'id': id, if (pin.isNotEmpty) 'pin': pin});
      ok = c1 != null && c1.ok;
      if (ok && mounted) {
        final c2 = await kopruGonderCevap(context, '/api/patron/personel-kaydet', {...maasGovde, 'id': id});
        if (mounted) {
          if (c2 != null && c2.ok) {
            kToast(context, c1.mesaj ?? 'Personel güncellendi.');
          } else {
            kToast(context, 'Bilgiler kaydedildi ama maaş/prim kaydedilemedi: ${c2?.hata ?? 'bağlantı'}', hata: true);
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    if (ok) Navigator.pop(context, true);
  }

  String _bugun() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: t.mavi.withValues(alpha: .1), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mavi.withValues(alpha: .3))),
        child: Text('Kasa / istasyon oluşturmak için: bir ad yazın (ör. "Kasa 1"), Rol = Kasa seçin ve bir PIN verin. Telefon gerekmez; o PIN\'le kasada giriş yapılır.',
            style: TextStyle(color: t.sub2, fontSize: 12.5, height: 1.4)),
      ),
      KAlan('Ad Soyad', _ad, zorunlu: true, ipucu: 'Ad Soyad veya "Kasa 1"'),
      _ikili(
        KAlan('Telefon (opsiyonel)', _tel, klavye: TextInputType.phone, ipucu: 'Kasa için boş bırakın'),
        KAlan(widget.p == null ? 'PIN (en az 4 hane)' : 'PIN (boş = değişmez)', _pin, klavye: TextInputType.number, zorunlu: widget.p == null),
      ),
      _ikili(
        KSecim<String>('Rol', deger: _rol, secenekler: [for (final e in kIkRolAd.entries) (e.key, e.value)], onSec: (v) => setState(() => _rol = v ?? 'garson')),
        KSecim<String>('Durum', deger: _aktif, secenekler: const [('1', 'Aktif'), ('0', 'Pasif (işten ayrıldı)')], onSec: (v) => setState(() {
              _aktif = v ?? '1';
              if (_aktif == '0' && _iseCikis.isEmpty) _iseCikis = _bugun();
            })),
      ),
      if (_aktif == '0')
        _ikili(
          _tarihAlan(t, 'Ayrılış tarihi', _iseCikis, (s) => _iseCikis = s, gelecekYok: true),
          KSecim<String>('Ayrılış sebebi', deger: _sebep, secenekler: [('', 'Seçin'), for (final e in _ayrilisSebep.entries) (e.key, e.value)], onSec: (v) => setState(() => _sebep = v ?? '')),
        ),
      _ikili(
        KAlan('Maaş (TL)', _maas, klavye: TextInputType.number, ipucu: '0'),
        KSecim<String>('Maaş tipi', deger: _maasTipi, secenekler: const [('aylik', 'Aylık'), ('gunluk', 'Günlük'), ('saatlik', 'Saatlik')], onSec: (v) => setState(() => _maasTipi = v ?? 'aylik')),
      ),
      _ikili(
        KSecim<String>('Prim', deger: _primTipi, secenekler: const [('yok', 'Prim Yok'), ('ciro', 'Ciro Yüzdesi')], onSec: (v) => setState(() => _primTipi = v ?? 'yok')),
        _primTipi == 'ciro' ? KAlan('Prim Oranı (% ciro)', _primOran, klavye: const TextInputType.numberWithOptions(decimal: true)) : const SizedBox.shrink(),
      ),
      KAlan('IBAN (opsiyonel)', _iban, ipucu: 'TR...'),
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Row(children: [
          Icon(Icons.badge_outlined, size: 17, color: t.sub),
          const SizedBox(width: 6),
          Text('Özlük Bilgileri (İK)', style: TextStyle(color: t.sub2, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ]),
      ),
      _ikili(
        _tarihAlan(t, 'İşe Başlama', _iseBaslama, (s) => _iseBaslama = s),
        _tarihAlan(t, 'Doğum Tarihi', _dogum, (s) => _dogum = s, gelecekYok: true),
      ),
      KAlan('TC Kimlik No (opsiyonel)', _tc, klavye: TextInputType.number, ipucu: '11 hane'),
      _ikili(
        KAlan('Acil Durum Kişisi', _acilKisi, ipucu: 'Ad Soyad'),
        KAlan('Acil Durum Telefonu', _acilTel, klavye: TextInputType.phone, ipucu: '05..'),
      ),
      const SizedBox(height: 4),
      KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediliyor, onTap: _kaydet),
    ]);
  }
}
