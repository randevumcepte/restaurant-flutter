import '../../kopru/ekran_kayit.dart';
import 'ajanda_screen.dart';
import 'bildirim_merkezi_screen.dart';
import 'departman_asistan_screen.dart';
import 'departman_brief_screen.dart';
import 'patron_ai_screen.dart';
import 'profilim_screen.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
void kayitAi() {
  // Departman brifingi — tek ekran, ?dep=… parametresine göre (mutfak, soguk_mutfak, pastane, kasap, satinalma, ik, finans…)
  EkranKayit.onek('/departman-brief', (u, a) => DepartmanBriefScreen(url: u, baslik: a));

  // AI departman asistanları — tek sohbet ekranı (sayfa verisindeki sorUrl / uygulaUrl ile konuşur)
  for (final y in const [
    '/departman-asistan',
    '/muhasebe-sohbet',
    '/pazarlama-sohbet',
    '/satis-sohbet',
    '/crm-sohbet',
    '/kalite-sohbet',
    '/it-sohbet',
    '/ik-asistan',
    '/patron-ai-sohbet',
  ]) {
    EkranKayit.tam(y, (u, a) => DepartmanAsistanScreen(url: u, baslik: a));
  }

  // Patron AI komuta merkezi (?tip=sabah|aksam, ?gm=1)
  EkranKayit.tam('/patron-ai', (u, a) => PatronAiScreen(url: u, baslik: a));

  // Ajanda & Hatırlatıcı (herkese açık)
  EkranKayit.tam('/ajanda', (u, a) => const AjandaScreen());

  // Profilim (menüde yok; sağ üst avatardan açılır)
  EkranKayit.tam('/profilim', (u, a) => const ProfilimScreen());

  // Bildirim merkezi (zil)
  EkranKayit.tam('/bildirimler', (u, a) => const BildirimMerkeziScreen());
}
