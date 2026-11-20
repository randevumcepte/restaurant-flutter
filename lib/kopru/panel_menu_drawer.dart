import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../screens/lan_ayar_screen.dart';
import '../screens/mesai_qr_screen.dart';
import '../screens/santral_ses_screen.dart';
import '../screens/dahili_yonetim_screen.dart';
import '../screens/freepbx_ayar_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/canli_uyari.dart';
import 'ekran_kayit.dart';
import 'panel_menu.dart';

/// Telefon çekmece menüsü: web menüsünün aynısı (sunucudan) + cihaza özgü ayarlar + tema + çıkış.
class PanelMenuDrawer extends StatelessWidget {
  final void Function(Widget ekran) onGit;
  const PanelMenuDrawer({super.key, required this.onGit});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    void kapatGit(Widget w) {
      Navigator.of(context).pop();
      onGit(w);
    }

    return Drawer(
      backgroundColor: t.card,
      width: 320,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          InkWell(
            onTap: () => kapatGit(EkranKayit.uret('/profilim', 'Profilim')), // avatar → Profilim (web ile aynı)
            child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi])),
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white.withValues(alpha: .22),
                child: Text((auth.ad ?? '?').trim().isEmpty ? '?' : (auth.ad ?? '?').trim()[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.ad ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text([auth.departmanAd, auth.sube].whereType<String>().where((s) => s.isNotEmpty).join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 12.5)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ]),
          ),
          ),
          Expanded(child: PanelMenuListesi(onAc: (o) => kapatGit(EkranKayit.uret(o.url, o.ad)))),
          Divider(height: 1, color: t.line),
          CihazMenusu(onGit: kapatGit),
          ListTile(
            dense: true,
            leading: Icon(t.koyu ? Icons.light_mode : Icons.dark_mode, color: t.gold, size: 21),
            title: Text(t.koyu ? 'Açık moda geç' : 'Koyu moda geç', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
            onTap: () => context.read<TemaProvider>().cevir(),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout, color: Color(0xFFF87171), size: 21),
            title: const Text('Çıkış', style: TextStyle(color: Color(0xFFF87171), fontSize: 14, fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).pop();
              PanelMenuServisi.ben.temizle();
              context.read<AuthProvider>().cikis();
            },
          ),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

/// Web'de olmayan, BU CİHAZA özgü ayarlar (LAN kasa sunucusu, kasa mesai QR'ı, santral telefon ayarları).
class CihazMenusu extends StatelessWidget {
  final void Function(Widget ekran) onGit;
  const CihazMenusu({super.key, required this.onGit});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final patron = auth.rol == 'sahip' || auth.rol == 'mudur';
    final santral = patron || auth.yetkiVar('gor_santral');
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Icon(Icons.devices_other_outlined, color: t.sub2, size: 21),
        title: Text('Bu cihaz', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
        iconColor: t.sub,
        collapsedIconColor: t.sub,
        children: [
          _oge(t, Icons.lan_outlined, 'LAN / Kasa Sunucu', () => onGit(const LanAyarScreen())),
          const _CanliUyariAnahtar(),
          if (patron) _oge(t, Icons.qr_code_2, 'Kasa Mesai QR', () => onGit(const MesaiQrScreen())),
          if (santral) _oge(t, Icons.graphic_eq, 'Santral — Ses', () => onGit(const SantralSesScreen())),
          if (santral) _oge(t, Icons.dialpad, 'Dahili Yönetimi', () => onGit(const DahiliYonetimScreen())),
          if (santral) _oge(t, Icons.settings_input_antenna, 'FreePBX API', () => onGit(const FreepbxAyarScreen())),
        ],
      ),
    );
  }

  Widget _oge(TemaProvider t, IconData i, String ad, VoidCallback onTap) => ListTile(
        dense: true,
        contentPadding: const EdgeInsets.only(left: 30, right: 16),
        leading: Icon(i, size: 20, color: t.sub2),
        title: Text(ad, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
        onTap: onTap,
      );
}

/// Canlı uyarılar (çağrı / servise hazır / yeni sipariş) bu cihazda açık mı — patron/müdürde varsayılan kapalı
class _CanliUyariAnahtar extends StatefulWidget {
  const _CanliUyariAnahtar();
  @override
  State<_CanliUyariAnahtar> createState() => _CanliUyariAnahtarState();
}

class _CanliUyariAnahtarState extends State<_CanliUyariAnahtar> {
  bool? _acik;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      final v = sp.getString(CanliUyariDinleyici.tercihAnahtar);
      if (!mounted) return;
      final a = context.read<AuthProvider>();
      final patron = a.rol == 'sahip' || a.rol == 'mudur';
      setState(() => _acik = v == null ? !patron : v == 'acik');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 30, right: 10),
      secondary: Icon(Icons.notifications_active_outlined, size: 20, color: t.sub2),
      title: Text('Canlı uyarılar', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
      subtitle: Text('Çağrı, servise hazır, yeni sipariş', style: TextStyle(color: t.sub, fontSize: 11.5)),
      value: _acik ?? false,
      activeThumbColor: t.mor1,
      onChanged: _acik == null ? null : (v) { setState(() => _acik = v); canliUyariTercihKaydet(v ? 'acik' : 'kapali'); },
    );
  }
}
