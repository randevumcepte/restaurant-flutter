import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Finansal Özet — aylık gelir / gider / net kâr. Gelir ödeme tipine, gider
/// kategoriye göre kırılım. Personel maaş + alış faturaları otomatik giderde.
class FinansScreen extends StatefulWidget {
  const FinansScreen({super.key});
  @override
  State<FinansScreen> createState() => _FinansScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _katAd = {'kira': 'Kira', 'fatura': 'Fatura', 'malzeme': 'Malzeme / Alış', 'maas': 'Maaş / Personel', 'vergi': 'Vergi', 'diger': 'Diğer'};
const _tipAd = {'nakit': 'Nakit', 'kredi': 'Kredi Kartı', 'yemek_karti': 'Yemek Kartı', 'acik_hesap': 'Açık Hesap'};

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';

class _FinansScreenState extends State<FinansScreen> {
  Map d = {};
  bool loading = true;
  DateTime _ay = DateTime.now();

  String get _ayParam => '${_ay.year}-${_ay.month.toString().padLeft(2, '0')}';
  String get _ayMetin => '${_aylar[_ay.month]} ${_ay.year}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.finans(auth.token!, ay: _ayParam);
      if (!mounted) return;
      setState(() { d = res['ok'] == 1 ? res : {}; loading = false; });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _ayDegis(int delta) {
    final y = DateTime(_ay.year, _ay.month + delta);
    if (y.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) return;
    setState(() => _ay = y);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final net = _n(d['net']);
    final gelirTip = (d['gelir_tip'] as List?) ?? [];
    final giderKat = (d['gider_kategori'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Kasa', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(onPressed: () => _ayDegis(-1), icon: const Icon(Icons.chevron_left, color: _mor1)),
                Text(_ayMetin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                IconButton(onPressed: () => _ayDegis(1), icon: const Icon(Icons.chevron_right, color: _mor1)),
              ]),
              Expanded(child: RefreshIndicator(onRefresh: _yukle, color: _mor1, backgroundColor: _card, child: ListView(padding: const EdgeInsets.all(14), children: [
                // Net kâr hero
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: net >= 0 ? const [_mor1, _mavi] : const [Color(0xFF7F1D1D), _kirmizi]), borderRadius: BorderRadius.circular(20)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(net >= 0 ? 'Net Kâr (bu ay)' : 'Net Zarar (bu ay)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(_tl(net), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _mini('Gelir', _tl(d['gelir']), Icons.arrow_downward)),
                      Expanded(child: _mini('Gider', _tl(d['gider']), Icons.arrow_upward)),
                      if (_n(d['bahsis']) > 0) Expanded(child: _mini('Bahşiş', _tl(d['bahsis']), Icons.volunteer_activism)),
                    ]),
                  ]),
                ),
                const SizedBox(height: 14),
                _kutu('💵 Gelir — Ödeme Tipi', [
                  if (gelirTip.isEmpty) _bos('Bu ay tahsilat yok.')
                  else for (final g in gelirTip) _satir(_tipAd[(g as Map)['tip']] ?? g['tip'].toString(), _tl(g['tutar']), renk: _yesil),
                ]),
                _kutu('🧾 Gider — Kategori', [
                  if (giderKat.isEmpty) _bos('Bu ay gider yok.')
                  else for (final g in giderKat) _satir(_katAd[(g as Map)['kategori']] ?? g['kategori'].toString(), _tl(g['tutar']), renk: _kirmizi),
                ]),
                if (_n(d['alis_toplam']) > 0)
                  _kutu('📦 Tedarikçi Alışı', [_satir('Toplam alış faturası', _tl(d['alis_toplam']))]),
                const SizedBox(height: 30),
              ]))),
            ]),
    );
  }

  Widget _mini(String e, String v, IconData ic) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ic, color: Colors.white70, size: 14),
        const SizedBox(height: 2),
        FittedBox(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))),
        Text(e, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ]);

  Widget _kutu(String baslik, List<Widget> c) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF232B42))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...c,
        ]),
      );

  Widget _satir(String s, String v, {Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(s, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13)),
          Text(v, style: TextStyle(color: renk ?? Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ]),
      );

  Widget _bos(String m) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(m, style: const TextStyle(color: _gri, fontSize: 13)));
}
