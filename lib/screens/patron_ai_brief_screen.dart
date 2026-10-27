import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Patron AI — Sabah Brifingi (asistan/genel sekreter edası). Veri panosu DEĞİL:
/// sıcak anlatı + öneriler + dünden devam + gündem + iletişim özeti + küçük rakam şeridi.
class PatronAiBriefScreen extends StatefulWidget {
  const PatronAiBriefScreen({super.key});
  @override
  State<PatronAiBriefScreen> createState() => _PatronAiBriefScreenState();
}

class _PatronAiBriefScreenState extends State<PatronAiBriefScreen> {
  bool _yukleniyor = true;
  String? _hata;
  Map<String, dynamic> _b = {};

  @override
  void initState() {
    super.initState();
    _getir(false);
  }

  Future<void> _getir(bool force) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null || tok.isEmpty) {
      setState(() { _yukleniyor = false; _hata = 'Oturum bulunamadı'; });
      return;
    }
    setState(() => _yukleniyor = true);
    try {
      final res = await Api.patronAiBrief(tok, force: force);
      if (res['ok'] == 1) { _b = Map<String, dynamic>.from(res); _hata = null; }
      else { _hata = res['hata']?.toString() ?? 'Yüklenemedi'; }
    } catch (_) { _hata = 'Bağlantı hatası'; }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _takipCoz(int id) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() {
      final sk = _b['sureklilik'];
      if (sk is Map && sk['acik'] is List) {
        (sk['acik'] as List).removeWhere((x) => ((x as Map)['id'] as num?)?.toInt() == id);
      }
    });
    try { await Api.patronAiTakipDurum(tok, id: id, durum: 'cozuldu'); } catch (_) {}
  }

  String _tl(dynamic n) {
    final v = (n is num) ? n : num.tryParse('$n') ?? 0;
    return '₺${v.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
  }

  String _selam() {
    final h = DateTime.now().hour;
    return h < 11 ? 'Günaydın' : (h < 18 ? 'İyi günler' : 'İyi akşamlar');
  }

  String _bugun() {
    const ay = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final d = DateTime.now();
    return '${d.day} ${ay[d.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final v = (_b['veri'] is Map) ? Map<String, dynamic>.from(_b['veri']) : {};
    final analiz = (_b['analiz'] is List) ? (_b['analiz'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
    final sk = (_b['sureklilik'] is Map) ? Map<String, dynamic>.from(_b['sureklilik']) : {'acik': [], 'kapanan': []};
    final wa = (_b['whatsapp'] is Map) ? Map<String, dynamic>.from(_b['whatsapp']) : {'giden': 0, 'gelen': []};
    final tk = (_b['tuketim'] is Map) ? Map<String, dynamic>.from(_b['tuketim']) : null;
    final takvim = (v['takvim'] is List) ? v['takvim'] as List : [];
    final eposta = (v['eposta'] is List) ? v['eposta'] as List : [];
    final adRaw = _b['ad']?.toString() ?? '';
    final ad = adRaw.isNotEmpty ? adRaw.split(' ').first : '';
    final kaynak = _b['kaynak']?.toString() ?? 'kural';
    num kayipTop = 0;
    if (v['kayip'] is Map) (v['kayip'] as Map).forEach((k, val) => kayipTop += (val is num ? val : num.tryParse('$val') ?? 0));

    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    } else if (_hata != null) {
      govde = Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(_hata!, style: TextStyle(color: t.sub))));
    } else {
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          // Selam + orb
          Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi]), shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_selam()}${ad.isNotEmpty ? ', $ad' : ''} 👋', style: TextStyle(color: t.ink, fontSize: 19, fontWeight: FontWeight.w800)),
              Text('${_bugun()} · ${kaynak == 'ai' ? 'AI yazdı' : 'kural motoru'}', style: TextStyle(color: t.sub, fontSize: 12)),
            ])),
            IconButton(onPressed: () => _getir(true), icon: Icon(Icons.refresh, color: t.sub2, size: 20)),
          ]),
          // AI tüketim ince şerit
          if (tk != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.auto_awesome, color: t.mor1, size: 14), const SizedBox(width: 6),
              Text('Bu ay dahil AI', style: TextStyle(color: t.sub, fontSize: 11)), const SizedBox(width: 8),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: (((tk['yuzde'] ?? 0) as num) / 100).clamp(0.0, 1.0), minHeight: 5,
                      backgroundColor: t.card2, color: ((tk['yuzde'] ?? 0) as num) >= 90 ? t.kirmizi : (((tk['yuzde'] ?? 0) as num) >= 70 ? t.amber : t.yesil)))),
              const SizedBox(width: 8), Text('${tk['kullanim'] ?? 0}/${tk['hak'] ?? 0}', style: TextStyle(color: t.sub, fontSize: 11)),
            ]),
          ],
          const SizedBox(height: 14),
          // AI DEĞERLENDİRMESİ (anahtar açıkken Haiku'nun özgün genel yorumu)
          if (_b['ai_var'] == true && (_b['ai_ozet']?.toString() ?? '').isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1.withValues(alpha: .10), t.mavi.withValues(alpha: .10)]),
                  borderRadius: BorderRadius.circular(16), border: Border.all(color: t.mor1.withValues(alpha: .25))),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.auto_awesome, color: t.mor1, size: 17), const SizedBox(width: 7),
                  Text('AI DEĞERLENDİRMESİ', style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .3))]),
                const SizedBox(height: 8),
                RichText(text: TextSpan(style: TextStyle(color: t.ink, fontSize: 14.5, height: 1.6),
                    children: _boldSpans(_b['ai_ozet'].toString(), TextStyle(color: t.ink, fontWeight: FontWeight.w800)))),
              ]),
            ),
          // ANALİZ BLOKLARI (durum + yorum + risk + öneri)
          for (final a in analiz) _analizKart(t, a),
          // DÜNDEN DEVAM
          if ((sk['acik'] as List).isNotEmpty || (sk['kapanan'] as List).isNotEmpty)
            _blok(t, baslik: 'Dünden Devam', ikon: Icons.history, ikonRenk: t.mavi, child: Column(children: [
              for (final k in (sk['kapanan'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
                _satir(t, Icon(Icons.check_circle, color: t.yesil, size: 18), k['konu']?.toString() ?? '', sag: Text(k['durum'] == 'devredildi' ? 'devredildi' : 'çözüldü', style: TextStyle(color: t.sub, fontSize: 11))),
              for (final a in (sk['acik'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
                _satir(t, Container(width: 9, height: 9, decoration: BoxDecoration(color: t.amber, shape: BoxShape.circle)), a['konu']?.toString() ?? '',
                    sag: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(((a['gun'] as num?)?.toInt() ?? 0) > 0 ? '${a['gun']} gün' : 'bugün', style: TextStyle(color: t.sub, fontSize: 11)),
                      TextButton(onPressed: () => _takipCoz((a['id'] as num?)?.toInt() ?? 0), style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                          child: Text('Çözüldü', style: TextStyle(color: t.yesil, fontSize: 12, fontWeight: FontWeight.w700))),
                    ])),
            ])),
          // GÜNDEM
          if (takvim.isNotEmpty)
            _blok(t, baslik: 'Bugünkü Gündem', ikon: Icons.event, ikonRenk: t.mor1, child: Column(children: [
              for (final e in takvim.map((x) => Map<String, dynamic>.from(x as Map)))
                Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 46, child: Text('${e['saat'] ?? ''}', style: TextStyle(color: t.mavi, fontWeight: FontWeight.w800))),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${e['baslik'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                    if ((e['not']?.toString() ?? '').isNotEmpty) Text('📝 ${e['not']}', style: TextStyle(color: t.sub, fontSize: 11.5)),
                  ])),
                ])),
            ])),
          // İLETİŞİM
          if (eposta.isNotEmpty || ((wa['giden'] as num?)?.toInt() ?? 0) > 0 || (wa['gelen'] as List).isNotEmpty)
            _blok(t, baslik: 'İletişim', ikon: Icons.forum, ikonRenk: t.yesil, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (eposta.isNotEmpty) ...[
                Text('📨 Yanıt bekleyen e-posta (${eposta.length})', style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700)),
                for (final e in eposta.map((x) => Map<String, dynamic>.from(x as Map)))
                  _satir(t, Icon(Icons.mail_outline, color: t.amber, size: 17),
                      '', cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${e['subject'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${e['from'] ?? ''}', style: TextStyle(color: t.sub, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])),
              ],
              if (((wa['giden'] as num?)?.toInt() ?? 0) > 0 || (wa['gelen'] as List).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('💬 WhatsApp', style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700)),
                Text('Bugün sistemden ${wa['giden'] ?? 0} mesaj gönderildi.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                for (final g in (wa['gelen'] as List).map((x) => Map<String, dynamic>.from(x as Map)))
                  _satir(t, const Icon(Icons.chat, color: Color(0xFF25D366), size: 17),
                      '', cocuk: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${g['mesaj'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 13)),
                        Text('${g['telefon'] ?? ''} · ${g['saat'] ?? ''}', style: TextStyle(color: t.sub, fontSize: 11)),
                      ])),
              ],
            ])),
          // RAKAM ŞERİDİ
          _blok(t, child: Wrap(spacing: 8, runSpacing: 6, children: [
            _cip(t, '💰 Ciro ${_tl(v['dun_ciro'])}'),
            _cip(t, '🍽 FC %${v['food_cost_yuzde'] ?? 0}'),
            _cip(t, '📉 Kayıp ${_tl(kayipTop)}'),
            _cip(t, '👥 ${v['misafir'] ?? 0} misafir'),
            _cip(t, '⚠️ ${v['kritik_sayi'] ?? 0} kritik'),
          ])),
        ],
      );
    }

    return MasaustuSayfa(baslik: 'Patron AI', ikon: Icons.auto_awesome, geri: true, govde: govde);
  }

  Widget _blok(TemaProvider t, {String? baslik, IconData? ikon, Color? ikonRenk, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line), boxShadow: t.golge),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (baslik != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
          Icon(ikon, color: ikonRenk ?? t.sub2, size: 17), const SizedBox(width: 7),
          Text(baslik.toUpperCase(), style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .3)),
        ])),
        child,
      ]),
    );
  }

  Widget _satir(TemaProvider t, Widget ikon, String metin, {Widget? sag, Widget? cocuk}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 20, child: Center(child: ikon)),
        const SizedBox(width: 8),
        Expanded(child: cocuk ?? Text(metin, style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.4))),
        if (sag != null) sag,
      ]),
    );
  }

  // **bold** -> kalın TextSpan'lar (çift yıldız arası kalın)
  List<TextSpan> _boldSpans(String s, TextStyle bold) {
    final parts = s.split('**');
    return [for (int i = 0; i < parts.length; i++) TextSpan(text: parts[i], style: i.isOdd ? bold : null)];
  }

  Color _durumRenk(TemaProvider t, String d) =>
      d == 'iyi' ? t.yesil : (d == 'dikkat' ? t.amber : (d == 'risk' ? t.kirmizi : t.sub));

  IconData _ikonAd(String a) {
    switch (a) {
      case 'payments': return Icons.payments;
      case 'restaurant': return Icons.restaurant;
      case 'inventory_2': return Icons.inventory_2;
      case 'trending_down': return Icons.trending_down;
      default: return Icons.insights;
    }
  }

  Widget _analizKart(TemaProvider t, Map<String, dynamic> a) {
    final durum = a['durum']?.toString() ?? 'notr';
    final renk = _durumRenk(t, durum);
    final et = {'iyi': 'İYİ', 'notr': 'NÖTR', 'dikkat': 'DİKKAT', 'risk': 'RİSK'}[durum] ?? 'NÖTR';
    final risk = a['risk']?.toString() ?? '';
    final boldStyle = TextStyle(color: t.ink, fontWeight: FontWeight.w800);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line), boxShadow: t.golge),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_ikonAd(a['ikon']?.toString() ?? ''), color: renk, size: 21), const SizedBox(width: 9),
          Flexible(child: Text(a['baslik']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 7),
          Expanded(child: Text('· ${a['deger'] ?? ''}', style: TextStyle(color: t.sub, fontSize: 12.5), overflow: TextOverflow.ellipsis)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(20)),
              child: Text(et, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 8),
        RichText(text: TextSpan(style: TextStyle(color: t.ink, fontSize: 14, height: 1.6), children: _boldSpans(a['yorum']?.toString() ?? '', boldStyle))),
        if (risk.isNotEmpty)
          Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.kirmizi.withValues(alpha: .10), borderRadius: BorderRadius.circular(10)),
              child: RichText(text: TextSpan(style: TextStyle(color: t.kirmizi, fontSize: 13, height: 1.45),
                  children: [const TextSpan(text: '🔴 '), TextSpan(text: 'Risk: ', style: const TextStyle(fontWeight: FontWeight.w800)), TextSpan(text: risk)]))),
        Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
            child: RichText(text: TextSpan(style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45),
                children: [const TextSpan(text: '✅ '), TextSpan(text: 'Öneri: ', style: boldStyle), ..._boldSpans(a['oneri']?.toString() ?? '', boldStyle)]))),
      ]),
    );
  }

  Widget _cip(TemaProvider t, String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(20)),
        child: Text(s, style: TextStyle(color: t.sub2, fontSize: 12.5)),
      );
}
