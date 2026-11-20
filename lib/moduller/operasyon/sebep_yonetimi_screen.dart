import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /sebep-yonetimi — ürün silme / iskonto / ikram / iptal sebepleri.
/// İşlemler: tür sekmeleri, sebep ekle (POST /sebep-yonetimi/ekle tur+metin), sil (POST /sebep-yonetimi/sil id).
/// Düzenleme yalnız sahip / müdür (web'deki $duz kuralı).
class OpSebepYonetimiScreen extends StatefulWidget {
  const OpSebepYonetimiScreen({super.key});

  @override
  State<OpSebepYonetimiScreen> createState() => _OpSebepYonetimiScreenState();
}

class _OpSebepYonetimiScreenState extends State<OpSebepYonetimiScreen> {
  static const _turler = [
    ('void', 'Ürün Silme'),
    ('indirim', 'İskonto'),
    ('ikram', 'İkram'),
    ('iptal', 'İptal'),
  ];
  static const _turRenk = {
    'void': Color(0xFFF43F5E),
    'indirim': Color(0xFFF59E0B),
    'ikram': Color(0xFF10B981),
    'iptal': Color(0xFF64748B),
  };
  static const _turAciklama = {
    'void': 'Garson / kasa siparişten ürün silerken seçilir.',
    'indirim': 'Adisyona iskonto uygulanırken seçilir.',
    'ikram': 'Ürün ikram edilirken seçilir.',
    'iptal': 'Adisyon / rezervasyon iptal edilirken seçilir.',
  };
  String _tur = 'void';

  String _turAd(String k) => _turler.firstWhere((e) => e.$1 == k, orElse: () => (k, k)).$2;

  Future<void> _ekle(Future<void> Function() yenile) async {
    final c = TextEditingController();
    bool gonderiliyor = false;
    final tamam = await kAltSayfa<bool>(
      context,
      baslik: '${_turAd(_tur)} sebebi ekle',
      icerik: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Future<void> kaydet() async {
          final m = c.text.trim();
          if (m.isEmpty) {
            kToast(ctx, 'Sebep metni boş olamaz.', hata: true);
            return;
          }
          setSt(() => gonderiliyor = true);
          final ok = await kopruGonder(context, '/sebep-yonetimi/ekle', {'tur': _tur, 'metin': m.length > 120 ? m.substring(0, 120) : m}, basariMesaji: 'Sebep eklendi.');
          if (!ctx.mounted) return;
          setSt(() => gonderiliyor = false);
          if (ok) Navigator.pop(ctx, true);
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Sebep metni', c, ipucu: 'Örn: Müşteri beğenmedi', zorunlu: true),
          KButon('Ekle', ikon: Icons.add, onTap: kaydet, yukleniyor: gonderiliyor, genis: true),
        ]);
      }),
    );
    if (tamam == true) await yenile();
  }

  Future<void> _sil(Map<String, dynamic> s, Future<void> Function() yenile) async {
    final ok = await kOnay(context, 'Bu sebep silinsin mi?', evet: 'Sil', tehlikeli: true, aciklama: '"${metinOku(s['metin'])}" artık seçim listesinde görünmez. Geçmiş kayıtlar etkilenmez.');
    if (!ok || !mounted) return;
    if (await kopruGonder(context, '/sebep-yonetimi/sil', {'id': s['id']}, basariMesaji: 'Sebep silindi.')) await yenile();
  }

  @override
  Widget build(BuildContext context) {
    final duz = context.watch<AuthProvider>().patron;
    return KopruEkran(
      yol: '/sebep-yonetimi',
      baslik: 'İptal / İkram Sebepleri',
      ikon: Icons.rule_folder_outlined,
      fab: duz ? (ctx, v, yenile) => FloatingActionButton.extended(onPressed: () => _ekle(yenile), icon: const Icon(Icons.add), label: const Text('Sebep Ekle')) : null,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final gruplar = harita(v['gruplar']);
        final secili = liste(gruplar[_tur]);
        final renk = _turRenk[_tur] ?? t.mor1;
        return KGovde(yenile: yenile, maxGenislik: 860, children: [
          KKpiIzgara([
            for (final (k, e) in _turler)
              KKpi(etiket: e, deger: '${liste(gruplar[k]).length}', alt: 'sebep', renk: _turRenk[k], onTap: () => setState(() => _tur = k)),
          ]),
          KCipler(secenekler: _turler, secili: _tur, onSec: (k) => setState(() => _tur = k)),
          if (!duz)
            KKart(
              renk: t.amber,
              child: Text('Sebepleri sadece işletme sahibi / müdürü düzenleyebilir.', style: TextStyle(color: t.sub2, fontSize: 13.5)),
            ),
          KBaslik(_turAd(_tur), ikon: Icons.list_alt, renk: renk, alt: _turAciklama[_tur]),
          if (secili.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Bu türde sebep yok',
                aciklama: duz
                    ? 'Personel ${_turAd(_tur).toLowerCase()} yaparken listeden sebep seçer. Sağ alttaki "Sebep Ekle" ile ekleyin.'
                    : 'Personel ${_turAd(_tur).toLowerCase()} yaparken listeden sebep seçer. Sebepleri işletme sahibi / müdürü bu ekrandan ekler.',
                ikon: Icons.rule_folder_outlined,
              ),
            )
          else
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(children: [
                for (var i = 0; i < secili.length; i++)
                  KSatir(
                    baslik: metinOku(secili[i]['metin'], '—'),
                    cizgi: i < secili.length - 1,
                    solIkon: KIkon(Icons.label_outline, renk: renk, boyut: 34),
                    sag: duz
                        ? IconButton(
                            tooltip: 'Sil',
                            onPressed: () => _sil(secili[i], yenile),
                            icon: Icon(Icons.delete_outline, color: t.kirmizi),
                          )
                        : null,
                  ),
              ]),
            ),
          if (genisMi(ctx)) const SizedBox(height: 10),
        ]);
      },
    );
  }
}
