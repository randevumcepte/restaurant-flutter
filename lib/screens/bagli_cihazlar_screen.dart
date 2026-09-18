import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../services/yazici_servisi.dart';
import 'menu_hamburger.dart';

/// Bağlı Cihazlar — İKİ katman:
///  1) Tanımlı Cihazlar: patron elle ekler (yazıcı/yazarkasa/terminal/çekmece…), IP/port/marka girer.
///     Bağlantı testi LAN'da (Socket) İSTEMCİDE yapılır — sunucu bulutta, yerel IP'ye erişemez.
///  2) Çevrimiçi Cihazlar: ResteOS çalışan cihazlar (heartbeat: yeşil=bağlı, kırmızı=kopuk).
/// + Yazarkasa (OKC) durumu. 10 sn'de bir yenilenir. Şimdilik sınırsız (ileride paket limiti).
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
  final Map<String, bool?> _testSonuc = {}; // 'ip:port' -> true/false/null(test ediliyor)

  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _amber = Color(0xFFF59E0B);
  static const _gri = Color(0xFF94A3B8);

  // tip -> etiket + ikon
  static const List<Map<String, dynamic>> _tipler = [
    {'k': 'yazici', 'ad': 'Yazıcı (fiş/mutfak)', 'ikon': Icons.print},
    {'k': 'yazarkasa', 'ad': 'Yazarkasa (ÖKC)', 'ikon': Icons.point_of_sale},
    {'k': 'terminal', 'ad': 'Ödeme Terminali (POS)', 'ikon': Icons.credit_card},
    {'k': 'cekmece', 'ad': 'Kasa Çekmecesi', 'ikon': Icons.inbox_outlined},
    {'k': 'bilgisayar', 'ad': 'Bilgisayar / Kasa', 'ikon': Icons.computer},
    {'k': 'kds', 'ad': 'Mutfak Ekranı (KDS)', 'ikon': Icons.tv},
    {'k': 'barkod', 'ad': 'Barkod Okuyucu', 'ikon': Icons.qr_code_scanner},
    {'k': 'el_terminali', 'ad': 'El Terminali', 'ikon': Icons.pan_tool_alt_outlined},
    {'k': 'tablet', 'ad': 'Tablet', 'ikon': Icons.tablet_android},
    {'k': 'telefon', 'ad': 'Telefon', 'ikon': Icons.smartphone},
    {'k': 'diger', 'ad': 'Diğer', 'ikon': Icons.devices_other},
  ];
  Map<String, dynamic> _tipBilgi(String k) => _tipler.firstWhere((e) => e['k'] == k, orElse: () => _tipler.last);
  IconData _tipIkon(String k) => _tipBilgi(k)['ikon'] as IconData;
  String _tipAd(String k) => _tipBilgi(k)['ad'] as String;

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

  Color _ykRenk(String durum) {
    switch (durum) {
      case 'online': return _yesil;
      case 'hata': return _kirmizi;
      case 'test':
      case 'bekliyor': return _amber;
      default: return _gri;
    }
  }

  void _snack(String m, [Color c = _gri, bool uzun = false]) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, duration: Duration(seconds: uzun ? 4 : 2)));
  }

  // LAN üstünden TCP bağlantı testi (istemcide — sunucu yerel IP'ye erişemez).
  Future<void> _baglantiTest(String ip, int port) async {
    final anahtar = '$ip:$port';
    setState(() => _testSonuc[anahtar] = null);
    bool ok = false;
    Socket? s;
    try {
      s = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
      ok = true;
    } catch (_) {
      ok = false;
    } finally {
      try { s?.destroy(); } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _testSonuc[anahtar] = ok);
    _snack(ok ? '✓ Bağlantı başarılı ($anahtar)' : '✗ Ulaşılamadı ($anahtar) — aynı ağda mı, IP doğru mu?', ok ? _yesil : _kirmizi, true);
  }

  Future<void> _yaziciYap(Map c) async {
    final y = YaziciServisi();
    await y.yukle();
    y.ip = (c['ip'] ?? '').toString();
    y.port = int.tryParse((c['port'] ?? '').toString()) ?? 9100;
    await y.kaydet();
    _snack('✓ "${c['ad']}" baskı yazıcısı olarak ayarlandı', _yesil);
  }

  Future<void> _sil(Map c) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cihazı sil'),
        content: Text('"${c['ad']}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: _kirmizi))),
        ],
      ),
    );
    if (onay != true || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      await Api.cihazSil(auth.token!, (c['id'] as num).toInt());
      _snack('Cihaz silindi');
      _yukle(sessiz: true);
    } catch (_) { _snack('Silinemedi', _kirmizi); }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final manuel = cihazlar.where((c) => (c as Map)['manuel'] == true).toList();
    final canli = cihazlar.where((c) => (c as Map)['manuel'] != true).toList();
    final onlineSayi = canli.where((c) => (c as Map)['online'] == true).length;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Bağlı Cihazlar', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub)), const MenuHamburger()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formAc(),
        backgroundColor: t.mor1,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Cihaz Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : RefreshIndicator(
              onRefresh: () => _yukle(), color: t.mor1, backgroundColor: t.card,
              child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 90), children: [
                // TANIMLI CIHAZLAR (manuel)
                _baslik(t, '🔌 Tanımlı Cihazlar', sayi: manuel.length),
                if (manuel.isEmpty)
                  _bosKutu(t, 'Henüz cihaz tanımlanmadı.\n"Cihaz Ekle" ile yazıcı, yazarkasa, terminal vb. ekleyip IP/port gir.')
                else
                  for (final c in manuel) _manuelKart(t, c as Map),
                const SizedBox(height: 20),

                // YAZARKASA (OKC durumu)
                if (yazarkasa != null) ...[
                  _baslik(t, '🧾 Yazarkasa (OKC)'),
                  _yazarkasaKart(t, yazarkasa!),
                  const SizedBox(height: 20),
                ],

                // CANLI (heartbeat) CIHAZLAR
                Row(children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: _yesil, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('$onlineSayi cihaz çevrimiçi', style: TextStyle(color: t.sub, fontSize: 12)),
                  const Spacer(),
                  Text('10 sn\'de bir yenilenir', style: TextStyle(color: t.sub, fontSize: 11)),
                ]),
                const SizedBox(height: 10),
                _baslik(t, '📱 Çevrimiçi Cihazlar (ResteOS)', sayi: canli.length),
                if (canli.isEmpty)
                  _bosKutu(t, 'Sinyal gönderen cihaz yok.\nBir cihazda ResteOS açık olduğunda burada görünür.')
                else
                  for (final c in canli) _canliKart(t, c as Map),
                const SizedBox(height: 20),
              ]),
            ),
    );
  }

  Widget _baslik(TemaProvider t, String s, {int? sayi}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Text(s, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          if (sayi != null) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)), child: Text('$sayi', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold))),
          ],
        ]),
      );

  Widget _bosKutu(TemaProvider t, String s) => Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Text(s, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13, height: 1.5)),
      );

  Widget _manuelKart(TemaProvider t, Map c) {
    final aktif = c['aktif'] == true;
    final tip = c['tip'].toString();
    final ip = (c['ip'] ?? '').toString();
    final port = int.tryParse((c['port'] ?? '').toString()) ?? 9100;
    final anahtar = '$ip:$port';
    final test = _testSonuc[anahtar];
    final renk = aktif ? _yesil : _gri;
    return Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: renk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(_tipIkon(tip), color: renk, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c['ad'].toString(), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(_tipAd(tip) + ((c['marka'] ?? '').toString().isNotEmpty ? ' · ${c['marka']}' : ''), style: TextStyle(color: t.sub, fontSize: 11.5)),
            if (ip.isNotEmpty) Text('IP: $ip${(c['port'] ?? '').toString().isNotEmpty ? ':${c['port']}' : ''}', style: TextStyle(color: t.sub2, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(aktif ? 'Aktif' : 'Pasif', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold))),
            if (test != null) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(test ? Icons.check_circle : Icons.cancel, size: 12, color: test ? _yesil : _kirmizi),
                const SizedBox(width: 3),
                Text(test ? 'Ulaşıldı' : 'Ulaşılamadı', style: TextStyle(color: test ? _yesil : _kirmizi, fontSize: 10.5)),
              ]),
            ] else if (_testSonuc.containsKey(anahtar)) ...[
              const SizedBox(height: 4),
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ]),
        ]),
        if ((c['notlar'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(c['notlar'].toString(), style: TextStyle(color: t.sub, fontSize: 11.5, height: 1.3)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          if (ip.isNotEmpty) _miniBtn(t, Icons.wifi_tethering, 'Test', const Color(0xFF3B82F6), () => _baglantiTest(ip, port)),
          if (ip.isNotEmpty) const SizedBox(width: 8),
          if (tip == 'yazici') _miniBtn(t, Icons.print, 'Yazıcı Yap', const Color(0xFF14B8A6), () => _yaziciYap(c)),
          if (tip == 'yazici') const SizedBox(width: 8),
          _miniBtn(t, Icons.edit_outlined, 'Düzenle', t.mor1, () => _formAc(mevcut: c)),
          const SizedBox(width: 8),
          _miniBtn(t, Icons.delete_outline, 'Sil', _kirmizi, () => _sil(c)),
        ]),
      ]),
    );
  }

  Widget _miniBtn(TemaProvider t, IconData i, String s, Color c, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9), alignment: Alignment.center,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(9), border: Border.all(color: c.withValues(alpha: 0.35))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(i, color: c, size: 15), const SizedBox(width: 4),
              Flexible(child: Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.bold))),
            ]),
          ),
        ),
      );

  Widget _canliKart(TemaProvider t, Map c) {
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
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)), child: Text(online ? 'Bağlı' : 'Kopuk', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold))),
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

  // ---- EKLE / DÜZENLE FORMU ----
  void _formAc({Map? mevcut}) {
    final t = context.read<TemaProvider>();
    final adC = TextEditingController(text: mevcut?['ad']?.toString() ?? '');
    final ipC = TextEditingController(text: mevcut?['ip']?.toString() ?? '');
    final portC = TextEditingController(text: mevcut?['port']?.toString() ?? '');
    final markaC = TextEditingController(text: mevcut?['marka']?.toString() ?? '');
    final seriC = TextEditingController(text: mevcut?['seri_no']?.toString() ?? '');
    final notC = TextEditingController(text: mevcut?['notlar']?.toString() ?? '');
    String tip = mevcut?['tip']?.toString() ?? 'yazici';
    if (!_tipler.any((e) => e['k'] == tip)) tip = 'diger';
    bool aktif = mevcut == null ? true : (mevcut['aktif'] == true);
    bool kaydediliyor = false;

    InputDecoration dek(String h) => InputDecoration(
          hintText: h, hintStyle: TextStyle(color: t.sub), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.mor1)),
        );
    Widget etiketli(String e, Widget w) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6), w, const SizedBox(height: 14),
        ]);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Future<void> kaydet() async {
          if (adC.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Cihaz adı gerekli'), backgroundColor: _kirmizi)); return; }
          setSt(() => kaydediliyor = true);
          final auth = context.read<AuthProvider>();
          try {
            final res = await Api.cihazKaydet(auth.token!, {
              if (mevcut != null) 'id': '${mevcut['id']}',
              'ad': adC.text.trim(), 'tip': tip, 'ip': ipC.text.trim(), 'port': portC.text.trim(),
              'marka': markaC.text.trim(), 'seri_no': seriC.text.trim(), 'notlar': notC.text.trim(),
              'aktif': aktif ? '1' : '0',
            });
            if (res['ok'] == 1) {
              if (ctx.mounted) Navigator.pop(ctx);
              _snack(mevcut == null ? 'Cihaz eklendi' : 'Cihaz güncellendi', _yesil);
              _yukle(sessiz: true);
            } else {
              setSt(() => kaydediliyor = false);
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Kaydedilemedi'), backgroundColor: _kirmizi));
            }
          } catch (_) {
            setSt(() => kaydediliyor = false);
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Kaydedilemedi'), backgroundColor: _kirmizi));
          }
        }

        return Padding(
          padding: EdgeInsets.only(left: 18, right: 18, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2)))),
            Text(mevcut == null ? 'Cihaz Ekle' : 'Cihazı Düzenle', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            etiketli('Cihaz Türü', Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _tipler)
                GestureDetector(
                  onTap: () => setSt(() => tip = e['k'] as String),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(color: tip == e['k'] ? t.mor1 : t.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: tip == e['k'] ? t.mor1 : t.line)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(e['ikon'] as IconData, size: 14, color: tip == e['k'] ? Colors.white : t.sub2),
                      const SizedBox(width: 5),
                      Text(e['ad'] as String, style: TextStyle(color: tip == e['k'] ? Colors.white : t.sub2, fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ])),
            etiketli('Cihaz Adı', TextField(controller: adC, style: TextStyle(color: t.ink), decoration: dek('örn. Mutfak Yazıcısı'))),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: etiketli('IP Adresi', TextField(controller: ipC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: dek('192.168.1.50')))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: etiketli('Port', TextField(controller: portC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: dek('9100')))),
            ]),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: etiketli('Marka/Model', TextField(controller: markaC, style: TextStyle(color: t.ink), decoration: dek('opsiyonel')))),
              const SizedBox(width: 10),
              Expanded(child: etiketli('Seri No', TextField(controller: seriC, style: TextStyle(color: t.ink), decoration: dek('opsiyonel')))),
            ]),
            etiketli('Not', TextField(controller: notC, style: TextStyle(color: t.ink), maxLines: 2, decoration: dek('opsiyonel açıklama'))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(children: [
                Expanded(child: Text('Aktif (kullanımda)', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600))),
                Switch(value: aktif, activeThumbColor: t.mor1, onChanged: (v) => setSt(() => aktif = v)),
              ]),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: kaydediliyor ? null : kaydet,
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15), alignment: Alignment.center,
                decoration: BoxDecoration(color: t.mor1, borderRadius: BorderRadius.circular(13)),
                child: kaydediliyor
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(mevcut == null ? 'Ekle' : 'Kaydet', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ])),
        );
      }),
    );
  }
}
