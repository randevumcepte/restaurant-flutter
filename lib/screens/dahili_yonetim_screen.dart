import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — Dahili Yönetimi (FreePBX GraphQL üzerinden SIP extension).
class DahiliYonetimScreen extends StatefulWidget {
  const DahiliYonetimScreen({super.key});
  @override
  State<DahiliYonetimScreen> createState() => _DahiliYonetimScreenState();
}

class _DahiliYonetimScreenState extends State<DahiliYonetimScreen> {
  List<Map<String, dynamic>> _liste = [];
  bool _yukleniyor = true;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final r = await SantralApi.dahiliListe();
      if (r['ok'] == 1) {
        _liste = ((r['liste'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _hata = null;
      } else {
        _hata = '${r['hata'] ?? 'FreePBX API ayarlı değil'}';
      }
    } catch (e) {
      _hata = '$e';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _ekleDialog() async {
    final numara = TextEditingController();
    final ad = TextEditingController();
    final sifre = TextEditingController();
    final ok = await _formDialog('Yeni Dahili (SIP Extension)', [
      _dlgKutu(numara, 'Dahili numara (örn 101)', klavye: TextInputType.number),
      _dlgKutu(ad, 'Ad (örn Kasa, Mutfak)'),
      _dlgKutu(sifre, 'SIP şifre'),
    ]);
    if (ok != true) return;
    final r = await SantralApi.dahiliEkle(numara.text.trim(), ad.text.trim(), sifre.text.trim());
    _uyar(r['ok'] == 1 || r['basarili'] == true ? 'Dahili eklendi ✓' : 'Hata: ${r['hata'] ?? r['message'] ?? 'eklenemedi'}');
    _yukle();
  }

  Future<void> _sifreDialog(String numara) async {
    final sifre = TextEditingController();
    final ok = await _formDialog('$numara — Yeni Şifre', [_dlgKutu(sifre, 'Yeni SIP şifre')]);
    if (ok != true) return;
    final r = await SantralApi.dahiliSifre(numara, sifre.text.trim());
    _uyar(r['ok'] == 1 || r['basarili'] == true ? 'Şifre güncellendi ✓' : 'Hata: ${r['hata'] ?? 'güncellenemedi'}');
  }

  Future<void> _sil(String numara) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$numara silinsin mi?'),
        content: const Text('Bu dahili FreePBX\'ten kaldırılacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)), onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    final r = await SantralApi.dahiliSil(numara);
    _uyar(r['ok'] == 1 || r['basarili'] == true ? 'Silindi ✓' : 'Hata: ${r['hata'] ?? 'silinemedi'}');
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Dahili Yönetimi',
      altBaslik: 'FreePBX SIP dahilileri — ekle / şifre / sil',
      ikon: Icons.dialpad,
      araclar: [
        MButon('Yenile', const Color(0xFF4F46E5), _yukle, dolu: false, ikon: Icons.refresh),
        const SizedBox(width: 8),
        MButon('Yeni Dahili', const Color(0xFF22C55E), _ekleDialog, ikon: Icons.add),
      ],
      govde: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : _hata != null
              ? _hataKart(t)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: _liste.isEmpty
                      ? Center(child: Text('Dahili yok. "Yeni Dahili" ile ekleyin.', style: TextStyle(color: t.sub)))
                      : ListView(children: [
                          MBolumBaslik('Dahililer', renk: const Color(0xFF0EA5E9), sayi: _liste.length),
                          MTablo(
                            sutunlar: const [MSutun('Dahili', flex: 6), MSutun('Ad', flex: 10), MSutun('İşlem', flex: 8, hiza: TextAlign.right)],
                            satirlar: _liste.map((x) => [
                              Text('${x['numara']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
                              Text('${x['ad'] ?? ''}', style: TextStyle(color: t.sub2)),
                              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                MButon('Şifre', const Color(0xFFF59E0B), () => _sifreDialog('${x['numara']}'), dolu: false, ikon: Icons.key),
                                const SizedBox(width: 6),
                                MButon('Sil', const Color(0xFFF43F5E), () => _sil('${x['numara']}'), dolu: false, ikon: Icons.delete_outline),
                              ]),
                            ]).toList(),
                          ),
                        ]),
                ),
    );
  }

  Widget _hataKart(TemaProvider t) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.settings_input_antenna, size: 44, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            Text(_hata!, textAlign: TextAlign.center, style: TextStyle(color: t.sub2, fontSize: 14)),
            const SizedBox(height: 8),
            Text('FreePBX API ayarını "FreePBX API" ekranından yapın.', textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5)),
          ]),
        ),
      );

  Future<bool?> _formDialog(String baslik, List<Widget> alanlar) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(baslik),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final a in alanlar) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: a),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet')),
        ],
      ),
    );
  }

  Widget _dlgKutu(TextEditingController c, String ipucu, {TextInputType? klavye}) => TextField(
        controller: c,
        keyboardType: klavye,
        decoration: InputDecoration(labelText: ipucu, border: const OutlineInputBorder(), isDense: true),
      );
}
