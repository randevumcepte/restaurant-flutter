import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'ai_analiz_sheet.dart';

/// Kart tiklama -> drill-down detay (Kerzz BOSS tarzi).
/// tip: urun | kayip | acik
class DetayScreen extends StatefulWidget {
  final String tip;
  final int? id;
  final String? alt;
  final String period;
  final String baslikFallback;
  const DetayScreen({super.key, required this.tip, this.id, this.alt, this.period = 'haftalik', this.baslikFallback = 'Detay'});

  @override
  State<DetayScreen> createState() => _DetayScreenState();
}

class _DetayScreenState extends State<DetayScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  String? hata;
  final _f = NumberFormat.decimalPattern('tr');

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mor2 = Color(0xFF9D5DC8);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tam(num v) => '₺${_f.format(v.round())}';

  // Detaydan detaya gecis (koyu FADE -> beyaz parlama olmaz)
  void _push({required String tip, int? id, String baslik = 'Detay'}) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 170),
      opaque: true,
      barrierColor: _bg,
      pageBuilder: (_, _, _) => DetayScreen(tip: tip, id: id, period: widget.period, baslikFallback: baslik),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }
  String _k(num v) {
    final a = v.abs();
    if (a >= 1000000) return '₺${(v / 1000000).toStringAsFixed(2)}M';
    if (a >= 1000) return '₺${(v / 1000).toStringAsFixed(1)}K';
    return '₺${_f.format(v.round())}';
  }

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
      final res = await Api.detay(auth.token!, tip: widget.tip, id: widget.id, alt: widget.alt, period: widget.period);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          d = res;
          loading = false;
        });
      } else {
        setState(() {
          hata = res['hata']?.toString() ?? 'Detay alınamadı';
          loading = false;
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baslik = d?['baslik']?.toString() ?? widget.baslikFallback;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor2))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: _kirmizi)))
              : RefreshIndicator(
                  onRefresh: _yukle, color: _mor2, backgroundColor: _card,
                  child: ListView(padding: const EdgeInsets.all(14), children: [..._aiOnek(), ..._icerik()]),
                ),
    );
  }

  // ✨ AI Yorumu (kural motoru) - detayin en ustunde
  List<Widget> _aiOnek() {
    final ai = (d?['ai'] as List?) ?? [];
    if (ai.isEmpty) return [];
    return [_aiKart(ai), const SizedBox(height: 12)];
  }

  Widget _aiKart(List ai) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF241B4D), Color(0xFF1E2647)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _mor2.withValues(alpha: 0.45)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Text('✨', style: TextStyle(fontSize: 15)),
            SizedBox(width: 6),
            Text('AI Yorumu', style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          for (final a in ai) _aiSatir(a as Map),
        ]),
      );

  Widget _aiSatir(Map a) {
    final s = a['seviye']?.toString() ?? 'bilgi';
    final renk = s == 'riskli' ? _kirmizi : (s == 'iyi' ? _yesil : _mavi);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 5, right: 8), width: 7, height: 7, decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
        Expanded(child: Text(a['mesaj'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, height: 1.35))),
      ]),
    );
  }

  List<Widget> _icerik() {
    switch (widget.tip) {
      case 'urun':
        return _urun();
      case 'kayip':
        return _kayip();
      case 'acik':
        return _acik();
      case 'maliyet':
        return _maliyet();
      case 'kapali':
        return _kapali();
      case 'adisyon':
        return _adisyon();
      case 'musteri':
        return _musteri();
      default:
        return [const Text('—', style: TextStyle(color: Colors.white))];
    }
  }

  // ---------------- URUN ----------------
  List<Widget> _urun() {
    final ozet = (d!['ozet'] as Map?) ?? {};
    final recete = (d!['recete'] as List?) ?? [];
    final garsonlar = (d!['garsonlar'] as List?) ?? [];
    final gunluk = (d!['gunluk'] as List?) ?? [];
    final maliyetYuzde = _n(d!['maliyetYuzde']).toInt();
    final renk = maliyetYuzde >= 35 ? _kirmizi : (maliyetYuzde >= 25 ? const Color(0xFFF59E0B) : _yesil);

    return [
      // Ozet chip grid
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: ozet.entries.map((e) => _statKart(e.key, e.value.toString())).toList(),
      ),
      const SizedBox(height: 14),
      // Recete maliyet
      _kutu('🧾 Reçete & Maliyet', [
        if (recete.isEmpty)
          const Text('Bu ürün için reçete tanımlı değil (tahmini maliyet kullanıldı).', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
        else
          for (final r in recete)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((r as Map)['malzeme'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(r['miktar']) % 1 == 0 ? _n(r['miktar']).toInt() : _n(r['miktar'])} ${r['birim']}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                SizedBox(width: 70, child: Text(_tam(_n(r['maliyet'])), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ),
        const Divider(color: Color(0xFF243049), height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('1 porsiyon birim maliyet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(_tam(_n(d!['receteBirimMaliyet'])), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Dönem toplam maliyet', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
          Row(children: [
            Text(_tam(_n(d!['toplamMaliyet'])), style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
              child: Text('%$maliyetYuzde', style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ]),
      const SizedBox(height: 14),
      // En cok satan garson
      _kutu('🏆 En Çok Satan Personel', [
        if (garsonlar.isEmpty)
          const Text('Kayıt yok', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (int i = 0; i < garsonlar.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Text('${i + 1}.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: Text((garsonlar[i] as Map)['ad'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n((garsonlar[i] as Map)['adet']).toInt()} adet', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_k(_n((garsonlar[i] as Map)['ciro'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
      ]),
      const SizedBox(height: 14),
      // Gunluk adet grafik
      _kutu('📈 Son 10 Gün (adet)', [_miniBar(gunluk, birim: '')]),
    ];
  }

  // ---------------- KAYIP ----------------
  List<Widget> _kayip() {
    final kayitlar = (d!['kayitlar'] as List?) ?? [];
    final sebepler = (d!['sebepler'] as List?) ?? [];
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${_n(d!['adet']).toInt()} kayıt', _kirmizi),
      const SizedBox(height: 14),
      if (sebepler.isNotEmpty) ...[
        _kutu('Sebep Dağılımı', [
          for (final s in sebepler)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((s as Map)['sebep'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(s['adet']).toInt()}×', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_tam(_n(s['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      _kutu('Kayıtlar', [
        if (kayitlar.isEmpty)
          const Text('Bu dönemde kayıt yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kayitlar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((k as Map)['garson'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${k['sebep']} · ${k['zaman']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ]),
                ),
                Text(_tam(_n(k['tutar'])), style: const TextStyle(color: _kirmizi, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
      ]),
    ];
  }

  // ---------------- ACIK ADISYON ----------------
  List<Widget> _acik() {
    final kayitlar = (d!['kayitlar'] as List?) ?? [];
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${_n(d!['adet']).toInt()} açık adisyon', _mavi),
      const SizedBox(height: 14),
      _kutu('Açık Masalar', [
        if (kayitlar.isEmpty)
          const Text('Şu an açık adisyon yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kayitlar)
            _adisyonRow(k as Map, _mavi.withValues(alpha: 0.2), const Color(0xFFC4B5FD),
                '${k['musteri'] != null ? '👤 ${k['musteri']} · ' : ''}${k['kalem']} ürün · ${k['misafir']} kişi · ${k['sure_dk']} dk'),
      ]),
    ];
  }

  // ---------------- FOOD-COST (MALIYET) ----------------
  List<Widget> _maliyet() {
    final urunler = (d!['urunler'] as List?) ?? [];
    final yuzde = _n(d!['maliyetYuzde']).toInt();
    final renk = yuzde >= 35 ? _kirmizi : (yuzde >= 25 ? const Color(0xFFF59E0B) : _yesil);
    return [
      _ozetSerit('${_tam(_n(d!['toplamMaliyet']))}  ·  %$yuzde', 'toplam food-cost', renk),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statKart('Satış', _tam(_n(d!['toplamSatis'])))),
        const SizedBox(width: 10),
        Expanded(child: _statKart('Brüt Kâr', _tam(_n(d!['brutKar'])))),
      ]),
      const SizedBox(height: 14),
      _kutu('🧾 Ürün Bazında Maliyet (dokunun → reçete)', [
        if (urunler.isEmpty)
          const Text('Bu dönemde satış yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final u in urunler)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _push(tip: 'urun', id: _n((u as Map)['urun_id']).toInt(), baslik: u['ad'].toString()),
              child: _maliyetSatir(u),
            ),
      ]),
    ];
  }

  Widget _maliyetSatir(Map u) {
    final y = _n(u['yuzde']).toInt();
    final renk = y >= 35 ? _kirmizi : (y >= 25 ? const Color(0xFFF59E0B) : _yesil);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 40, padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFF243049), borderRadius: BorderRadius.circular(6)),
          child: Text('${_n(u['adet']).toInt()}×', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(u['ad'].toString(), overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_tam(_n(u['maliyet'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text('satış ${_k(_n(u['satis']))}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
        ]),
        const SizedBox(width: 8),
        Container(
          width: 38, padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
          child: Text('%$y', textAlign: TextAlign.center, style: TextStyle(color: renk, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }

  // ---------------- KAPANAN ADISYON ----------------
  List<Widget> _kapali() {
    final kayitlar = (d!['kayitlar'] as List?) ?? [];
    final odeme = (d!['odemeDagilim'] as List?) ?? [];
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${_n(d!['adet']).toInt()} kapanan adisyon', _yesil),
      const SizedBox(height: 14),
      if (odeme.isNotEmpty) ...[
        _kutu('💳 Ödeme Dağılımı', [
          for (final o in odeme)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((o as Map)['tip'].toString().toUpperCase(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(o['adet']).toInt()} işlem', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_k(_n(o['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      _kutu('Kapanan Adisyonlar', [
        if (kayitlar.isEmpty)
          const Text('Bu dönemde kapanan adisyon yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kayitlar)
            _adisyonRow(k as Map, _yesil.withValues(alpha: 0.18), const Color(0xFF6EE7B7),
                '${k['musteri'] != null ? '👤 ${k['musteri']} · ' : ''}${k['misafir']} kişi · ${k['zaman']}'),
      ]),
    ];
  }

  // ---------------- TEK ADISYON DETAY ----------------
  List<Widget> _adisyon() {
    final ozet = (d!['ozet'] as Map?) ?? {};
    final kalemler = (d!['kalemler'] as List?) ?? [];
    final odemeler = (d!['odemeler'] as List?) ?? [];
    final musteri = d!['musteri'] as Map?;
    final deg = d!['degerlendirme'] as Map?;
    final indirim = _n(d!['indirim']);
    final ikram = _n(d!['ikram']);
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${d!['kanal']} · ${d!['acilis']}${d!['kapanis'] != null ? ' → ${d!['kapanis']}' : ' (açık)'}', _mavi),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: ozet.entries.map((e) => _statKart(e.key, e.value.toString())).toList(),
      ),
      // Musteri (kayitliysa) - ozetin hemen altinda, VURGULU mor kart
      if (musteri != null) ...[
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _push(tip: 'musteri', id: _n(musteri['id']).toInt(), baslik: musteri['ad'].toString()),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: _mor1.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 24, backgroundColor: Colors.white24,
                child: Text(musteri['ad'].toString().substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.verified_user, size: 13, color: Colors.white70),
                    const SizedBox(width: 4),
                    const Text('KAYITLI MÜŞTERİ', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ]),
                  const SizedBox(height: 2),
                  Text(musteri['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  Text('📞 ${musteri['telefon']?.toString() ?? '-'}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Kartı Aç', style: TextStyle(color: _mor1, fontSize: 12, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_forward, size: 14, color: _mor1),
                ]),
              ),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 14),
      // Musteri degerlendirmesi (patron ONCE bunu gorsun)
      if (deg != null) _degerlendirmeKart(deg) else _kutu('💬 Müşteri Değerlendirmesi', [
        const Text('Bu adisyon için müşteri anketi doldurulmamış.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ]),
      const SizedBox(height: 14),
      // Siparis icerigi
      _kutu('🍽️ Sipariş İçeriği', [
        if (kalemler.isEmpty)
          const Text('Ürün yok', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kalemler) _kalemSatir(k as Map),
      ]),
      const SizedBox(height: 14),
      // Hesap dokumu
      _kutu('🧮 Hesap', [
        _hesapSatir('Ara Toplam', _tam(_n(d!['araToplam'])), false),
        if (indirim > 0) _hesapSatir('İskonto', '- ${_tam(indirim)}', true),
        if (ikram > 0) _hesapSatir('İkram', '- ${_tam(ikram)}', true),
        const Divider(color: Color(0xFF243049), height: 18),
        _hesapSatir('TOPLAM', _tam(_n(d!['toplam'])), false, kalin: true),
      ]),
      if (odemeler.isNotEmpty) ...[
        const SizedBox(height: 14),
        _kutu('💳 Ödeme', [
          for (final o in odemeler)
            _hesapSatir((o as Map)['tip'].toString().toUpperCase(), _tam(_n(o['tutar'])), false),
        ]),
      ],
    ];
  }

  Widget _degerlendirmeKart(Map deg) {
    final mutlu = deg['mutlu'] == true;
    final renk = mutlu ? _yesil : _kirmizi;
    final puan = _n(deg['puan']).toInt();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: renk.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(mutlu ? '😊' : '😞', style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(mutlu ? 'Müşteri Memnun' : 'Memnuniyetsiz',
              style: TextStyle(color: renk, fontSize: 15, fontWeight: FontWeight.bold)),
          const Spacer(),
          _yildizlar(puan),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _altPuan('Lezzet', _n(deg['lezzet']).toInt())),
          Expanded(child: _altPuan('Servis', _n(deg['servis']).toInt())),
          Expanded(child: _altPuan('Hız', _n(deg['hiz']).toInt())),
        ]),
        if ((deg['yorum']?.toString() ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
            child: Text('“${deg['yorum']}”', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontStyle: FontStyle.italic)),
          ),
        ],
        const SizedBox(height: 6),
        Text(deg['zaman']?.toString() ?? '', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
      ]),
    );
  }

  Widget _yildizlar(int p) => Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) => Icon(i < p ? Icons.star : Icons.star_border, size: 18, color: const Color(0xFFF59E0B))));

  Widget _altPuan(String ad, int p) => Column(children: [
        Text(ad, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Icon(i < p ? Icons.star : Icons.star_border, size: 11, color: const Color(0xFFF59E0B)))),
      ]);

  Widget _kalemSatir(Map k) {
    final iptal = k['durum'] == 'iptal';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text('${_n(k['adet']).toInt()}×', style: TextStyle(color: iptal ? _kirmizi : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k['ad'].toString(),
                style: TextStyle(
                    color: iptal ? const Color(0xFF64748B) : const Color(0xFFE2E8F0), fontSize: 13,
                    decoration: iptal ? TextDecoration.lineThrough : null)),
            if ((k['not']?.toString() ?? '').isNotEmpty)
              Text('not: ${k['not']}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
            if (iptal) const Text('İPTAL / SİLİNDİ', style: TextStyle(color: _kirmizi, fontSize: 9, fontWeight: FontWeight.bold)),
          ]),
        ),
        Text(_tam(_n(k['tutar'])),
            style: TextStyle(
                color: iptal ? const Color(0xFF64748B) : Colors.white, fontSize: 13, fontWeight: FontWeight.bold,
                decoration: iptal ? TextDecoration.lineThrough : null)),
      ]),
    );
  }

  Widget _hesapSatir(String sol, String sag, bool eksi, {bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(sol, style: TextStyle(color: kalin ? Colors.white : const Color(0xFF94A3B8), fontSize: kalin ? 14 : 13, fontWeight: kalin ? FontWeight.bold : FontWeight.normal)),
          Text(sag, style: TextStyle(color: eksi ? _kirmizi : (kalin ? Colors.white : const Color(0xFFE2E8F0)), fontSize: kalin ? 15 : 13, fontWeight: FontWeight.bold)),
        ]),
      );

  // ---------------- MUSTERI DETAY ----------------
  List<Widget> _musteri() {
    final profil = (d!['profil'] as Map?) ?? {};
    final ozet = (d!['ozet'] as Map?) ?? {};
    final siparisler = (d!['siparisler'] as List?) ?? [];
    final odeme = (d!['odeme'] as List?) ?? [];
    final favori = (d!['favori'] as List?) ?? [];
    final yorumlar = (d!['yorumlar'] as List?) ?? [];
    final ad = profil['ad']?.toString() ?? 'Müşteri';
    return [
      // Profil header
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 26, backgroundColor: Colors.white24,
            child: Text(ad.substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
              if ((profil['telefon']?.toString() ?? '').isNotEmpty)
                Text('📞 ${profil['telefon']}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if ((profil['adres']?.toString() ?? '').isNotEmpty)
                Text('📍 ${profil['adres']}', style: const TextStyle(color: Colors.white60, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      ),
      if (d!['kvkk'] == true) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: const Color(0xFF3B2F14), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF854D0E))),
          child: const Row(children: [
            Icon(Icons.lock_outline, size: 15, color: Color(0xFFFCD34D)),
            SizedBox(width: 8),
            Expanded(child: Text('KVKK: İsim/telefon maskeli. Tam bilgiyi yalnızca patron (sahip) görebilir.',
                style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11))),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      // Ozet chips
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: ozet.entries.map((e) => _statKart(e.key, e.value.toString())).toList(),
      ),
      const SizedBox(height: 12),
      // Bu musteri icin Derin AI Analizi
      GestureDetector(
        onTap: () => AiAnalizSheet.goster(context, kapsam: 'musteri', id: widget.id, period: widget.period, baslik: 'Müşteri AI Analizi'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF241B4D), Color(0xFF3B2E7E)]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _mor1.withValues(alpha: 0.5)),
          ),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('✨', style: TextStyle(fontSize: 15)),
            SizedBox(width: 8),
            Text('Bu Müşteri İçin AI Analizi', style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      // Favori urunler
      if (favori.isNotEmpty) ...[
        _kutu('❤️ Favori Ürünler', [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final u in favori)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(20)),
                child: Text('${(u as Map)['urun_adi']} · ${_n(u['adet']).toInt()}×', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12)),
              ),
          ]),
        ]),
        const SizedBox(height: 14),
      ],
      // Odeme aliskanligi
      if (odeme.isNotEmpty) ...[
        _kutu('💳 Ödeme Alışkanlığı', [
          for (final o in odeme)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((o as Map)['tip'].toString().toUpperCase(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(o['adet']).toInt()} işlem', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_k(_n(o['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      // Gecmis siparisler
      _kutu('🧾 Geçmiş Siparişler', [
        if (siparisler.isEmpty)
          const Text('Kayıtlı sipariş yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final s in siparisler)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _push(tip: 'adisyon', id: _n(s['id']).toInt(), baslik: s['masa'].toString()),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Text(s['zaman'].toString(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${s['masa']} · ${s['kanal']}', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Text(_tam(_n(s['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right, size: 16, color: Color(0xFF475569)),
                ]),
              ),
            ),
      ]),
      const SizedBox(height: 14),
      // Yorumlar
      _kutu('💬 Müşteri Yorumları', [
        if (yorumlar.isEmpty)
          const Text('Henüz yorum yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final y in yorumlar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _yildizlar(_n((y as Map)['puan']).toInt()),
                  const Spacer(),
                  Text(y['zaman'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                ]),
                if ((y['yorum']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('“${y['yorum']}”', style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12, fontStyle: FontStyle.italic)),
                ],
              ]),
            ),
      ]),
    ];
  }

  // ---------------- ORTAK ----------------
  // Tiklanabilir adisyon satiri (acik/kapali listelerde) -> tek adisyon detayina gider
  Widget _adisyonRow(Map k, Color badgeRenk, Color badgeText, String altSatir) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _push(tip: 'adisyon', id: _n(k['id']).toInt(), baslik: k['masa'].toString()),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: badgeRenk, borderRadius: BorderRadius.circular(8)),
              child: Text(k['masa'].toString(), style: TextStyle(color: badgeText, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k['garson'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(altSatir, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ]),
            ),
            Text(_tam(_n(k['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF475569)),
          ]),
        ),
      );

  Widget _statKart(String baslik, String deger) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(baslik, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 3),
          FittedBox(child: Text(deger, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _ozetSerit(String buyuk, String alt, Color renk) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [renk.withValues(alpha: 0.85), renk.withValues(alpha: 0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(buyuk, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          Text(alt, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );

  Widget _kutu(String baslik, List<Widget> cocuklar) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...cocuklar,
        ]),
      );

  Widget _miniBar(List gunluk, {String birim = ''}) {
    final maks = gunluk.fold<num>(1, (a, e) => _n((e as Map)['deger']) > a ? _n(e['deger']) : a);
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: gunluk.asMap().entries.map<Widget>((entry) {
          final i = entry.key;
          final m = entry.value as Map;
          final v = _n(m['deger']);
          final h = maks > 0 ? (v / maks * 84).clamp(3.0, 84.0).toDouble() : 3.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${v % 1 == 0 ? v.toInt() : v}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8)),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: h),
                  duration: Duration(milliseconds: 450 + i * 40),
                  curve: Curves.easeOutCubic,
                  builder: (_, hv, child) => Container(
                    height: hv,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_mor2, _mor1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(m['gun'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 8)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}
