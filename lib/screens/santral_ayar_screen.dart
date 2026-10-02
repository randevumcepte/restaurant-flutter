import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — Aktarma / Teslimat ayarları (native).
class SantralAyarScreen extends StatefulWidget {
  const SantralAyarScreen({super.key});
  @override
  State<SantralAyarScreen> createState() => _SantralAyarScreenState();
}

class _SantralAyarScreenState extends State<SantralAyarScreen> {
  bool _yukleniyor = true;
  bool _kaydediyor = false;
  int _subeId = 1;

  bool _aktif = false;
  String _strateji = 'hepsi';
  int _zil = 30;
  final _teslimat = TextEditingController();
  final List<Map<String, dynamic>> _hedefler = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() { _teslimat.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final r = await SantralApi.ayarGet(_subeId);
      if (r['ok'] == 1) {
        final a = Map<String, dynamic>.from(r['ayar']);
        _subeId = a['sube_id'] ?? _subeId;
        _aktif = (a['aktif'] ?? 0) == 1;
        _strateji = a['strateji'] == 'sirali' ? 'sirali' : 'hepsi';
        _zil = a['zil_sure'] ?? 30;
        _teslimat.text = '${a['teslimat_bolge'] ?? ''}';
        _hedefler.clear();
        for (final h in (a['hedefler'] as List? ?? [])) {
          final m = Map<String, dynamic>.from(h);
          _hedefler.add({'tip': m['tip'] ?? 'dahili', 'teknoloji': m['teknoloji'] ?? 'SIP', 'numara': '${m['numara'] ?? ''}', 'trunk': '${m['trunk'] ?? ''}'});
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    try {
      final r = await SantralApi.ayarKaydet(
        subeId: _subeId,
        aktif: _aktif,
        strateji: _strateji,
        hedefler: _hedefler.where((h) => '${h['numara']}'.trim().isNotEmpty).map((h) => {
          'tip': h['tip'], 'teknoloji': h['teknoloji'], 'numara': '${h['numara']}'.trim(), 'trunk': '${h['trunk']}'.trim(),
        }).toList(),
        zilSure: _zil,
        teslimatBolge: _teslimat.text.trim(),
      );
      if (mounted) _uyar(r['ok'] == 1 ? 'Kaydedildi ✓' : 'Hata: ${r['hata'] ?? ''}');
    } catch (e) {
      if (mounted) _uyar('Hata: $e');
    }
    if (mounted) setState(() => _kaydediyor = false);
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Santral — Aktarma / Teslimat',
      altBaslik: 'Çağrı aktarma hedefleri + AI teslimat bölgesi kuralı',
      ikon: Icons.call_split,
      araclar: [
        MButon(_kaydediyor ? 'Kaydediliyor...' : 'Kaydet', const Color(0xFF22C55E), _kaydediyor ? () {} : _kaydet, ikon: Icons.save),
      ],
      govde: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MBolumBaslik('Çağrı Aktarma', renk: Color(0xFF7C3AED)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _aktif,
                  activeThumbColor: const Color(0xFF7C3AED),
                  title: Text('Aktarma aktif', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('AI gerekince çağrıyı yetkiliye aktarır', style: TextStyle(color: t.sub, fontSize: 12)),
                  onChanged: (v) => setState(() => _aktif = v),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Strateji:', style: TextStyle(color: t.sub2, fontSize: 13)),
                  const SizedBox(width: 12),
                  _secimCip('Hepsini birden ara', 'hepsi', t),
                  const SizedBox(width: 8),
                  _secimCip('Sırayla ara', 'sirali', t),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Zil süresi (sn):', style: TextStyle(color: t.sub2, fontSize: 13)),
                  const SizedBox(width: 12),
                  SizedBox(width: 90, child: _kutu(
                    baslangic: '$_zil',
                    onChanged: (v) => _zil = int.tryParse(v) ?? 30,
                    klavye: TextInputType.number,
                  )),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: Text('Hedefler', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold))),
                  MButon('Hedef ekle', const Color(0xFF4F46E5), () => setState(() => _hedefler.add({'tip': 'dahili', 'teknoloji': 'SIP', 'numara': '', 'trunk': ''})), dolu: false, ikon: Icons.add),
                ]),
                const SizedBox(height: 8),
                if (_hedefler.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Henüz hedef yok. "Hedef ekle" ile dahili/dış numara tanımlayın.', style: TextStyle(color: t.sub, fontSize: 12.5))),
                for (int i = 0; i < _hedefler.length; i++) _hedefSatir(i, t),
              ])),
              const SizedBox(height: 14),
              MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MBolumBaslik('Teslimat Bölgesi', renk: Color(0xFF10B981)),
                Text('AI, teslimat alanınızı doğal dille buradan okur ve alan dışı adresleri kibarca reddeder. Örn: "Sadece Karşıyaka ve Bostanlı\'ya teslimat yapıyoruz; en fazla 5 km."',
                    style: TextStyle(color: t.sub, fontSize: 12.5)),
                const SizedBox(height: 10),
                _kutu(controller: _teslimat, cokSatir: 4, ipucu: 'Teslimat yaptığınız bölgeleri/mesafeyi yazın...'),
              ])),
            ]),
    );
  }

  Widget _hedefSatir(int i, TemaProvider t) {
    final h = _hedefler[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Row(children: [
        _mini(h['tip'], const {'dahili': 'Dahili', 'dis': 'Dış hat'}, (v) => setState(() => h['tip'] = v), t),
        const SizedBox(width: 8),
        _mini(h['teknoloji'], const {'SIP': 'SIP', 'PJSIP': 'PJSIP'}, (v) => setState(() => h['teknoloji'] = v), t),
        const SizedBox(width: 8),
        Expanded(child: _kutu(baslangic: '${h['numara']}', onChanged: (v) => h['numara'] = v, ipucu: 'Numara (örn 101 / 05xx)')),
        if (h['tip'] == 'dis') ...[
          const SizedBox(width: 8),
          Expanded(child: _kutu(baslangic: '${h['trunk']}', onChanged: (v) => h['trunk'] = v, ipucu: 'Trunk adı')),
        ],
        IconButton(onPressed: () => setState(() => _hedefler.removeAt(i)), icon: const Icon(Icons.delete_outline, color: Color(0xFFF43F5E), size: 20)),
      ]),
    );
  }

  Widget _secimCip(String etiket, String deger, TemaProvider t) {
    final secili = _strateji == deger;
    return GestureDetector(
      onTap: () => setState(() => _strateji = deger),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: secili ? const Color(0xFF7C3AED) : t.card2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: secili ? const Color(0xFF7C3AED) : t.line),
        ),
        child: Text(etiket, style: TextStyle(color: secili ? Colors.white : t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _mini(String deger, Map<String, String> secenek, ValueChanged<String> onChanged, TemaProvider t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: secenek.containsKey(deger) ? deger : secenek.keys.first,
          isDense: true,
          dropdownColor: t.card,
          style: TextStyle(color: t.ink, fontSize: 12.5),
          items: secenek.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }

  Widget _kutu({TextEditingController? controller, String? baslangic, ValueChanged<String>? onChanged, String? ipucu, int cokSatir = 1, TextInputType? klavye}) {
    final t = context.read<TemaProvider>();
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? baslangic : null,
      onChanged: onChanged,
      maxLines: cokSatir,
      keyboardType: klavye,
      style: TextStyle(color: t.ink, fontSize: 13),
      decoration: InputDecoration(
        hintText: ipucu,
        hintStyle: TextStyle(color: t.sub, fontSize: 12.5),
        isDense: true,
        filled: true,
        fillColor: t.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
      ),
    );
  }
}
