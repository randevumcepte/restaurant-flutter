import '../../kopru/ekran_kayit.dart';
import 'ai_eylem_log_screen.dart';
import 'cihaz_bagli_screen.dart';
import 'hareket_log_screen.dart';
import 'sebep_yonetimi_screen.dart';
import 'yazici_ayarlari_screen.dart';

/// Operasyon › Sistem ayarları & loglar (web Ayarlar & Entegrasyon grubundan)
void kayitOperasyonSistem() {
  EkranKayit.tam('/sebep-yonetimi', (u, a) => const OpSebepYonetimiScreen());
  EkranKayit.tam('/hareketler', (u, a) => const OpHareketlerScreen());
  EkranKayit.tam('/ai-eylem-log', (u, a) => const OpAiEylemLogScreen());
  EkranKayit.tam('/bagli-cihazlar', (u, a) => const OpBagliCihazlarScreen());
  EkranKayit.tam('/yazici-ayarlari', (u, a) => const OpYaziciAyarlariScreen());
}
