import 'package:flutter/material.dart';
import '../ana_sekme.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import '../widgets/sef_garson_serit.dart';
import 'satis_ekrani.dart';

class MasalarScreen extends StatefulWidget {
  const MasalarScreen({super.key});

  @override
  State<MasalarScreen> createState() => _MasalarScreenState();
}

class _MasalarScreenState extends State<MasalarScreen> {
  List masalar = [];
  bool loading = true;
  String? _secilenBolge; // ust sekmede secili bolge
  final Set<int> _benimMasalar = {}; // giren personelin sorumlu masalari (vurgu + varsayilan bolge)
  bool _sadeceBenim = false;         // "Sadece benim masalarim" filtresi (atamasi olanda varsayilan acik)
  bool _ilkAtama = true;             // _sadeceBenim varsayilanini bir kez ayarla
  final _f = NumberFormat.decimalPattern('tr');

  TemaProvider get _t => context.watch<TemaProvider>();

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.masalar(auth.token!);
      if (!mounted) return;
      final liste = (res['masalar'] as List?) ?? [];
      // Kendi atamam: sorumlu masalar (vurgu) + varsayilan bolge sekmesi
      try {
        final benim = await Api.benimAtamam(auth.token!);
        _benimMasalar
          ..clear()
          ..addAll(((benim['masa_idler'] as List?) ?? []).map((e) => _n(e).toInt()));
        if (_ilkAtama) { _sadeceBenim = _benimMasalar.isNotEmpty; _ilkAtama = false; }
      } catch (_) {}
      if (_secilenBolge == null && _benimMasalar.isNotEmpty) {
        final mine = liste.cast<Map?>().firstWhere(
              (m) => m != null && _benimMasalar.contains(_n(m['id']).toInt()),
              orElse: () => null,
            );
        if (mine != null) _secilenBolge = mine['bolge']?.toString();
      }
      setState(() {
        masalar = liste;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // Masa tasima/birlestirme ipucu (AppBar info ikonundan acilir)
  void _ipucuGoster() {
    final t = context.read<TemaProvider>();   // build DIŞI -> watch değil read (yoksa "watch outside build" hatası)
    Widget satir(IconData ik, Color renk, String baslik, String aciklama) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ik, size: 20, color: renk),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(baslik, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: t.ink)),
                Text(aciklama, style: TextStyle(fontSize: 12.5, color: t.sub, height: 1.3)),
              ]),
            ),
          ]),
        );
    showDialog(useRootNavigator: true, 
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        surfaceTintColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          const Icon(Icons.touch_app_outlined, color: Color(0xFF4F46E5)),
          const SizedBox(width: 8),
          Expanded(child: Text('Masa taşıma & birleştirme', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: t.ink))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bir masayı basılı tutup başka masanın üzerine sürükleyin:',
              style: TextStyle(fontSize: 13, color: t.sub2)),
          const SizedBox(height: 8),
          satir(Icons.add_circle_outline, const Color(0xFF4F46E5), 'Boş → Boş', 'İki masayı birleştirip yeni hesap açar.'),
          satir(Icons.merge_type, const Color(0xFF4F46E5), 'Boş → Dolu', 'Boş masayı dolu masanın hesabına ekler.'),
          satir(Icons.merge_type, const Color(0xFF4F46E5), 'Dolu → Dolu', 'İki hesabı tek masada birleştirir.'),
          satir(Icons.swap_horiz, const Color(0xFF0EA5E9), 'Dolu → Boş', 'Hesabı boş masaya taşır.'),
        ]),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım')),
        ],
      ),
    );
  }

  // Bos masaya tiklaninca: kisi sor -> masa ac -> adisyon detayina git
  Future<void> _masaAc(Map m) async {
    final misafir = await _misafirSor(m['ad'].toString(), _n(m['kapasite']).toInt());
    if (misafir == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.masaAc(auth.token!, _n(m['id']).toInt(), misafir);
      if (!mounted) return;
      if (res['ok'] == 1 && res['adisyon_id'] != null) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SatisEkrani(adisyonId: _n(res['adisyon_id']).toInt(), masaAd: m['ad'].toString())));
        _yukle();
      } else {
        _uyar(res['hata']?.toString() ?? 'Masa açılamadı');
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      _uyar('Bağlantı hatası');
    }
  }

  Future<int?> _misafirSor(String masaAd, int kapasite) {
    final t = context.read<TemaProvider>();   // build DIŞI -> read
    int sayi = kapasite >= 1 && kapasite <= 20 ? kapasite : 2;
    return showDialog<int>(useRootNavigator: true, 
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: t.card,
          surfaceTintColor: t.card,
          title: Text('$masaAd — Masa Aç', style: TextStyle(fontSize: 17, color: t.ink)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Kaç kişi?', style: TextStyle(color: t.sub)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi > 1) sayi--; }), icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 56, child: Text('$sayi', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: t.ink))),
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi < 20) sayi++; }), icon: const Icon(Icons.add_circle_outline)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, sayi), child: const Text('Masayı Aç')),
          ],
        ),
      ),
    );
  }

  /// Masa kartı görünümü — durum + tema. Katmanlı gradient + belirgin kenar + okunaklı vurgu.
  /// ($1 gradient renkleri, $2 kenar, $3 tutar/durum vurgu rengi)
  (List<Color>, Color, Color) _masaStil(String durum) {
    final k = _t.koyu;
    switch (durum) {
      case 'dolu': // DOLU: canlı mor/indigo — belirgin dursun
        return (
          k ? const [Color(0xFF3E2F78), Color(0xFF241E45)] : const [Color(0xFFEEF0FF), Color(0xFFDDE1FF)],
          k ? const Color(0xFF8B6FF0) : const Color(0xFFA5B4FC),
          k ? const Color(0xFFC9B8FF) : const Color(0xFF4F46E5),
        );
      case 'rezerve': // REZERVE: amber
        return (
          k ? const [Color(0xFF3C3113), Color(0xFF29220D)] : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
          k ? const Color(0xFFB88A1E) : const Color(0xFFFCD34D),
          k ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        );
      case 'kirli': // KİRLİ: turuncu
        return (
          k ? const [Color(0xFF3C2913), Color(0xFF291C0D)] : const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
          k ? const Color(0xFFB5651D) : const Color(0xFFFDBA74),
          k ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
        );
      default: // BOŞ: sakin kart + yeşil "müsait" vurgusu
        return (
          k ? const [Color(0xFF171E33), Color(0xFF121829)] : const [Colors.white, Color(0xFFF7F9FF)],
          k ? const Color(0xFF2B3552) : const Color(0xFFE4E7F2),
          k ? const Color(0xFF5FD8A6) : const Color(0xFF10B981),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    // Bolgeye gore grupla
    final Map<String, List> gruplu = {};
    for (final m in masalar) {
      final b = (m['bolge'] ?? 'Salon').toString();
      gruplu.putIfAbsent(b, () => []).add(m);
    }
    final bolgeler = gruplu.keys.toList();
    final aktif = (_secilenBolge != null && bolgeler.contains(_secilenBolge)) ? _secilenBolge! : (bolgeler.isNotEmpty ? bolgeler.first : '');
    var aktifMasalar = gruplu[aktif] ?? [];
    // "Sadece benim masalarim" acikken sorumlu masalara filtrele
    if (_sadeceBenim && _benimMasalar.isNotEmpty) {
      aktifMasalar = aktifMasalar.where((m) => _benimMasalar.contains(_n(m['id']).toInt())).toList();
    }
    final dolu = masalar.where((m) => m['adisyon_id'] != null).length;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        surfaceTintColor: t.card,
        elevation: 0.5,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Masalar  ($dolu / ${masalar.length} dolu)',
            style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          if (_benimMasalar.isNotEmpty)
            TextButton.icon(
              onPressed: () async { setState(() => _sadeceBenim = !_sadeceBenim); await _yukle(); },
              icon: Icon(_sadeceBenim ? Icons.person : Icons.groups, color: const Color(0xFF7C3AED), size: 19),
              label: Text(_sadeceBenim ? 'Benim' : 'Tümü', style: const TextStyle(color: Color(0xFF7C3AED), fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          IconButton(
            tooltip: 'Masa taşıma/birleştirme nasıl yapılır?',
            onPressed: _ipucuGoster,
            icon: Icon(Icons.info_outline, color: t.sub),
          ),
          IconButton(
            tooltip: 'Menü',
            onPressed: () => anaScaffoldKey.currentState?.openDrawer(),
            icon: Icon(Icons.menu, color: t.ink),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // SEF GARSON AI: satis firsati/uyari seridi — SADECE telefonda (garson). Masaustu = KASA, garson degil.
              if (!genisMi(context)) const SefGarsonSerit(),
              // Bolge sekmeleri (buton gibi) — tiklayinca aninda o bolge (client-side, kasmaz)
              Container(
                color: t.card,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bolgeler.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final b = bolgeler[i];
                      final secili = b == aktif;
                      final bDolu = (gruplu[b] ?? []).where((m) => m['adisyon_id'] != null).length;
                      return GestureDetector(
                        onTap: () => setState(() => _secilenBolge = b),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: secili ? const Color(0xFF4F46E5) : t.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: secili ? const Color(0xFF4F46E5) : t.line),
                          ),
                          child: Row(children: [
                            Text(b, style: TextStyle(color: secili ? Colors.white : t.ink, fontWeight: FontWeight.bold, fontSize: 13)),
                            if (bDolu > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: secili ? Colors.white24 : const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(10)),
                                child: Text('$bDolu', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Renk açıklaması (lejant) — hangi renk ne demek
              _lejant(),
              // Secili bolgenin masalari
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle,
                  child: GridView.builder(
                    padding: EdgeInsets.all(genisMi(context) ? 24 : 16),
                    // Genis ekran: sabit 3 sutun yerine ekrani dolduran ~180px kutular (6-8 sutun)
                    // DİKDÖRTGEN masa kartları (en > boy). childAspectRatio = en/boy.
                    gridDelegate: genisMi(context)
                        ? const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 230, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.5)
                        : const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.55),
                    itemCount: aktifMasalar.length,
                    itemBuilder: (context, i) => _masaHucre(aktifMasalar[i] as Map),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _masaHucre(Map m) {
    final acik = m['adisyon_id'] != null;
    final birlesik = m['durum'].toString() == 'birlesik'; // baska masaya birlesmis kaynak masa
    // Dokununca ac/detay (mevcut davranis). Birlesik kaynak masa -> hedef hesabi acar.
    final tapCell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (birlesik && m['birlesik_hedef_adisyon_id'] != null) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SatisEkrani(adisyonId: _n(m['birlesik_hedef_adisyon_id']).toInt(), masaAd: m['birlesik_hedef_ad']?.toString() ?? m['ad'].toString())));
          _yukle();
        } else if (acik) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SatisEkrani(adisyonId: _n(m['adisyon_id']).toInt(), masaAd: m['ad'].toString())));
          _yukle();
        } else {
          await _masaAc(m);
        }
      },
      child: _hucreVurgulu(m),
    );

    // Her masa hem surukleyici hem hedef olabilir. Birlesik (linkli) kaynak masa haric.
    return DragTarget<Map>(
      onWillAcceptWithDetails: (d) =>
          _n(d.data['id']).toInt() != _n(m['id']).toInt() && !birlesik && d.data['durum'].toString() != 'birlesik',
      onAcceptWithDetails: (d) => _birlestirVeyaTasi(d.data, m),
      builder: (ctx, cand, rej) {
        final hover = cand.isNotEmpty;
        // Birlesik olmayan tum masalar suruklenebilir (bos masayi da grup icin surukle)
        Widget cell = !birlesik
            ? LongPressDraggable<Map>(
                data: m,
                feedback: _suruklenenGorunum(m),
                childWhenDragging: Opacity(opacity: 0.3, child: _hucreGovde(m)),
                child: tapCell,
              )
            : tapCell;
        if (hover) {
          // Renk niyet: sadece DOLU->BOS tasima mavi; digerleri (birlestir/grupla) mor
          final srcAcik = cand.isNotEmpty && cand.first != null && cand.first!['adisyon_id'] != null;
          final tasima = !acik && srcAcik; // dolu kaynak -> bos hedef
          final vurguRenk = tasima ? const Color(0xFF0EA5E9) : const Color(0xFF4F46E5);
          cell = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: vurguRenk, width: 2.5),
              color: vurguRenk.withValues(alpha: 0.08),
            ),
            child: cell,
          );
        }
        return cell;
      },
    );
  }

  // Hucre + "senin masan" rozeti (atanan masalarda sag ustte)
  Widget _hucreVurgulu(Map m) {
    final govde = _hucreGovde(m);
    if (!_benimMasalar.contains(_n(m['id']).toInt())) return govde;
    return Stack(children: [
      Positioned.fill(child: govde),
      Positioned(
        top: 5, right: 5,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: const BoxDecoration(color: Color(0xFF7C3AED), shape: BoxShape.circle),
          child: const Icon(Icons.person, size: 10, color: Colors.white),
        ),
      ),
    ]);
  }

  // AÇIK masanın renk-DURUMU (gradient, kenar, vurgu, etiket). Öncelik sırası:
  // Ödendi > Hesap istedi > Sipariş bekliyor > Durgun > Yeni > Serviste.
  ({List<Color> grad, Color border, Color accent, String etiket}) _masaDurum(Map m) {
    final k = _t.koyu;
    final kalemSay = _n(m['kalem_say']).toInt();
    final acilisDk = _n(m['acilis_dk']).toInt();
    final sonDk = _n(m['son_siparis_dk'] ?? -1).toInt();
    final odenen = _n(m['odenen']);
    final hesap = m['hesap_istendi'] == true;
    String dkYazi(int d) => d >= 60 ? '${(d / 60).floor()} sa ${d % 60} dk' : '$d dk';
    // ÖDENDİ -> yeşil (hesap kapandı, masa toparlanmayı bekliyor)
    if (odenen > 0) {
      return (grad: k ? const [Color(0xFF123524), Color(0xFF0C241A)] : const [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
        border: k ? const Color(0xFF2FA36E) : const Color(0xFF6EE7B7), accent: k ? const Color(0xFF5FD8A6) : const Color(0xFF059669), etiket: '✅ Ödendi');
    }
    // HESAP İSTEDİ -> mor (garson hesap götürsün)
    if (hesap) {
      return (grad: k ? const [Color(0xFF2E1F4D), Color(0xFF1E1436)] : const [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
        border: k ? const Color(0xFF9F7AEA) : const Color(0xFFC4B5FD), accent: k ? const Color(0xFFC9B8FF) : const Color(0xFF6D28D9), etiket: '💳 Hesap istedi');
    }
    // OTURDU AMA SİPARİŞ VERMEDİ, zaman geçti -> sarı/amber (garson gitsin)
    if (kalemSay == 0 && acilisDk >= 12) {
      return (grad: k ? const [Color(0xFF3C3113), Color(0xFF29220D)] : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
        border: k ? const Color(0xFFB88A1E) : const Color(0xFFFCD34D), accent: k ? const Color(0xFFFCD34D) : const Color(0xFFB45309), etiket: '⏳ Sipariş bekliyor · ${dkYazi(acilisDk)}');
    }
    // YENİ AÇILDI -> mavi
    if (kalemSay == 0) {
      return (grad: k ? const [Color(0xFF14233F), Color(0xFF0F1A2E)] : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
        border: k ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD), accent: k ? const Color(0xFF93C5FD) : const Color(0xFF2563EB), etiket: '🆕 Yeni açıldı');
    }
    // UZUN SÜREDİR YENİ SİPARİŞ YOK (ör. bir çay, 45 dk+) -> turuncu (ilgilen/upsell)
    if (sonDk >= 45) {
      return (grad: k ? const [Color(0xFF3C2913), Color(0xFF291C0D)] : const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
        border: k ? const Color(0xFFB5651D) : const Color(0xFFFDBA74), accent: k ? const Color(0xFFFDBA74) : const Color(0xFFC2410C), etiket: '🔔 Durgun · ${dkYazi(sonDk)}');
    }
    // AKTİF / SERVİSTE -> indigo (normal dolu)
    return (grad: k ? const [Color(0xFF3E2F78), Color(0xFF241E45)] : const [Color(0xFFEEF0FF), Color(0xFFDDE1FF)],
      border: k ? const Color(0xFF8B6FF0) : const Color(0xFFA5B4FC), accent: k ? const Color(0xFFC9B8FF) : const Color(0xFF4F46E5), etiket: '🍽️ Serviste');
  }

  // Renk açıklaması şeridi (masa durumları)
  Widget _lejant() {
    final t = _t;
    Widget nokta(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 11, height: 11, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 5),
          Text(s, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.sub)),
        ]);
    return Container(
      color: t.card,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          nokta(const Color(0xFF2563EB), 'Yeni'), const SizedBox(width: 14),
          nokta(const Color(0xFFB45309), 'Sipariş bekliyor'), const SizedBox(width: 14),
          nokta(const Color(0xFF4F46E5), 'Serviste'), const SizedBox(width: 14),
          nokta(const Color(0xFFC2410C), 'Durgun'), const SizedBox(width: 14),
          nokta(const Color(0xFF6D28D9), 'Hesap istedi'), const SizedBox(width: 14),
          nokta(const Color(0xFF059669), 'Ödendi'), const SizedBox(width: 14),
          nokta(t.line, 'Boş'),
        ]),
      ),
    );
  }

  Widget _hucreGovde(Map m) {
    final t = _t;
    final acik = m['adisyon_id'] != null;
    final durum = m['durum'].toString();
    final birlesik = durum == 'birlesik';
    final grup = (m['birlesik_masalar'] as List?)?.map((e) => e.toString()).toList() ?? [];

    // Kaynak masa (baska masaya birlesmis, artik bos): gri, linkli
    if (birlesik) {
      return Container(
        decoration: BoxDecoration(
          color: t.card2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line, width: 1.5, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m['ad'].toString(),
                style: TextStyle(fontWeight: FontWeight.bold, color: t.sub, decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 4),
            const Icon(Icons.merge_type, size: 15, color: Color(0xFF4F46E5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('${m['birlesik_hedef_ad'] ?? ''} ile birleşik',
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
            ),
          ],
        ),
      );
    }

    final stil = _masaStil(durum);
    final coklu = grup.length > 1;
    // AÇIK masa (birleşik değil) -> renk-durum motoru; diğerleri eski stil
    final ds = (acik && !coklu) ? _masaDurum(m) : null;
    final grad = ds?.grad ?? stil.$1;
    final kenar = coklu ? const Color(0xFFC4B5FD) : (ds?.border ?? stil.$2);
    final vurgu = ds?.accent ?? stil.$3;
    return Container(
      decoration: BoxDecoration(
        gradient: coklu ? null : LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
        color: coklu ? (t.koyu ? const Color(0xFF2A2350) : const Color(0xFFF5F3FF)) : null,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kenar, width: coklu ? 2 : (ds != null ? 1.7 : 1.4)),
        boxShadow: t.koyu
            ? (acik ? [BoxShadow(color: kenar.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 5))] : null)
            : t.golge,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Birlesikse "Masa 1 + Masa 2" rozeti, degilse normal masa adi
          if (grup.length > 1) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.merge_type, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(grup.join(' + '),
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text('birleşik masa', style: TextStyle(fontSize: 9, color: t.sub)),
          ] else ...[
            Text(m['ad'].toString(), style: TextStyle(fontWeight: FontWeight.bold, color: t.ink)),
            Text('${m['kapasite']} kişi', style: TextStyle(fontSize: 10, color: t.sub)),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: acik
                ? Text(_n(m['tutar']) > 0 ? '${_f.format(_n(m['tutar']).round())}TL' : 'açık',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: vurgu))
                : Text('● boş', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: vurgu)),
          ),
          // DURUM ETİKETİ (açık masa) — renkle beraber ne durumda olduğu yazıyla da belli
          if (ds != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: vurgu.withValues(alpha: t.koyu ? 0.22 : 0.14), borderRadius: BorderRadius.circular(20)),
                child: Text(ds.etiket, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: vurgu)),
              ),
            ),
        ],
      ),
    );
  }

  // Suruklerken parmagin altinda gorunen kart
  Widget _suruklenenGorunum(Map m) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.drag_indicator, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(m['ad'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (_n(m['tutar']) > 0) ...[
              const SizedBox(width: 8),
              Text('${_f.format(_n(m['tutar']).round())}TL', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ]),
        ),
      );

  // Surukle-birak sonucu: hedef dolu ise birlestir, bos ise tasi.
  Future<void> _birlestirVeyaTasi(Map source, Map target) async {
    final auth = context.read<AuthProvider>();
    final srcAcik = source['adisyon_id'] != null;
    final tgtAcik = target['adisyon_id'] != null;

    // 1) DOLU -> DOLU: fatura birlestir
    if (srcAcik && tgtAcik) {
      final combined = _n(source['tutar']) + _n(target['tutar']);
      final onay = await _onayDialog(
        baslik: 'Masaları Birleştir', ikon: Icons.merge_type, renk: const Color(0xFF4F46E5),
        mesaj: '${source['ad']} hesabı ${target['ad']} masasına aktarılacak.\n'
            '${source['ad']} boşalacak, birleşik hesap ${target['ad']} masasında toplanacak.',
        vurgu: 'Birleşik toplam: ${_f.format(combined.round())}TL', onayText: 'Birleştir',
      );
      if (onay != true) return;
      await _apiCagir(() => Api.masaBirlestir(auth.token!, _n(target['adisyon_id']).toInt(), _n(source['adisyon_id']).toInt()));
      return;
    }

    // 2) DOLU -> BOS: tasi
    if (srcAcik && !tgtAcik) {
      final onay = await _onayDialog(
        baslik: 'Masayı Taşı', ikon: Icons.swap_horiz, renk: const Color(0xFF0EA5E9),
        mesaj: '${source['ad']} hesabı boş ${target['ad']} masasına taşınacak.', vurgu: null, onayText: 'Taşı',
      );
      if (onay != true) return;
      await _apiCagir(() => Api.masaTasi(auth.token!, _n(source['adisyon_id']).toInt(), _n(target['id']).toInt()));
      return;
    }

    // 3) BOS kaynak -> grupla
    int? misafir;
    if (!tgtAcik) {
      // BOS -> BOS: birlesik masa acilacak, once kisi sor (grup oturur, sonra siparis)
      misafir = await _misafirSor('${source['ad']} + ${target['ad']}',
          _n(source['kapasite']).toInt() + _n(target['kapasite']).toInt());
      if (misafir == null) return;
    } else {
      // BOS -> DOLU: bos masayi mevcut hesaba ekle (grup genisliyor)
      final onay = await _onayDialog(
        baslik: 'Masaya Ekle', ikon: Icons.merge_type, renk: const Color(0xFF4F46E5),
        mesaj: '${source['ad']} (boş), ${target['ad']} masasının hesabına eklenecek — grup genişliyor.',
        vurgu: null, onayText: 'Birleştir',
      );
      if (onay != true) return;
    }
    try {
      final res = await Api.masaGrupla(auth.token!,
          hedefMasaId: _n(target['id']).toInt(), kaynakMasaId: _n(source['id']).toInt(), misafir: misafir);
      if (!mounted) return;
      _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '');
      if (res['ok'] == 1) {
        // Yeni birlesik masa acildiysa hemen siparise gec
        if (res['yeni_acildi'] == true && res['adisyon_id'] != null) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SatisEkrani(adisyonId: _n(res['adisyon_id']).toInt(),
                  masaAd: '${source['ad']} + ${target['ad']}')));
        }
        _yukle();
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      _uyar('Bağlantı hatası');
    }
  }

  // API cagrisi + standart hata/yenile akisi (tekrari onler)
  Future<void> _apiCagir(Future<Map<String, dynamic>> Function() call) async {
    try {
      final res = await call();
      if (!mounted) return;
      _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '');
      if (res['ok'] == 1) _yukle();
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      _uyar('Bağlantı hatası');
    }
  }

  Future<bool?> _onayDialog({
    required String baslik,
    required IconData ikon,
    required Color renk,
    required String mesaj,
    String? vurgu,
    required String onayText,
  }) {
    final t = context.read<TemaProvider>();   // build DIŞI (dialog) -> read
    return showDialog<bool>(useRootNavigator: true, 
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        surfaceTintColor: t.card,
        title: Row(children: [Icon(ikon, color: renk), const SizedBox(width: 8), Text(baslik, style: TextStyle(fontSize: 17, color: t.ink))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mesaj, style: TextStyle(color: t.sub2, height: 1.4)),
          if (vurgu != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(vurgu, style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: renk), child: Text(onayText)),
        ],
      ),
    );
  }
}
