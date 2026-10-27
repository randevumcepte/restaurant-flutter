import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// İK Self-Servis — personel kendi İK bilgilerini görür ve talep gönderir.
/// Backend: GET /api/ik/self , POST /api/ik/self/izin , POST /api/ik/self/avans
class IkSelfServisScreen extends StatefulWidget {
  const IkSelfServisScreen({super.key});
  @override
  State<IkSelfServisScreen> createState() => _IkSelfServisScreenState();
}

class _IkSelfServisScreenState extends State<IkSelfServisScreen> {
  bool _yukleniyor = true;
  String? _hata;
  Map<String, dynamic> _veri = {};

  static const Color _amber = Color(0xFFF59E0B);

  TemaProvider get _t => context.read<TemaProvider>();

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null || tok.isEmpty) {
      setState(() { _yukleniyor = false; _hata = 'Oturum bulunamadı'; });
      return;
    }
    try {
      final res = await Api.ikSelf(tok);
      if (res['ok'] == 1) {
        _veri = Map<String, dynamic>.from(res);
        _hata = null;
      } else {
        _hata = res['hata']?.toString() ?? 'Yüklenemedi';
      }
    } catch (_) {
      _hata = 'Bağlantı hatası';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  String _tl(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b₺';
  }

  String _gunFmt(String? iso) {
    if (iso == null || iso.length < 10) return iso ?? '';
    return '${iso.substring(8, 10)}.${iso.substring(5, 7)}.${iso.substring(0, 4)}';
  }

  Color _durumRenk(String d) =>
      d == 'onay' ? _t.yesil : (d == 'ret' ? _t.kirmizi : _amber);
  String _durumAd(String d) =>
      d == 'onay' ? 'Onaylandı' : (d == 'ret' ? 'Reddedildi' : 'Bekliyor');

  // ---------------- İZİN TALEBİ ----------------
  Future<void> _izinTalep() async {
    final t = _t;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    String tip = 'yillik';
    DateTime? bas, bit;
    final aciklama = TextEditingController();
    final sonuc = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: t.card,
          title: Text('İzin Talebi', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('İzin tipi', style: TextStyle(color: t.sub, fontSize: 12)),
              DropdownButton<String>(
                value: tip, isExpanded: true, dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 14),
                items: const [
                  DropdownMenuItem(value: 'yillik', child: Text('Yıllık izin')),
                  DropdownMenuItem(value: 'hastalik', child: Text('Hastalık (rapor)')),
                  DropdownMenuItem(value: 'ucretsiz', child: Text('Ücretsiz izin')),
                  DropdownMenuItem(value: 'mazeret', child: Text('Mazeret izni')),
                  DropdownMenuItem(value: 'dogum', child: Text('Doğum/babalık')),
                  DropdownMenuItem(value: 'diger', child: Text('Diğer')),
                ],
                onChanged: (v) => setD(() => tip = v ?? 'yillik'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _tarihBtn(t, 'Başlangıç', bas, () async {
                  final d = await _tarihSec(bas);
                  if (d != null) setD(() => bas = d);
                })),
                const SizedBox(width: 8),
                Expanded(child: _tarihBtn(t, 'Bitiş', bit, () async {
                  final d = await _tarihSec(bit ?? bas);
                  if (d != null) setD(() => bit = d);
                })),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: aciklama, style: TextStyle(color: t.ink),
                decoration: InputDecoration(
                  labelText: 'Açıklama (opsiyonel)', labelStyle: TextStyle(color: t.sub),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.line)),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: t.mor1),
              onPressed: () {
                if (bas == null || bit == null) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
    if (sonuc == true && bas != null && bit != null) {
      final res = await Api.ikSelfIzin(tok, tip: tip, baslangic: _iso(bas!), bitis: _iso(bit!), aciklama: aciklama.text.trim());
      _sonucGoster(res, 'İzin talebin gönderildi ✓ Yönetici onayına düştü.');
    }
  }

  // ---------------- AVANS TALEBİ ----------------
  Future<void> _avansTalep() async {
    final t = _t;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    final tutar = TextEditingController();
    final aciklama = TextEditingController();
    final sonuc = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Avans Talebi', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: tutar, keyboardType: TextInputType.number, style: TextStyle(color: t.ink),
            decoration: InputDecoration(
              labelText: 'Tutar (₺)', labelStyle: TextStyle(color: t.sub),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.line)),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: aciklama, style: TextStyle(color: t.ink),
            decoration: InputDecoration(
              labelText: 'Açıklama (opsiyonel)', labelStyle: TextStyle(color: t.sub),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.line)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.mor1),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    if (sonuc == true) {
      final tut = double.tryParse(tutar.text.trim().replaceAll(',', '.')) ?? 0;
      if (tut <= 0) return;
      final res = await Api.ikSelfAvans(tok, tutar: tut.toString(), aciklama: aciklama.text.trim());
      _sonucGoster(res, 'Avans talebin gönderildi ✓ Yönetici onayına düştü.');
    }
  }

  Future<DateTime?> _tarihSec(DateTime? baslangic) => showDatePicker(
        context: context,
        initialDate: baslangic ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 30)),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _tarihBtn(TemaProvider t, String etiket, DateTime? deger, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: t.line), borderRadius: BorderRadius.circular(8)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5)),
            const SizedBox(height: 2),
            Text(deger == null ? 'Seç' : '${deger.day}.${deger.month}.${deger.year}',
                style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  void _sonucGoster(Map<String, dynamic> res, String basariMesaj) {
    if (!mounted) return;
    final ok = res['ok'] == 1;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? basariMesaj : (res['hata']?.toString() ?? 'İşlem başarısız')),
      backgroundColor: ok ? _t.yesil : _t.kirmizi,
    ));
    if (ok) _getir();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    } else if (_hata != null) {
      govde = Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(_hata!, style: TextStyle(color: t.sub))));
    } else {
      final per = Map<String, dynamic>.from(_veri['personel'] ?? {});
      final izin = Map<String, dynamic>.from(_veri['izin'] ?? {});
      final bordro = Map<String, dynamic>.from(_veri['bordro'] ?? {});
      final vardiya = (_veri['vardiya'] as List?) ?? [];
      final izinGecmis = (izin['gecmis'] as List?) ?? [];
      final avansTalepleri = (_veri['avans_talepleri'] as List?) ?? [];

      govde = RefreshIndicator(
        onRefresh: _getir,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
          children: [
            Text('Merhaba ${per['ad'] ?? ''} 👋', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Kendi vardiyan, iznin, avansın ve bordro özetin', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 14),

            // ---- BU HAFTA VARDİYAM ----
            _kart(t, Icons.calendar_month, 'Bu Hafta Vardiyam', t.mavi, [
              if (vardiya.isEmpty)
                Text('Bu hafta için planlanmış vardiyan yok.', style: TextStyle(color: t.sub, fontSize: 13))
              else
                for (final v in vardiya)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(children: [
                      SizedBox(width: 56, child: Text('${v['gun']} ${v['tarih_kisa']}', style: TextStyle(color: t.sub, fontSize: 12.5))),
                      Text('${v['bas']}–${v['bit']}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                      if ((v['pozisyon'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(6)),
                          child: Text(v['pozisyon'].toString(), style: TextStyle(color: t.sub, fontSize: 11)),
                        ),
                      ],
                    ]),
                  ),
            ]),

            // ---- İZİN ----
            _kart(t, Icons.event_available, 'Yıllık İznim', t.yesil, [
              Row(children: [
                _miniKpi(t, '${izin['hak'] ?? 0}', 'Hak (gün)'),
                _miniKpi(t, _num(izin['kullanilan']), 'Kullanılan'),
                _miniKpi(t, _num(izin['kalan']), 'Kalan', renk: t.yesil),
              ]),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _izinTalep,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('İzin Talep Et'),
                style: OutlinedButton.styleFrom(foregroundColor: t.mor1, side: BorderSide(color: t.mor1)),
              )),
              if (izinGecmis.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final iz in izinGecmis.take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text('${_gunFmt(iz['baslangic'])} – ${_gunFmt(iz['bitis'])} · ${_num(iz['gun'])} gün',
                          style: TextStyle(color: t.sub, fontSize: 12.5))),
                      _rozet(iz['durum']?.toString() ?? 'talep'),
                    ]),
                  ),
              ],
            ]),

            // ---- BORDRO ----
            _kart(t, Icons.account_balance_wallet, 'Bordro Özetim (bu ay)', t.mor1, [
              _satir(t, 'Maaş', _tl(_d(bordro['maas']))),
              _satir(t, 'Bu ayki hakediş', _tl(_d(bordro['hakedis']))),
              _satir(t, 'Alınan avans', _tl(_d(bordro['avans'])), renk: _amber),
              _satir(t, 'Ödenen', _tl(_d(bordro['odenen']))),
              Divider(color: t.line),
              _satir(t, 'Kalan (net)', _tl(_d(bordro['net'])), renk: t.yesil, kalin: true),
            ]),

            // ---- AVANS ----
            _kart(t, Icons.payments, 'Avans Taleplerim', _amber, [
              SizedBox(width: double.infinity, child: OutlinedButton.icon(
                onPressed: _avansTalep,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Avans Talep Et'),
                style: OutlinedButton.styleFrom(foregroundColor: t.mor1, side: BorderSide(color: t.mor1)),
              )),
              if (avansTalepleri.isEmpty)
                Padding(padding: const EdgeInsets.only(top: 8), child: Text('Henüz avans talebin yok.', style: TextStyle(color: t.sub, fontSize: 12.5)))
              else
                for (final a in avansTalepleri)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text('${_tl(_d(a['tutar']))}${(a['aciklama'] ?? '').toString().isNotEmpty ? ' · ${a['aciklama']}' : ''}',
                          style: TextStyle(color: t.ink, fontSize: 13))),
                      Text('${_gunFmt(a['tarih'])}  ', style: TextStyle(color: t.sub, fontSize: 11)),
                      _rozet(a['durum']?.toString() ?? 'talep'),
                    ]),
                  ),
            ]),
          ],
        ),
      );
    }
    return MasaustuSayfa(
      baslik: 'İK Self-Servis',
      ikon: Icons.badge,
      geri: true,
      govde: govde,
    );
  }

  double _d(dynamic v) => v is num ? v.toDouble() : (double.tryParse('$v') ?? 0);
  String _num(dynamic v) {
    final d = _d(v);
    return d == d.roundToDouble() ? d.round().toString() : d.toString();
  }

  Widget _kart(TemaProvider t, IconData ikon, String baslik, Color renk, List<Widget> cocuklar) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line), boxShadow: t.golge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ikon, size: 18, color: renk),
            const SizedBox(width: 7),
            Text(baslik, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          ...cocuklar,
        ]),
      );

  Widget _miniKpi(TemaProvider t, String v, String l, {Color? renk}) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(color: renk ?? t.ink, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(l, style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      );

  Widget _satir(TemaProvider t, String l, String v, {Color? renk, bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: TextStyle(color: t.sub, fontSize: 13)),
          Text(v, style: TextStyle(color: renk ?? t.ink, fontSize: kalin ? 15 : 13.5, fontWeight: kalin ? FontWeight.bold : FontWeight.w600)),
        ]),
      );

  Widget _rozet(String durum) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(color: _durumRenk(durum), borderRadius: BorderRadius.circular(20)),
        child: Text(_durumAd(durum), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
      );
}
