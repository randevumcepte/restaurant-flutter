import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /fatura-ocr — faturayı fotoğrafla / PDF yükle → AI kalemleri okur (POST /fatura-ocr/oku, multipart alan "fatura").
class FaturaOcrScreen extends StatefulWidget {
  const FaturaOcrScreen({super.key});
  @override
  State<FaturaOcrScreen> createState() => _FaturaOcrScreenState();
}

class _FaturaOcrScreenState extends State<FaturaOcrScreen> {
  Map<String, dynamic>? _sonuc;
  bool _okunuyor = false;
  String? _dosyaAdi;

  Future<void> _gonder(String ad, List<int> b) async {
    if (b.length > 8 * 1024 * 1024) return kToast(context, 'Dosya 8 MB\'den küçük olmalı.', hata: true);
    setState(() {
      _okunuyor = true;
      _dosyaAdi = ad;
      _sonuc = null;
    });
    final c = await saDosyaYukle(context, '/fatura-ocr/oku', [('fatura', ad, b)]);
    if (!mounted) return;
    setState(() => _okunuyor = false);
    if (c == null) return;
    if (!c.ok || metinOku(c.j['hata']).isNotEmpty) {
      kToast(context, metinOku(c.j['hata'], 'Fatura okunamadı.'), hata: true);
      return;
    }
    final s = harita(c.veri['sonuc']);
    if (s.isEmpty) {
      kToast(context, 'Fatura okunamadı. Daha net bir fotoğrafla tekrar deneyin.', hata: true);
      return;
    }
    setState(() => _sonuc = s);
  }

  Future<void> _foto(ImageSource k) async {
    final x = await ImagePicker().pickImage(source: k, maxWidth: 2000, maxHeight: 2000, imageQuality: 85);
    if (x == null) return;
    final b = await x.readAsBytes();
    await _gonder(x.name.isEmpty ? 'fatura.jpg' : x.name, b);
  }

  Future<void> _dosya() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'], withData: true);
    final f = r?.files.firstOrNull;
    if (f == null || f.bytes == null) return;
    await _gonder(f.name, f.bytes!);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final s = _sonuc;
    final k = liste(s?['kalemler']);
    return KSayfa(
      baslik: 'Fatura OCR (AI)',
      ikon: Icons.document_scanner_outlined,
      govde: KGovde(maxGenislik: 900, children: [
        KKart(
          renk: t.mor1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Faturayı yükleyin, AI kalemleri çıkarsın', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
            Text('JPG / PNG / WEBP / PDF, en fazla 8 MB. Rakamları mutlaka faturayla karşılaştırın.', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              KButon('Fotoğraf çek', ikon: Icons.photo_camera_outlined, yukleniyor: _okunuyor, onTap: () => _foto(ImageSource.camera)),
              KButon('Galeriden seç', ikon: Icons.photo_library_outlined, ikincil: true, onTap: _okunuyor ? null : () => _foto(ImageSource.gallery)),
              KButon('PDF / dosya seç', ikon: Icons.upload_file, ikincil: true, onTap: _okunuyor ? null : _dosya),
            ]),
            if (_okunuyor) Padding(padding: const EdgeInsets.only(top: 10), child: Text('${_dosyaAdi ?? 'Dosya'} AI ile okunuyor… birkaç saniye', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w600))),
          ]),
        ),
        if (s == null && !_okunuyor)
          const KBos(baslik: 'Henüz fatura okunmadı', aciklama: 'Yukarıdan fatura fotoğrafı çekin ya da PDF seçin; tedarikçi, tarih, kalemler ve toplamlar burada görünür.', ikon: Icons.document_scanner_outlined),
        if (s != null) ...[
          KBaslik('Okunan Fatura', ikon: Icons.check_circle_outline, renk: t.yesil),
          KKpiIzgara([
            KKpi(etiket: 'Tedarikçi', deger: metinOku(s['tedarikci'], '—'), renk: t.mor1),
            KKpi(etiket: 'Tarih', deger: metinOku(s['tarih'], '—'), renk: t.mavi),
            KKpi(etiket: 'Genel Toplam', deger: tl(s['genel_toplam']), renk: t.yesil),
          ]),
          if (k.isEmpty)
            const KBos(baslik: 'Kalem okunamadı', aciklama: 'Daha net bir fotoğrafla tekrar deneyin.')
          else
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KTablo(basliklar: const ['Ürün', 'Miktar', 'Birim Fiyat', 'Tutar'], sagaYasla: const {1, 2, 3}, satirlar: [
                  for (final x in k) [metinOku(x['urun'], '—'), '${sayiYaz(x['miktar'])} ${metinOku(x['birim'])}', tl(x['birim_fiyat']), tl(x['tutar'])],
                ]),
                const Divider(),
                SaDeger('Ara Toplam', tl(s['ara_toplam'])),
                SaDeger('KDV', tl(s['kdv'])),
                SaDeger('GENEL TOPLAM', tl(s['genel_toplam']), kalin: true, renk: t.mor1),
              ]),
            ),
          const SaBilgi('AI okuması; rakamları faturayla karşılaştırın. Faturayı sisteme işlemek için Mal Kabul (fotoğraftan doldur) ya da Fatura Eşleştir ekranını kullanın.', ikon: Icons.lightbulb_outline),
        ],
      ]),
    );
  }
}
