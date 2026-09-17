import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// Bağlı Cihazlar — ResteOS çalışan cihazların canlı durumu (heartbeat: yeşil=bağlı,
/// kırmızı=kopuk) + Yazarkasa (OKC) durumu. 10 sn'de bir otomatik yenilenir.
class BagliCihazlarScreen extends StatefulWidget {
  const BagliCihazlarScreen({super.key});
  @override
  State<BagliCihazlarScreen> createState() => _BagliCihazlarScreenState();
}

class _BagliCihazlarScreenState extends State<BagliCihazlarScreen> {
  List cihazlar = [];
  Map? yazarkasa;
  bool loading = true;
  Timer? _oto;

  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _amber = Color(0xFFF59E0B);
  static const _gri = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _yukle();
    _oto = Timer.periodic(const Duration(seconds: 10), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() { _oto?.cancel(); super.dispose(); }

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() => loading = true);
    try {
      final res = await Api.cihazlar(auth.token!);
      if (!mounted) return;
      setState(() {
        cihazlar = (res['cihazlar'] as List?) ?? [];
        yazarkasa = res['yazarkasa'] as Map?;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  IconData _tipIkon(String tip) {
    switch (tip) {
      case 'telefon': return Icons.smartphone;
      case 'tablet': return Icons.tablet_android;
      case 'kds': return Icons.tv;
      case 'yazarkasa': return Icons.point_of_sale;
      default: return Icons.computer;
    }
  }

  Color _ykRenk(String durum) {
    switch (durum) {
      case 'online': return _yesil;
      case 'hata': return _kirmizi;
      case 'test':
      case 'bekliyor': return _amber;
      default: return _gri;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final onlineSayi = cihazlar.where((c) => (c as Map)['online'] == true).length;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Bağlı Cihazlar', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub)), const MenuHamburger()],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : RefreshIndicator(
              onRefresh: () => _yukle(), color: t.mor1, backgroundColor: t.card,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                // Canlı bilgi
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: _yesil, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$onlineSayi cihaz çevrimiçi', style: TextStyle(color: t.sub, fontSize: 12)),
                  const Spacer(),
                  Text('10 sn\'de bir yenilenir', style: TextStyle(color: t.sub, fontSize: 11)),
                ]),
                const SizedBox(height: 12),

                // YAZARKASA
                if (yazarkasa != null) ...[
                  _baslik(t, '🧾 Yazarkasa (OKC)'),
                  _yazarkasaKart(t, yazarkasa!),
                  const SizedBox(height: 18),
                ],

                // RESTEOS CIHAZLARI
                _baslik(t, '📱 ResteOS Cihazları', sayi: cihazlar.length),
                if (cihazlar.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Center(child: Text('Henüz sinyal gönderen cihaz yok.\nBir cihazda ResteOS açık olduğunda burada görünür.', textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13, height: 1.5))))
                else
                  for (final c in cihazlar) _cihazKart(t, c as Map),
                const SizedBox(height: 30),
              ]),
            ),
    );
  }

  Widget _baslik(TemaProvider t, String s, {int? sayi}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(s, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          if (sayi != null) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)), child: Text('$sayi', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold))),
          ],
        ]),
      );

  Widget _cihazKart(TemaProvider t, Map c) {
    final online = c['online'] == true;
    final renk = online ? _yesil : _kirmizi;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: renk.withValues(alpha: 0.35))),
      child: Row(children: [
        Stack(alignment: Alignment.bottomRight, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)), child: Icon(_tipIkon(c['tip'].toString()), color: t.sub2, size: 24)),
          Container(width: 13, height: 13, decoration: BoxDecoration(color: renk, shape: BoxShape.circle, border: Border.all(color: t.card, width: 2))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['ad'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${c['platform'] ?? ''}${c['ip'] != null && c['ip'].toString().isNotEmpty ? ' · ${c['ip']}' : ''}', style: TextStyle(color: t.sub, fontSize: 11.5)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(online ? 'Bağlı' : 'Kopuk', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 3),
          Text('${c['son_gorulme']}', style: TextStyle(color: t.sub, fontSize: 10.5)),
        ]),
      ]),
    );
  }

  Widget _yazarkasaKart(TemaProvider t, Map yk) {
    final durum = yk['durum'].toString();
    final renk = _ykRenk(durum);
    final aktif = yk['aktif'] == true;
    final etiket = {'online': 'Bağlı', 'hata': 'HATA', 'test': 'Test/Simülasyon', 'bekliyor': 'Aktif · fiş yok', 'kapali': 'Kapalı'}[durum] ?? durum;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: renk.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Stack(alignment: Alignment.bottomRight, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.point_of_sale, color: renk, size: 24)),
            Container(width: 13, height: 13, decoration: BoxDecoration(color: renk, shape: BoxShape.circle, border: Border.all(color: t.card, width: 2))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Yazarkasa${yk['marka'] != null && yk['marka'].toString().isNotEmpty ? ' · ${yk['marka']}' : ''}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            if (aktif && yk['ip'] != null && yk['ip'].toString().isNotEmpty)
              Text('IP: ${yk['ip']}${yk['port'] != null && yk['port'].toString().isNotEmpty ? ':${yk['port']}' : ''}', style: TextStyle(color: t.sub, fontSize: 11.5)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(etiket, style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Text(yk['mesaj'].toString(), style: TextStyle(color: t.sub2, fontSize: 12.5, height: 1.3)),
        if (yk['son_fis'] != null) ...[
          const SizedBox(height: 4),
          Text('Son mali fiş: ${yk['son_fis']}', style: TextStyle(color: t.sub, fontSize: 11)),
        ],
      ]),
    );
  }
}
