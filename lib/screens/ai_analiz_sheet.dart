import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// "🤖 Derin AI Analizi" alt sayfasi (Haiku LLM, kural motoru ustune, on-demand).
class AiAnalizSheet {
  static Future<void> goster(BuildContext context, {required String kapsam, int? id, String period = 'haftalik', String baslik = 'Derin AI Analizi'}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161C2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => _AiAnalizBody(kapsam: kapsam, id: id, period: period, baslik: baslik),
    );
  }
}

class _AiAnalizBody extends StatefulWidget {
  final String kapsam;
  final int? id;
  final String period;
  final String baslik;
  const _AiAnalizBody({required this.kapsam, this.id, required this.period, required this.baslik});

  @override
  State<_AiAnalizBody> createState() => _AiAnalizBodyState();
}

class _AiAnalizBodyState extends State<_AiAnalizBody> {
  bool loading = true;
  List yorumlar = [];
  String kaynak = '';
  String? hata;

  static const _mor2 = Color(0xFF9D5DC8);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.aiAnaliz(auth.token!, kapsam: widget.kapsam, id: widget.id, period: widget.period);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          yorumlar = (res['yorumlar'] as List?) ?? [];
          kaynak = res['kaynak']?.toString() ?? '';
          loading = false;
        });
      } else {
        setState(() {
          hata = res['hata']?.toString() ?? 'Analiz alınamadı';
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  String get _kaynakEtiket {
    switch (kaynak) {
      case 'haiku':
        return 'Claude Haiku';
      case 'onbellek':
        return 'Önbellek';
      case 'yapilandirilmamis':
        return 'Kurulum gerekli';
      case 'hata':
        return 'Servis hatası';
      default:
        return kaynak;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(12)),
                child: const Text('✨', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.baslik, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  const Text('Kural motoru + LLM', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ]),
              ),
              if (!loading && kaynak.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF243049), borderRadius: BorderRadius.circular(20)),
                  child: Text(_kaynakEtiket, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 16),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Column(children: [
                    CircularProgressIndicator(color: _mor2),
                    SizedBox(height: 12),
                    Text('AI verileri analiz ediyor…', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                  ]),
                ),
              )
            else if (hata != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(hata!, style: const TextStyle(color: Color(0xFFF43F5E))),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final y in yorumlar)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E263B),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF2D3752)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('💡', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(y.toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, height: 1.4))),
                        ]),
                      ),
                    if (kaynak == 'yapilandirilmamis')
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text('Not: Kurallı AI yorumları uygulamada zaten çalışıyor. Bu buton, anahtar eklenince derin LLM analizini getirir.',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
