import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /urun-fotolar — her ürüne kendi fotoğrafını yükle (yoksa otomatik/stok görsel kullanılır).
/// İşlemler: foto yükle/değiştir (galeri ya da kamera → /urun-foto-yukle), kaldır (/urun-foto-sil → otomatik görsele döner).
class MenuUrunFotolarScreen extends StatefulWidget {
  const MenuUrunFotolarScreen({super.key});

  @override
  State<MenuUrunFotolarScreen> createState() => _MenuUrunFotolarScreenState();
}

class _MenuUrunFotolarScreenState extends State<MenuUrunFotolarScreen> {
  final Map<int, String> _yeniUrl = {}; // yüklenen fotoğraf (önbellek kırıcıyla) — yenilemeyi beklemeden görünsün
  final Set<int> _yukleniyor = {};
  String _filtre = 'hepsi';
  String _ara = '';

  Future<void> _yukle(Map<String, dynamic> u, ImageSource kaynak, Future<void> Function() yenile) async {
    final id = tamOku(u['id']);
    XFile? x;
    try {
      x = await ImagePicker().pickImage(source: kaynak, maxWidth: 1600, imageQuality: 85);
    } catch (_) {
      if (mounted) kToast(context, 'Bu cihazda kamera/galeri açılamadı.', hata: true);
      return;
    }
    if (x == null || !mounted) return;
    setState(() => _yukleniyor.add(id));
    final c = await menuDosyaGonder(context, '/urun-foto-yukle', {'urun_id': '$id'}, 'foto', x, basariMesaji: '${metinOku(u['ad'])} fotoğrafı yüklendi.');
    if (!mounted) return;
    setState(() {
      _yukleniyor.remove(id);
      final url = metinOku(c?.j['url']);
      if (c?.ok == true && url.isNotEmpty) _yeniUrl[id] = url;
    });
    if (c?.ok == true) yenile();
  }

  Future<void> _kaldir(Map<String, dynamic> u, Future<void> Function() yenile) async {
    final id = tamOku(u['id']);
    if (!await kOnay(context, 'Fotoğraf kaldırılsın mı?', aciklama: '${metinOku(u['ad'])} yeniden otomatik görsele döner.', tehlikeli: true, evet: 'Kaldır')) return;
    if (!mounted) return;
    setState(() => _yukleniyor.add(id));
    final ok = await kopruGonder(context, '/urun-foto-sil', {'urun_id': '$id'}, basariMesaji: 'Fotoğraf kaldırıldı.');
    if (!mounted) return;
    setState(() {
      _yukleniyor.remove(id);
      if (ok) _yeniUrl.remove(id);
    });
    if (ok) yenile();
  }

  void _kaynakSec(Map<String, dynamic> u, Future<void> Function() yenile) {
    kAltSayfa(context, baslik: '${metinOku(u['ad'])} · fotoğraf', icerik: (c) {
      final t = c.watch<TemaProvider>();
      return Column(mainAxisSize: MainAxisSize.min, children: [
        KSatir(baslik: 'Galeriden / dosyadan seç', solIkon: KIkon(Icons.photo_library_outlined, renk: t.mor1), onTap: () {
          Navigator.pop(c);
          _yukle(u, ImageSource.gallery, yenile);
        }),
        KSatir(baslik: 'Kamerayla çek', alt: 'Telefon/tablette', solIkon: KIkon(Icons.photo_camera_outlined, renk: t.mavi), onTap: () {
          Navigator.pop(c);
          _yukle(u, ImageSource.camera, yenile);
        }),
        if (u['yuklendi'] == true)
          KSatir(baslik: 'Fotoğrafı kaldır', alt: 'Otomatik görsele döner', solIkon: KIkon(Icons.delete_outline, renk: t.kirmizi), cizgi: false, onTap: () {
            Navigator.pop(c);
            _kaldir(u, yenile);
          }),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sid = context.read<AuthProvider>().subeId;
    return KopruEkran(
      yol: '/urun-fotolar',
      // web sayfası şubeyi ?sube= ile alır (yoksa ilk şube) → oturumdaki şube açıkça gönderilir
      q: {if (sid != null) 'sube': '$sid'},
      baslik: 'Ürün Fotoğrafları',
      ikon: Icons.photo_library_outlined,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final l = liste(v['liste']);
    final yuklu = l.where((u) => u['yuklendi'] == true || _yeniUrl.containsKey(tamOku(u['id']))).length;
    final gorunen = l.where((u) {
      final y = u['yuklendi'] == true || _yeniUrl.containsKey(tamOku(u['id']));
      if (_filtre == 'yuklu' && !y) return false;
      if (_filtre == 'eksik' && y) return false;
      if (_ara.isNotEmpty && !metinOku(u['ad']).toLowerCase().contains(_ara.toLowerCase())) return false;
      return true;
    }).toList();

    Widget kart(Map<String, dynamic> u) {
      final id = tamOku(u['id']);
      final y = u['yuklendi'] == true || _yeniUrl.containsKey(id);
      final url = _yeniUrl[id] ?? metinOku(u['onizleme']);
      final yuk = _yukleniyor.contains(id);
      return KKart(
        padding: EdgeInsets.zero,
        onTap: yuk ? null : () => _kaynakSec(u, yenile),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                Container(color: t.card2),
                if (url.startsWith('http'))
                  Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.image_not_supported_outlined, color: t.sub, size: 36))
                else
                  Icon(Icons.image_outlined, color: t.sub, size: 40),
                Positioned(
                  left: 8,
                  top: 8,
                  child: KRozet(y ? '✓ Yüklendi' : 'Otomatik', renk: y ? t.yesil : t.sub),
                ),
                if (yuk) Container(color: Colors.black38, child: const Center(child: CircularProgressIndicator(color: Colors.white))),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Text(metinOku(u['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Text('${metinOku(u['kat'], '-')} · ${metinOku(u['fiyat'])}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              Expanded(
                child: KButon(y ? 'Değiştir' : 'Fotoğraf yükle', ikon: Icons.upload_outlined, ikincil: true, yukleniyor: yuk, onTap: () => _kaynakSec(u, yenile)),
              ),
              if (y) ...[
                const SizedBox(width: 4),
                IconButton(tooltip: 'Kaldır', onPressed: yuk ? null : () => _kaldir(u, yenile), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
              ],
            ]),
          ),
        ]),
      );
    }

    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Aktif ürün', deger: '${l.length}', ikon: Icons.restaurant_menu_outlined, renk: t.mor1),
        KKpi(etiket: 'Özel fotoğraflı', deger: '$yuklu', ikon: Icons.photo_outlined, renk: t.yesil),
        KKpi(etiket: 'Otomatik görselde', deger: '${l.length - yuklu}', ikon: Icons.auto_awesome_outlined, renk: t.amber),
      ]),
      const SizedBox(height: 10),
      KAra(ipucu: 'Ürün ara…', onDegis: (s) => setState(() => _ara = s.trim())),
      const SizedBox(height: 8),
      KCipler(
        secenekler: const [('hepsi', 'Tümü'), ('eksik', 'Fotoğrafsız'), ('yuklu', 'Fotoğraflı')],
        secili: _filtre,
        onSec: (k) => setState(() => _filtre = k),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text('JPG, PNG ya da WEBP · en fazla 6 MB. Fotoğrafı olmayan ürünlerde QR menü otomatik görsel gösterir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
      ),
      if (l.isEmpty)
        const KBos(baslik: 'Aktif ürün yok', aciklama: 'Fotoğraf yüklemek için önce Menü Yönetimi ekranından ürün ekleyin (pasif ürünler burada listelenmez).', ikon: Icons.photo_library_outlined)
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtreye uyan ürün yok', aciklama: 'Filtreyi "Tümü" yapın ya da arama metnini değiştirin.', ikon: Icons.filter_alt_off_outlined)
      else
        LayoutBuilder(builder: (c, s) {
          final sutun = s.maxWidth >= 1000 ? 5 : (s.maxWidth >= 720 ? 4 : (s.maxWidth >= 480 ? 3 : 2));
          final w = (s.maxWidth - (sutun - 1) * 10) / sutun;
          return Wrap(spacing: 10, children: [for (final u in gorunen) SizedBox(width: w, child: kart(u))]);
        }),
    ]);
  }
}
