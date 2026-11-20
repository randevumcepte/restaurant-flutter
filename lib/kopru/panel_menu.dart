import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/kit.dart';
import 'kopru_api.dart';

/// PANEL MENÜSÜ — web sol menüsünün AYNISI (GET /panel-menu). Hangi bağlantıyı kimin göreceği
/// (yetki, departman, işletme büyüklüğü, kasiyer, mutfak ekibi, satın almacı) sunucuda tek yerde.
class MenuOge {
  final String url, ad, ikon;
  final String? renk;
  final int rozet;
  final bool rapor;
  MenuOge(this.url, this.ad, this.ikon, this.renk, this.rozet, this.rapor);
  factory MenuOge.j(Map m) => MenuOge('${m['url']}', '${m['ad']}', '${m['ikon'] ?? ''}', m['renk']?.toString(), tamOku(m['rozet']), m['rapor'] == true);
}

class MenuGrup {
  final String anahtar, ad, ikon;
  final bool basliksiz;
  final int rozet;
  final List<MenuOge> ogeler;
  MenuGrup(this.anahtar, this.ad, this.ikon, this.basliksiz, this.rozet, this.ogeler);
  factory MenuGrup.j(Map m) => MenuGrup('${m['anahtar']}', '${m['ad']}', '${m['ikon'] ?? ''}', m['basliksiz'] == true, tamOku(m['rozet']),
      [for (final o in (m['ogeler'] as List? ?? const [])) if (o is Map) MenuOge.j(o)]);
}

class MenuBolum {
  final String? baslik, ikon;
  final List<MenuGrup> gruplar;
  MenuBolum(this.baslik, this.ikon, this.gruplar);
  factory MenuBolum.j(Map m) => MenuBolum(m['baslik']?.toString(), m['ikon']?.toString(), [for (final g in (m['gruplar'] as List? ?? const [])) if (g is Map) MenuGrup.j(g)]);
}

class PanelMenu {
  final List<MenuBolum> bolumler;
  final bool duz;
  PanelMenu(this.bolumler, this.duz);
  factory PanelMenu.j(Map m) => PanelMenu([for (final b in (m['bolumler'] as List? ?? const [])) if (b is Map) MenuBolum.j(b)], m['duz'] == true);
  Iterable<MenuOge> get tumOgeler sync* { for (final b in bolumler) { for (final g in b.gruplar) { yield* g.ogeler; } } }
  bool var_(String url) => tumOgeler.any((o) => o.url == url);
}

/// Menüyü sunucudan çeker; çevrimdışıyken son kayıtlı menüyü gösterir.
class PanelMenuServisi extends ChangeNotifier {
  static final PanelMenuServisi ben = PanelMenuServisi._();
  PanelMenuServisi._();

  PanelMenu? menu;
  bool yukleniyor = false;
  String? hata;
  String? _tokenIcin;

  static const _anahtar = 'panel_menu_v1';

  Future<void> yukle(String token, {bool zorla = false}) async {
    if (yukleniyor) return;
    if (!zorla && menu != null && _tokenIcin == token) return;
    yukleniyor = true;
    hata = null;
    if (menu == null || _tokenIcin != token) {
      try {
        final sp = await SharedPreferences.getInstance();
        final s = sp.getString('$_anahtar:${token.hashCode}');
        if (s != null) menu = PanelMenu.j(jsonDecode(s) as Map);
      } catch (_) {}
    }
    _tokenIcin = token;
    notifyListeners();
    try {
      final c = await KopruApi.al(token, '/panel-menu');
      if (c.ok) {
        menu = PanelMenu.j(c.j);
        try {
          final sp = await SharedPreferences.getInstance();
          await sp.setString('$_anahtar:${token.hashCode}', jsonEncode(c.j));
        } catch (_) {}
      } else {
        hata = c.hata;
      }
    } on ApiYetkiHatasi {
      hata = 'Oturum süresi doldu';
    } catch (_) {
      hata = 'Menü yüklenemedi';
    }
    yukleniyor = false;
    notifyListeners();
  }

  void temizle() {
    menu = null;
    _tokenIcin = null;
    notifyListeners();
  }
}

/// Menü listesi (çekmece / masaüstü yan menü / "Tüm Menü" ekranı ortak).
/// Arama kutusu + bölüm başlıkları + açılır gruplar + rozetler. [onAc] seçilen bağlantıyı açar.
class PanelMenuListesi extends StatefulWidget {
  final void Function(MenuOge oge) onAc;
  final bool kompakt;
  const PanelMenuListesi({super.key, required this.onAc, this.kompakt = false});

  @override
  State<PanelMenuListesi> createState() => _PanelMenuListesiState();
}

class _PanelMenuListesiState extends State<PanelMenuListesi> {
  String _ara = '';
  final Set<String> _acik = {};
  static const _acikAnahtar = 'panel_menu_acik_gruplar';

  @override
  void initState() {
    super.initState();
    final tok = context.read<AuthProvider>().token;
    if (tok != null) PanelMenuServisi.ben.yukle(tok);
    SharedPreferences.getInstance().then((sp) {
      final l = sp.getStringList(_acikAnahtar);
      if (l != null && mounted) setState(() => _acik.addAll(l));
    });
  }

  void _grupCevir(String a) {
    setState(() => _acik.contains(a) ? _acik.remove(a) : _acik.add(a));
    SharedPreferences.getInstance().then((sp) => sp.setStringList(_acikAnahtar, _acik.toList()));
  }

  String _norm(String s) => s.toLowerCase().replaceAll('ı', 'i').replaceAll('İ', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g').replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c');

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final srv = context.watch<PanelMenuServisi>();
    final menu = srv.menu;
    if (menu == null) {
      if (srv.yukleniyor) return const KYukleniyor(metin: 'Menü yükleniyor…');
      return KHata(srv.hata ?? 'Menü yüklenemedi', tekrar: () {
        final tok = context.read<AuthProvider>().token;
        if (tok != null) PanelMenuServisi.ben.yukle(tok, zorla: true);
      });
    }
    final q = _norm(_ara.trim());
    final cocuklar = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: TextField(
          onChanged: (v) => setState(() => _ara = v),
          style: TextStyle(color: t.ink, fontSize: 14.5),
          decoration: InputDecoration(
            hintText: 'Menüde ara… (ör. stok, izin, fatura)',
            hintStyle: TextStyle(color: t.sub, fontSize: 13.5),
            prefixIcon: Icon(Icons.search, color: t.sub, size: 20),
            filled: true,
            fillColor: t.card2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ),
    ];
    if (q.isNotEmpty) {
      final bulunan = <(MenuGrup, MenuOge)>[];
      final gorulen = <String>{};
      for (final b in menu.bolumler) {
        for (final g in b.gruplar) {
          for (final o in g.ogeler) {
            if ((_norm(o.ad).contains(q) || _norm(g.ad).contains(q)) && gorulen.add(o.url)) bulunan.add((g, o));
          }
        }
      }
      if (bulunan.isEmpty) {
        cocuklar.add(KBos(baslik: '“$_ara” bulunamadı', aciklama: 'Görmediğiniz bir ekran varsa yetkiniz olmayabilir.', ikon: Icons.search_off));
      } else {
        for (final (g, o) in bulunan) {
          cocuklar.add(_oge(t, o, alt: g.basliksiz ? null : g.ad));
        }
      }
    } else {
      for (final b in menu.bolumler) {
        if (b.baslik != null) {
          cocuklar.add(Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 16, 4),
            child: Row(children: [
              Icon(ikonAdi(b.ikon, Icons.folder_outlined), size: 15, color: t.sub),
              const SizedBox(width: 6),
              Text(b.baslik!, style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ]),
          ));
        }
        for (final g in b.gruplar) {
          if (g.basliksiz || menu.duz) {
            for (final o in g.ogeler) { cocuklar.add(_oge(t, o)); }
            continue;
          }
          final acik = _acik.contains(g.anahtar);
          cocuklar.add(_grupBaslik(t, g, acik));
          if (acik) {
            final islem = g.ogeler.where((o) => !o.rapor).toList();
            final rapor = g.ogeler.where((o) => o.rapor).toList();
            for (final o in islem) { cocuklar.add(_oge(t, o, girinti: true)); }
            if (rapor.length > 1) {
              final ra = '${g.anahtar}#rapor';
              final rAcik = _acik.contains(ra);
              cocuklar.add(_altBaslik(t, 'Raporlar', rapor.length, rAcik, () => _grupCevir(ra)));
              if (rAcik) { for (final o in rapor) { cocuklar.add(_oge(t, o, girinti: true, derin: true)); } }
            } else {
              for (final o in rapor) { cocuklar.add(_oge(t, o, girinti: true)); }
            }
          }
        }
      }
    }
    return RefreshIndicator(
      onRefresh: () async {
        final tok = context.read<AuthProvider>().token;
        if (tok != null) await PanelMenuServisi.ben.yukle(tok, zorla: true);
      },
      child: ListView(padding: const EdgeInsets.only(bottom: 20), children: cocuklar),
    );
  }

  Widget _grupBaslik(TemaProvider t, MenuGrup g, bool acik) => InkWell(
        onTap: () => _grupCevir(g.anahtar),
        child: Container(
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Icon(ikonAdi(g.ikon, Icons.folder_open_outlined), size: 21, color: acik ? t.mor1 : t.sub2),
            const SizedBox(width: 12),
            Expanded(child: Text(g.ad, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: acik ? FontWeight.bold : FontWeight.w600))),
            if (g.rozet > 0 && !acik) _rozet(g.rozet),
            const SizedBox(width: 4),
            AnimatedRotation(turns: acik ? .5 : 0, duration: const Duration(milliseconds: 180), child: Icon(Icons.expand_more, color: t.sub, size: 20)),
          ]),
        ),
      );

  Widget _altBaslik(TemaProvider t, String ad, int n, bool acik, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 42),
          padding: const EdgeInsets.fromLTRB(46, 6, 14, 6),
          child: Row(children: [
            Icon(Icons.insights, size: 18, color: t.mavi),
            const SizedBox(width: 10),
            Expanded(child: Text(ad, style: TextStyle(color: t.sub2, fontSize: 14, fontWeight: FontWeight.w700))),
            Text('$n', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            AnimatedRotation(turns: acik ? .5 : 0, duration: const Duration(milliseconds: 180), child: Icon(Icons.expand_more, color: t.sub, size: 18)),
          ]),
        ),
      );

  Widget _oge(TemaProvider t, MenuOge o, {bool girinti = false, bool derin = false, String? alt}) {
    final r = o.renk == null ? t.sub2 : renkOku(o.renk, t.sub2);
    return InkWell(
      onTap: () => widget.onAc(o),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: EdgeInsets.fromLTRB(derin ? 62 : (girinti ? 30 : 14), 6, 14, 6),
        child: Row(children: [
          Icon(ikonAdi(o.ikon), size: 20, color: r),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(o.ad, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
              if (alt != null) Text(alt, style: TextStyle(color: t.sub, fontSize: 11.5)),
            ]),
          ),
          if (o.rozet > 0) _rozet(o.rozet),
        ]),
      ),
    );
  }

  Widget _rozet(int n) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xFFF43F5E), borderRadius: BorderRadius.circular(99)),
        child: Text(n > 99 ? '99+' : '$n', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
