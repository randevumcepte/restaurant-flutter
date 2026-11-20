import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Web /santral-egitim — AI Santral eğitimi, 4 sekme (web'in aynısı):
///  SSS / Kalıplar (ekle, aktif/pasif, düzenle, sil) · Öğrendikleri (düzelt, sil) ·
///  Cevaplanamayanlar (cevap ekle → kalıba çevir, sil) · PDF'ten çıkar (AI önerir → hepsini ekle).
/// Şube: sayfanın verdiği subeId (web ile aynı).
class OpSantralEgitimScreen extends StatelessWidget {
  const OpSantralEgitimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/santral-egitim',
      baslik: 'AI Santral Eğitimi',
      ikon: Icons.school_outlined,
      altBaslik: 'Hazır cevaplar, öğrenilenler, cevaplanamayanlar ve PDF\'ten kalıp',
      govde: (ctx, veri, yenile) => _OpSantralEgitimGovde(subeId: tamOku(veri['subeId'])),
    );
  }
}

class _OpSantralEgitimGovde extends StatefulWidget {
  final int subeId;
  const _OpSantralEgitimGovde({required this.subeId});
  @override
  State<_OpSantralEgitimGovde> createState() => _OpSantralEgitimGovdeState();
}

class _OpSantralEgitimGovdeState extends State<_OpSantralEgitimGovde> {
  String _sekme = 'kalip';
  final Map<String, List<Map<String, dynamic>>?> _veri = {'kalip': null, 'ogr': null, 'coz': null};
  final Map<String, String?> _hata = {};

  // yeni kalıp formu
  final _tet = TextEditingController();
  final _cev = TextEditingController();
  final _kat = TextEditingController();
  bool _ekliyor = false;

  // pdf
  bool _pdfIsliyor = false;
  String? _pdfDurum;
  bool _pdfHata = false;
  List<Map<String, dynamic>> _oneriler = [];

  static const _uclar = {
    'kalip': '/api/santral-egitim/kalip-liste',
    'ogr': '/api/santral-egitim/ogrenilen-liste',
    'coz': '/api/santral-egitim/cozulemeyen-liste',
  };

  @override
  void initState() {
    super.initState();
    _yukle('kalip');
  }

  @override
  void dispose() {
    _tet.dispose();
    _cev.dispose();
    _kat.dispose();
    super.dispose();
  }

  Future<void> _yukle(String s) async {
    final yol = _uclar[s];
    if (yol == null) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, yol, q: {'sube_id': '${widget.subeId}'});
      if (!mounted) return;
      setState(() {
        if (c.ok) {
          _veri[s] = liste(c.j['liste']);
          _hata[s] = null;
        } else {
          _hata[s] = c.hata;
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  Future<bool> _post(String yol, Map<String, dynamic> v, {String? basari}) async {
    final c = await kopruGonderCevap(context, yol, {'sube_id': widget.subeId, ...v});
    if (c == null || !c.ok) return false;
    if (basari != null && mounted) kToast(context, basari);
    return true;
  }

  // ───────── KALIP ─────────
  Future<void> _kalipEkle() async {
    final tet = _tet.text.trim(), cev = _cev.text.trim();
    if (tet.isEmpty || cev.isEmpty) {
      kToast(context, 'Tetikleyici ve cevap zorunlu.', hata: true);
      return;
    }
    setState(() => _ekliyor = true);
    final ok = await _post('/api/santral-egitim/kalip-ekle', {'tetikleyiciler': tet, 'cevap': cev, 'kategori': _kat.text.trim()}, basari: 'Kalıp eklendi.');
    if (!mounted) return;
    setState(() => _ekliyor = false);
    if (ok) {
      _tet.clear();
      _cev.clear();
      _kat.clear();
      _yukle('kalip');
    }
  }

  Future<void> _kalipDuzenle(Map<String, dynamic> x) async {
    final tet = TextEditingController(text: metinOku(x['tetikleyiciler']));
    final cev = TextEditingController(text: metinOku(x['cevap']));
    final kaydet = await kAltSayfa<bool>(context, baslik: 'Kalıbı düzenle', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Tetikleyici kelimeler (virgülle)', tet, zorunlu: true),
          KAlan('Cevap (telefonda okunacak)', cev, satir: 4, zorunlu: true),
          KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(c, true)),
        ]));
    if (kaydet == true && mounted) {
      if (tet.text.trim().isEmpty || cev.text.trim().isEmpty) {
        kToast(context, 'Tetikleyici ve cevap boş olamaz.', hata: true);
      } else if (await _post('/api/santral-egitim/kalip-guncelle', {'id': x['id'], 'tetikleyiciler': tet.text.trim(), 'cevap': cev.text.trim()}, basari: 'Kalıp güncellendi.')) {
        _yukle('kalip');
      }
    }
    tet.dispose();
    cev.dispose();
  }

  // ───────── ÖĞRENİLEN ─────────
  Future<void> _ogrDuzelt(Map<String, dynamic> x) async {
    final cev = TextEditingController(text: metinOku(x['cevap']));
    final kaydet = await kAltSayfa<bool>(context, baslik: 'Cevabı düzelt', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(metinOku(x['soru_key']), style: TextStyle(color: context.read<TemaProvider>().sub2, fontSize: 13.5)),
          const SizedBox(height: 10),
          KAlan('Yeni cevap', cev, satir: 4, zorunlu: true),
          KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(c, true)),
        ]));
    if (kaydet == true && mounted) {
      if (await _post('/api/santral-egitim/ogrenilen-guncelle', {'id': x['id'], 'cevap': cev.text.trim()}, basari: 'Cevap düzeltildi.')) _yukle('ogr');
    }
    cev.dispose();
  }

  // ───────── ÇÖZÜLEMEYEN ─────────
  Future<void> _cozKalip(Map<String, dynamic> x) async {
    final cev = TextEditingController();
    final kaydet = await kAltSayfa<bool>(context, baslik: 'AI cevabı ekle', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Soru: ${metinOku(x['ham'], metinOku(x['soru_norm']))}', style: TextStyle(color: context.read<TemaProvider>().ink, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          KAlan('Bu soruya AI ne cevap versin?', cev, satir: 4, zorunlu: true, ipucu: 'Cevap metni'),
          KButon('Ekle', ikon: Icons.add, genis: true, onTap: () => Navigator.pop(c, true)),
        ]));
    if (kaydet == true && mounted && cev.text.trim().isNotEmpty) {
      if (await _post('/api/santral-egitim/cozulemeyen-kalipla', {'id': x['id'], 'cevap': cev.text.trim()}, basari: 'Kalıba eklendi, artık AI cevaplayacak.')) {
        _yukle('coz');
        _veri['kalip'] = null;
      }
    }
    cev.dispose();
  }

  Future<void> _sil(String sekme, String yol, dynamic id, String soru) async {
    if (!await kOnay(context, soru, tehlikeli: true, evet: 'Sil')) return;
    if (!mounted) return;
    if (await _post(yol, {'id': id}, basari: 'Silindi.')) _yukle(sekme);
  }

  // ───────── PDF ─────────
  Future<void> _pdfSec() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
    final bayt = res?.files.single.bytes;
    if (bayt == null || !mounted) return;
    setState(() { _pdfIsliyor = true; _pdfDurum = 'AI belgeyi okuyor…'; _pdfHata = false; _oneriler = []; });
    final c = await kopruGonderCevap(context, '/api/santral-egitim/pdf-cikar', {'sube_id': widget.subeId, 'pdf_base64': base64Encode(bayt)}, sessiz: true);
    if (!mounted) return;
    setState(() {
      _pdfIsliyor = false;
      if (c != null && c.ok) {
        _oneriler = liste(c.j['kaliplar']);
        _pdfDurum = '${_oneriler.length} kalıp önerildi. İnceleyin, istemediklerinizi çıkarın, sonra ekleyin.';
      } else {
        _pdfHata = true;
        _pdfDurum = c?.hata ?? 'PDF işlenemedi.';
      }
    });
  }

  Future<void> _pdfOnayla() async {
    final c = await kopruGonderCevap(context, '/api/santral-egitim/pdf-onayla', {'sube_id': widget.subeId, 'kaliplar': jsonEncode(_oneriler)});
    if (!mounted || c == null || !c.ok) return;
    kToast(context, '${tamOku(c.j['eklendi'])} kalıp eklendi.');
    setState(() { _oneriler = []; _pdfDurum = null; _veri['kalip'] = null; });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ust = KCipler(
      secenekler: const [('kalip', 'SSS / Kalıplar'), ('ogr', 'Öğrendikleri'), ('coz', 'Cevaplanamayanlar'), ('pdf', 'PDF\'ten çıkar')],
      secili: _sekme,
      onSec: (k) {
        setState(() => _sekme = k);
        if (_uclar.containsKey(k)) _yukle(k);
      },
    );
    final icerik = switch (_sekme) {
      'kalip' => _kalipSekme(t),
      'ogr' => _ogrSekme(t),
      'coz' => _cozSekme(t),
      _ => _pdfSekme(t),
    };
    return KGovde(yenile: () => _yukle(_sekme), children: [ust, ...icerik]);
  }

  Widget? _durum(String s, String bosBaslik, String bosAciklama, IconData ikon) {
    final v = _veri[s];
    if (v == null) {
      if (_hata[s] != null) return KKart(child: KHata(_hata[s]!, tekrar: () => _yukle(s)));
      return const KKart(child: SizedBox(height: 120, child: KYukleniyor()));
    }
    if (v.isEmpty) return KKart(child: KBos(baslik: bosBaslik, aciklama: bosAciklama, ikon: ikon));
    return null;
  }

  List<Widget> _kalipSekme(TemaProvider t) {
    final form = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Yeni hazır cevap (SSS)', ikon: Icons.add_comment_outlined),
        KAlan('Tetikleyici kelimeler (virgülle)', _tet, ipucu: 'otopark, park yeri, araç', zorunlu: true),
        KAlan('Cevap (telefonda okunacak)', _cev, ipucu: 'Evet, ücretsiz otoparkımız var.', satir: 3, zorunlu: true),
        KAlan('Kategori (isteğe bağlı)', _kat, ipucu: 'genel'),
        Text('Müşteri bu kelimelerden birini söyleyince AI, modele gitmeden bu cevabı verir (bedava, anında).', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerLeft, child: KButon('Ekle', ikon: Icons.add, yukleniyor: _ekliyor, onTap: _kalipEkle)),
      ]),
    );
    final d = _durum('kalip', 'Henüz kalıp yok', 'Sık sorulan soruların (otopark, çalışma saati, paket servis bölgesi…) hazır cevabını yukarıdaki formdan ekleyin; AI bu soruları anında cevaplar.', Icons.quiz_outlined);
    final lst = d ??
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final x in _veri['kalip']!)
              KSatir(
                baslik: metinOku(x['tetikleyiciler']),
                alt: '${metinOku(x['cevap'])}${metinOku(x['kategori']).isEmpty ? '' : '\nKategori: ${x['kategori']}'}',
                solIkon: KIkon(Icons.quiz_outlined, renk: tamOku(x['aktif']) == 1 ? t.yesil : t.sub),
                sag: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, children: [
                  if (tamOku(x['aktif']) != 1) KRozet('pasif', renk: t.sub),
                  Switch.adaptive(
                    value: tamOku(x['aktif']) == 1,
                    activeTrackColor: t.yesil,
                    onChanged: (v) async {
                      if (await _post('/api/santral-egitim/kalip-guncelle', {'id': x['id'], 'aktif': v ? 1 : 0}, basari: v ? 'Kalıp aktif.' : 'Kalıp pasif.')) _yukle('kalip');
                    },
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'İşlemler',
                    onSelected: (k) {
                      if (k == 'duzenle') _kalipDuzenle(x);
                      if (k == 'sil') _sil('kalip', '/api/santral-egitim/kalip-sil', x['id'], 'Kalıp silinsin mi?');
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
                      PopupMenuItem(value: 'sil', child: Text('Sil')),
                    ],
                  ),
                ]),
              ),
          ]),
        );
    if (genisMi(context)) {
      return [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: form),
          const SizedBox(width: 16),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const KBaslik('Kayıtlı kalıplar', ikon: Icons.list_alt), lst])),
        ]),
      ];
    }
    return [form, const KBaslik('Kayıtlı kalıplar', ikon: Icons.list_alt), lst];
  }

  List<Widget> _ogrSekme(TemaProvider t) {
    final d = _durum('ogr', 'Henüz öğrenilen yok', 'AI bir bilgi sorusunu ilk kez cevapladığında cevabı burada saklar; aynı soru tekrar gelince bedava verir. Santral çağrı aldıkça dolar.', Icons.psychology_outlined);
    return [
      KBaslik('AI\'nın öğrendikleri', ikon: Icons.psychology_outlined, alt: 'Yanlış öğrendiyse düzeltin ya da silin.'),
      d ??
          KKart(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (final x in _veri['ogr']!)
                KSatir(
                  baslik: metinOku(x['soru_key']),
                  alt: metinOku(x['cevap']),
                  solIkon: KIkon(Icons.psychology_outlined, renk: t.mor1),
                  sag: Row(mainAxisSize: MainAxisSize.min, children: [
                    KRozet('${sayiYaz(x['kullanim'])} kez', renk: t.mavi),
                    IconButton(tooltip: 'Düzelt', onPressed: () => _ogrDuzelt(x), icon: Icon(Icons.edit_outlined, color: t.mor1)),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => _sil('ogr', '/api/santral-egitim/ogrenilen-sil', x['id'], 'Silinsin mi? (Bir daha sorulursa yeniden öğrenir)'),
                      icon: Icon(Icons.delete_outline, color: t.kirmizi),
                    ),
                  ]),
                ),
            ]),
          ),
    ];
  }

  List<Widget> _cozSekme(TemaProvider t) {
    final d = _durum('coz', 'Cevaplanamayan soru yok', 'AI\'nın çözemeyip yetkiliye aktardığı sorular burada toplanır. Şu an bekleyen yok — harika.', Icons.verified_outlined);
    return [
      KBaslik('Cevaplanamayan sorular', ikon: Icons.help_outline, alt: 'En çok sorulan üstte. "Cevap ekle" ile kalıba çevirin.'),
      d ??
          KKart(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (final x in _veri['coz']!)
                KSatir(
                  baslik: metinOku(x['ham'], metinOku(x['soru_norm'])),
                  solIkon: KIkon(Icons.help_outline, renk: t.amber),
                  sag: Row(mainAxisSize: MainAxisSize.min, children: [
                    KRozet('${sayiYaz(x['adet'])} kez', renk: t.amber),
                    const SizedBox(width: 6),
                    KButon('Cevap ekle', ikon: Icons.add, onTap: () => _cozKalip(x)),
                    IconButton(
                      tooltip: 'Sil',
                      onPressed: () => _sil('coz', '/api/santral-egitim/cozulemeyen-sil', x['id'], 'Soru silinsin mi?'),
                      icon: Icon(Icons.delete_outline, color: t.kirmizi),
                    ),
                  ]),
                ),
            ]),
          ),
    ];
  }

  List<Widget> _pdfSekme(TemaProvider t) => [
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('PDF\'ten kalıp çıkar', ikon: Icons.picture_as_pdf_outlined),
            Text('Menü, SSS ya da kurumsal bilgi PDF\'i seçin; AI soru-cevap kalıpları önersin, onaylayınca eklensin.', style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: KButon(_pdfIsliyor ? 'Çıkarılıyor…' : 'PDF seç ve kalıpları çıkar', ikon: Icons.upload_file, yukleniyor: _pdfIsliyor, onTap: _pdfSec),
            ),
            if (_pdfDurum != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_pdfDurum!, style: TextStyle(color: _pdfHata ? t.kirmizi : t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        if (_oneriler.isNotEmpty) ...[
          KBaslik('Önerilen kalıplar', ikon: Icons.auto_awesome_outlined, alt: '${_oneriler.length} öneri', sag: KButon('Hepsini ekle', ikon: Icons.done_all, renk: t.yesil, onTap: _pdfOnayla)),
          for (var i = 0; i < _oneriler.length; i++)
            KKart(
              child: KSatir(
                cizgi: false,
                baslik: metinOku(_oneriler[i]['tetikleyiciler']),
                alt: metinOku(_oneriler[i]['cevap']),
                sag: IconButton(tooltip: 'Öneriyi çıkar', onPressed: () => setState(() => _oneriler.removeAt(i)), icon: Icon(Icons.close, color: t.sub)),
              ),
            ),
        ],
      ];
}
