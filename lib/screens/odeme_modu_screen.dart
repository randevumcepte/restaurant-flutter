import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Ödeme Modu & Kaçak Önleme (Sahip/Müdür).
/// mod: post_pay (klasik) | on_odeme (ön ödemeli) | acik_kart (açık hesap + kart)
class OdemeModuScreen extends StatefulWidget {
  const OdemeModuScreen({super.key});
  @override
  State<OdemeModuScreen> createState() => _OdemeModuScreenState();
}

class _OdemeModuScreenState extends State<OdemeModuScreen> {
  String mod = 'post_pay';
  bool kacakAktif = true;
  int kacakDk = 90;
  bool loading = true, kaydediyor = false, duzenleyebilir = false;

  TemaProvider get _t => context.watch<TemaProvider>();

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.odemeModu(auth.token!);
      if (!mounted) return;
      setState(() {
        mod = res['mod']?.toString() ?? 'post_pay';
        kacakAktif = res['kacak_aktif'] == true;
        kacakDk = (res['kacak_dk'] is num) ? (res['kacak_dk'] as num).toInt() : int.tryParse('${res['kacak_dk']}') ?? 90;
        duzenleyebilir = res['duzenleyebilir'] == true;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _kaydet() async {
    final auth = context.read<AuthProvider>();
    setState(() => kaydediyor = true);
    try {
      final res = await Api.odemeModuKaydet(auth.token!, mod: mod, kacakAktif: kacakAktif, kacakDk: kacakDk);
      if (!mounted) return;
      if (res['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi ✓')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedilemedi')));
    } finally {
      if (mounted) setState(() => kaydediyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card,
        elevation: 0.5,
        title: Text('Kaçak Önleme', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.ink),
        actions: const [MenuHamburger()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 40), children: [
              _baslik(t, 'Ödeme Modu'),
              _mod(t, 'post_pay', '🍽️', 'Klasik (servis sonrası öde)', 'Müşteri yer, sonra öder. Aktif koruma: aşağıdaki Kaçak Radarı.'),
              _mod(t, 'on_odeme', '💳', 'Ön Ödemeli', 'Sipariş önce ödenir, sonra mutfağa düşer. Kaçak = sıfır.', kilit: true),
              _mod(t, 'acik_kart', '🔐', 'Açık Hesap + Kart', 'QR’da kart bağlanır, çıkışta otomatik çekilir.', kilit: true),

              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: .12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: .4))),
                child: Text(
                  '🔒 “Ön Ödemeli” ve “Açık Hesap + Kart”, canlı ödeme (Iyzico/PayTR) devreye girince tam aktifleşir. Şu an her modda aktif koruma: Kaçak Radarı.',
                  style: TextStyle(color: t.ink, fontSize: 12.5, height: 1.35),
                ),
              ),

              _baslik(t, 'Kaçak Radarı'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                child: Column(children: [
                  SwitchListTile(
                    value: kacakAktif,
                    activeColor: const Color(0xFF22C55E),
                    contentPadding: EdgeInsets.zero,
                    title: Text('Uzun süredir açık + ödenmemiş masaları uyar', style: TextStyle(color: t.ink, fontSize: 14.5)),
                    subtitle: Text('Garson ekranında kırmızı “ödemeden ayrılma riski” kartı gösterilir.', style: TextStyle(color: t.sub2, fontSize: 12)),
                    onChanged: (v) => setState(() => kacakAktif = v),
                  ),
                  if (kacakAktif) ...[
                    Divider(color: t.line, height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        Text('Uyarı süresi', style: TextStyle(color: t.sub, fontSize: 13.5)),
                        Expanded(
                          child: Slider(
                            value: kacakDk.toDouble().clamp(15, 240),
                            min: 15, max: 240, divisions: 15,
                            activeColor: const Color(0xFF4F46E5),
                            label: '$kacakDk dk',
                            onChanged: (v) => setState(() => kacakDk = v.round()),
                          ),
                        ),
                        Text('$kacakDk dk', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 2),
                child: Text('Örn: 90 dk’dan uzun süredir açık ve ödenmemiş bir masa varsa garson uyarılır. Süreyi restoranın ortalama oturma süresine göre ayarla.', style: TextStyle(color: t.sub2, fontSize: 12, height: 1.35)),
              ),

              const SizedBox(height: 18),
              if (duzenleyebilir)
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: kaydediyor ? null : _kaydet,
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: kaydediyor
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                Text('Bu ayarları yalnızca işletme sahibi/müdürü değiştirebilir.', style: TextStyle(color: t.sub)),
            ]),
    );
  }

  Widget _baslik(TemaProvider t, String s) => Padding(padding: const EdgeInsets.fromLTRB(2, 18, 0, 8), child: Text(s, style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w700)));

  Widget _mod(TemaProvider t, String v, String ik, String ad, String aciklama, {bool kilit = false}) {
    final secili = mod == v;
    return GestureDetector(
      onTap: duzenleyebilir ? () => setState(() => mod = v) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: secili ? const Color(0xFF4F46E5) : t.line, width: secili ? 2 : 1),
        ),
        child: Row(children: [
          Text(ik, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
                if (kilit) Padding(padding: const EdgeInsets.only(left: 6), child: Text('🔒', style: TextStyle(fontSize: 12, color: t.sub2))),
              ]),
              const SizedBox(height: 3),
              Text(aciklama, style: TextStyle(color: t.sub2, fontSize: 12, height: 1.3)),
            ]),
          ),
          Icon(secili ? Icons.radio_button_checked : Icons.radio_button_off, color: secili ? const Color(0xFF4F46E5) : t.sub2, size: 22),
        ]),
      ),
    );
  }
}
