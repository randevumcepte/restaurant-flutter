import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';

/// Tedarikçiler — cari bilgi + toplam alış. Ekle/düzenle/sil = sahip.
class TedarikciScreen extends StatefulWidget {
  const TedarikciScreen({super.key});
  @override
  State<TedarikciScreen> createState() => _TedarikciScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _gri = Color(0xFF94A3B8);
final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';

InputDecoration _dec(String label) => InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: _gri),
      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
    );

class _TedarikciScreenState extends State<TedarikciScreen> {
  List tedarikciler = [];
  bool loading = true;
  bool duzenleyebilir = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.tedarikciler(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          tedarikciler = (res['tedarikciler'] as List?) ?? [];
          duzenleyebilir = res['duzenleyebilir'] == true;
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Tedarikçiler', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
      floatingActionButton: duzenleyebilir ? FloatingActionButton.extended(backgroundColor: _mor1, onPressed: () => _form(null), icon: const Icon(Icons.add, color: Colors.white), label: const Text('Tedarikçi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))) : null,
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : RefreshIndicator(onRefresh: _yukle, color: _mor1, backgroundColor: _card, child: ListView(padding: const EdgeInsets.all(14), children: [
              if (tedarikciler.isEmpty)
                const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('Tedarikçi yok. Sağ alttan ekleyin.', style: TextStyle(color: _gri))))
              else
                for (final t in tedarikciler) _kart(t as Map),
              const SizedBox(height: 80),
            ])),
    );
  }

  // ---- MASAÜSTÜ (PC/tablet) ----
  Widget _masaustu(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final toplamAlis = tedarikciler.fold<num>(0, (s, e) => s + _n((e as Map)['toplam_alis']));
    final toplamFatura = tedarikciler.fold<num>(0, (s, e) => s + _n((e as Map)['fatura_sayisi']));
    return MasaustuSayfa(
      baslik: 'Tedarikçiler',
      ikon: Icons.local_shipping_outlined,
      altBaslik: '${tedarikciler.length} tedarikçi',
      araclar: [
        if (duzenleyebilir) MButon('Yeni Tedarikçi', t.mor1, () => _form(null), ikon: Icons.add),
      ],
      govde: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: t.mor1,
              backgroundColor: t.card,
              child: ListView(padding: const EdgeInsets.all(24), children: [
                if (tedarikciler.isNotEmpty) ...[
                  MIstatKart(
                    baslik: 'Toplam Alış',
                    renk: t.mor1,
                    buyukDeger: _tl(toplamAlis),
                    satirlar: [
                      MIstatSatir('Tedarikçi adedi', '${tedarikciler.length}'),
                      MIstatSatir('Toplam fatura', '${toplamFatura.toInt()}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                tedarikciler.isEmpty
                    ? MKart(child: Text('Tedarikçi yok.${duzenleyebilir ? ' Yukarıdan ekleyin.' : ''}', style: TextStyle(color: t.sub)))
                    : MTablo(
                        sutunlar: const [
                          MSutun('Tedarikçi', flex: 30),
                          MSutun('Telefon', flex: 20),
                          MSutun('Toplam Alış', flex: 20, hiza: TextAlign.right),
                          MSutun('Fatura', flex: 14, hiza: TextAlign.right),
                          MSutun('', flex: 16, hiza: TextAlign.right),
                        ],
                        satirlar: [
                          for (final e in tedarikciler) _masaustuSatir(t, e as Map),
                        ],
                      ),
                const SizedBox(height: 40),
              ]),
            ),
    );
  }

  List<Widget> _masaustuSatir(TemaProvider t, Map e) {
    final ad = e['ad'].toString();
    final tel = e['telefon']?.toString() ?? '';
    return [
      // Tedarikçi: avatar baş harf + ad
      Row(children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: t.mor1.withValues(alpha: 0.20),
          child: Text(ad.isNotEmpty ? ad.characters.first.toUpperCase() : '?', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(ad, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
      ]),
      // Telefon
      Text(tel.isNotEmpty ? tel : '—', style: TextStyle(color: tel.isNotEmpty ? t.sub2 : t.sub, fontSize: 13)),
      // Toplam alış
      Text(_tl(e['toplam_alis']), textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.bold)),
      // Fatura sayısı
      Text('${_n(e['fatura_sayisi']).toInt()}', textAlign: TextAlign.right, style: TextStyle(color: t.sub, fontSize: 13)),
      // Aksiyonlar (Düzenle / Sil) — sadece yetkili
      Align(
        alignment: Alignment.centerRight,
        child: duzenleyebilir
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                MButon('Düzenle', t.sub2, () => _form(e), dolu: false, ikon: Icons.edit_outlined),
                const SizedBox(width: 6),
                MButon('Sil', t.kirmizi, () => _silOnay(e), dolu: false, ikon: Icons.delete_outline),
              ])
            : Text('—', style: TextStyle(color: t.sub)),
      ),
    ];
  }

  Future<void> _silOnay(Map e) async {
    final t = context.read<TemaProvider>();
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Tedarikçi silinsin mi?', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        content: Text('${e['ad']} silinecek. Bu işlem geri alınamaz.', style: TextStyle(color: t.sub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub2))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: t.kirmizi), onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay == true) await _sil(e);
  }

  Widget _kart(Map t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF232B42))),
        child: Row(children: [
          CircleAvatar(radius: 20, backgroundColor: _mor1.withValues(alpha: 0.18), child: Text(t['ad'].toString().characters.first.toUpperCase(), style: const TextStyle(color: _mor1, fontWeight: FontWeight.bold, fontSize: 18))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text('${(t['telefon']?.toString() ?? '').isNotEmpty ? '${t['telefon']} · ' : ''}${_n(t['fatura_sayisi']).toInt()} fatura', style: const TextStyle(color: _gri, fontSize: 12)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_tl(t['toplam_alis']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('toplam alış', style: TextStyle(color: _gri, fontSize: 10)),
          ]),
          if (duzenleyebilir)
            PopupMenuButton<String>(
              color: _card, icon: const Icon(Icons.more_vert, color: _gri, size: 20),
              onSelected: (v) { if (v == 'duzenle') { _form(t); } else { _sil(t); } },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle', style: TextStyle(color: Colors.white))),
                PopupMenuItem(value: 'sil', child: Text('Sil', style: TextStyle(color: Color(0xFFF43F5E)))),
              ],
            ),
        ]),
      );

  Future<void> _sil(Map t) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.tedarikciSil(auth.token!, _n(t['id']).toInt());
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Silinemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _form(Map? t) async {
    final adC = TextEditingController(text: t?['ad']?.toString() ?? '');
    final telC = TextEditingController(text: t?['telefon']?.toString() ?? '');
    final aciklamaC = TextEditingController(text: t?['aciklama']?.toString() ?? '');
    final yeni = t == null;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
          Text(yeni ? 'Yeni Tedarikçi' : 'Tedarikçi Düzenle', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          TextField(controller: adC, style: const TextStyle(color: Colors.white), decoration: _dec('Firma / Kişi adı')),
          const SizedBox(height: 10),
          TextField(controller: telC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: _dec('Telefon')),
          const SizedBox(height: 10),
          TextField(controller: aciklamaC, style: const TextStyle(color: Colors.white), decoration: _dec('Not (opsiyonel)')),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
    if (ok != true) return;
    if (adC.text.trim().isEmpty) { _uyar('Ad boş olamaz'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.tedarikciKaydet(auth.token!, id: yeni ? null : _n(t['id']).toInt(), ad: adC.text.trim(), telefon: telC.text.trim(), aciklama: aciklamaC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Kaydedilemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }
}
