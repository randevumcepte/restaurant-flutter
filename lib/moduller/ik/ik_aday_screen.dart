import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /ik-aday — İşe Alım / Aday Havuzu (web ile aynı veri ve işlemler):
/// başvuru linki (kopyala/önizle), durum filtresi, aday ekle, durum/puan değiştir, not, CV indir, işe al, sil.
class IkAdayScreen extends StatefulWidget {
  const IkAdayScreen({super.key});
  @override
  State<IkAdayScreen> createState() => _IkAdayScreenState();
}

const Map<String, String> _durumVarsayilan = {
  'yeni': 'Yeni', 'inceleme': 'İnceleniyor', 'mulakat': 'Mülakat', 'teklif': 'Teklif', 'islendi': 'İşe Alındı', 'red': 'Olumsuz',
};

Color _durumRenk(String d) => const {
      'yeni': Color(0xFF4F46E5),
      'inceleme': Color(0xFFF59E0B),
      'mulakat': Color(0xFF7C3AED),
      'teklif': Color(0xFF0EA5E9),
      'islendi': Color(0xFF10B981),
      'red': Color(0xFF64748B),
    }[d] ??
    const Color(0xFF64748B);

class _IkAdayScreenState extends State<IkAdayScreen> {
  final _anahtar = GlobalKey<KopruEkranState>();
  String _filtre = '';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _anahtar,
      yol: '/ik-aday',
      baslik: 'İşe Alım / Aday Havuzu',
      ikon: Icons.how_to_reg_outlined,
      fab: (c, v, yenile) => FloatingActionButton.extended(
        heroTag: 'ik_aday_ekle',
        onPressed: () => _adayEkle(c, yenile),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Aday Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final durumlarH = harita(v['durumlar']);
    final durumlar = durumlarH.isEmpty ? _durumVarsayilan : {for (final e in durumlarH.entries) e.key: metinOku(e.value)};
    final sayac = harita(v['sayac']);
    final toplam = sayac.values.fold<int>(0, (a, b) => a + tamOku(b));
    final subeId = metinOku(v['subeId'], '');
    final link = '${AppConfig.baseUrl}/kariyer/$subeId';
    var adaylar = liste(v['adaylar']);
    if (_ara.isNotEmpty) {
      final q = _ara.toLowerCase();
      adaylar = adaylar
          .where((a) => '${a['ad']} ${a['pozisyon']} ${a['telefon']} ${a['email']}'.toLowerCase().contains(q))
          .toList();
    }
    final genis = genisMi(context);

    return KGovde(yenile: yenile, children: [
      KKart(
        renk: t.mavi,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.campaign_outlined, color: t.mavi, size: 20),
            const SizedBox(width: 8),
            Text('Genel Başvuru Linki', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          SelectableText(link, style: TextStyle(color: t.sub2, fontSize: 13)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Kopyala', ikon: Icons.content_copy, ikincil: true, onTap: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (context.mounted) kToast(context, 'Link kopyalandı.');
            }),
            KButon('Önizle', ikon: Icons.open_in_new, ikincil: true, onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication)),
          ]),
          const SizedBox(height: 6),
          Text('Bu linki iş ilanlarında, sosyal medyada veya kapıdaki QR\'da paylaşın. Dolduran herkes aşağıdaki havuza "Yeni" olarak düşer.',
              style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
      ),
      KCipler(
        secenekler: [('', 'Tümü ($toplam)'), for (final e in durumlar.entries) (e.key, '${e.value} (${tamOku(sayac[e.key])})')],
        secili: _filtre,
        onSec: (k) {
          setState(() => _filtre = k);
          _anahtar.currentState?.sorgu(k.isEmpty ? {} : {'durum': k}, birlestir: false);
        },
      ),
      KAra(ipucu: 'Ad, pozisyon, telefon ara…', onDegis: (s) => setState(() => _ara = s.trim())),
      if (adaylar.isEmpty)
        KBos(
          ikon: Icons.inbox_outlined,
          baslik: _filtre.isNotEmpty || _ara.isNotEmpty ? 'Bu filtrede aday yok' : 'Henüz aday yok',
          aciklama: _filtre.isNotEmpty || _ara.isNotEmpty
              ? 'Filtreyi "Tümü" yapın ya da aramayı temizleyin.'
              : 'Adaylar, yukarıdaki başvuru linkini dolduranlardan otomatik gelir. Elden başvuranları "Aday Ekle" ile girebilirsiniz.',
        )
      else if (genis)
        LayoutBuilder(builder: (c, k) {
          final w = (k.maxWidth - 12) / 2;
          return Wrap(spacing: 12, children: [for (final a in adaylar) SizedBox(width: w, child: _adayKart(context, a, durumlar, yenile))]);
        })
      else
        for (final a in adaylar) _adayKart(context, a, durumlar, yenile),
    ]);
  }

  Widget _adayKart(BuildContext context, Map<String, dynamic> a, Map<String, String> durumlar, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final durum = metinOku(a['durum'], 'yeni');
    final r = _durumRenk(durum);
    final puan = tamOku(a['puan']);
    final cv = metinOku(a['cv_dosya']).isNotEmpty;
    final id = tamOku(a['id']);
    final altParca = [
      metinOku(a['pozisyon'], 'Pozisyon belirtilmemiş'),
      if (metinOku(a['telefon']).isNotEmpty) metinOku(a['telefon']),
      if (metinOku(a['email']).isNotEmpty) metinOku(a['email']),
      tarihYaz(a['created_at'], saat: false),
    ];
    return KKart(
      renk: r,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(a['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
          KRozet(durumlar[durum] ?? durum, renk: r),
        ]),
        const SizedBox(height: 4),
        Text('${metinOku(a['kaynak']) == 'web' ? 'Web başvurusu' : 'Elden'} · ${altParca.join(' · ')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        if (puan > 0) Padding(padding: const EdgeInsets.only(top: 4), child: Text('★' * puan, style: TextStyle(color: t.amber, fontSize: 15))),
        if (metinOku(a['notlar']).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
            child: Text(metinOku(a['notlar']), style: TextStyle(color: t.sub2, fontSize: 13)),
          ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _MiniSecim(
            etiket: 'Durum: ${durumlar[durum] ?? durum}',
            ikon: Icons.swap_horiz,
            secenekler: [for (final e in durumlar.entries) (e.key, e.value)],
            onSec: (k) async {
              if (k == durum) return;
              if (await kopruGonder(context, '/ik-aday/guncelle', {'id': id, 'durum': k})) await yenile();
            },
          ),
          _MiniSecim(
            etiket: puan > 0 ? 'Puan: ${'★' * puan}' : '★ Puan ver',
            ikon: Icons.star_outline,
            secenekler: [('', 'Puanı kaldır'), for (var i = 1; i <= 5; i++) ('$i', '★' * i)],
            onSec: (k) async {
              if (await kopruGonder(context, '/ik-aday/guncelle', {'id': id, 'puan': k})) await yenile();
            },
          ),
          KButon('Not', ikon: Icons.edit_note, ikincil: true, onTap: () => _notDuzenle(context, a, yenile)),
          if (cv) KButon('CV', ikon: Icons.description_outlined, ikincil: true, renk: t.mavi, onTap: () => _cvIndir(context, id, metinOku(a['ad']), metinOku(a['cv_dosya']))),
          if (durum != 'islendi')
            KButon('İşe Al', ikon: Icons.how_to_reg, renk: t.yesil, onTap: () => _iseAl(context, a, yenile))
          else if (tamOku(a['personel_id']) > 0)
            KButon('Sicil Kartı', ikon: Icons.folder_shared_outlined, ikincil: true, renk: t.yesil, onTap: () => _ac(context, '/ik-sicil?id=${tamOku(a['personel_id'])}', 'Sicil Kartı')),
          KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
            if (!await kOnay(context, '${metinOku(a['ad'])} adayı silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
            if (!context.mounted) return;
            if (await kopruGonder(context, '/ik-aday/sil', {'id': id})) await yenile();
          }),
        ]),
      ]),
    );
  }

  void _ac(BuildContext context, String yol, String ad) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(yol, ad)));
  }

  Future<void> _notDuzenle(BuildContext context, Map<String, dynamic> a, Future<void> Function() yenile) async {
    final c = TextEditingController(text: metinOku(a['notlar']));
    final kaydet = await kAltSayfa<bool>(context,
        baslik: 'Not — ${metinOku(a['ad'])}',
        icerik: (sc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KAlan('Not', c, satir: 4, ipucu: 'Mülakat notu, referans vb.'),
              KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(sc, true)),
            ]));
    if (kaydet != true || !context.mounted) return;
    if (await kopruGonder(context, '/ik-aday/guncelle', {'id': tamOku(a['id']), 'notlar': c.text.trim()})) await yenile();
  }

  Future<void> _adayEkle(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController(), tel = TextEditingController(), poz = TextEditingController();
    final mail = TextEditingController(), not = TextEditingController();
    const pozList = ['Garson', 'Komi', 'Mutfak', 'Aşçı', 'Kasa', 'Bar', 'Host', 'Bulaşık', 'Temizlik', 'Müdür'];
    final tamam = await kAltSayfa<bool>(context,
        baslik: 'Aday Ekle (elden)',
        icerik: (sc) => StatefulBuilder(
              builder: (sc, ss) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KAlan('Ad Soyad', ad, zorunlu: true),
                KAlan('Telefon', tel, klavye: TextInputType.phone),
                KAlan('Pozisyon', poz, ipucu: 'ör. Garson'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final p in pozList) ActionChip(label: Text(p, style: const TextStyle(fontSize: 12.5)), onPressed: () => ss(() => poz.text = p)),
                  ]),
                ),
                KAlan('E-posta', mail, klavye: TextInputType.emailAddress),
                KAlan('Not', not, ipucu: 'ör. referans: …'),
                KButon('Ekle', ikon: Icons.person_add_alt_1, genis: true, onTap: () {
                  if (ad.text.trim().isEmpty) {
                    kToast(sc, 'Ad boş olamaz.', hata: true);
                    return;
                  }
                  Navigator.pop(sc, true);
                }),
              ]),
            ));
    if (tamam != true || !context.mounted) return;
    final ok = await kopruGonder(context, '/ik-aday/ekle', {
      'ad': ad.text.trim(), 'telefon': tel.text.trim(), 'pozisyon': poz.text.trim(), 'email': mail.text.trim(), 'notlar': not.text.trim(),
    });
    if (ok) await yenile();
  }

  Future<void> _iseAl(BuildContext context, Map<String, dynamic> a, Future<void> Function() yenile) async {
    String rol = 'garson';
    final pin = TextEditingController();
    DateTime bas = DateTime.now();
    final tamam = await kAltSayfa<bool>(context,
        baslik: '${metinOku(a['ad'])} — İşe Al',
        icerik: (sc) => StatefulBuilder(builder: (sc, ss) {
              final t = sc.watch<TemaProvider>();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Adaydan bir personel kartı oluşturulur. POS\'a bu PIN ile giriş yapar; özlük bilgilerini sonra sicil kartından tamamlarsınız.',
                      style: TextStyle(color: t.sub2, fontSize: 13)),
                ),
                KSecim<String>('Rol', deger: rol, secenekler: const [
                  ('garson', 'Garson'), ('mutfak', 'Mutfak'), ('kasa', 'Kasa'), ('satinalmaci', 'Satın Almacı'), ('mudur', 'Müdür'),
                ], onSec: (v) => ss(() => rol = v ?? 'garson')),
                KAlan('PIN (en az 4 hane)', pin, klavye: TextInputType.number, zorunlu: true),
                KSatir(
                  baslik: 'İşe başlama tarihi',
                  alt: '${bas.day.toString().padLeft(2, '0')}.${bas.month.toString().padLeft(2, '0')}.${bas.year}',
                  solIkon: KIkon(Icons.event, renk: t.mavi),
                  sag: Icon(Icons.edit_calendar, color: t.sub),
                  onTap: () async {
                    final d = await showDatePicker(context: sc, initialDate: bas, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (d != null) ss(() => bas = d);
                  },
                ),
                const SizedBox(height: 12),
                KButon('İşe Al', ikon: Icons.how_to_reg, renk: t.yesil, genis: true, onTap: () {
                  if (pin.text.replaceAll(RegExp(r'\D'), '').length < 4) {
                    kToast(sc, 'En az 4 haneli PIN girin.', hata: true);
                    return;
                  }
                  Navigator.pop(sc, true);
                }),
              ]);
            }));
    if (tamam != true || !context.mounted) return;
    final tarih = '${bas.year}-${bas.month.toString().padLeft(2, '0')}-${bas.day.toString().padLeft(2, '0')}';
    final ok = await kopruGonder(context, '/ik-aday/ise-al', {'id': tamOku(a['id']), 'rol': rol, 'pin': pin.text.trim(), 'ise_baslama': tarih},
        basariMesaji: '${metinOku(a['ad'])} işe alındı.');
    if (ok) await yenile();
  }

  Future<void> _cvIndir(BuildContext context, int id, String ad, String dosya) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    kToast(context, 'CV indiriliyor…');
    Uint8List? b;
    try {
      b = await KopruApi.dosya(tok, '/ik-cv-indir', q: {'id': '$id'});
    } on ApiYetkiHatasi {
      if (context.mounted) context.read<AuthProvider>().cikis();
      return;
    }
    if (!context.mounted) return;
    if (b == null) {
      kToast(context, 'CV dosyası bulunamadı ya da indirilemedi.', hata: true);
      return;
    }
    await dosyaKaydetPaylas(context, b, 'CV-$ad.${_uzanti(dosya, b)}');
  }

  String _uzanti(String dosya, Uint8List b) {
    final i = dosya.lastIndexOf('.');
    if (i > 0 && i < dosya.length - 1) return dosya.substring(i + 1).toLowerCase();
    if (b.length > 4 && b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) return 'pdf';
    return 'dat';
  }
}

/// İndirilen dosyayı kaydet/paylaş: PDF → sistem paylaş/yazdır; diğerleri → "Farklı kaydet" penceresi.
Future<void> dosyaKaydetPaylas(BuildContext context, Uint8List b, String ad) async {
  try {
    if (ad.toLowerCase().endsWith('.pdf')) {
      await Printing.sharePdf(bytes: b, filename: ad);
      return;
    }
    final yol = await FilePicker.platform.saveFile(dialogTitle: 'Dosyayı kaydet', fileName: ad, bytes: b);
    if (yol == null) return;
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final f = File(yol);
      if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(b);
    }
    if (context.mounted) kToast(context, 'Kaydedildi.');
  } catch (_) {
    if (context.mounted) kToast(context, 'Dosya kaydedilemedi.', hata: true);
  }
}

/// Küçük açılır menü butonu (durum / puan seçimi)
class _MiniSecim extends StatelessWidget {
  final String etiket;
  final IconData ikon;
  final List<(String, String)> secenekler;
  final ValueChanged<String> onSec;
  const _MiniSecim({required this.etiket, required this.ikon, required this.secenekler, required this.onSec});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return PopupMenuButton<String>(
      tooltip: etiket,
      color: t.card,
      onSelected: onSec,
      itemBuilder: (_) => [for (final (k, e) in secenekler) PopupMenuItem(value: k, child: Text(e, style: TextStyle(color: t.ink)))],
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: t.mor1.withValues(alpha: .08), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.mor1.withValues(alpha: .3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 17, color: t.mor1),
          const SizedBox(width: 6),
          Text(etiket, style: TextStyle(color: t.mor1, fontSize: 13.5, fontWeight: FontWeight.w700)),
          Icon(Icons.arrow_drop_down, color: t.mor1),
        ]),
      ),
    );
  }
}
