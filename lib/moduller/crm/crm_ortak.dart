import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';

/// CRM / Pazarlama modülünün ortak yardımcıları.

/// Web'deki bir bağlantıyı (ör. '/crm-sohbet', '/sadakat') uygulama içinde aç — kayıtlı yerel ekran ya da genel görünüm.
void crmSayfaAc(BuildContext context, String url, String ad) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));
}

/// Metni panoya kopyala + bildirim
Future<void> crmKopyala(BuildContext context, String metin, {String mesaj = 'Kopyalandı.'}) async {
  await Clipboard.setData(ClipboardData(text: metin));
  if (context.mounted) kToast(context, mesaj);
}

/// Oturumdaki kişi sahip/müdür mü (web'de bazı uçlar yalnız bu rollere açık)
bool crmPatronMu(BuildContext context) => context.read<AuthProvider>().patron;

/// Müşteri sağlık durumu (web musteri_360 ile aynı renk/ad/ikon)
const Map<String, Color> kCrmDurumRenk = {
  'vip': Color(0xFFF6A623), 'aktif': Color(0xFF2FBE94), 'risk': Color(0xFFF59E0B),
  'kayip': Color(0xFFF5576C), 'uyuyan': Color(0xFF64748B), 'yeni': Color(0xFF5B8DEF),
};
const Map<String, String> kCrmDurumAd = {
  'vip': 'VIP', 'aktif': 'Aktif', 'risk': 'Riskli', 'kayip': 'Kayıp', 'uyuyan': 'Uyuyan', 'yeni': 'Yeni',
};
const Map<String, IconData> kCrmDurumIkon = {
  'vip': Icons.workspace_premium_outlined, 'aktif': Icons.how_to_reg_outlined, 'risk': Icons.warning_amber_outlined,
  'kayip': Icons.person_off_outlined, 'uyuyan': Icons.bedtime_outlined, 'yeni': Icons.person_add_outlined,
};

/// Baş harf avatarı
class CrmAvatar extends StatelessWidget {
  final String ad;
  final Color renk;
  final double boyut;
  const CrmAvatar(this.ad, {super.key, required this.renk, this.boyut = 42});

  @override
  Widget build(BuildContext context) {
    final h = ad.trim().isEmpty ? 'M' : ad.trim().substring(0, 1).toUpperCase();
    return Container(
      width: boyut,
      height: boyut,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
      child: Text(h, style: TextStyle(color: Colors.white, fontSize: boyut * .4, fontWeight: FontWeight.bold)),
    );
  }
}

/// Uzun açıklama / bilgi notu kutusu
class CrmNot extends StatelessWidget {
  final String metin;
  final IconData ikon;
  final Color? renk;
  const CrmNot(this.metin, {super.key, this.ikon = Icons.info_outline, this.renk});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final r = renk ?? t.amber;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: r.withValues(alpha: .09), borderRadius: BorderRadius.circular(12), border: Border.all(color: r.withValues(alpha: .25))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ikon, size: 18, color: r),
        const SizedBox(width: 8),
        Expanded(child: Text(metin, style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45))),
      ]),
    );
  }
}

/// JSON uçlarında web bazen {success:true} bazen {ok:1} döner — ikisini de başarı say.
bool crmBasari(Map<String, dynamic> j) => j['ok'] == 1 || j['ok'] == true || j['success'] == true || j['success'] == 1;
