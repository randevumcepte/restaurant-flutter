import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /one-cikanlar — Öne Çıkan Ürünler / Günün Önerisi: işaretlenen ürünleri asistan müşteriye öne çıkararak önerir.
/// Her ürün: öne çıkan (aç/kapa) + rozet (≤60) + iştah kabartıcı cümle (≤255) + sıra. Kaydet → /one-cikanlar-kaydet.
/// Not: web sayfası JSON view değil ham HTML döndürür → form alanları HTML'den okunur (sunucu değişikliği gerekmez).
class MenuOneCikanlarScreen extends StatefulWidget {
  const MenuOneCikanlarScreen({super.key});

  @override
  State<MenuOneCikanlarScreen> createState() => _MenuOneCikanlarScreenState();
}

class _Urun {
  final int id;
  final String ad;
  final String kategori;
  bool oneCikan;
  final TextEditingController etiket;
  final TextEditingController soz;
  final TextEditingController sira;
  _Urun(this.id, this.ad, this.kategori, this.oneCikan, String et, String sz, String sr)
      : etiket = TextEditingController(text: et),
        soz = TextEditingController(text: sz),
        sira = TextEditingController(text: sr);
}

class _MenuOneCikanlarScreenState extends State<MenuOneCikanlarScreen> {
  List<_Urun>? _urunler;
  String? _hata;
  bool _kaydediyor = false;
  bool _degisti = false;
  String _filtre = 'hepsi';
  String _ara = '';

  static final RegExp _kat = RegExp(r'<div class="kat"><h2>(.*?)</h2>');
  static final RegExp _satir = RegExp(
    r'name="oc\[(\d+)\]" value="1"\s*(checked)?[^>]*><b>(.*?)</b></label><div class="alan">'
    r'<input name="et\[\d+\]" value="(.*?)"[^>]*><input name="sz\[\d+\]" value="(.*?)"[^>]*>'
    r'<input class="sira" type="number" name="sr\[\d+\]" value="(-?\d*)"',
  );

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final u in _urunler ?? <_Urun>[]) {
      u.etiket.dispose();
      u.soz.dispose();
      u.sira.dispose();
    }
    super.dispose();
  }

  Future<void> _yukle() async {
    final sid = context.read<AuthProvider>().subeId;
    // Web sayfası şubeyi ?sube= ile alır (yoksa ilk şube) → oturumdaki şubeyi açıkça gönder.
    final html = await menuHtmlAl(context, '/one-cikanlar', q: {if (sid != null) 'sube': '$sid'});
    if (!mounted) return;
    if (html == null) {
      setState(() => _hata = 'Öne çıkan ürünler yüklenemedi. Bağlantınızı ya da yetkinizi (yönetici) kontrol edin.');
      return;
    }
    // Kategori başlıklarının konumları → her satırın kategorisi
    final katlar = [for (final m in _kat.allMatches(html)) (m.start, htmlCoz(m.group(1) ?? ''))];
    String katBul(int konum) {
      var k = '';
      for (final (s, ad) in katlar) {
        if (s < konum) k = ad;
      }
      return k;
    }

    final l = <_Urun>[
      for (final m in _satir.allMatches(html))
        _Urun(int.parse(m.group(1)!), htmlCoz(m.group(3) ?? ''), katBul(m.start), m.group(2) != null, htmlCoz(m.group(4) ?? ''), htmlCoz(m.group(5) ?? ''),
            (m.group(6) ?? '0').isEmpty ? '0' : m.group(6)!),
    ];
    setState(() {
      _urunler = l;
      _hata = null;
      _degisti = false;
    });
  }

  Future<void> _kaydet() async {
    final l = _urunler;
    if (l == null) return;
    final sid = context.read<AuthProvider>().subeId;
    setState(() => _kaydediyor = true);
    final ok = await kopruGonder(context, '/one-cikanlar-kaydet', {
      'sube': '${sid ?? ''}',
      'oc': {for (final u in l) if (u.oneCikan) '${u.id}': '1'},
      'et': {for (final u in l) '${u.id}': u.etiket.text.trim()},
      'sz': {for (final u in l) '${u.id}': u.soz.text.trim()},
      'sr': {for (final u in l) '${u.id}': u.sira.text.trim().isEmpty ? '0' : u.sira.text.trim()},
    }, basariMesaji: 'Kaydedildi. Asistan artık bu önerileri sunacak.');
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (ok) _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    final l = _urunler;
    if (l == null && _hata == null) {
      govde = const KYukleniyor();
    } else if (l == null) {
      govde = KHata(_hata!, tekrar: _yukle);
    } else {
      final secili = l.where((u) => u.oneCikan).length;
      final gorunen = l.where((u) {
        if (_filtre == 'secili' && !u.oneCikan) return false;
        if (_ara.isNotEmpty && !u.ad.toLowerCase().contains(_ara.toLowerCase())) return false;
        return true;
      }).toList();
      final gruplar = <String, List<_Urun>>{};
      for (final u in gorunen) {
        gruplar.putIfAbsent(u.kategori.isEmpty ? 'Kategorisiz' : u.kategori, () => []).add(u);
      }
      govde = KGovde(yenile: _yukle, maxGenislik: 860, children: [
        KKart(
          renk: t.amber,
          child: Text(
            '💡 Nasıl çalışır? Bir ürünü öne çıkarın → kartta görünen kısa Rozet (ör. "Şefin Önerisi") ve iştah kabartıcı bir cümle girin. '
            'Sıra küçük olan önce gösterilir. Müşteri "ne önerirsin / içecek / günün yemeği" dediğinde asistan bunları anlatır.',
            style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45),
          ),
        ),
        KKpiIzgara([
          KKpi(etiket: 'Aktif ürün', deger: '${l.length}', ikon: Icons.restaurant_menu_outlined, renk: t.mor1),
          KKpi(etiket: 'Öne çıkan', deger: '$secili', ikon: Icons.star_outline, renk: t.gold),
        ]),
        const SizedBox(height: 10),
        KAra(ipucu: 'Ürün ara…', onDegis: (s) => setState(() => _ara = s.trim())),
        const SizedBox(height: 8),
        KCipler(secenekler: const [('hepsi', 'Tüm ürünler'), ('secili', 'Yalnız öne çıkanlar')], secili: _filtre, onSec: (k) => setState(() => _filtre = k)),
        if (l.isEmpty)
          const KBos(baslik: 'Bu şubede aktif ürün yok', aciklama: 'Önce Menü Yönetimi ekranından ürün ekleyin ya da pasif ürünleri aktif yapın.', ikon: Icons.restaurant_menu_outlined)
        else if (gorunen.isEmpty)
          KBos(
            baslik: _filtre == 'secili' ? 'Henüz öne çıkan ürün yok' : 'Aramaya uyan ürün yok',
            aciklama: _filtre == 'secili' ? '"Tüm ürünler" sekmesinden bir ürünün anahtarını açın, rozet ve cümle yazıp Kaydet\'e basın.' : 'Arama metnini değiştirin.',
            ikon: Icons.star_outline,
          ),
        for (final g in gruplar.entries) ...[
          KBaslik(g.key, ikon: Icons.folder_outlined),
          for (final u in g.value) _urunKart(t, u),
        ],
      ]);
    }
    return KSayfa(
      baslik: 'Öne Çıkan Ürünler',
      ikon: Icons.star_outline,
      altBaslik: 'Günün önerisi — asistan müşteriye öne çıkararak önerir',
      araclar: [IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh))],
      fab: l == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _kaydediyor ? null : _kaydet,
              backgroundColor: _degisti ? t.mor1 : null,
              icon: _kaydediyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined),
              label: Text(_degisti ? 'Kaydet (değişiklik var)' : 'Kaydet', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
      govde: govde,
    );
  }

  Widget _urunKart(TemaProvider t, _Urun u) {
    void degisti([String? _]) {
      if (!_degisti) setState(() => _degisti = true);
    }

    InputDecoration dek(String ipucu) => InputDecoration(
          hintText: ipucu,
          hintStyle: TextStyle(color: t.sub, fontSize: 13),
          filled: true,
          fillColor: t.card2,
          isDense: true,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1, width: 1.5)),
        );
    return KKart(
      renk: u.oneCikan ? t.mor1 : null,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(u.oneCikan ? Icons.star : Icons.star_border, color: u.oneCikan ? t.gold : t.sub, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(u.ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          Switch(
            value: u.oneCikan,
            activeThumbColor: t.mor1,
            onChanged: (v) => setState(() {
              u.oneCikan = v;
              _degisti = true;
            }),
          ),
        ]),
        if (u.oneCikan)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 6, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(controller: u.etiket, maxLength: 60, onChanged: degisti, style: TextStyle(color: t.ink, fontSize: 14), decoration: dek('Rozet: örn. Şefin Önerisi / Bugüne Özel')),
              const SizedBox(height: 8),
              TextField(controller: u.soz, maxLength: 255, maxLines: 2, minLines: 1, onChanged: degisti, style: TextStyle(color: t.ink, fontSize: 14), decoration: dek('İştah kabartıcı cümle: örn. Bugüne özel, mangalda pişmiş enfes köftemiz sizi bekliyor 😋')),
              const SizedBox(height: 8),
              Row(children: [
                SizedBox(width: 130, child: TextField(controller: u.sira, keyboardType: TextInputType.number, onChanged: degisti, style: TextStyle(color: t.ink, fontSize: 14), decoration: dek('Sıra'))),
                const SizedBox(width: 10),
                Expanded(child: Text('Küçük sayı önce gösterilir', style: TextStyle(color: t.sub, fontSize: 12))),
              ]),
            ]),
          ),
      ]),
    );
  }
}
