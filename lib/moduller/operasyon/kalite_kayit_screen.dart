import 'package:flutter/material.dart';
import 'kalite_it_defter.dart';

/// Web /kalite-kayit?tip=… — Kalite kayıt defteri (şahit numune, ilaçlama, kalibrasyon, tedarikçi belgesi, denetim).
/// Uçlar: GET /kalite-kayit?tip= · POST /kalite-kayit/ekle · POST /kalite-kayit/sil
const KaliteItDefterAyar kKaliteKayitAyar = KaliteItDefterAyar(
  baslik: 'Kalite Kayıt Defteri',
  ikon: Icons.fact_check_outlined,
  yol: '/kalite-kayit',
  ekleYol: '/kalite-kayit/ekle',
  silYol: '/kalite-kayit/sil',
  varsayilanTip: 'numune',
  tipler: {
    'numune': KaliteItDefterTip('Şahit Numune', Icons.science_outlined, Color(0xFF7C3AED), 'Örn: Akşam menüsü – tavuk sote', 'Saklama yeri / saat',
        'İmha tarihi (72 saat sonra)', "Her öğün servis edilen yemeklerden 100-150 g numune alınır, 72 saat +4 °C'de saklanır. Yasal zorunluluk."),
    'ilaclama': KaliteItDefterTip('Haşere / İlaçlama', Icons.pest_control_outlined, Color(0xFFEA580C), 'Örn: Aylık genel ilaçlama', 'İlaçlama firması',
        'Sonraki ilaçlama tarihi', 'Lisanslı firma ile periyodik ilaçlama + uygunluk belgesi. Denetimde sorulur.'),
    'kalibrasyon': KaliteItDefterTip('Kalibrasyon', Icons.straighten, Color(0xFF0EA5E9), 'Örn: Buzdolabı termometresi', 'Sonuç / sapma',
        'Sonraki kalibrasyon tarihi', 'Termometre ve teraziler periyodik kalibre edilmeli; ölçümlerin güvenilirliği için.'),
    'tedarikci_belge': KaliteItDefterTip('Tedarikçi Belgesi', Icons.description_outlined, Color(0xFF16A34A), 'Örn: ABC Gıda – İşletme Kayıt Belgesi', 'Belge no / firma',
        'Belge geçerlilik sonu', 'Tedarikçilerin işletme kayıt / gıda güvenliği (ISO 22000) belgelerini izle; süresi dolanı yenilet.'),
    'denetim': KaliteItDefterTip('Denetim / Teftiş', Icons.verified_user_outlined, Color(0xFF16A34A), 'Örn: Tarım Bakanlığı rutin denetim', 'Sonuç / puan / denetçi',
        'Sonraki denetim (planlı)', 'Resmi denetim ve iç teftiş geçmişi; bulgular ve kapanışları kaydet.'),
  },
);

class KaliteKayitScreen extends StatelessWidget {
  final String tip;
  const KaliteKayitScreen({super.key, this.tip = 'numune'});

  @override
  Widget build(BuildContext context) => KaliteItDefterEkran(ayar: kKaliteKayitAyar, tip: tip);
}
