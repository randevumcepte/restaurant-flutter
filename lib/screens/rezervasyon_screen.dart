import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Online masa rezervasyonu — gün seçici + günlük özet + rezervasyon kartları
/// (onayla/geldi/gelmedi/iptal) + yeni rezervasyon ekleme.
class RezervasyonScreen extends StatefulWidget {
  const RezervasyonScreen({super.key});
  @override
  State<RezervasyonScreen> createState() => _RezervasyonScreenState();
}

class _RezervasyonScreenState extends State<RezervasyonScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String tarih = '';

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor = Color(0xFF9D5DC8);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String get _token => context.read<AuthProvider>().token!;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle({String? t}) async {
    setState(() => loading = true);
    try {
      final res = await Api.rezervasyonlar(_token, tarih: t ?? (tarih.isEmpty ? null : tarih));
      if (!mounted) return;
      setState(() {
        data = res;
        tarih = res['tarih']?.toString() ?? tarih;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _durum(int id, String durum) async {
    try {
      await Api.rezervasyonDurum(_token, id, durum);
      _yukle();
    } catch (_) {}
  }

  // ---- durum stili ----
  Color _renk(String d) => {
        'bekliyor': _amber, 'onaylandi': _mavi, 'geldi': _yesil, 'iptal': const Color(0xFF64748B), 'gelmedi': _kirmizi,
      }[d] ?? _mor;
  String _durumAd(String d) => {
        'bekliyor': 'BEKLİYOR', 'onaylandi': 'ONAYLI', 'geldi': 'GELDİ', 'iptal': 'İPTAL', 'gelmedi': 'GELMEDİ',
      }[d] ?? d.toUpperCase();
  String _kaynakIkon(String k) => {'web': '🌐', 'telefon': '📞', 'qr': '📱'}[k] ?? '•';

  // ---- gün etiketi ----
  static const _gunAd = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  String _gunKisa(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final bugun = DateTime.now();
    final fark = DateTime(d.year, d.month, d.day).difference(DateTime(bugun.year, bugun.month, bugun.day)).inDays;
    if (fark == 0) return 'Bugün';
    if (fark == 1) return 'Yarın';
    return _gunAd[d.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final rezervasyonlar = (data?['rezervasyonlar'] as List?) ?? [];
    final ozet = (data?['ozet'] as Map?) ?? {};
    final gunler = (data?['gunler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        title: const Text('Rezervasyonlar', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => _yukle(), icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _mor,
        onPressed: _ekleDialog,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Rezervasyon', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading && data == null
          ? const Center(child: CircularProgressIndicator(color: _mor))
          : Column(children: [
              // Gün seçici (7 gün)
              SizedBox(
                height: 74,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  children: [for (final g in gunler) _gunPill(g as Map)],
                ),
              ),
              // Özet
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Row(children: [
                  _ozetChip('Bekleyen', _n(ozet['bekleyen']).toInt(), _amber),
                  const SizedBox(width: 8),
                  _ozetChip('Onaylı', _n(ozet['onayli']).toInt(), _mavi),
                  const SizedBox(width: 8),
                  _ozetChip('Geldi', _n(ozet['geldi']).toInt(), _yesil),
                  const SizedBox(width: 8),
                  _ozetChip('Kişi', _n(ozet['kisi']).toInt(), _mor),
                ]),
              ),
              Expanded(
                child: rezervasyonlar.isEmpty
                    ? _bos()
                    : RefreshIndicator(
                        onRefresh: () => _yukle(),
                        color: _mor, backgroundColor: _card,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                          itemCount: rezervasyonlar.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _kart(rezervasyonlar[i] as Map),
                        ),
                      ),
              ),
            ]),
    );
  }

  Widget _gunPill(Map g) {
    final t = g['tarih'].toString();
    final aktif = t == tarih;
    final adet = _n(g['adet']).toInt();
    return GestureDetector(
      onTap: () { setState(() => tarih = t); _yukle(t: t); },
      child: Container(
        width: 62,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: aktif ? _mor : _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: aktif ? _mor : const Color(0xFF2D3752)),
        ),
        child: Stack(children: [
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_gunKisa(t), style: TextStyle(color: aktif ? Colors.white : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('${DateTime.tryParse(t)?.day ?? ''}', style: TextStyle(color: aktif ? Colors.white : const Color(0xFFCBD5E1), fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          if (adet > 0)
            Positioned(
              right: 5, top: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: aktif ? Colors.white24 : _mavi, borderRadius: BorderRadius.circular(20)),
                child: Text('$adet', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _ozetChip(String etiket, int deger, Color renk) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text('$deger', style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
            Text(etiket, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ]),
        ),
      );

  Widget _kart(Map r) {
    final durum = r['durum'].toString();
    final renk = _renk(durum);
    final pasif = durum == 'iptal' || durum == 'gelmedi';
    final not = (r['not']?.toString() ?? '');
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: renk, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Saat
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r['saat'].toString(), style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['ad'].toString(),
                    style: TextStyle(color: pasif ? const Color(0xFF64748B) : Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold,
                        decoration: pasif ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.people_outline, size: 13, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 3),
                  Text('${_n(r['kisi']).toInt()} kişi', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  const SizedBox(width: 10),
                  Text(_kaynakIkon(r['kaynak'].toString()), style: const TextStyle(fontSize: 12)),
                  if ((r['masa_ad']?.toString() ?? '').isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.table_restaurant, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 3),
                    Text('Masa ${r['masa_ad']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                  ],
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: Text(_durumAd(durum), style: TextStyle(color: renk, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ]),
          if (not.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('📝 $not', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12.5)),
            ),
          if ((r['telefon']?.toString() ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('📞 ${r['telefon']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
            ),
          // Aksiyonlar
          if (!pasif && durum != 'geldi') ...[
            const SizedBox(height: 12),
            Row(children: _aksiyonlar(r, durum)),
          ],
        ]),
      ),
    );
  }

  List<Widget> _aksiyonlar(Map r, String durum) {
    final id = _n(r['id']).toInt();
    final btns = <Widget>[];
    void ekle(String etiket, IconData ikon, Color renk, String yeni) {
      btns.add(Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            onPressed: () => _durum(id, yeni),
            style: OutlinedButton.styleFrom(
              foregroundColor: renk, side: BorderSide(color: renk.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 9), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: Icon(ikon, size: 15),
            label: Text(etiket, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ),
      ));
    }
    if (durum == 'bekliyor') {
      ekle('Onayla', Icons.check, _yesil, 'onaylandi');
      ekle('İptal', Icons.close, _kirmizi, 'iptal');
    } else if (durum == 'onaylandi') {
      ekle('Geldi', Icons.login, _yesil, 'geldi');
      ekle('Gelmedi', Icons.person_off, _kirmizi, 'gelmedi');
    }
    return btns;
  }

  Widget _bos() => ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.event_available, size: 56, color: Color(0xFF334155)),
        SizedBox(height: 12),
        Center(child: Text('Bu gün için rezervasyon yok.', style: TextStyle(color: Color(0xFF64748B)))),
      ]);

  // ---- Yeni rezervasyon ----
  Future<void> _ekleDialog() async {
    final adC = TextEditingController();
    final telC = TextEditingController();
    final notC = TextEditingController();
    int kisi = 2;
    String saat = '19:30';
    DateTime secilenTarih = DateTime.tryParse(tarih) ?? DateTime.now();
    final saatler = <String>[for (int h = 12; h <= 23; h++) for (final m in ['00', '30']) '${h.toString().padLeft(2, '0')}:$m'];

    await showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        InputDecoration dec(String h) => InputDecoration(
              labelText: h, labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
              filled: true, fillColor: const Color(0xFF0F1424),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            );
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 18, right: 18, top: 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            const Text('Yeni Rezervasyon', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: adC, style: const TextStyle(color: Colors.white), decoration: dec('Ad Soyad')),
            const SizedBox(height: 10),
            TextField(controller: telC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: dec('Telefon')),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Kişi:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: Slider(
                  value: kisi.toDouble(), min: 1, max: 16, divisions: 15, activeColor: _mor, label: '$kisi',
                  onChanged: (v) => setSt(() => kisi = v.round()),
                ),
              ),
              Text('$kisi', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx, initialDate: secilenTarih, firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 120)),
                    );
                    if (d != null) setSt(() => secilenTarih = d);
                  },
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0xFF2D3752)), padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.calendar_today, size: 15),
                  label: Text('${secilenTarih.day}.${secilenTarih.month}.${secilenTarih.year}', style: const TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: saat,
                  dropdownColor: _card,
                  decoration: dec('Saat'),
                  style: const TextStyle(color: Colors.white),
                  items: [for (final s in saatler) DropdownMenuItem(value: s, child: Text(s))],
                  onChanged: (v) => setSt(() => saat = v ?? saat),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(controller: notC, style: const TextStyle(color: Colors.white), decoration: dec('Not (opsiyonel)')),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (adC.text.trim().isEmpty) return;
                  final iso = '${secilenTarih.year}-${secilenTarih.month.toString().padLeft(2, '0')}-${secilenTarih.day.toString().padLeft(2, '0')}';
                  Navigator.pop(ctx);
                  try {
                    await Api.rezervasyonEkle(_token, ad: adC.text.trim(), telefon: telC.text.trim(), kisi: kisi, tarih: iso, saat: saat, not: notC.text.trim());
                    setState(() => tarih = iso);
                    _yukle(t: iso);
                  } catch (_) {}
                },
                child: const Text('Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 20),
          ]),
        );
      }),
    );
  }
}
