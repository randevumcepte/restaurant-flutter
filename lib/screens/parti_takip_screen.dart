import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Parti / SKT Takip — FEFO + yaklaşan/geçmiş son kullanma. Veri /api/patron/parti-takip.
class PartiTakipScreen extends StatefulWidget {
  const PartiTakipScreen({super.key});
  @override
  State<PartiTakipScreen> createState() => _PartiTakipScreenState();
}

const _kirmizi = Color(0xFFF43F5E);
const _amber = Color(0xFFF59E0B);
const _yesil = Color(0xFF10B981);

final _fmt = NumberFormat('#,##0.###', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _mik(dynamic v) => _fmt.format(_n(v));
String _tarih(dynamic v) {
  if (v == null || '$v'.isEmpty) return '—';
  try {
    return DateFormat('dd.MM.yyyy').format(DateTime.parse('$v'));
  } catch (_) {
    return '$v';
  }
}

class _PartiTakipScreenState extends State<PartiTakipScreen> {
  bool loading = true;
  List partiler = [];
  int gecmis = 0, yaklasan = 0, esik = 7;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.partiTakip(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          partiler = (res['partiler'] as List?) ?? [];
          gecmis = _n(res['gecmis']).toInt();
          yaklasan = _n(res['yaklasan']).toInt();
          esik = _n(res['esik']).toInt();
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _ozet(TemaProvider t, String say, String alt, Color c) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Column(children: [
            Text(say, style: TextStyle(color: c, fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(alt, textAlign: TextAlign.center, style: TextStyle(color: t.sub2, fontSize: 11)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Parti / SKT Takip',
      ikon: Icons.event_busy,
      geri: true,
      altBaslik: 'FEFO · ilk bozulan ilk çıkar',
      araclar: [MButon('Yenile', _kirmizi, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(children: [
                    _ozet(t, '$gecmis', 'Son kullanma GEÇMİŞ', _kirmizi),
                    _ozet(t, '$yaklasan', '$esik güne YAKLAŞAN', _amber),
                    _ozet(t, '${partiler.length}', 'Aktif parti', t.ink),
                  ]),
                  const SizedBox(height: 18),
                  MBolumBaslik('Partiler (SKT sırasıyla)', renk: _kirmizi, sayi: partiler.length),
                  const SizedBox(height: 8),
                  if (partiler.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                      child: Text('Henüz parti yok. Mal kabulde lot/SKT girdikçe oluşur.', textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13)),
                    )
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Malzeme', flex: 24),
                        MSutun('Lot', flex: 14),
                        MSutun('SKT', flex: 16, hiza: TextAlign.right),
                        MSutun('Durum', flex: 16, hiza: TextAlign.center),
                        MSutun('Kalan', flex: 14, hiza: TextAlign.right),
                      ],
                      satirlar: [
                        for (final p in partiler)
                          [
                            Text('${p['ad']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(('${p['lot'] ?? ''}').isEmpty ? '—' : '${p['lot']}', style: TextStyle(color: t.sub2, fontSize: 11.5)),
                            Text(_tarih(p['skt']), textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: p['durum'] == 'gecmis' ? _kirmizi : (p['durum'] == 'yaklasan' ? _amber : t.ink))),
                            Align(
                              alignment: Alignment.center,
                              child: p['durum'] == 'gecmis'
                                  ? MRozet('Geçti', _kirmizi)
                                  : (p['durum'] == 'yaklasan' ? MRozet('${p['kalan_gun']} gün', _amber) : MRozet('Normal', _yesil)),
                            ),
                            Text(_mik(p['kalan']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ],
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text('FEFO: satış tüketiminde en yakın SKT\'li partiden otomatik düşülür.', style: TextStyle(color: t.sub2, fontSize: 11.5)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
