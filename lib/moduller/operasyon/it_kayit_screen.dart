import 'package:flutter/material.dart';
import 'kalite_it_defter.dart';

/// Web /it-kayit?tip=… — IT kayıt / arıza defteri (arıza-destek, lisans-domain-SSL, yedek, KVKK, bakım).
/// Uçlar: GET /it-kayit?tip= · POST /it-destek/ekle · POST /it-destek/durum (kapat) · POST /it-destek/sil
const KaliteItDefterAyar kItKayitAyar = KaliteItDefterAyar(
  baslik: 'IT Kayıt / Arıza Defteri',
  ikon: Icons.dns_outlined,
  yol: '/it-kayit',
  ekleYol: '/it-destek/ekle',
  silYol: '/it-destek/sil',
  kapatYol: '/it-destek/durum',
  varsayilanTip: 'ariza',
  tipler: {
    'ariza': KaliteItDefterTip('Arıza / Destek', Icons.build_outlined, Color(0xFFF97316), 'Örn: Kasa yazıcısı çıktı vermiyor', 'Cihaz / konum', 'Hedef çözüm tarihi',
        'Arıza/talep açıldığında kaydet; çözülünce "Kapat" ile kapat. Tekrarlayan arıza kök neden analizi gerektirir.',
        oncelik: true, kapat: true),
    'lisans': KaliteItDefterTip('Lisans / Domain / SSL', Icons.verified_outlined, Color(0xFF4F46E5), 'Örn: restoran.com SSL sertifikası', 'Sağlayıcı / no',
        'Bitiş / yenileme tarihi', 'Domain, SSL sertifikası ve yazılım lisanslarını bitiş tarihiyle izle; süresi dolmadan yenile (kesinti/erişim kaybı olmasın).'),
    'yedek': KaliteItDefterTip('Yedekleme', Icons.backup_outlined, Color(0xFFA855F7), 'Örn: Günlük veritabanı yedeği', 'Konum / boyut', 'Sonraki yedek (planlı)',
        'Her yedekten sonra kaydet (tarih = alındığı gün). 7 günden eski yedek brifingde uyarı verir. Ara sıra geri yükleme testi yap.'),
    'kvkk': KaliteItDefterTip('KVKK / Veri Güvenliği', Icons.policy_outlined, Color(0xFF14B8A6), 'Örn: Aydınlatma metni yayınlandı', 'Sorumlu / referans',
        'Gözden geçirme tarihi', 'Aydınlatma metni, veri işleme envanteri, saklama/imha ve varsa ihlal kayıtları. Kişisel veri (müşteri/personel) işleyen her işletme için zorunlu.'),
    'bakim': KaliteItDefterTip('Periyodik Bakım', Icons.handyman_outlined, Color(0xFF0EA5E9), 'Örn: POS cihazları genel temizlik/bakım', 'Firma / teknisyen',
        'Sonraki bakım tarihi', 'Donanım (POS/yazıcı/ağ) periyodik bakım ve güncelleme kayıtları; arızayı önceden önler.'),
  },
);

class ItKayitScreen extends StatelessWidget {
  final String tip;
  const ItKayitScreen({super.key, this.tip = 'ariza'});

  @override
  Widget build(BuildContext context) => KaliteItDefterEkran(ayar: kItKayitAyar, tip: tip);
}
