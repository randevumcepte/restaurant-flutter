import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Giderler — aylık işletme giderleri (kira/fatura/malzeme/maaş/vergi/diğer).
/// Personel avans/ödemeleri OTOMATİK 'maaş' kategorisinde görünür. Ekleme = sahip.
class GiderScreen extends StatefulWidget {
  const GiderScreen({super.key});
  @override
  State<GiderScreen> createState() => _GiderScreenState();
}

const _bg = Color(0xFF0B1020);
const _card = Color(0xFF161C2E);
const _mor1 = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _kirmizi = Color(0xFFF43F5E);
const _gri = Color(0xFF94A3B8);

const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

const _katAd = {'kira': 'Kira', 'fatura': 'Fatura', 'malzeme': 'Malzeme', 'maas': 'Maaş / Personel', 'vergi': 'Vergi', 'diger': 'Diğer'};
const _katIkon = {'kira': Icons.home_work_outlined, 'fatura': Icons.receipt_long_outlined, 'malzeme': Icons.inventory_2_outlined, 'maas': Icons.people_alt_outlined, 'vergi': Icons.account_balance_outlined, 'diger': Icons.more_horiz};
Color _katRenk(String k) => {'kira': const Color(0xFFD97706), 'fatura': _mavi, 'malzeme': const Color(0xFF10B981), 'maas': _mor1, 'vergi': _kirmizi}[k] ?? _gri;

final _fmt = NumberFormat.decimalPattern('tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
String _tl(dynamic v) => '${_fmt.format(_n(v).round())}TL';

class _GiderScreenState extends State<GiderScreen> {
  List giderler = [];
  Map kategoriler = {};
  double toplam = 0;
  bool loading = true;
  bool duzenleyebilir = false;
  DateTime _ay = DateTime.now();

  String get _ayParam => '${_ay.year}-${_ay.month.toString().padLeft(2, '0')}';
  String get _ayMetin => '${_aylar[_ay.month]} ${_ay.year}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.giderler(auth.token!, ay: _ayParam);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          giderler = (res['giderler'] as List?) ?? [];
          kategoriler = (res['kategoriler'] as Map?) ?? {};
          toplam = _n(res['toplam']).toDouble();
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

  void _ayDegis(int delta) {
    final yeni = DateTime(_ay.year, _ay.month + delta);
    if (yeni.isAfter(DateTime(DateTime.now().year, DateTime.now().month))) return;
    setState(() => _ay = yeni);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Giderler', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      // Bu ekrana zaten sadece patron (sahip/mudur) ulasabilir -> buton daima gorunur.
      // Backend gider-ekle de patron seviyesinde; yetkisiz durumda uc zaten reddeder.
      floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _mor1, onPressed: _ekleDialog,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Gider', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              Container(
                color: _bg,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: () => _ayDegis(-1), icon: const Icon(Icons.chevron_left, color: _mor1)),
                  Text(_ayMetin, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  IconButton(onPressed: () => _ayDegis(1), icon: const Icon(Icons.chevron_right, color: _mor1)),
                ]),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle, color: _mor1, backgroundColor: _card,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    _toplamKart(),
                    const SizedBox(height: 12),
                    if (giderler.isEmpty)
                      const Padding(padding: EdgeInsets.only(top: 30), child: Center(child: Text('Bu ay gider kaydı yok.', style: TextStyle(color: _gri))))
                    else
                      for (final g in giderler) _giderSatir(g as Map),
                    const SizedBox(height: 80),
                  ]),
                ),
              ),
            ]),
    );
  }

  Widget _toplamKart() {
    final kats = kategoriler.entries.toList()..sort((a, b) => _n(b.value).compareTo(_n(a.value)));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bu Ay Toplam Gider', style: TextStyle(color: Colors.white70, fontSize: 12)),
        Text(_tl(toplam), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        if (kats.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kats)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                child: Text('${_katAd[e.key] ?? e.key}: ${_tl(e.value)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _giderSatir(Map g) {
    final kat = g['kategori'].toString();
    final renk = _katRenk(kat);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF232B42))),
      child: Row(children: [
        CircleAvatar(radius: 18, backgroundColor: renk.withValues(alpha: 0.18), child: Icon(_katIkon[kat] ?? Icons.more_horiz, color: renk, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text((g['aciklama']?.toString().isNotEmpty ?? false) ? g['aciklama'].toString() : (_katAd[kat] ?? kat), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('${_katAd[kat] ?? kat} · ${g['tarih']}', style: const TextStyle(color: _gri, fontSize: 11)),
        ])),
        Text(_tl(g['tutar']), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        if (duzenleyebilir && kat != 'maas')
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32), onPressed: () => _sil(_n(g['id']).toInt()), icon: const Icon(Icons.close, color: _gri, size: 18)),
      ]),
    );
  }

  Future<void> _sil(int id) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.giderSil(auth.token!, id);
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Silinemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  Future<void> _ekleDialog() async {
    final tutarC = TextEditingController();
    final aciklamaC = TextEditingController();
    String kategori = 'kira';
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: _bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFF2D3752), borderRadius: BorderRadius.circular(2))),
            const Text('Yeni Gider', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: _dec('Kategori'),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: kategori, isDense: true, isExpanded: true, dropdownColor: _card, style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'kira', child: Text('Kira')),
                  DropdownMenuItem(value: 'fatura', child: Text('Fatura (elektrik/su/doğalgaz)')),
                  DropdownMenuItem(value: 'malzeme', child: Text('Malzeme / Alım')),
                  DropdownMenuItem(value: 'vergi', child: Text('Vergi / Resmi')),
                  DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                ],
                onChanged: (v) { if (v != null) setS(() => kategori = v); },
              )),
            ),
            const SizedBox(height: 10),
            TextField(controller: tutarC, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: Colors.white), decoration: _dec('Tutar (TL)')),
            const SizedBox(height: 10),
            TextField(controller: aciklamaC, style: const TextStyle(color: Colors.white), decoration: _dec('Açıklama (opsiyonel)')),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
            )),
          ]),
        ),
      ),
    );
    if (ok != true) return;
    final tutar = double.tryParse(tutarC.text.replaceAll(',', '.')) ?? 0;
    if (tutar <= 0) { _uyar('Geçerli bir tutar girin'); return; }
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.giderEkle(auth.token!, kategori, tutar, aciklama: aciklamaC.text.trim());
      if (!mounted) return;
      if (res['ok'] == 1) { _yukle(); } else { _uyar(res['hata']?.toString() ?? 'Kaydedilemedi'); }
    } catch (_) { _uyar('Bağlantı hatası'); }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _gri),
        enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2D3752))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: _mor1)),
      );
}
