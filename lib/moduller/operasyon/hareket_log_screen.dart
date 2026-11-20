import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Web /hareketler — işletmedeki tüm hareketler (aktivite log + ödeme + kayıp + stok + gider + iptal).
/// Filtre: gün (Bugün/Hafta/Ay), kategori, personel, arama; sayfalı (sonsuz kaydırma: ?sayfa=).
/// Satıra dokununca detay (tarih, kim, IP, işlem yolu, kategori) açılır.
class OpHareketlerScreen extends StatefulWidget {
  const OpHareketlerScreen({super.key});

  @override
  State<OpHareketlerScreen> createState() => _OpHareketlerScreenState();
}

class _KatMeta {
  final Color renk;
  final IconData ikon;
  final String ad;
  const _KatMeta(this.renk, this.ikon, this.ad);
}

const Map<String, _KatMeta> _katMeta = {
  'satis': _KatMeta(Color(0xFF10B981), Icons.receipt_long_outlined, 'Satış'),
  'odeme': _KatMeta(Color(0xFF10B981), Icons.payments_outlined, 'Ödeme'),
  'kayip': _KatMeta(Color(0xFFF43F5E), Icons.remove_circle_outline, 'Kayıp'),
  'stok': _KatMeta(Color(0xFF3B82F6), Icons.inventory_2_outlined, 'Stok'),
  'kasa': _KatMeta(Color(0xFF14B8A6), Icons.point_of_sale, 'Kasa'),
  'cari': _KatMeta(Color(0xFF6366F1), Icons.account_balance_wallet_outlined, 'Cari'),
  'personel': _KatMeta(Color(0xFFF59E0B), Icons.badge_outlined, 'Personel'),
  'gider': _KatMeta(Color(0xFFEA580C), Icons.money_off, 'Gider'),
  'fis': _KatMeta(Color(0xFF7C3AED), Icons.description_outlined, 'Fiş'),
  'menu': _KatMeta(Color(0xFF7C3AED), Icons.restaurant_menu, 'Menü'),
  'recete': _KatMeta(Color(0xFF7C3AED), Icons.menu_book_outlined, 'Reçete'),
  'ayar': _KatMeta(Color(0xFF94A3B8), Icons.settings_outlined, 'Ayar'),
  'giris': _KatMeta(Color(0xFF94A3B8), Icons.login, 'Giriş'),
  'mesai': _KatMeta(Color(0xFF14B8A6), Icons.schedule, 'Mesai'),
  'cagri': _KatMeta(Color(0xFFF43F5E), Icons.notifications_active_outlined, 'Çağrı'),
  'diger': _KatMeta(Color(0xFF94A3B8), Icons.bolt, 'Diğer'),
};

/// Web'deki kategoriBul() — kategori boş/diger ise başlık+açıklamadan tahmin
String _kategoriBul(Map<String, dynamic> h) {
  final k = metinOku(h['kategori']);
  if (k.isNotEmpty && k != 'diger' && _katMeta.containsKey(k)) return k;
  final s = '${metinOku(h['baslik'])} ${metinOku(h['aciklama'])}'.toLowerCase();
  bool c(List<String> ks) => ks.any(s.contains);
  if (c(['iptal', 'geri alın', 'geri alind', 'void', 'iskonto', 'indirim', 'ikram', 'fire'])) return 'kayip';
  if (c(['ödeme', 'odeme', 'tahsil', 'nakit', 'kredi', 'kart', 'yemek kart'])) return 'odeme';
  if (c(['masa', 'adisyon', 'sipariş', 'siparis', 'satış', 'satis', 'birleştir', 'taşın', 'tasin', 'böl', 'bol'])) return 'satis';
  if (c(['stok', 'malzeme', 'sayım', 'sayim', 'alış', 'alis', 'tedarik'])) return 'stok';
  if (c(['kasa', 'çekmece', 'cekmece', 'vardiya'])) return 'kasa';
  if (c(['cari', 'açık hesap', 'acik hesap', 'borç', 'borc'])) return 'cari';
  if (c(['personel', 'maaş', 'maas', 'yetki', 'avans'])) return 'personel';
  if (c(['mesai', 'puantaj'])) return 'mesai';
  if (c(['gider', 'masraf'])) return 'gider';
  if (c(['menü', 'menu', 'ürün', 'urun', 'kategori'])) return 'menu';
  if (c(['reçete', 'recete', 'yarı mamül', 'yari mamul'])) return 'recete';
  if (c(['fiş', 'fis', 'fatura'])) return 'fis';
  if (c(['giriş', 'giris', 'login', 'çıkış', 'cikis', 'logout'])) return 'giris';
  if (c(['ayar', 'tema', 'şema', 'sema'])) return 'ayar';
  if (c(['çağrı', 'cagri', 'garson'])) return 'cagri';
  return k.isNotEmpty ? k : 'diger';
}

class _OpHareketlerScreenState extends State<OpHareketlerScreen> {
  int _gun = 7;
  String _kategori = 'hepsi';
  int? _kim;
  String _ara = '';
  int _sayfa = 1;
  final int _boyut = 40;
  final List<Map<String, dynamic>> _liste = [];
  List<Map<String, dynamic>> _personeller = [];
  Map<String, dynamic> _ozet = {};
  bool _yukleniyor = true;
  bool _dahaYukleniyor = false;
  bool _son = false;
  bool _yetkisiz = false;
  String? _hata;
  Timer? _araZaman;
  final _araC = TextEditingController();
  final _kaydir = ScrollController();
  final Set<int> _acik = {};

  @override
  void initState() {
    super.initState();
    _kaydir.addListener(() {
      if (_kaydir.position.pixels > _kaydir.position.maxScrollExtent - 500) _dahaYukle();
    });
    _yukle();
  }

  @override
  void dispose() {
    _araZaman?.cancel();
    _araC.dispose();
    _kaydir.dispose();
    super.dispose();
  }

  Map<String, String> get _q => {
        'gun': '$_gun',
        if (_kategori != 'hepsi') 'kategori': _kategori,
        if (_kim != null) 'kim': '$_kim',
        if (_ara.isNotEmpty) 'ara': _ara,
        'boyut': '$_boyut',
      };

  Future<void> _yukle() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() {
      _yukleniyor = _liste.isEmpty;
      _hata = null;
    });
    try {
      final c = await KopruApi.al(tok, '/hareketler', q: {..._q, 'sayfa': '1'});
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        if (!c.ok) {
          _hata = c.hata;
          _yetkisiz = c.yetkisiz;
          return;
        }
        final v = c.veri;
        _sayfa = 1;
        _liste
          ..clear()
          ..addAll(liste(v['hareketler']));
        _acik.clear();
        _personeller = liste(v['personeller']);
        _ozet = harita(v['ozet']);
        _son = _liste.length >= tamOku(_ozet['toplam']) || liste(v['hareketler']).length < _boyut;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  Future<void> _dahaYukle() async {
    if (_son || _dahaYukleniyor || _yukleniyor) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() => _dahaYukleniyor = true);
    try {
      final c = await KopruApi.al(tok, '/hareketler', q: {..._q, 'sayfa': '${_sayfa + 1}'});
      if (!mounted) return;
      setState(() {
        _dahaYukleniyor = false;
        if (!c.ok) return;
        final yeni = liste(c.veri['hareketler']);
        _sayfa++;
        _liste.addAll(yeni);
        _son = yeni.isEmpty || _liste.length >= tamOku(_ozet['toplam']);
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  void _araDegis(String s) {
    _araZaman?.cancel();
    _araZaman = Timer(const Duration(milliseconds: 450), () {
      _ara = s.trim();
      _yukle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    if (_yukleniyor && _liste.isEmpty && _hata == null) {
      govde = const KYukleniyor();
    } else if (_hata != null && _liste.isEmpty) {
      govde = KHata(_hata!, tekrar: _yukle, yetkisiz: _yetkisiz);
    } else {
      govde = RefreshIndicator(
        onRefresh: _yukle,
        child: ListView(
          controller: _kaydir,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(genisMi(context) ? 22 : 14, 14, genisMi(context) ? 22 : 14, 90),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _icerik(t)),
              ),
            ),
          ],
        ),
      );
    }
    return KSayfa(
      baslik: 'Hareketler',
      ikon: Icons.history,
      araclar: [IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh))],
      govde: govde,
    );
  }

  List<Widget> _icerik(TemaProvider t) {
    final katSay = harita(_ozet['kategori']);
    final giris = sayiOku(_ozet['giris']);
    final cikis = sayiOku(_ozet['cikis']);
    final out = <Widget>[
      KCipler(
        secenekler: const [('1', 'Bugün'), ('7', 'Son 7 gün'), ('30', 'Son 30 gün')],
        secili: '$_gun',
        onSec: (k) {
          _gun = int.parse(k);
          _yukle();
        },
      ),
      if (genisMi(context))
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: KAra(ipucu: 'Başlık, açıklama ya da tutar ara…', onDegis: _araDegis, kontrol: _araC)),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _kimSecici()),
        ])
      else ...[
        KAra(ipucu: 'Başlık, açıklama ya da tutar ara…', onDegis: _araDegis, kontrol: _araC),
        _kimSecici(),
      ],
      KCipler(
        secenekler: [
          ('hepsi', 'Hepsi'),
          for (final e in _katMeta.entries)
            if (katSay.containsKey(e.key) || _kategori == e.key) (e.key, '${e.value.ad} (${tamOku(katSay[e.key])})') else (e.key, e.value.ad),
        ],
        secili: _kategori,
        onSec: (k) {
          _kategori = k;
          _yukle();
        },
      ),
      KKpiIzgara([
        KKpi(etiket: 'Hareket', deger: sayiYaz(_ozet['toplam']), ikon: Icons.history, renk: t.mor1),
        KKpi(etiket: 'Giriş (para)', deger: tl(giris, kisa: true), ikon: Icons.south_west, renk: t.yesil),
        KKpi(etiket: 'Çıkış (para)', deger: tl(cikis, kisa: true), ikon: Icons.north_east, renk: t.kirmizi),
      ]),
    ];
    if (_liste.isEmpty) {
      out.add(KKart(
        child: KBos(
          baslik: 'Bu filtrede hareket yok',
          aciklama: (_kategori != 'hepsi' || _kim != null || _ara.isNotEmpty)
              ? 'Seçili kategori / personel / aramaya uyan kayıt bulunamadı. Filtreleri temizleyin ya da süreyi "Son 30 gün" yapın.'
              : 'Seçilen sürede kayıtlı işlem yok. Satış, ödeme, stok, gider ve giriş işlemleri yapıldıkça burada otomatik listelenir.',
          ikon: Icons.history,
        ),
      ));
      return out;
    }
    String? oncekiGun;
    for (var i = 0; i < _liste.length; i++) {
      final h = _liste[i];
      final gun = metinOku(h['tarih']);
      if (gun != oncekiGun) {
        oncekiGun = gun;
        out.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(gun, style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w700)),
        ));
      }
      out.add(_satir(t, h, i));
    }
    out.add(Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: _dahaYukleniyor
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : _son
                ? Text('Tümü gösterildi · ${_liste.length} kayıt', style: TextStyle(color: t.sub, fontSize: 12.5))
                : KButon('Daha fazla yükle', ikon: Icons.expand_more, ikincil: true, onTap: _dahaYukle),
      ),
    ));
    return out;
  }

  Widget _kimSecici() {
    return KSecim<int>(
      'Personel',
      deger: _kim ?? 0,
      secenekler: [(0, 'Herkes'), for (final p in _personeller) (tamOku(p['id']), metinOku(p['ad'], '—'))],
      onSec: (v) {
        _kim = (v == null || v == 0) ? null : v;
        _yukle();
      },
    );
  }

  Widget _satir(TemaProvider t, Map<String, dynamic> h, int i) {
    final kat = _kategoriBul(h);
    final m = _katMeta[kat] ?? _katMeta['diger']!;
    final yon = metinOku(h['yon']);
    final tutar = h['tutar'];
    final tRenk = yon == 'cikis' ? t.kirmizi : (yon == 'giris' ? t.yesil : t.ink);
    final isaret = yon == 'cikis' ? '−' : (yon == 'giris' ? '+' : '');
    final acik = _acik.contains(i);
    final personel = metinOku(h['personel']);
    final aciklama = metinOku(h['aciklama']);
    Widget detay(IconData ik, String et, String deger) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ik, size: 16, color: t.sub),
            const SizedBox(width: 8),
            SizedBox(width: 92, child: Text(et, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600))),
            Expanded(child: SelectableText(deger, style: TextStyle(color: t.ink, fontSize: 13))),
          ]),
        );
    return KKart(
      renk: m.renk,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: () => setState(() => acik ? _acik.remove(i) : _acik.add(i)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KIkon(m.ikon, renk: m.renk, boyut: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(metinOku(h['baslik'], '—'), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
                KRozet(m.ad, renk: m.renk),
              ]),
              if (aciklama.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: Text(aciklama, maxLines: acik ? 6 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 13))),
              const SizedBox(height: 4),
              Row(children: [
                if (personel.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 14, color: t.sub),
                  const SizedBox(width: 3),
                  Flexible(child: Text(personel, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5))),
                  const SizedBox(width: 10),
                ],
                Icon(Icons.access_time, size: 14, color: t.sub),
                const SizedBox(width: 3),
                Text(metinOku(h['saat']), style: TextStyle(color: t.sub, fontSize: 12.5)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (tutar != null && sayiOku(tutar) != 0) Text('$isaret${tl(tutar, kisa: true)}', style: TextStyle(color: tRenk, fontSize: 14, fontWeight: FontWeight.w700)),
            Icon(acik ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: t.sub),
          ]),
        ]),
        if (acik) ...[
          const SizedBox(height: 6),
          Divider(color: t.line, height: 1),
          detay(Icons.event, 'Tarih & Saat', metinOku(h['zaman_tam'], '${metinOku(h['tarih'])} ${metinOku(h['saat'])}')),
          if (personel.isNotEmpty) detay(Icons.badge_outlined, 'Kim', personel + (metinOku(h['rol']).isNotEmpty ? ' · ${metinOku(h['rol'])}' : '')),
          if (metinOku(h['ip']).isNotEmpty) detay(Icons.lan_outlined, 'IP adresi', metinOku(h['ip'])),
          detay(Icons.category_outlined, 'Kategori', m.ad),
          if (metinOku(h['yol']).isNotEmpty) detay(Icons.route_outlined, 'İşlem yolu', metinOku(h['yol'])),
          if (tutar != null && sayiOku(tutar) != 0) detay(Icons.payments_outlined, 'Tutar', '$isaret${tl(tutar)}'),
        ],
      ]),
    );
  }
}
