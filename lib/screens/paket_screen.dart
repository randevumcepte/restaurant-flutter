import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import 'fis.dart';

class PaketScreen extends StatefulWidget {
  const PaketScreen({super.key});

  @override
  State<PaketScreen> createState() => _PaketScreenState();
}

class _PaketScreenState extends State<PaketScreen> {
  List siparisler = [];
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.paket(auth.token!);
      if (!mounted) return;
      setState(() {
        siparisler = (res['siparisler'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _platRenk(String p) {
    switch (p) {
      case 'getir':
        return const Color(0xFF7C3AED);
      case 'yemeksepeti':
        return const Color(0xFFE11D48);
      case 'trendyol':
        return const Color(0xFFEA580C);
      case 'migros':
        return const Color(0xFF16A34A);
      case 'whatsapp':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  // Bekleme süresine göre renk: gecikme uyarısı
  Color _sureRenk(int dk) {
    if (dk >= 45) return const Color(0xFFDC2626); // kırmızı
    if (dk >= 25) return const Color(0xFFEA580C); // turuncu
    return const Color(0xFF16A34A); // yeşil
  }

  // Ödeme yöntemi: kurye/paket çalışanı hazırlığını buna göre yapar
  static Map<String, dynamic> odemeStil(String? y) {
    switch (y) {
      case 'online':
        return {'ad': 'Online Ödendi', 'renk': const Color(0xFF16A34A), 'ikon': Icons.check_circle, 'tahsilat': false};
      case 'kredi':
        return {'ad': 'Kart · Kapıda', 'renk': const Color(0xFF2563EB), 'ikon': Icons.credit_card, 'tahsilat': true};
      case 'nakit':
      default:
        return {'ad': 'Nakit · Kapıda', 'renk': const Color(0xFFD97706), 'ikon': Icons.payments, 'tahsilat': true};
    }
  }

  Widget _odemeRozet(String? y, {bool buyuk = false}) {
    final st = odemeStil(y);
    final renk = st['renk'] as Color;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: buyuk ? 10 : 8, vertical: buyuk ? 5 : 3),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: renk.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(st['ikon'] as IconData, size: buyuk ? 15 : 13, color: renk),
        const SizedBox(width: 4),
        Text(st['ad'] as String, style: TextStyle(fontSize: buyuk ? 13 : 11.5, fontWeight: FontWeight.bold, color: renk)),
      ]),
    );
  }

  void _detayAc(int id) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaketDetayScreen(id: id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Paket Siparişler  (${siparisler.length})',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: const Icon(Icons.refresh, color: Color(0xFF64748B))),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: siparisler.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Şu an aktif paket sipariş yok.', style: TextStyle(color: Color(0xFF94A3B8)))),
                    ])
                  : genisMi(context)
                  ? _masaustuTablo()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: siparisler.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = siparisler[i];
                        final plat = (s['platform'] ?? '-').toString();
                        final dk = _n(s['gecen_dk']).toInt();
                        final adet = _n(s['urun_adet']).toInt();
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _detayAc(_n(s['id']).toInt()),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: _platRenk(plat), borderRadius: BorderRadius.circular(6)),
                                            child: Text(plat.toUpperCase(),
                                                style: const TextStyle(
                                                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('● ${s['teslimat_durumu'] ?? ''}',
                                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                          const Spacer(),
                                          // Süre rozeti
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color: _sureRenk(dk).withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(6)),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                                              Icon(Icons.schedule, size: 12, color: _sureRenk(dk)),
                                              const SizedBox(width: 3),
                                              Text(s['gecen_metin']?.toString() ?? '$dk dk',
                                                  style: TextStyle(
                                                      fontSize: 11, fontWeight: FontWeight.bold, color: _sureRenk(dk))),
                                            ]),
                                          ),
                                        ]),
                                        const SizedBox(height: 6),
                                        Text(s['musteri']?.toString() ?? 'Müşteri',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                        const SizedBox(height: 5),
                                        // Ödeme yöntemi — paket çalışanı buna göre hazırlanır
                                        _odemeRozet(s['odeme_yontemi']?.toString()),
                                        const SizedBox(height: 5),
                                        Row(children: [
                                          if (adet > 0) ...[
                                            const Icon(Icons.shopping_bag_outlined,
                                                size: 12, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 3),
                                            Text('$adet ürün',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                            const SizedBox(width: 10),
                                          ],
                                          if (s['kurye'] != null)
                                            Flexible(
                                              child: Text('🛵 ${s['kurye']}',
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                                            ),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('${_f.format(_n(s['toplam']).round())}TL',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15)),
                                      const SizedBox(height: 4),
                                      const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  // ===================== MASAUSTU: gruplu sipariş tablosu (SepetTakip tarzı) =====================
  static const int _fPlat = 20, _fMus = 24, _fAdr = 30, _fTut = 16, _fOde = 26, _fSure = 15, _fIsl = 52;

  Widget _masaustuTablo() {
    final gruplar = [
      {'baslik': 'Yeni Sipariş', 'durumlar': const ['hazirlaniyor', '', 'yeni'], 'renk': const Color(0xFF2563EB)},
      {'baslik': 'Yola Çıkarılması Gereken', 'durumlar': const ['hazir'], 'renk': const Color(0xFFEA580C)},
      {'baslik': 'Teslim Edilmesi Gereken', 'durumlar': const ['yolda'], 'renk': const Color(0xFF16A34A)},
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        for (final g in gruplar)
          ..._grupBolum(g['baslik'] as String, g['renk'] as Color, (g['durumlar'] as List).cast<String>()),
      ],
    );
  }

  List<Widget> _grupBolum(String baslik, Color renk, List<String> durumlar) {
    final list = siparisler.where((s) {
      final d = (s['teslimat_durumu'] ?? '').toString();
      return durumlar.contains(d);
    }).toList();
    if (list.isEmpty) return [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(baslik, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text('${list.length}', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(children: [
          _baslikSatiri(),
          for (int i = 0; i < list.length; i++) _dataSatiri(list[i], i == list.length - 1),
        ]),
      ),
      const SizedBox(height: 18),
    ];
  }

  Widget _baslikSatiri() {
    Widget h(String t, int flex, {TextAlign a = TextAlign.left}) =>
        Expanded(flex: flex, child: Text(t, textAlign: a, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      child: Row(children: [
        h('Platform', _fPlat),
        h('Müşteri', _fMus),
        h('Adres', _fAdr),
        h('Tutar', _fTut, a: TextAlign.right),
        h('Ödeme', _fOde),
        h('Süre', _fSure),
        h('İşlemler', _fIsl, a: TextAlign.right),
      ]),
    );
  }

  Widget _dataSatiri(dynamic s, bool son) {
    final plat = (s['platform'] ?? '-').toString();
    final dk = _n(s['gecen_dk']).toInt();
    final durum = (s['teslimat_durumu'] ?? '').toString();
    final id = _n(s['id']).toInt();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: son ? null : const Border(bottom: BorderSide(color: Color(0xFFEEF2F7)))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          flex: _fPlat,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: _platRenk(plat), borderRadius: BorderRadius.circular(6)),
              child: Text(plat.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        Expanded(
          flex: _fMus,
          child: Text(s['musteri']?.toString() ?? 'Müşteri', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ),
        Expanded(
          flex: _fAdr,
          child: Text((s['teslimat_adres'] ?? '-').toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ),
        Expanded(
          flex: _fTut,
          child: Text('${_f.format(_n(s['toplam']).round())}TL', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ),
        Expanded(
          flex: _fOde,
          child: Align(alignment: Alignment.centerLeft, child: _odemeRozet(s['odeme_yontemi']?.toString())),
        ),
        Expanded(
          flex: _fSure,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule, size: 12, color: _sureRenk(dk)),
            const SizedBox(width: 3),
            Flexible(child: Text(s['gecen_metin']?.toString() ?? '$dk dk', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _sureRenk(dk)))),
          ]),
        ),
        Expanded(
          flex: _fIsl,
          child: Wrap(alignment: WrapAlignment.end, spacing: 6, runSpacing: 6, children: _aksiyonButonlari(id, durum)),
        ),
      ]),
    );
  }

  List<Widget> _aksiyonButonlari(int id, String durum) {
    final btns = <Widget>[];
    if (durum == 'hazirlaniyor' || durum == '' || durum == 'yeni') {
      btns.add(_btn('Kabul Et', const Color(0xFF16A34A), () => _aksiyon(id, 'kabul')));
      btns.add(_btn('İptal', const Color(0xFFDC2626), () => _aksiyonOnay(id), dolu: false));
    } else if (durum == 'hazir') {
      btns.add(_btn('Yola Çıkar', const Color(0xFFEA580C), () => _aksiyon(id, 'yola')));
      btns.add(_btn('İptal', const Color(0xFFDC2626), () => _aksiyonOnay(id), dolu: false));
    } else if (durum == 'yolda') {
      btns.add(_btn('Teslim Et', const Color(0xFF16A34A), () => _aksiyon(id, 'teslim')));
    }
    btns.add(_btn('Detay', const Color(0xFF64748B), () => _detayAc(id), dolu: false));
    btns.add(_btn('Yazdır', const Color(0xFF64748B), () => _yazdir(id), dolu: false));
    return btns;
  }

  Widget _btn(String label, Color renk, VoidCallback onTap, {bool dolu = true}) {
    return Material(
      color: dolu ? renk : Colors.white,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), border: dolu ? null : Border.all(color: const Color(0xFFCBD5E1))),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: dolu ? Colors.white : const Color(0xFF475569))),
        ),
      ),
    );
  }

  Future<void> _aksiyon(int id, String aksiyon) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.paketDurum(auth.token!, id, aksiyon);
      if (!mounted) return;
      if (res['ok'] == 1) {
        const adlar = {'kabul': 'Sipariş kabul edildi', 'yola': 'Yola çıkarıldı', 'teslim': 'Teslim edildi', 'iptal': 'Sipariş iptal edildi'};
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(adlar[aksiyon] ?? 'Güncellendi'),
          backgroundColor: aksiyon == 'iptal' ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          duration: const Duration(seconds: 2),
        ));
        _yukle();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İşlem başarısız'), backgroundColor: Color(0xFFDC2626)));
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası'), backgroundColor: Color(0xFFDC2626)));
    }
  }

  Future<void> _aksiyonOnay(int id) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Siparişi iptal et'),
        content: const Text('Bu paket siparişi iptal edilecek. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );
    if (onay == true) _aksiyon(id, 'iptal');
  }

  Future<void> _yazdir(int id) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.paketDetay(auth.token!, id);
      final d = (res['siparis'] as Map?)?.cast<String, dynamic>();
      if (d == null || !mounted) return;
      final kalemler = ((d['kalemler'] as List?) ?? [])
          .map((k) => {'adet': _n((k as Map)['adet']), 'ad': k['urun_adi'], 'tutar': _n(k['tutar'])})
          .toList();
      final no = d['platform_siparis_no']?.toString() ?? '';
      await fisYazdir(context, {
        'isletme': auth.sube ?? 'ResteOS',
        'masa': 'PAKET · ${d['platform'] ?? ''}',
        'adisyon_no': no.isNotEmpty ? no : id,
        'garson': d['kurye'] ?? d['platform'] ?? '',
        'tarih': d['acilis'] ?? '',
        'telefon': d['telefon'] ?? '',
        'adres': d['teslimat_adres'] ?? '',
        'kalemler': kalemler,
        'ara_toplam': _n(d['ara_toplam']),
        'indirim': _n(d['indirim']),
        'ikram': _n(d['ikram']),
        'toplam': _n(d['toplam']),
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yazdırma hatası')));
    }
  }
}

/// Paket sipariş detay sayfası — karta tıklanınca açılır.
class PaketDetayScreen extends StatefulWidget {
  final int id;
  const PaketDetayScreen({super.key, required this.id});

  @override
  State<PaketDetayScreen> createState() => _PaketDetayScreenState();
}

class _PaketDetayScreenState extends State<PaketDetayScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _para(dynamic v) => '${_f.format(_n(v).round())}TL';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.paketDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        d = (res['siparis'] as Map?)?.cast<String, dynamic>();
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _platRenk(String p) {
    switch (p) {
      case 'getir':
        return const Color(0xFF7C3AED);
      case 'yemeksepeti':
        return const Color(0xFFE11D48);
      case 'trendyol':
        return const Color(0xFFEA580C);
      case 'migros':
        return const Color(0xFF16A34A);
      case 'whatsapp':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _sureRenk(int dk) {
    if (dk >= 45) return const Color(0xFFDC2626);
    if (dk >= 25) return const Color(0xFFEA580C);
    return const Color(0xFF16A34A);
  }

  Widget _kart({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );

  Widget _satir(IconData ic, String etiket, String deger) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 16, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 10),
          Text(etiket, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(deger,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final plat = (d?['platform'] ?? '-').toString();
    final dk = _n(d?['gecen_dk']).toInt();
    final kalemler = (d?['kalemler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Sipariş Detayı',
            style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
              ? const Center(child: Text('Sipariş bulunamadı.', style: TextStyle(color: Color(0xFF94A3B8))))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Üst özet: platform + durum + süre
                    _kart(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                  color: _platRenk(plat), borderRadius: BorderRadius.circular(6)),
                              child: Text(plat.toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('● ${d?['teslimat_durumu'] ?? ''}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: _sureRenk(dk).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.schedule, size: 14, color: _sureRenk(dk)),
                                const SizedBox(width: 4),
                                Text(d?['gecen_metin']?.toString() ?? '$dk dk',
                                    style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: _sureRenk(dk))),
                              ]),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Text(d?['musteri']?.toString() ?? 'Müşteri',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          if ((d?['platform_siparis_no'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Sipariş No: ${d?['platform_siparis_no']}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                            ),
                        ],
                      ),
                    ),

                    // ÖDEME YÖNTEMİ — paket çalışanı/kurye için en kritik bilgi
                    Builder(builder: (_) {
                      final st = _PaketScreenState.odemeStil(d?['odeme_yontemi']?.toString());
                      final renk = st['renk'] as Color;
                      final tahsilat = st['tahsilat'] as bool;
                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: renk.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: renk.withValues(alpha: 0.4), width: 1.5),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                            child: Icon(st['ikon'] as IconData, color: renk, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(st['ad'] as String, style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(tahsilat ? 'Kapıda tahsil edilecek' : 'Ödeme alındı — tahsilat yok',
                                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                            ]),
                          ),
                          if (tahsilat)
                            Text(_para(d?['toplam']), style: TextStyle(color: renk, fontSize: 18, fontWeight: FontWeight.bold)),
                        ]),
                      );
                    }),

                    // Müşteri / teslimat bilgileri
                    _kart(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Teslimat Bilgileri',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 6),
                          if ((d?['telefon'] ?? '').toString().isNotEmpty)
                            _satir(Icons.phone, 'Telefon', d?['telefon'].toString() ?? '-'),
                          if ((d?['teslimat_adres'] ?? '').toString().isNotEmpty)
                            _satir(Icons.location_on_outlined, 'Adres', d?['teslimat_adres'].toString() ?? '-'),
                          if ((d?['kurye'] ?? '').toString().isNotEmpty)
                            _satir(Icons.two_wheeler, 'Kurye',
                                '${d?['kurye']}${(d?['kurye_tel'] ?? '').toString().isNotEmpty ? '  •  ${d?['kurye_tel']}' : ''}'),
                          _satir(Icons.access_time, 'Sipariş Saati', d?['acilis']?.toString() ?? '-'),
                        ],
                      ),
                    ),

                    // Ürünler
                    _kart(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ürünler (${kalemler.length})',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                          const SizedBox(height: 8),
                          if (kalemler.isEmpty)
                            const Text('Ürün bilgisi yok.',
                                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)))
                          else
                            ...kalemler.map((k) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 1),
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(6)),
                                        child: Text('${_n(k['adet']).toInt()}x',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF4F46E5))),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(k['urun_adi']?.toString() ?? 'Ürün',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0F172A))),
                                            if ((k['not'] ?? '').toString().isNotEmpty)
                                              Text('Not: ${k['not']}',
                                                  style: const TextStyle(
                                                      fontSize: 12, color: Color(0xFFEA580C))),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_para(k['tutar']),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A))),
                                    ],
                                  ),
                                )),
                        ],
                      ),
                    ),

                    // Tutar dökümü
                    _kart(
                      child: Column(
                        children: [
                          _tutarSatir('Ara Toplam', _para(d?['ara_toplam'])),
                          if (_n(d?['indirim']) > 0)
                            _tutarSatir('İndirim', '- ${_para(d?['indirim'])}', renk: const Color(0xFF16A34A)),
                          if (_n(d?['ikram']) > 0)
                            _tutarSatir('İkram', '- ${_para(d?['ikram'])}', renk: const Color(0xFF16A34A)),
                          const Divider(height: 20),
                          _tutarSatir('Toplam', _para(d?['toplam']), kalin: true),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _tutarSatir(String etiket, String deger, {bool kalin = false, Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(etiket,
                style: TextStyle(
                    fontSize: kalin ? 16 : 14,
                    fontWeight: kalin ? FontWeight.bold : FontWeight.normal,
                    color: const Color(0xFF334155))),
            Text(deger,
                style: TextStyle(
                    fontSize: kalin ? 18 : 14,
                    fontWeight: kalin ? FontWeight.bold : FontWeight.w600,
                    color: renk ?? const Color(0xFF0F172A))),
          ],
        ),
      );
}
