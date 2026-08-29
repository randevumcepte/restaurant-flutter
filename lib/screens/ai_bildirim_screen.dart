import 'package:flutter/material.dart';
import 'detay_screen.dart';
import 'ai_analiz_sheet.dart';

/// AI Bildirim Merkezi — kural motorunun "yakaladığı" durumlar, başlık + detaylı
/// açıklama + (varsa) ilgili detay sayfasına köprü. Üstte derin AI analizi butonu.
class AiBildirimScreen extends StatelessWidget {
  final List bildirimler;
  final String period;
  const AiBildirimScreen({super.key, required this.bildirimler, this.period = 'haftalik'});

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  Color _renk(String seviye) {
    switch (seviye) {
      case 'riskli': return const Color(0xFFF43F5E);
      case 'uyari': return const Color(0xFFF59E0B);
      case 'iyi': return const Color(0xFF10B981);
      default: return const Color(0xFF4F46E5);
    }
  }

  String _seviyeAd(String seviye) {
    switch (seviye) {
      case 'riskli': return 'RİSK';
      case 'uyari': return 'DİKKAT';
      case 'iyi': return 'İYİ HABER';
      default: return 'BİLGİ';
    }
  }

  void _detayAc(BuildContext context, Map aksiyon) {
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 220),
      opaque: true,
      barrierColor: _bg,
      pageBuilder: (_, _, _) => DetayScreen(
        tip: aksiyon['tip'].toString(),
        alt: aksiyon['alt']?.toString(),
        period: period,
        baslikFallback: aksiyon['etiket']?.toString() ?? 'Detay',
      ),
      transitionsBuilder: (_, anim, _, child) => SlideTransition(
        position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF94A3B8)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(9)),
            child: const Text('✨', style: TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 10),
          const Text('AI Bildirimleri', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
      ),
      body: bildirimler.isEmpty
          ? _bos()
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: [
                Text('Restoranında yakaladıklarım · ${bildirimler.length} durum',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(height: 14),
                for (final b in bildirimler) _kart(context, b as Map),
                const SizedBox(height: 6),
                _derinAiButon(context),
              ],
            ),
    );
  }

  Widget _kart(BuildContext context, Map b) {
    final seviye = b['seviye']?.toString() ?? 'bilgi';
    final renk = _renk(seviye);
    final aksiyon = b['aksiyon'] is Map ? b['aksiyon'] as Map : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: renk, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text(b['ikon']?.toString() ?? '•', style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(b['baslik']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Text(_seviyeAd(seviye), style: TextStyle(color: renk, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ]),
            const SizedBox(height: 10),
            // Kısa mesaj (vurgulu)
            Text(b['mesaj']?.toString() ?? '', style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
            const SizedBox(height: 8),
            // Detaylı açıklama (AI okuması)
            Text(b['detay']?.toString() ?? '', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.5)),
          ]),
        ),
        if (aksiyon != null)
          InkWell(
            onTap: () => _detayAc(context, aksiyon),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              ),
              child: Row(children: [
                Icon(Icons.arrow_forward, size: 16, color: renk),
                const SizedBox(width: 8),
                Text(aksiyon['etiket']?.toString() ?? 'Detayı gör', style: TextStyle(color: renk, fontSize: 13.5, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
      ]),
    );
  }

  Widget _derinAiButon(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_mor1, _mavi]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => AiAnalizSheet.goster(context, kapsam: 'ozet', period: period, baslik: 'Derin AI Analizi'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              child: Row(children: [
                Text('🤖', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Derin AI Analizi', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('Yapay zekâ tüm tabloyu okuyup yorumlasın', style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 12)),
                  ]),
                ),
                Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ]),
            ),
          ),
        ),
      );

  Widget _bos() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF10B981)),
            SizedBox(height: 16),
            Text('Her şey yolunda 👌', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Şu an dikkat çeken bir durum yakalamadım. Yeni bir şey fark edersem burada göreceksin.',
                textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5, height: 1.5)),
          ]),
        ),
      );
}
