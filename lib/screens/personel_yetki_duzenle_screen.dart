import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Tek personelin yetkileri + limitleri (iskonto %, ikram ₺). Kişinin kendi
/// Personel detay sayfasından açılır. Düzenleme = sahip; müdür görüntüler.
class PersonelYetkiDuzenleScreen extends StatefulWidget {
  final int personelId;
  final String personelAd;
  const PersonelYetkiDuzenleScreen({super.key, required this.personelId, required this.personelAd});
  @override
  State<PersonelYetkiDuzenleScreen> createState() => _PersonelYetkiDuzenleScreenState();
}

const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _yesil = Color(0xFF10B981);

const _etiketler = {
  'adisyon_ac': 'Adisyon Aç',
  'adisyon_kapat': 'Ödeme Al / Masa Kapat',
  'adisyon_iptal': 'Adisyon İptal',
  'adisyon_bol': 'Adisyon Böl',
  'adisyon_birlestir': 'Masa Birleştir',
  'iskonto': 'İskonto Uygula',
  'ikram': 'İkram',
  'urun_sil': 'Ürün Sil (Void)',
  'fatura_kes': 'Fatura Kes',
  'geri_islem': 'Geriye Dönük İşlem',
  'maliyet_gor': 'Maliyet Görebilir',
  'rapor_gor': 'Rapor Görebilir',
};
const _gruplar = {
  '🧾 Adisyon': ['adisyon_ac', 'adisyon_kapat', 'adisyon_iptal', 'adisyon_bol', 'adisyon_birlestir'],
  '💸 Para & Kayıp': ['iskonto', 'ikram', 'urun_sil', 'fatura_kes'],
  '📊 Yönetim': ['geri_islem', 'maliyet_gor', 'rapor_gor'],
};

num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

class _PersonelYetkiDuzenleScreenState extends State<PersonelYetkiDuzenleScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _card2 => _t.card2;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _sub2 => _t.sub2;
  Color get _line => _t.line;

  Map<String, bool> yetkiler = {};
  double iskontoLimit = 0;
  final _ikramC = TextEditingController();
  bool loading = true;
  bool duzenleyebilir = false;
  bool kaydediliyor = false;
  String? hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() { loading = true; hata = null; });
    try {
      final res = await Api.personeller(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        final liste = (res['personeller'] as List?) ?? [];
        final kisi = liste.firstWhere((p) => _n((p as Map)['id']).toInt() == widget.personelId, orElse: () => null);
        if (kisi == null) { setState(() { hata = 'Personel bulunamadı'; loading = false; }); return; }
        final y = ((kisi as Map)['yetkiler'] as Map?) ?? {};
        setState(() {
          yetkiler = {for (final k in _etiketler.keys) k: y[k] == true};
          iskontoLimit = _n(kisi['iskonto_limit']).toDouble().clamp(0, 100);
          _ikramC.text = _n(kisi['ikram_limit']) > 0 ? _n(kisi['ikram_limit']).round().toString() : '';
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() { hata = res['hata']?.toString() ?? 'Alınamadı'; loading = false; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  Future<void> _kaydet() async {
    setState(() => kaydediliyor = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.yetkiKaydet(auth.token!, widget.personelId, yetkiler, iskontoLimit, double.tryParse(_ikramC.text.replaceAll(',', '.')) ?? 0);
      if (!mounted) return;
      if (res['ok'] == 1) {
        _uyar('Yetkiler kaydedildi');
        Navigator.of(context).pop();
      } else {
        setState(() => kaydediliyor = false);
        _uyar(res['hata']?.toString() ?? 'Kaydedilemedi');
      }
    } catch (_) {
      if (mounted) { setState(() => kaydediliyor = false); _uyar('Bağlantı hatası'); }
    }
  }

  @override
  Widget build(BuildContext context) {
    final acik = yetkiler.values.where((v) => v).length;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg, elevation: 0, iconTheme: IconThemeData(color: _ink),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.personelAd, style: TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.bold)),
          Text('Yetkiler & Limitler', style: TextStyle(color: _sub, fontSize: 11)),
        ]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: Color(0xFFF43F5E))))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  if (!duzenleyebilir)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF3B1D1D), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Yetkileri yalnızca işletme sahibi düzenleyebilir. Görüntülüyorsunuz.', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                    ),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      const Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text('$acik / ${_etiketler.length} yetki açık', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  for (final g in _gruplar.entries) _grup(g.key, g.value),
                  const SizedBox(height: 4),
                  _limitler(),
                  const SizedBox(height: 20),
                  if (duzenleyebilir)
                    SizedBox(width: double.infinity, child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: kaydediliyor ? null : _kaydet,
                      child: kaydediliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Yetkileri Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                    )),
                  const SizedBox(height: 30),
                ]),
    );
  }

  Widget _grup(String baslik, List<String> keys) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line), boxShadow: _t.golge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(baslik, style: TextStyle(color: _sub, fontSize: 12, fontWeight: FontWeight.bold))),
          for (final k in keys)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              activeThumbColor: _yesil,
              inactiveTrackColor: _card2,
              title: Text(_etiketler[k] ?? k, style: TextStyle(color: _ink, fontSize: 14)),
              value: yetkiler[k] ?? false,
              onChanged: duzenleyebilir ? (v) => setState(() => yetkiler[k] = v) : null,
            ),
        ]),
      );

  Widget _limitler() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line), boxShadow: _t.golge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Limitler', style: TextStyle(color: _ink, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Text('İskonto limiti', style: TextStyle(color: _sub2, fontSize: 13)),
            const Spacer(),
            Text('%${iskontoLimit.round()}', style: const TextStyle(color: _yesil, fontWeight: FontWeight.bold)),
          ]),
          Slider(
            value: iskontoLimit, min: 0, max: 100, divisions: 20, activeColor: _mor1, inactiveColor: _line,
            label: '%${iskontoLimit.round()}',
            onChanged: duzenleyebilir ? (v) => setState(() => iskontoLimit = v) : null,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _ikramC,
            enabled: duzenleyebilir,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: _ink),
            decoration: InputDecoration(
              labelText: 'İkram limiti (₺)', labelStyle: TextStyle(color: _sub),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _line)),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
            ),
          ),
        ]),
      );
}
