import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Personel Yetkileri — Kerzz tarzi granular yetki yonetimi (SADECE sahip duzenler).
class PersonelYetkileriScreen extends StatefulWidget {
  const PersonelYetkileriScreen({super.key});

  @override
  State<PersonelYetkileriScreen> createState() => _PersonelYetkileriScreenState();
}

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

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);

Color _rolRenk(String rol) {
  switch (rol) {
    case 'sahip':
      return _mor1;
    case 'mudur':
      return _mavi;
    case 'kasa':
      return const Color(0xFFD97706);
    case 'garson':
      return const Color(0xFF10B981);
    default:
      return const Color(0xFF64748B);
  }
}

String _rolAd(String rol) => {'sahip': 'Sahip', 'mudur': 'Müdür', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak'}[rol] ?? rol;

class _PersonelYetkileriScreenState extends State<PersonelYetkileriScreen> {
  List personeller = [];
  bool loading = true;
  bool duzenleyebilir = false;
  String? hata;

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
      final res = await Api.personeller(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          personeller = (res['personeller'] as List?) ?? [];
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() {
          hata = res['hata']?.toString() ?? 'Alınamadı';
          loading = false;
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  int _acikSayi(Map p) {
    final y = (p['yetkiler'] as Map?) ?? {};
    return y.values.where((v) => v == true).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Personel Yetkileri', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: Color(0xFFF43F5E))))
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: _mor1,
                  backgroundColor: _card,
                  child: ListView(
                    padding: const EdgeInsets.all(14),
                    children: [
                      if (!duzenleyebilir)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: const Color(0xFF3B1D1D), borderRadius: BorderRadius.circular(12)),
                          child: const Text('Yetkileri yalnızca işletme sahibi düzenleyebilir. Bu ekranı görüntülüyorsunuz.',
                              style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                        ),
                      for (final p in personeller) _personelKart(p as Map),
                    ],
                  ),
                ),
    );
  }

  Widget _personelKart(Map p) {
    final rol = p['rol'].toString();
    final renk = _rolRenk(rol);
    return GestureDetector(
      onTap: () async {
        final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => _YetkiDuzenle(personel: p, duzenleyebilir: duzenleyebilir),
        ));
        if (degisti == true) _yukle();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          CircleAvatar(
            radius: 20, backgroundColor: renk.withValues(alpha: 0.25),
            child: Text(p['ad'].toString().substring(0, 1).toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: renk.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text(_rolAd(rol), style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('${_acikSayi(p)} yetki', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                if ((p['yetkiler']?['iskonto'] == true))
                  Text('  ·  iskonto %${(p['iskonto_limit'] ?? 0).round()}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF64748B)),
        ]),
      ),
    );
  }
}

class _YetkiDuzenle extends StatefulWidget {
  final Map personel;
  final bool duzenleyebilir;
  const _YetkiDuzenle({required this.personel, required this.duzenleyebilir});

  @override
  State<_YetkiDuzenle> createState() => _YetkiDuzenleState();
}

class _YetkiDuzenleState extends State<_YetkiDuzenle> {
  late Map<String, bool> yetkiler;
  late double iskontoLimit;
  late double ikramLimit;
  bool kaydediyor = false;

  @override
  void initState() {
    super.initState();
    final y = (widget.personel['yetkiler'] as Map?) ?? {};
    yetkiler = {for (final e in _etiketler.keys) e: y[e] == true};
    iskontoLimit = ((widget.personel['iskonto_limit'] ?? 0) as num).toDouble();
    ikramLimit = ((widget.personel['ikram_limit'] ?? 0) as num).toDouble();
  }

  Future<void> _kaydet() async {
    setState(() => kaydediyor = true);
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.yetkiKaydet(auth.token!, (widget.personel['id'] as num).toInt(), yetkiler, iskontoLimit, ikramLimit);
      if (!mounted) return;
      if (res['ok'] == 1) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => kaydediyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Kaydedilemedi'), backgroundColor: _card));
      }
    } catch (_) {
      if (mounted) {
        setState(() => kaydediyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = widget.personel['rol'].toString();
    final renk = _rolRenk(rol);
    final duzen = widget.duzenleyebilir;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.personel['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              CircleAvatar(radius: 18, backgroundColor: renk.withValues(alpha: 0.25), child: Text(widget.personel['ad'].toString().substring(0, 1).toUpperCase(), style: TextStyle(color: renk, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              Text(_rolAd(rol), style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 14),
          for (final grup in _gruplar.entries) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: Text(grup.key, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            Container(
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (final k in grup.value) ...[
                  SwitchListTile(
                    value: yetkiler[k] ?? false,
                    onChanged: duzen ? (v) => setState(() => yetkiler[k] = v) : null,
                    activeThumbColor: renk,
                    title: Text(_etiketler[k]!, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14)),
                    dense: true,
                  ),
                  // Iskonto limiti (iskonto acikken)
                  if (k == 'iskonto' && (yetkiler['iskonto'] ?? false))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: Row(children: [
                        const Text('Limit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: iskontoLimit.clamp(0, 100),
                            min: 0, max: 100, divisions: 20,
                            label: '%${iskontoLimit.round()}',
                            activeColor: renk,
                            onChanged: duzen ? (v) => setState(() => iskontoLimit = v) : null,
                          ),
                        ),
                        SizedBox(width: 44, child: Text('%${iskontoLimit.round()}', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ]),
                    ),
                  // Ikram limiti (TL) — ikram acikken
                  if (k == 'ikram' && (yetkiler['ikram'] ?? false))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(children: [
                        const Text('Limit TL', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: ikramLimit.round().toString(),
                            enabled: duzen,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              isDense: true, filled: true, fillColor: const Color(0xFF0F1526),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              hintText: 'örn. 100', hintStyle: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            onChanged: (v) => ikramLimit = double.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Flexible(child: Text('üstü müdür onayı', style: TextStyle(color: Color(0xFF64748B), fontSize: 10))),
                      ]),
                    ),
                ],
              ]),
            ),
            const SizedBox(height: 14),
          ],
          if (duzen)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: kaydediyor ? null : _kaydet,
                style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: kaydediyor
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Düzenleme yetkisi yalnızca işletme sahibinde.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}
