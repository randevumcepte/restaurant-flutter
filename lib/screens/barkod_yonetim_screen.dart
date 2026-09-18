import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'barkod_tarayici.dart';

/// BARKOD YÖNETİMİ — bir ürüne (tur='urun') ya da malzemeye (tur='malzeme') barkod ekle/sil.
/// Çoklu barkod destekli (aynı ürünün birden çok barkodu olabilir).
class BarkodYonetimScreen extends StatefulWidget {
  final String tur;       // urun | malzeme
  final int hedefId;
  final String ad;        // başlıkta gösterilecek öğe adı
  const BarkodYonetimScreen({super.key, required this.tur, required this.hedefId, required this.ad});

  @override
  State<BarkodYonetimScreen> createState() => _BarkodYonetimScreenState();
}

class _BarkodYonetimScreenState extends State<BarkodYonetimScreen> {
  bool loading = true, mesgul = false;
  List<Map<String, dynamic>> barkodlar = [];
  final _elle = TextEditingController();

  @override
  void initState() { super.initState(); _yukle(); }
  @override
  void dispose() { _elle.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => loading = true);
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.barkodListe(auth.token!, widget.tur, widget.hedefId);
      if (!mounted) return;
      if (r['ok'] == 1) barkodlar = ((r['barkodlar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _ekle(String kod) async {
    kod = kod.trim();
    if (kod.isEmpty || mesgul) return;
    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    final r = await Api.barkodEkle(auth.token!, kod, widget.tur, widget.hedefId);
    if (!mounted) return;
    setState(() => mesgul = false);
    if (r['ok'] == 1) { _elle.clear(); _yukle(); }
    else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['hata']?.toString() ?? 'Eklenemedi'), backgroundColor: const Color(0xFFDC2626))); }
  }

  Future<void> _okut() async {
    final kod = await BarkodTarayici.oku(context, baslik: '${widget.ad} — Barkod Okut');
    if (kod != null) _ekle(kod);
  }

  Future<void> _sil(int id) async {
    final auth = context.read<AuthProvider>();
    await Api.barkodSil(auth.token!, id);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, iconTheme: IconThemeData(color: t.ink),
        title: Text('Barkod: ${widget.ad}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _elle,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: t.ink),
                    decoration: InputDecoration(hintText: 'Barkod (elle yaz)', hintStyle: TextStyle(color: t.sub),
                      filled: true, fillColor: t.card2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                    onSubmitted: _ekle,
                  )),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: mesgul ? null : () => _ekle(_elle.text),
                    style: IconButton.styleFrom(backgroundColor: t.mor1), icon: const Icon(Icons.add, color: Colors.white)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(width: double.infinity, height: 50, child: ElevatedButton.icon(
                  onPressed: _okut,
                  style: ElevatedButton.styleFrom(backgroundColor: t.mor1, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Kamerayla Barkod Okut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)))),
              ),
              const SizedBox(height: 8),
              Expanded(child: barkodlar.isEmpty
                  ? Center(child: Text('Henüz barkod yok.\nOkut ya da elle ekle.', textAlign: TextAlign.center, style: TextStyle(color: t.sub)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: barkodlar.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final b = barkodlar[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), boxShadow: t.golge),
                          child: Row(children: [
                            Icon(Icons.qr_code_2, color: t.mor1),
                            const SizedBox(width: 12),
                            Expanded(child: Text(b['barkod']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
                            IconButton(onPressed: () => _sil((b['id'] as num).toInt()), icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626))),
                          ]),
                        );
                      },
                    )),
            ]),
    );
  }
}
