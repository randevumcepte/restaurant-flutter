import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — Çağrı Kayıtları (native). Sol liste + sağ detay (döküm + sipariş + ses).
class SantralKayitlarScreen extends StatefulWidget {
  const SantralKayitlarScreen({super.key});
  @override
  State<SantralKayitlarScreen> createState() => _SantralKayitlarScreenState();
}

class _SantralKayitlarScreenState extends State<SantralKayitlarScreen> {
  List<Map<String, dynamic>> _liste = [];
  Map<String, dynamic>? _detay;
  int? _seciliId;
  bool _yukleniyor = true;
  bool _detayYukleniyor = false;
  String _ara = '';

  // sonuc -> etiket/ikon/renk
  static const _smap = {'siparis': 'Sipariş', 'rezervasyon': 'Rezervasyon', 'aktar': 'Aktarıldı', 'kufur': 'Küfür', 'bilgi': 'Bilgi'};
  static const _imap = {'siparis': '🛒', 'rezervasyon': '📅', 'aktar': '↪️', 'kufur': '🚫', 'bilgi': 'ℹ️'};
  Color _renk(String? s) {
    switch (s) {
      case 'siparis': return const Color(0xFF22C55E);
      case 'rezervasyon': return const Color(0xFF3B82F6);
      case 'aktar': return const Color(0xFFF59E0B);
      case 'kufur': return const Color(0xFFF43F5E);
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final r = await SantralApi.kayitListe();
      final l = (r['liste'] as List?) ?? [];
      _liste = l.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _detayAc(int id) async {
    setState(() { _seciliId = id; _detayYukleniyor = true; _detay = null; });
    try {
      final r = await SantralApi.kayitDetay(id);
      if (r['ok'] == 1) _detay = Map<String, dynamic>.from(r['kayit']);
    } catch (_) {}
    if (mounted) setState(() => _detayYukleniyor = false);
  }

  List<Map<String, dynamic>> get _filtre {
    if (_ara.trim().isEmpty) return _liste;
    final q = _ara.toLowerCase();
    return _liste.where((x) =>
        '${x['telefon'] ?? ''}'.toLowerCase().contains(q) ||
        '${x['son_musteri'] ?? ''}'.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final toplam = _liste.length;
    final sip = _liste.where((x) => x['sonuc'] == 'siparis').length;
    final rez = _liste.where((x) => x['sonuc'] == 'rezervasyon').length;
    final akt = _liste.where((x) => x['sonuc'] == 'aktar').length;

    return MasaustuSayfa(
      baslik: 'AI Santral — Çağrı Kayıtları',
      altBaslik: 'Her telefon görüşmesinin tam dökümü, sonucu ve bağlı siparişi.',
      ikon: Icons.support_agent,
      araclar: [MButon('Yenile', const Color(0xFF7C3AED), _yukle, ikon: Icons.refresh)],
      govde: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                // KPI kartlari
                Row(children: [
                  Expanded(child: MIstatKart(baslik: 'Toplam çağrı', renk: const Color(0xFF64748B), buyukDeger: '$toplam')),
                  const SizedBox(width: 12),
                  Expanded(child: MIstatKart(baslik: 'Sipariş', renk: const Color(0xFF22C55E), buyukDeger: '$sip')),
                  const SizedBox(width: 12),
                  Expanded(child: MIstatKart(baslik: 'Rezervasyon', renk: const Color(0xFF3B82F6), buyukDeger: '$rez')),
                  const SizedBox(width: 12),
                  Expanded(child: MIstatKart(baslik: 'Aktarılan', renk: const Color(0xFFF59E0B), buyukDeger: '$akt')),
                ]),
                const SizedBox(height: 16),
                Expanded(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SizedBox(width: 340, child: _solListe()),
                    const SizedBox(width: 16),
                    Expanded(child: _sagDetay()),
                  ]),
                ),
              ]),
            ),
    );
  }

  Widget _solListe() {
    final t = context.watch<TemaProvider>();
    return MKart(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          onChanged: (v) => setState(() => _ara = v),
          style: TextStyle(color: t.ink, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Telefon veya içerik ara...',
            hintStyle: TextStyle(color: t.sub, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: t.sub, size: 18),
            isDense: true,
            filled: true,
            fillColor: t.card2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtre.isEmpty
              ? Center(child: Text('Kayıt yok', style: TextStyle(color: t.sub)))
              : ListView.separated(
                  itemCount: _filtre.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _listeSatir(_filtre[i]),
                ),
        ),
      ]),
    );
  }

  Widget _listeSatir(Map<String, dynamic> x) {
    final t = context.watch<TemaProvider>();
    final s = x['sonuc'] as String?;
    final renk = _renk(s);
    final secili = _seciliId == x['id'];
    return Material(
      color: secili ? renk.withValues(alpha: 0.10) : t.card2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _detayAc(x['id'] as int),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: renk, width: 3)),
          ),
          child: Row(children: [
            CircleAvatar(radius: 16, backgroundColor: renk.withValues(alpha: 0.18), child: Text(_imap[s] ?? '📞', style: const TextStyle(fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${x['telefon'] ?? 'numara yok'}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
                  Text(_kisaTarih('${x['created_at'] ?? ''}'), style: TextStyle(color: t.sub, fontSize: 10.5)),
                ]),
                const SizedBox(height: 2),
                Text('${x['son_musteri'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5)),
                const SizedBox(height: 5),
                Row(children: [
                  MRozet(_smap[s] ?? 'Çağrı', renk),
                  const SizedBox(width: 6),
                  Text('${x['tur'] ?? 0} tur', style: TextStyle(color: t.sub, fontSize: 10.5)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _sagDetay() {
    final t = context.watch<TemaProvider>();
    if (_seciliId == null) {
      return MKart(child: Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.call_outlined, size: 44, color: t.sub),
          const SizedBox(height: 12),
          Text('Bir çağrı seçin', style: TextStyle(color: t.sub, fontSize: 15)),
        ]),
      )));
    }
    if (_detayYukleniyor || _detay == null) {
      return const MKart(child: Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())));
    }
    final r = _detay!;
    final s = r['sonuc'] as String?;
    final renk = _renk(s);
    final gecmis = (r['gecmis'] as List?) ?? [];
    final sesler = (r['sesler'] as List?) ?? [];
    final sp = r['siparis_veri'];
    return MKart(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Ust bilgi
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('${_imap[s] ?? '📞'} ${r['telefon'] ?? '-'}', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              MRozet(_smap[s] ?? 'Çağrı', renk),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _cip('🕐 ${r['created_at'] ?? '-'}', t),
              if (r['adisyon_id'] != null) _cip('🧾 Adisyon #${r['adisyon_id']}', t),
              if (r['rezervasyon_id'] != null) _cip('📅 Rezervasyon #${r['rezervasyon_id']}', t),
              _cip('Durum: ${r['durum'] ?? '-'}', t),
            ]),
          ]),
        ),
        Divider(height: 1, color: t.line),
        // Govde: ses + siparis + dokum
        Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            for (final se in sesler) ...[
              _SesOynatici(
                url: SantralApi.sesUrl('${se['url']}'),
                etiket: se['tur'] == 'aktarma' ? '↪️ Yetkiliye aktarılan görüşme' : '🤖 AI görüşmesi',
                boyutKb: ((se['boyut'] ?? 0) / 1024).round(),
              ),
              const SizedBox(height: 10),
            ],
            if (sp != null) ...[
              const MBolumBaslik('Sipariş', renk: Color(0xFF22C55E)),
              _siparisKart(sp, t),
              const SizedBox(height: 12),
            ],
            const MBolumBaslik('Görüşme Dökümü'),
            for (final m in gecmis) _balon(Map<String, dynamic>.from(m), t),
          ]),
        ),
      ]),
    );
  }

  Widget _cip(String s, TemaProvider t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
        child: Text(s, style: TextStyle(color: t.sub2, fontSize: 11.5)),
      );

  Widget _siparisKart(dynamic sp, TemaProvider t) {
    final kalemler = (sp is Map && sp['kalemler'] is List) ? sp['kalemler'] as List : [];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final k in kalemler)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('• ${(k is Map ? (k['adet'] ?? '') : '')} ${(k is Map ? (k['urun'] ?? k['ad'] ?? '') : k)}', style: TextStyle(color: t.ink, fontSize: 13)),
          ),
        if (sp is Map && sp['adres'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('📍 ${sp['adres']}', style: TextStyle(color: t.sub2, fontSize: 12.5))),
        if (sp is Map && sp['odeme'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('💳 ${_odeme('${sp['odeme']}')}', style: TextStyle(color: t.sub2, fontSize: 12.5))),
      ]),
    );
  }

  String _odeme(String o) {
    switch (o) {
      case 'kapida_nakit': return 'Kapıda nakit';
      case 'kapida_kart': return 'Kapıda kart';
      case 'online': return 'Online';
      default: return o;
    }
  }

  Widget _balon(Map<String, dynamic> m, TemaProvider t) {
    final musteri = (m['role'] == 'user');
    final renk = musteri ? const Color(0xFF7C3AED) : t.card2;
    return Align(
      alignment: musteri ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: musteri ? renk : t.card2,
          borderRadius: BorderRadius.circular(12),
          border: musteri ? null : Border.all(color: t.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(musteri ? 'MÜŞTERİ' : 'AI', style: TextStyle(color: musteri ? Colors.white70 : t.sub, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text('${m['content'] ?? ''}', style: TextStyle(color: musteri ? Colors.white : t.ink, fontSize: 13.5)),
        ]),
      ),
    );
  }

  String _kisaTarih(String s) {
    // "2026-10-02 10:40:xx" -> "10-02 10:40"
    if (s.length >= 16) return '${s.substring(5, 10)} ${s.substring(11, 16)}';
    return s;
  }
}

/// Basit tema-duyarli ses oynatici (audioplayers).
class _SesOynatici extends StatefulWidget {
  final String url;
  final String etiket;
  final int boyutKb;
  const _SesOynatici({required this.url, required this.etiket, required this.boyutKb});
  @override
  State<_SesOynatici> createState() => _SesOynaticiState();
}

class _SesOynaticiState extends State<_SesOynatici> {
  final _p = AudioPlayer();
  Duration _poz = Duration.zero;
  Duration _sure = Duration.zero;
  bool _caliyor = false;

  @override
  void initState() {
    super.initState();
    _p.onPositionChanged.listen((d) { if (mounted) setState(() => _poz = d); });
    _p.onDurationChanged.listen((d) { if (mounted) setState(() => _sure = d); });
    _p.onPlayerComplete.listen((_) { if (mounted) setState(() { _caliyor = false; _poz = Duration.zero; }); });
    _p.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _caliyor = s == PlayerState.playing); });
  }

  @override
  void dispose() { _p.dispose(); super.dispose(); }

  Future<void> _calDurdur() async {
    if (_caliyor) { await _p.pause(); }
    else { await _p.play(UrlSource(widget.url)); }
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final max = _sure.inMilliseconds.toDouble();
    final val = _poz.inMilliseconds.clamp(0, _sure.inMilliseconds).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.etiket, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600))),
          Text('${widget.boyutKb} KB', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          IconButton(
            onPressed: _calDurdur,
            icon: Icon(_caliyor ? Icons.pause_circle_filled : Icons.play_circle_fill, color: const Color(0xFF7C3AED), size: 34),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(
                min: 0,
                max: max <= 0 ? 1 : max,
                value: max <= 0 ? 0 : val,
                activeColor: const Color(0xFF7C3AED),
                inactiveColor: t.line,
                onChanged: max <= 0 ? null : (v) => _p.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ),
          Text('${_fmt(_poz)} / ${_fmt(_sure)}', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      ]),
    );
  }
}
