import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Sebep Yönetimi (Ayarlar) — silme/iskonto/ikram/iptal sebeplerini düzenle (sahip/müdür).
class SebepYonetimiScreen extends StatefulWidget {
  const SebepYonetimiScreen({super.key});

  @override
  State<SebepYonetimiScreen> createState() => _SebepYonetimiScreenState();
}

class _SebepYonetimiScreenState extends State<SebepYonetimiScreen> {
  List sebepler = [];
  bool loading = true;
  bool duzenleyebilir = false;
  String _tur = 'void';

  static const _turler = {'void': 'Ürün Silme', 'indirim': 'İskonto', 'ikram': 'İkram', 'iptal': 'İptal'};
  static const _mavi = Color(0xFF4F46E5);

  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _card2 => _t.card2;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _sub2 => _t.sub2;
  Color get _line => _t.line;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.sebepler(auth.token!);
      if (!mounted) return;
      setState(() {
        sebepler = (res['sebepler'] as List?) ?? [];
        duzenleyebilir = res['duzenleyebilir'] == true;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _ekle() async {
    final ctrl = TextEditingController();
    final metin = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_turler[_tur]} sebebi ekle'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Örn: Müşteri beğenmedi')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Ekle')),
        ],
      ),
    );
    if (metin == null || metin.isEmpty || !mounted) return;
    final auth = context.read<AuthProvider>();
    final res = await Api.sebepEkle(auth.token!, _tur, metin);
    if (!mounted) return;
    if (res['ok'] == 1) {
      _yukle();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Eklenemedi')));
    }
  }

  Future<void> _sil(int id) async {
    final auth = context.read<AuthProvider>();
    await Api.sebepSil(auth.token!, id);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final liste = sebepler.where((s) => (s as Map)['tur'] == _tur).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0.5,
        title: Text('Sebep Yönetimi', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: _ink),
      ),
      floatingActionButton: duzenleyebilir
          ? FloatingActionButton.extended(onPressed: _ekle, backgroundColor: _mavi, icon: const Icon(Icons.add, color: Colors.white), label: const Text('Sebep Ekle', style: TextStyle(color: Colors.white)))
          : null,
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Tur sekmeleri
              Container(
                color: _card,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final e in _turler.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _tur = e.key),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _tur == e.key ? _mavi : _card2,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _tur == e.key ? _mavi : _line),
                              ),
                              child: Text(e.value, style: TextStyle(color: _tur == e.key ? Colors.white : _sub2, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!duzenleyebilir)
                Padding(padding: const EdgeInsets.all(12), child: Text('Sebepleri sadece işletme sahibi/müdürü düzenleyebilir.', style: TextStyle(color: _sub))),
              Expanded(
                child: liste.isEmpty
                    ? Center(child: Text('Bu türde sebep yok.', style: TextStyle(color: _sub)))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: liste.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final s = liste[i] as Map;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
                            child: Row(children: [
                              Expanded(child: Text(s['metin'].toString(), style: TextStyle(color: _ink, fontSize: 14))),
                              if (duzenleyebilir)
                                GestureDetector(onTap: () => _sil((s['id'] as num).toInt()), child: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 20)),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
