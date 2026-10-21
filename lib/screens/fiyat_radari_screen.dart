import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Fiyat Radarı — Gizli Zam Dedektörü + daha ucuz tedarikçi (son 120 gün alış geçmişi + katalog).
/// Web /fiyat-radari ile birebir; veri /api/patron/fiyat-radari.
class FiyatRadariScreen extends StatefulWidget {
  const FiyatRadariScreen({super.key});
  @override
  State<FiyatRadariScreen> createState() => _FiyatRadariScreenState();
}

const _kirmizi = Color(0xFFF43F5E);
const _amber = Color(0xFFF59E0B);
const _yesil = Color(0xFF10B981);
const _pembe = Color(0xFFEC4899);

final _fmtP = NumberFormat('#,##0.00', 'tr');
final _fmt0 = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))}TL';
String _p0(dynamic v) => '${_fmt0.format(_n(v).round())}TL';

class _FiyatRadariScreenState extends State<FiyatRadariScreen> {
  bool loading = true;
  List zamlar = [];
  List firsatlar = [];
  num toplamEtki = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.fiyatRadari(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          zamlar = (res['zamlar'] as List?) ?? [];
          firsatlar = (res['firsatlar'] as List?) ?? [];
          toplamEtki = _n(res['toplam_etki']);
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
      baslik: 'Fiyat Radarı',
      ikon: Icons.radar,
      geri: true,
      altBaslik: 'Gizli zam · daha ucuz tedarikçi',
      araclar: [MButon('Yenile', _pembe, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (toplamEtki > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kirmizi.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kirmizi.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.radar, color: _pembe, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Gizli zamların yıllık etkisi',
                              style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text('~${_p0(toplamEtki)}',
                            style: const TextStyle(color: _kirmizi, fontSize: 20, fontWeight: FontWeight.w900)),
                      ]),
                    ),

                  // ---- GİZLİ ZAM ----
                  MBolumBaslik('Gizli Zam Dedektörü', renk: _kirmizi, sayi: zamlar.length),
                  const SizedBox(height: 8),
                  Text('Son 120 günde %8+ tırmanan malzemeler — birikince büyük para.',
                      style: TextStyle(color: t.sub2, fontSize: 12)),
                  const SizedBox(height: 10),
                  if (zamlar.isEmpty)
                    _bos(t, 'Sinsi zam yok 👍 (en az 2 faturalı malzeme gerekir)')
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Malzeme', flex: 24),
                        MSutun('İlk', flex: 14, hiza: TextAlign.right),
                        MSutun('Son', flex: 14, hiza: TextAlign.right),
                        MSutun('Artış', flex: 14, hiza: TextAlign.center),
                        MSutun('Yıllık', flex: 16, hiza: TextAlign.right),
                      ],
                      satirlar: [
                        for (final z in zamlar)
                          [
                            Text('${z['ad']}',
                                style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(_p(z['ilk']), textAlign: TextAlign.right, style: TextStyle(color: t.sub, fontSize: 12)),
                            Text(_p(z['son']), textAlign: TextAlign.right,
                                style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Align(
                              alignment: Alignment.center,
                              child: MRozet('+${z['yuzde']}%', _n(z['yuzde']) >= 15 ? _kirmizi : _amber),
                            ),
                            Text('~${_p0(z['yillik_etki'])}', textAlign: TextAlign.right,
                                style: const TextStyle(color: _kirmizi, fontSize: 12.5, fontWeight: FontWeight.bold)),
                          ],
                      ],
                    ),

                  const SizedBox(height: 22),

                  // ---- DAHA UCUZ TEDARİKÇİ ----
                  MBolumBaslik('Daha Ucuz Tedarikçi Var', renk: _yesil, sayi: firsatlar.length),
                  const SizedBox(height: 10),
                  if (firsatlar.isEmpty)
                    _bos(t, 'Kıyas için bir malzemeyi en az 2 farklı tedarikçiden al.')
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Malzeme', flex: 26),
                        MSutun('En Ucuz Tedarikçi', flex: 28),
                        MSutun('En Ucuz', flex: 16, hiza: TextAlign.right),
                        MSutun('Fark', flex: 14, hiza: TextAlign.center),
                      ],
                      satirlar: [
                        for (final f in firsatlar)
                          [
                            Text('${f['ad']}',
                                style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text('${f['en_ucuz_ted']}',
                                style: const TextStyle(color: _yesil, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(_p(f['en_ucuz']), textAlign: TextAlign.right,
                                style: const TextStyle(color: _yesil, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Align(alignment: Alignment.center, child: MRozet('%${f['tasarruf']}', _yesil)),
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
        padding: const EdgeInsets.all(28),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.line),
        ),
        child: Text(metin, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13)),
      );
}
