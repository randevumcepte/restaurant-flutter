import '../../kopru/ekran_kayit.dart';
import '../../screens/demirbas_screen.dart';
import '../../screens/etiket_merkezi_screen.dart';
import 'alerjen_screen.dart';
import 'barkod_screen.dart';
import 'mutfak_defteri_screen.dart';
import 'parti_takip_screen.dart';
import 'recete_screen.dart';
import 'sayim_screen.dart';
import 'stok_hub_screen.dart';
import 'stok_malzeme_screen.dart';
import 'tedarikci_analiz_screen.dart';
import 'tedarikci_screen.dart';
import 'uretim_plani_screen.dart';
import 'uretim_riski_screen.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
void kayitStok() {
  // Stok & malzeme
  EkranKayit.tam('/stok', (u, a) => const StokHubScreen());
  EkranKayit.tam('/stok/malzeme', (u, a) => const StokMalzemeScreen());
  EkranKayit.tam('/sayim', (u, a) => const SayimScreen());
  EkranKayit.tam('/sayim/gecmis', (u, a) => const SayimGecmisScreen());
  EkranKayit.tam('/parti-takip', (u, a) => const PartiTakipScreen());
  // Üretim & reçete
  EkranKayit.tam('/recete', (u, a) => const ReceteScreen());
  EkranKayit.tam('/uretim-riski', (u, a) => const UretimRiskiScreen());
  EkranKayit.tam('/uretim-plani', (u, a) => const UretimPlaniScreen());
  EkranKayit.tam('/mutfak-defteri', (u, a) => const MutfakDefteriScreen());
  EkranKayit.tam('/alerjen', (u, a) => const AlerjenScreen());
  // Barkod & etiket
  EkranKayit.tam('/barkod', (u, a) => const BarkodScreen());
  EkranKayit.tam('/barkod-etiket/barkod', (u, a) => const BarkodUretScreen());
  // Barkod & Etiket Merkezi: mevcut yerel ekran web ile aynı uçları kullanıyor (ürün etiketi · tartılı · raf kartı · ayarlar)
  EkranKayit.onek('/barkod-etiket', (u, a) => const EtiketMerkeziScreen());
  // Demirbaş: mevcut yerel ekran (liste · bul/okut · detay/zimmet/bakım/durum · sayım · etiket ayarı) web ile aynı uçlar
  EkranKayit.onek('/demirbas', (u, a) => const DemirbasScreen());
  // Tedarikçi
  EkranKayit.tam('/tedarikci', (u, a) => const TedarikciScreen());
  EkranKayit.tam('/tedarikci-detay', (u, a) => TedarikciDetayScreen(url: u));
  EkranKayit.tam('/tedarikci-karne', (u, a) => const TedarikciKarneScreen());
  EkranKayit.tam('/satinalma-analiz', (u, a) => const SatinalmaAnalizScreen());
}
