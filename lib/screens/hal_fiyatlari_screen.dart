import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Hal Fiyatları — belediye açık-veri API'sinden (İzmir) oto-çekim + "sen vs hal".
/// Veri /api/patron/hal-fiyatlari.
class HalFiyatlariScreen extends StatefulWidget {
  const HalFiyatlariScreen({super.key});
  @override
  State<HalFiyatlariScreen> createState() => _HalFiyatlariScreenState();
}

const _yesilK = Color(0xFF059669);
const _kirmizi = Color(0xFFF43F5E);
const _amber = Color(0xFFF59E0B);
const _yesil = Color(0xFF10B981);

final _fmtP = NumberFormat('#,##0.00', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => v == null ? '—' : '${_fmtP.format(_n(v))}TL';

class _HalFiyatlariScreenState extends State<HalFiyatlariScreen> {
  bool loading = true;
  List hal = [];
  List kiyas = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.halFiyatlari(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          hal = (res['hal'] as List?) ?? [];
          kiyas = (res['kiyas'] as List?) ?? [];
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Hal Fiyatları',
      ikon: Icons.storefront,
      geri: true,
      altBaslik: 'Toptan hal referansı · sen vs hal',
      araclar: [MButon('Yenile', _yesilK, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: _yesilK.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: _yesilK.withValues(alpha: 0.25))),
                    child: Text('Hal fiyatı belediye açık-veri API\'sinden otomatik çekilir ve son alış fiyatınla kıyaslanır. Not: hal toptan fiyatıdır; kapına teslimde marj+nakliye eklenir — kozu trend/bant olarak kullan.',
                        style: TextStyle(color: t.sub, fontSize: 12.5)),
                  ),

                  // ---- SEN vs HAL ----
                  MBolumBaslik('Sen vs Hal', renk: _kirmizi, sayi: kiyas.length),
                  const SizedBox(height: 8),
                  if (kiyas.isEmpty)
                    _bos(t, 'Eşleşen malzeme/alış yok. Hal ürün adı malzeme adına benzemeli.')
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Malzeme', flex: 28),
                        MSutun('Hal Ort.', flex: 18, hiza: TextAlign.right),
                        MSutun('Senin Son', flex: 18, hiza: TextAlign.right),
                        MSutun('Fark', flex: 14, hiza: TextAlign.center),
                      ],
                      satirlar: [
                        for (final k in kiyas)
                          [
                            Text('${k['malzeme']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(_p(k['hal']), textAlign: TextAlign.right, style: TextStyle(color: t.sub, fontSize: 12)),
                            Text(_p(k['senin']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Align(
                              alignment: Alignment.center,
                              child: MRozet(_n(k['fark']) > 0 ? '+${k['fark']}%' : '${k['fark']}%', _n(k['fark']) >= 20 ? _kirmizi : (_n(k['fark']) > 0 ? _amber : _yesil)),
                            ),
                          ],
                      ],
                    ),

                  const SizedBox(height: 22),
                  MBolumBaslik('Hal Fiyatları', renk: _yesilK, sayi: hal.length),
                  const SizedBox(height: 8),
                  if (hal.isEmpty)
                    _bos(t, 'Hal fiyatı yok. Sunucu dış erişime kapalıysa webden manuel girilebilir.')
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Ürün', flex: 30),
                        MSutun('Asgari', flex: 18, hiza: TextAlign.right),
                        MSutun('Ortalama', flex: 20, hiza: TextAlign.right),
                        MSutun('Azami', flex: 18, hiza: TextAlign.right),
                      ],
                      satirlar: [
                        for (final h in hal)
                          [
                            Text('${h['urun_ad']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(_p(h['asgari']), textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 12)),
                            Text(_p(h['ortalama']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Text(_p(h['azami']), textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 12)),
                          ],
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _bos(TemaProvider t, String metin) => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
        child: Text(metin, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13)),
      );
}
