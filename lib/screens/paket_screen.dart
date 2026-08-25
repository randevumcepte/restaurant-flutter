import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

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
                                        const SizedBox(height: 2),
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
                                      Text('${_f.format(_n(s['toplam']).round())} ₺',
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
  String _para(dynamic v) => '${_f.format(_n(v).round())} ₺';

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
