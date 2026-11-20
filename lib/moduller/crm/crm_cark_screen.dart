import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /cark-yonetim (+ /cark-kazananlar, /cark-hatirlatma sekmeleri).
///  Çark: /cark-yonetim-veri (GET) → dilimler (6-12), tam olarak BİR kazanan dilim (probability=100), tip/değer/birim, renk, ad;
///        aktif, çevirme aralığı, kupon geçerlilik (çark / puan), kurallar → /cark-yonetim/kaydet (JSON). Önerilen düzen: /cark-yonetim/onerilen.
///  Kazananlar: son 200 çevirme. Hatırlatma: günde 3 push hatırlatma (saat/başlık/alt yazı/mesaj, gönderilmeyecek günler) → /cark-hatirlatma/kaydet (JSON).
/// Eski lib/screens/cark_yonetim_screen.dart ağırlıklı-olasılık modelini (/api/patron/cark) kullanıyordu; web "kazanan dilim" modeline geçtiği için yerine bu yazıldı.
class CrmCarkScreen extends StatelessWidget {
  final int ilkSekme;
  const CrmCarkScreen({super.key, this.ilkSekme = 0});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return DefaultTabController(
      length: 3,
      initialIndex: ilkSekme,
      child: KSayfa(
        baslik: 'Çarkıfelek',
        ikon: Icons.casino_outlined,
        govde: Column(children: [
          Material(
            color: t.card,
            child: TabBar(
              isScrollable: !genisMi(context),
              labelColor: t.mor1,
              unselectedLabelColor: t.sub,
              indicatorColor: t.mor1,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(icon: Icon(Icons.casino_outlined, size: 20), text: 'Çarkıfelek'),
                Tab(icon: Icon(Icons.emoji_events_outlined, size: 20), text: 'Kazananlar'),
                Tab(icon: Icon(Icons.notifications_outlined, size: 20), text: 'Hatırlatma'),
              ],
            ),
          ),
          const Expanded(child: TabBarView(children: [_CarkSekme(), _KazananlarSekme(), _HatirlatmaSekme()])),
        ]),
      ),
    );
  }
}

// ───────────────────────── Çark (dilimler + ayarlar) ─────────────────────────
const _kRenkler = ['#FF6B6B', '#FF8E53', '#FFC107', '#51CF66', '#339AF0', '#CC5DE8', '#F06595', '#74C0FC', '#63E6BE', '#FFD43B', '#FF922B', '#20C997',
  '#4DABF7', '#DA77F2', '#F783AC', '#E64980', '#7950F2', '#4C6EF5', '#228BE6', '#099268'];
const _kTipler = [('puan', '💰 Puan'), ('hizmet_indirimi', '🧾 Hesap'), ('urun_indirimi', '🍽️ Ürün'), ('paket_indirimi', '🛵 Paket'), ('tekrar_dene', '🔄 Tekrar'), ('bos', '— Boş')];
bool _indirimMi(String tip) => tip == 'hizmet_indirimi' || tip == 'urun_indirimi' || tip == 'paket_indirimi';
bool _degerli(String tip) => tip == 'puan' || _indirimMi(tip);

class _Dilim {
  String ad;
  String renk;
  String tip;
  double? deger;
  String birim; // yuzde | tutar
  _Dilim({required this.ad, required this.renk, required this.tip, this.deger, this.birim = 'yuzde'});

  String get tamAd {
    if (_degerli(tip) && deger != null) {
      final d = sayiYaz(deger);
      final s = _indirimMi(tip) ? (birim == 'tutar' ? '$d₺' : '%$d') : d;
      return ad.contains(d) ? ad : '$s $ad';
    }
    return ad;
  }
}

class _CarkSekme extends StatefulWidget {
  const _CarkSekme();
  @override
  State<_CarkSekme> createState() => _CarkSekmeState();
}

class _CarkSekmeState extends State<_CarkSekme> with SingleTickerProviderStateMixin {
  bool _yukleniyor = true, _kaydediyor = false;
  String? _hata;
  List<_Dilim> _dilimler = [];
  int _kazanan = 0;
  bool _aktif = true;
  int _surum = 0; // alanların yeniden kurulması için
  final _aralik = TextEditingController();
  final _kuponCark = TextEditingController();
  final _kuponPuan = TextEditingController();
  final _kurallar = TextEditingController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  double _donus = 0, _baslangic = 0, _hedef = 0;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() => setState(() => _donus = _baslangic + (_hedef - _baslangic) * Curves.easeOutCubic.transform(_anim.value)));
    _yukle();
  }

  @override
  void dispose() {
    _anim.dispose();
    _aralik.dispose();
    _kuponCark.dispose();
    _kuponPuan.dispose();
    _kurallar.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() {
      _yukleniyor = _dilimler.isEmpty;
      _hata = null;
    });
    try {
      final c = await KopruApi.al(tok, '/cark-yonetim-veri');
      if (!mounted) return;
      final d = harita(c.j['data']);
      if (!crmBasari(c.j) || d.isEmpty) {
        setState(() {
          _yukleniyor = false;
          _hata = c.yetkisiz ? 'Bu sayfa için yetkiniz yok.' : (c.hata ?? 'Çark verisi alınamadı.');
        });
        return;
      }
      final ds = liste(d['dilimler']);
      setState(() {
        _dilimler = [
          for (var i = 0; i < ds.length; i++)
            _Dilim(
              ad: metinOku(ds[i]['name'], 'Ödül ${i + 1}'),
              renk: metinOku(ds[i]['color'], _kRenkler[i % _kRenkler.length]),
              tip: metinOku(ds[i]['tip'], 'bos'),
              deger: ds[i]['deger'] == null ? null : sayiOku(ds[i]['deger']),
              birim: metinOku(ds[i]['indirim_tipi']) == 'tutar' ? 'tutar' : 'yuzde',
            ),
        ];
        final k = ds.indexWhere((x) => tamOku(x['probability']) == 100);
        _kazanan = k < 0 ? 0 : k;
        _aktif = tamOku(d['aktifmi']) == 1;
        _aralik.text = '${math.max(1, tamOku(d['cevirme_araligi_gun']))}';
        _kuponCark.text = '${tamOku(d['kupon_cark_gecerlilik_gun'])}';
        _kuponPuan.text = '${tamOku(d['kupon_puan_gecerlilik_gun'])}';
        _kurallar.text = metinOku(d['kurallar']);
        _surum++;
        _yukleniyor = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  Future<void> _kaydet() async {
    if (_dilimler.length < 6) return kToast(context, 'En az 6 dilim olmalıdır.', hata: true);
    if (_dilimler.length > 12) return kToast(context, 'En fazla 12 dilim eklenebilir.', hata: true);
    if (_kazanan < 0 || _kazanan >= _dilimler.length) return kToast(context, 'Lütfen önce bir kazanan dilim seçin.', hata: true);
    final kurallar = _kurallar.text.split('\n').map((l) => l.trimRight()).where((l) => l.isNotEmpty && l != '•' && l != '-').join('\n');
    _kurallar.text = kurallar;
    setState(() => _kaydediyor = true);
    final c = await kopruGonderCevap(context, '/cark-yonetim/kaydet', {
      'dilimler': [
        for (var i = 0; i < _dilimler.length; i++)
          {
            'name': _dilimler[i].ad.trim().isEmpty ? 'Ödül ${i + 1}' : _dilimler[i].ad.trim(),
            'color': _dilimler[i].renk,
            'probability': i == _kazanan ? 100 : 0,
            'tip': _dilimler[i].tip,
            'deger': _degerli(_dilimler[i].tip) ? _dilimler[i].deger : null,
            'indirim_tipi': _indirimMi(_dilimler[i].tip) && _dilimler[i].birim == 'tutar' ? 'tutar' : 'yuzde',
          }
      ],
      'aktifmi': _aktif ? 1 : 0,
      'kurallar': kurallar,
      'kupon_cark_gecerlilik_gun': math.max(0, tamOku(_kuponCark.text)),
      'kupon_puan_gecerlilik_gun': math.max(0, tamOku(_kuponPuan.text)),
      'cevirme_araligi_gun': math.max(1, tamOku(_aralik.text)),
    }, json: true, sessiz: true);
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (c == null) return;
    if (crmBasari(c.j)) {
      kToast(context, 'Ayar kaydedildi! Çark müşteri uygulamasında güncellendi.');
    } else {
      kToast(context, metinOku(c.j['message'], c.hata ?? 'Bir hata oluştu.'), hata: true);
    }
  }

  Future<void> _onerilen() async {
    final ok = await kOnay(context, 'Önerilen restoran düzeni uygulansın mı?',
        evet: 'Uygula',
        aciklama: '8 dilim kurulur: 10 Puan · %10 Ürün · 25 Puan (★ kazanan) · %5 Hesap · Tekrar Dene · 50 Puan · Paket 25₺ · Bedava İçecek (40₺).\n'
            'Ayarlar: aktif · çevirme aralığı 7 gün · çark kuponu 7 gün · puan kuponu 14 gün.\n\n'
            'Dikkat: mevcut çark dilimleriniz bu düzenle değiştirilir (üzerine yazar).');
    if (!ok || !mounted) return;
    final c = await kopruGonderCevap(context, '/cark-yonetim/onerilen', {}, json: true, sessiz: true);
    if (!mounted || c == null) return;
    if (crmBasari(c.j)) {
      kToast(context, 'Önerilen düzen uygulandı.');
      _yukle();
    } else {
      kToast(context, metinOku(c.j['message'], c.hata ?? 'Uygulanamadı.'), hata: true);
    }
  }

  void _sayiDegis(int d) {
    final n = _dilimler.length + d;
    if (n < 6) return kToast(context, 'En az 6 dilim olmalıdır.', hata: true);
    if (n > 12) return kToast(context, 'En fazla 12 dilim eklenebilir.', hata: true);
    setState(() {
      if (d < 0) {
        _dilimler.removeLast();
        if (_kazanan >= _dilimler.length) _kazanan = _dilimler.length - 1;
      } else {
        _dilimler.add(_Dilim(ad: 'Ödül ${_dilimler.length + 1}', renk: _kRenkler[_dilimler.length % _kRenkler.length], tip: 'bos'));
      }
      _surum++;
    });
  }

  void _testCevir() {
    if (_anim.isAnimating || _dilimler.isEmpty) return;
    final seg = 2 * math.pi / _dilimler.length;
    final mevcut = _donus % (2 * math.pi);
    // Kazanan dilimin ortası üstteki işaretçiye gelsin
    var hedefAci = -(_kazanan + .5) * seg;
    hedefAci = (hedefAci % (2 * math.pi) + 2 * math.pi) % (2 * math.pi);
    var fark = hedefAci - mevcut;
    if (fark < 0) fark += 2 * math.pi;
    _baslangic = _donus;
    _hedef = _donus + 6 * 2 * math.pi + fark;
    _anim.forward(from: 0).then((_) {
      if (!mounted) return;
      kToast(context, '🎉 Kazanılan: ${_dilimler[_kazanan].tamAd}');
    });
  }

  void _yardim() {
    final t = context.read<TemaProvider>();
    kAltSayfa(context, baslik: '🎡 Çarkıfelek nasıl çalışır?', icerik: (c) {
      Widget adim(String no, String b, String a) => KSatir(
            solIkon: CircleAvatar(radius: 16, backgroundColor: t.mor1, child: Text(no, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            baslik: b,
            alt: a,
          );
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Müşterileriniz çarkı çevirir, hangi dilimi kazanacaklarını siz belirlersiniz. Puan biriktirir, indirim kazanır ve tekrar gelir. Maliyeti tamamen siz kontrol edersiniz.',
            style: TextStyle(color: t.sub2, fontSize: 14, height: 1.45)),
        const SizedBox(height: 10),
        adim('1', 'Dilimleri düzenle', 'Her dilime renk, ad, ödül tipi (Puan/Hesap/Ürün/Paket) ve değer verin. − / + ile 6–12 dilim.'),
        adim('2', 'Kazanan dilimi seç', '"★ Kazanan" işaretlediğiniz dilim, müşteri ne kadar döndürürse döndürsün her zaman çıkar.'),
        adim('3', 'Kaydet', '"Ayarı Kaydet"e basın — çark müşteri uygulamasında anında güncellenir.'),
        const SizedBox(height: 8),
        Text('Puan ödülü müşterinin puanına anında eklenir. İndirim ödülü kupon kodu olarak verilir; kasada "Ödül Doğrula" ile kullanılır.',
            style: TextStyle(color: t.sub, fontSize: 13, height: 1.4)),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (_yukleniyor) return const KYukleniyor();
    if (_hata != null && _dilimler.isEmpty) return KHata(_hata!, tekrar: _yukle);
    final genis = genisMi(context);
    final cark = KKart(
      child: Column(children: [
        Row(children: [
          Expanded(child: Text('Önizleme', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w700))),
          KRozet(_aktif ? 'Aktif' : 'Pasif', renk: _aktif ? t.yesil : t.sub),
        ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (c, k) {
          final boy = math.min(k.maxWidth, 320.0);
          return SizedBox(
            width: boy,
            height: boy + 18,
            child: Stack(alignment: Alignment.topCenter, children: [
              Positioned(
                top: 18,
                child: Transform.rotate(
                  angle: _donus,
                  child: CustomPaint(size: Size(boy, boy), painter: _CarkCizer(_dilimler, _kazanan)),
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 48, color: Color(0xFFEF4444)),
            ]),
          );
        }),
        const SizedBox(height: 10),
        KButon('Test et', ikon: Icons.casino_outlined, renk: const Color(0xFFE17055), onTap: _anim.isAnimating ? null : _testCevir),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _aktif,
          activeThumbColor: t.yesil,
          title: Text('Çark durumu', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          subtitle: Text(_aktif ? 'Müşteri uygulamasında görünür' : 'Kapalı — müşteriler çeviremez (Kaydet ile uygulanır)', style: TextStyle(color: t.sub, fontSize: 12.5)),
          onChanged: (x) => setState(() => _aktif = x),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.gold.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Text('🏆', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Çıkacak dilim', style: TextStyle(color: t.sub, fontSize: 12)),
                Text(_dilimler.isEmpty ? 'Seçilmedi' : _dilimler[_kazanan].tamAd, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),
      ]),
    );

    final yonetim = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('Dilim yönetimi', ikon: Icons.pie_chart_outline, alt: 'Kazanan dilimi seçin — müşteri ne kadar çevirirse çevirsin o dilim çıkar (min 6 · maks 12)',
          sag: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton.filledTonal(onPressed: () => _sayiDegis(-1), icon: const Icon(Icons.remove)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: Text('${_dilimler.length}', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold))),
            IconButton.filledTonal(onPressed: () => _sayiDegis(1), icon: const Icon(Icons.add)),
          ])),
      for (var i = 0; i < _dilimler.length; i++) _dilimKart(t, i),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KBaslik('🔁 Çevirme sıklığı', alt: 'Müşteri çarkı kaç günde bir çevirebilsin? 1 = her gün'),
          KAlan('Çevirme aralığı (gün)', _aralik, klavye: TextInputType.number, ipucu: '1 = her gün'),
          const KBaslik('⏳ Kupon geçerlilik süreleri', alt: '0 veya boş = süresiz'),
          Row(children: [
            Expanded(child: KAlan('Çark ödülü kuponu (gün)', _kuponCark, klavye: TextInputType.number, ipucu: '0 = süresiz')),
            const SizedBox(width: 10),
            Expanded(child: KAlan('Puan ödülü kuponu (gün)', _kuponPuan, klavye: TextInputType.number, ipucu: '0 = süresiz')),
          ]),
        ]),
      ),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KBaslik('📋 Çark kuralları', alt: 'Müşteri uygulamasında çarkın altında görünür. Boş bırakırsanız koruyucu varsayılan kurallar gösterilir.'),
          KAlan('Kurallar', _kurallar, satir: 6, ipucu: 'Her satıra bir kural'),
        ]),
      ),
      KButon('Ayarı kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediyor, onTap: _kaydet),
    ]);

    return RefreshIndicator(
      onRefresh: _yukle,
      child: KGovde(children: [
        Wrap(spacing: 10, runSpacing: 10, children: [
          KButon('Nasıl çalışır?', ikon: Icons.help_outline, ikincil: true, onTap: _yardim),
          KButon('Önerilen düzeni uygula', ikon: Icons.auto_fix_high, renk: t.yesil, onTap: _onerilen),
        ]),
        const SizedBox(height: 12),
        if (genis)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 380, child: cark),
            const SizedBox(width: 16),
            Expanded(child: yonetim),
          ])
        else ...[
          cark,
          yonetim,
        ],
      ]),
    );
  }

  Widget _dilimKart(TemaProvider t, int i) {
    final d = _dilimler[i];
    final kaz = i == _kazanan;
    final renk = renkOku(d.renk);
    return KKart(
      renk: kaz ? t.gold : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${i + 1}', style: TextStyle(color: t.sub, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => _renkSec(i),
            child: Container(width: 40, height: 40, decoration: BoxDecoration(color: renk, shape: BoxShape.circle, border: Border.all(color: t.line, width: 2))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: ValueKey('ad-$_surum-$i'),
              initialValue: d.ad,
              style: TextStyle(color: t.ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Dilim adı',
                isDense: true,
                filled: true,
                fillColor: t.card2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              ),
              onChanged: (x) => setState(() => d.ad = x),
            ),
          ),
          const SizedBox(width: 8),
          kaz
              ? KRozet('★ Kazanan', renk: t.gold)
              : OutlinedButton(onPressed: () => setState(() => _kazanan = i), child: const Text('Seç')),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (k, e) in _kTipler)
            ChoiceChip(
              label: Text(e, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              selected: d.tip == k,
              selectedColor: t.mor1.withValues(alpha: .2),
              onSelected: (_) => setState(() {
                d.tip = k;
                if (!_degerli(k)) d.deger = null;
                _surum++;
              }),
            ),
        ]),
        if (_degerli(d.tip)) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('dg-$_surum-$i'),
                initialValue: d.deger == null ? '' : sayiYaz(d.deger).replaceAll('.', ''),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: t.ink, fontSize: 15),
                decoration: InputDecoration(
                  hintText: d.tip == 'puan' ? 'Puan miktarı' : (d.birim == 'tutar' ? 'Tutar (₺)' : 'Yüzde (%)'),
                  isDense: true,
                  filled: true,
                  fillColor: t.card2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                ),
                onChanged: (x) => setState(() => d.deger = x.trim().isEmpty ? null : sayiOku(x)),
              ),
            ),
            const SizedBox(width: 10),
            if (_indirimMi(d.tip))
              SegmentedButton<String>(
                segments: const [ButtonSegment(value: 'yuzde', label: Text('%')), ButtonSegment(value: 'tutar', label: Text('₺'))],
                selected: {d.birim},
                onSelectionChanged: (s) => setState(() => d.birim = s.first),
              )
            else
              Text('puan', style: TextStyle(color: t.sub, fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }

  Future<void> _renkSec(int i) async {
    final t = context.read<TemaProvider>();
    final s = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Dilim rengi', style: TextStyle(color: t.ink)),
        content: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final r in _kRenkler)
            InkWell(
              onTap: () => Navigator.pop(c, r),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: renkOku(r),
                  shape: BoxShape.circle,
                  border: Border.all(color: r == _dilimler[i].renk ? t.ink : Colors.transparent, width: 3),
                ),
              ),
            ),
        ]),
      ),
    );
    if (s != null) setState(() => _dilimler[i].renk = s);
  }
}

class _CarkCizer extends CustomPainter {
  final List<_Dilim> dilimler;
  final int kazanan;
  _CarkCizer(this.dilimler, this.kazanan);

  @override
  void paint(Canvas canvas, Size size) {
    if (dilimler.isEmpty) return;
    final m = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final seg = 2 * math.pi / dilimler.length;
    final rect = Rect.fromCircle(center: m, radius: r);
    canvas.drawCircle(m, r + 4, Paint()..color = const Color(0xFF1E1B4B));
    for (var i = 0; i < dilimler.length; i++) {
      final bas = -math.pi / 2 + i * seg;
      canvas.drawArc(rect, bas, seg, true, Paint()..color = renkOku(dilimler[i].renk));
      canvas.drawArc(rect, bas, seg, true, Paint()
        ..color = Colors.white.withValues(alpha: .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5);
      // yazı
      final orta = bas + seg / 2;
      canvas.save();
      canvas.translate(m.dx, m.dy);
      canvas.rotate(orta);
      final tp = TextPainter(
        text: TextSpan(
          text: dilimler[i].tamAd,
          style: TextStyle(color: Colors.white, fontSize: dilimler.length <= 8 ? 12.5 : 10.5, fontWeight: FontWeight.w700, shadows: const [Shadow(blurRadius: 3, color: Colors.black54)]),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: r * .68);
      tp.paint(canvas, Offset(r * .25, -tp.height / 2));
      canvas.restore();
    }
    // kazanan dilim altın kenar
    final bas = -math.pi / 2 + kazanan * seg;
    canvas.drawArc(rect.deflate(2), bas, seg, false, Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5);
    canvas.drawCircle(m, r * .13, Paint()..color = Colors.white);
    canvas.drawCircle(m, r * .09, Paint()..color = const Color(0xFF7C3AED));
  }

  @override
  bool shouldRepaint(covariant _CarkCizer old) => true;
}

// ───────────────────────── Kazananlar ─────────────────────────
class _KazananlarSekme extends StatelessWidget {
  const _KazananlarSekme();

  static const _tipAd = {
    'puan': '💰 Puan', 'yuzde': '% İndirim', 'tutar': '₺ İndirim', 'hizmet_indirimi': '🧾 Hesap ind.', 'urun_indirimi': '🍽️ Ürün ind.',
    'paket_indirimi': '🛵 Paket ind.', 'tekrar_dene': '🔄 Tekrar', 'tekrar': '🔄 Tekrar', 'bos': '— Boş',
  };

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/cark-kazananlar',
      baslik: 'Çark Kazananlar',
      kabuksuz: true,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['rows']);
        String ad(Map<String, dynamic> r) {
          final s = '${metinOku(r['m_ad'])} ${metinOku(r['m_soyad'])}'.trim();
          return s.isEmpty ? 'Müşteri' : s;
        }

        if (l.isEmpty) {
          return KGovde(yenile: yenile, children: const [
            KBos(baslik: 'Henüz çark çevrilmemiş', aciklama: 'Müşteriler müşteri uygulamasında çarkı çevirdikçe burada listelenir. Çarkın "Aktif" olduğundan emin olun.', ikon: Icons.casino_outlined),
          ]);
        }
        return KGovde(yenile: yenile, children: [
          KBaslik('Son çevirmeler', ikon: Icons.emoji_events_outlined, alt: '${l.length} kayıt'),
          if (genisMi(ctx))
            KKart(
              padding: const EdgeInsets.all(6),
              child: KTablo(
                basliklar: const ['Müşteri', 'Telefon', 'Kazandığı', 'Tip', 'Kupon', 'Tarih'],
                satirlar: [
                  for (final r in l)
                    [ad(r), metinOku(r['m_tel'], '—'), metinOku(r['dilim_ad'], '—'), _tipAd[metinOku(r['tip'])] ?? metinOku(r['tip']), metinOku(r['kupon_kodu'], '—'), tarihYaz(r['created_at'])]
                ],
              ),
            )
          else
            for (final r in l)
              KKart(
                child: KSatir(
                  cizgi: false,
                  solIkon: KIkon(Icons.emoji_events_outlined, renk: t.gold),
                  baslik: '${ad(r)} · ${metinOku(r['dilim_ad'], '—')}',
                  alt: '${_tipAd[metinOku(r['tip'])] ?? metinOku(r['tip'])} · ${tarihYaz(r['created_at'])}${metinOku(r['m_tel']).isEmpty ? '' : '\n${metinOku(r['m_tel'])}'}',
                  sag: metinOku(r['kupon_kodu']).isEmpty
                      ? null
                      : InkWell(onTap: () => crmKopyala(ctx, metinOku(r['kupon_kodu']), mesaj: 'Kupon kodu kopyalandı.'), child: KRozet(metinOku(r['kupon_kodu']), renk: t.mor1)),
                ),
              ),
        ]);
      },
    );
  }
}

// ───────────────────────── Hatırlatma ─────────────────────────
class _HatirlatmaSekme extends StatefulWidget {
  const _HatirlatmaSekme();
  @override
  State<_HatirlatmaSekme> createState() => _HatirlatmaSekmeState();
}

class _HatirlatmaSekmeState extends State<_HatirlatmaSekme> {
  static const _varsayilan = [
    ('Sabah Hatırlatması', 'Güne hediyeyle başla', '10:00', '🎡 Bugün çark hakkınız var, hediyeler sizi bekliyor!'),
    ('Öğleden Sonra', 'Çark hâlâ açık', '15:00', '⏰ Çark hakkınız hâlâ duruyor — son birkaç saat!'),
    ('Akşam Hatırlatması', 'Bugünün son şansı', '20:00', '🚨 Son saatler! Çarkı çevirmeyi unutmayın'),
  ];
  static const _gunler = [(1, 'Pzt'), (2, 'Sal'), (3, 'Çar'), (4, 'Per'), (5, 'Cum'), (6, 'Cmt'), (7, 'Paz')];

  int _kurulan = -1;
  bool _aktif = false, _kaydediyor = false;
  final List<bool> _slotAktif = [true, true, true];
  final List<String> _saat = ['10:00', '15:00', '20:00'];
  final _baslik = List.generate(3, (_) => TextEditingController());
  final _alt = List.generate(3, (_) => TextEditingController());
  final _mesaj = List.generate(3, (_) => TextEditingController());
  final Set<int> _atla = {};

  @override
  void dispose() {
    for (final c in [..._baslik, ..._alt, ..._mesaj]) {
      c.dispose();
    }
    super.dispose();
  }

  void _kur(Map<String, dynamic> v) {
    final a = harita(v['ayar']);
    final imza = a.hashCode ^ metinOku(a['updated_at']).hashCode;
    if (_kurulan == imza) return;
    _kurulan = imza;
    _aktif = tamOku(a['aktif']) == 1;
    for (var i = 0; i < 3; i++) {
      final n = i + 1;
      _slotAktif[i] = a['aktif_$n'] == null ? true : tamOku(a['aktif_$n']) == 1;
      final s = metinOku(a['saat_$n']);
      _saat[i] = s.length >= 5 ? s.substring(0, 5) : _varsayilan[i].$3;
      _baslik[i].text = metinOku(a['baslik_$n']);
      _alt[i].text = metinOku(a['altyazi_$n']);
      _mesaj[i].text = metinOku(a['mesaj_$n'], _varsayilan[i].$4);
    }
    _atla
      ..clear()
      ..addAll(dizi(a['gonderim_gunleri']).map((e) => tamOku(e)));
  }

  Future<void> _kaydet(Future<void> Function() yenile) async {
    setState(() => _kaydediyor = true);
    final veri = <String, dynamic>{'aktif': _aktif ? 1 : 0, 'gonderim_gunleri': (_atla.toList()..sort())};
    for (var i = 0; i < 3; i++) {
      final n = i + 1;
      veri['saat_$n'] = _saat[i];
      veri['mesaj_$n'] = _mesaj[i].text.trim();
      veri['aktif_$n'] = _slotAktif[i] ? 1 : 0;
      veri['baslik_$n'] = _baslik[i].text.trim();
      veri['altyazi_$n'] = _alt[i].text.trim();
    }
    final c = await kopruGonderCevap(context, '/cark-hatirlatma/kaydet', veri, json: true, sessiz: true);
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (c == null) return;
    if (crmBasari(c.j)) {
      kToast(context, 'Hatırlatma ayarları kaydedildi.');
      _kurulan = -1;
      yenile();
    } else {
      kToast(context, metinOku(c.j['message'], c.hata ?? 'Kaydedilemedi.'), hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/cark-hatirlatma',
      baslik: 'Çark Hatırlatma',
      kabuksuz: true,
      govde: (ctx, v, yenile) {
        _kur(v);
        final t = ctx.watch<TemaProvider>();
        return KGovde(yenile: yenile, children: [
          KKart(
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _aktif,
              activeThumbColor: t.yesil,
              title: Text('Çark hatırlatma bildirimleri', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
              subtitle: Text('Çevirme hakkı olan müşterilere günde en fazla 3 uygulama bildirimi. Bugün gönderilen: ${sayiYaz(v['bugun'])}',
                  style: TextStyle(color: t.sub, fontSize: 12.5)),
              onChanged: (x) => setState(() => _aktif = x),
            ),
          ),
          for (var i = 0; i < 3; i++) _slot(ctx, t, i),
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const KBaslik('Hangi günler gönderilmesin?', alt: 'İşaretlediğiniz günlerde bildirim gönderilmez (ör. işletmenin kapalı olduğu günler).'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (g, ad) in _gunler)
                  FilterChip(
                    label: Text(ad, style: const TextStyle(fontWeight: FontWeight.w700)),
                    selected: _atla.contains(g),
                    selectedColor: t.kirmizi.withValues(alpha: .18),
                    onSelected: (s) => setState(() => s ? _atla.add(g) : _atla.remove(g)),
                  ),
              ]),
            ]),
          ),
          KButon('Hatırlatma ayarlarını kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediyor, onTap: () => _kaydet(yenile)),
        ]);
      },
    );
  }

  Widget _slot(BuildContext context, TemaProvider t, int i) {
    final v = _varsayilan[i];
    final acik = _slotAktif[i];
    return KKart(
      renk: acik ? t.mor1 : t.sub,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text('${i + 1}. ${_baslik[i].text.trim().isEmpty ? v.$1 : _baslik[i].text.trim()}',
                style: TextStyle(color: acik ? t.ink : t.sub, fontSize: 15.5, fontWeight: FontWeight.bold)),
          ),
          Switch(value: acik, activeThumbColor: t.mor1, onChanged: (x) => setState(() => _slotAktif[i] = x)),
        ]),
        if (acik) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: KAlan('Başlık', _baslik[i], ipucu: v.$1)),
            const SizedBox(width: 10),
            Expanded(child: KAlan('Alt yazı', _alt[i], ipucu: v.$2)),
          ]),
          KSatir(
            cizgi: false,
            solIkon: Icon(Icons.schedule, color: t.mor1),
            baslik: 'Gönderim saati: ${_saat[i]}',
            sag: Icon(Icons.edit_outlined, color: t.sub),
            onTap: () async {
              final p = _saat[i].split(':');
              final s = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 10, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0),
                builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: w!),
              );
              if (s != null) setState(() => _saat[i] = '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}');
            },
          ),
          const SizedBox(height: 8),
          KAlan('Bildirim mesajı (en fazla 200 karakter)', _mesaj[i], satir: 2, ipucu: v.$4),
        ] else
          Text('Bu hatırlatma kapalı.', style: TextStyle(color: t.sub, fontSize: 13)),
      ]),
    );
  }
}
