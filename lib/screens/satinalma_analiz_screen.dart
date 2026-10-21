import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Satınalma Analizi — tedarikçi karnesi (zamanında/red/yıldız) + aylık harcama trendi.
/// Veri /api/patron/satinalma-analiz.
class SatinalmaAnalizScreen extends StatefulWidget {
  const SatinalmaAnalizScreen({super.key});
  @override
  State<SatinalmaAnalizScreen> createState() => _SatinalmaAnalizScreenState();
}

const _mavi = Color(0xFF4F46E5);
const _mor1 = Color(0xFF7C3AED);
const _yesil = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _kirmizi = Color(0xFFF43F5E);
const _gold = Color(0xFFF6CE63);

final _fmt0 = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl0(dynamic v) => '${_fmt0.format(_n(v).round())}TL';

const _aylar = ['', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
String _ayKisa(String ym) {
  final p = ym.split('-');
  if (p.length == 2) {
    final m = int.tryParse(p[1]) ?? 0;
    if (m >= 1 && m <= 12) return _aylar[m];
  }
  return ym;
}

class _SatinalmaAnalizScreenState extends State<SatinalmaAnalizScreen> {
  bool loading = true;
  List karne = [];
  List aylik = [];
  num toplamAlis = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.satinalmaAnaliz(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          karne = (res['karne'] as List?) ?? [];
          aylik = (res['aylik'] as List?) ?? [];
          toplamAlis = _n(res['toplam_alis']);
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _yildiz(num p) {
    final tam = p.floor();
    final yarim = (p - tam) >= 0.5;
    return '★' * tam + (yarim ? '½' : '');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final enYuksek = aylik.fold<num>(1, (a, b) => _n(b['t']) > a ? _n(b['t']) : a);
    return MasaustuSayfa(
      baslik: 'Satınalma Analizi',
      ikon: Icons.leaderboard,
      geri: true,
      altBaslik: 'Tedarikçi karnesi + harcama trendi',
      araclar: [MButon('Yenile', _mavi, _yukle, dolu: false, ikon: Icons.refresh)],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ---- Harcama trendi ----
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        MBolumBaslik('Harcama Trendi (6 ay)', renk: _mavi),
                        const Spacer(),
                        MRozet('Toplam ${_tl0(toplamAlis)}', _mavi),
                      ]),
                      const SizedBox(height: 10),
                      if (aylik.isEmpty)
                        Text('Henüz alış faturası yok.', style: TextStyle(color: t.sub, fontSize: 13))
                      else
                        SizedBox(
                          height: 150,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final a in aylik)
                                Expanded(
                                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    Text(_tl0(a['t']), style: TextStyle(color: t.sub2, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      height: (12 + (_n(a['t']) / enYuksek) * 110).toDouble(),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_mavi, _mor1]),
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(_ayKisa('${a['ay']}'), style: TextStyle(color: t.sub2, fontSize: 11)),
                                  ]),
                                ),
                            ],
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // ---- Tedarikçi karnesi ----
                  MBolumBaslik('Tedarikçi Karnesi', renk: _gold, sayi: karne.length),
                  const SizedBox(height: 8),
                  Text('Zamanında teslim + red/eksik oranı → yıldız puanı.', style: TextStyle(color: t.sub2, fontSize: 12)),
                  const SizedBox(height: 10),
                  if (karne.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(26),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                      child: Text('Karne için alış + mal kabul verisi gerekir.', style: TextStyle(color: t.sub, fontSize: 13)),
                    )
                  else
                    MTablo(
                      sutunlar: const [
                        MSutun('Tedarikçi', flex: 26),
                        MSutun('Toplam', flex: 18, hiza: TextAlign.right),
                        MSutun('Zamanında', flex: 16, hiza: TextAlign.center),
                        MSutun('Red', flex: 12, hiza: TextAlign.center),
                        MSutun('Puan', flex: 16, hiza: TextAlign.center),
                      ],
                      satirlar: [
                        for (final k in karne)
                          [
                            Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                            Text(_tl0(k['toplam']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
                            Align(
                              alignment: Alignment.center,
                              child: Text(k['zamaninda'] == null ? '—' : '%${k['zamaninda']}',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: k['zamaninda'] == null ? t.sub2 : (_n(k['zamaninda']) >= 90 ? _yesil : (_n(k['zamaninda']) >= 70 ? _amber : _kirmizi)))),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: Text(_n(k['red_oran']) > 0 ? '%${k['red_oran']}' : '—',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _n(k['red_oran']) > 0 ? _kirmizi : t.sub2)),
                            ),
                            Align(
                              alignment: Alignment.center,
                              child: MRozet('${k['puan']} ${_yildiz(_n(k['puan']))}', _n(k['puan']) >= 4 ? _yesil : (_n(k['puan']) >= 3 ? _amber : _kirmizi)),
                            ),
                          ],
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
