import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';

/// Garsonun elle girdiği siparişte ÜRÜN NOTU ve ALERJİ seçimi (web POS ile aynı seçenekler).
/// Not biçimi sunucu/mutfak/fiş ile ortak: "Soğansız · Az pişmiş · ALERJİ: Gluten" (' · ' ayraç).
class NotAlerji {
  static const hizli = ['Az pişmiş', 'Orta pişmiş', 'İyi pişmiş', 'Soğansız', 'Acısız', 'Bol acılı', 'Sossuz', 'Tuzsuz', 'Buzsuz', 'Şekersiz', 'Sos ayrı', 'Yemekten sonra getirilsin'];
  // Yasal 14 alerjen (ürün alerjen kaydıyla aynı adlar -> menü uyarısı eşleşir)
  static const alerjenler = ['Gluten', 'Süt (laktoz)', 'Yumurta', 'Yer fıstığı', 'Sert kabuklu yemiş', 'Susam', 'Soya', 'Balık', 'Kabuklu deniz ürünleri', 'Yumuşakça', 'Kereviz', 'Hardal', 'Sülfit', 'Acı bakla (lupin)'];
  static const kirmizi = Color(0xFFF43F5E);

  static final _alerjiRe = RegExp(r'^ALERJ[İI]\s*:\s*', caseSensitive: false);

  /// Not -> parçalar ("QR sipariş" etiketi mutfak/garsonu ilgilendirmez)
  static List<String> parcalar(String? not) =>
      (not ?? '').split(' · ').map((p) => p.trim()).where((p) => p.isNotEmpty && !p.startsWith('QR sipariş')).toList();
  static bool alerjiMi(String p) => _alerjiRe.hasMatch(p);
  static List<String> alerjiAdlari(String p) => p.replaceFirst(_alerjiRe, '').split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  /// Ürün notu + masa alerjisi birleşik (yerel mutfak fişi için; sunucu da aynısını kaydeder)
  static String birlestir(String? not, List<String> masaAlerji) {
    final notlar = <String>[];
    final alj = <String>[];
    for (final p in parcalar(not)) {
      if (alerjiMi(p)) { for (final a in alerjiAdlari(p)) { if (!alj.contains(a)) alj.add(a); } } else { notlar.add(p); }
    }
    for (final a in masaAlerji) { if (!alj.contains(a)) alj.add(a); }
    return [...notlar, if (alj.isNotEmpty) 'ALERJİ: ${alj.join(', ')}'].join(' · ');
  }

  /// Not parçalarını rozet olarak gösterir (alerji kırmızı ⚠️, "sonra" ⏰, diğerleri 📝)
  static Widget rozetler(String? not, {double sol = 0}) {
    final p = parcalar(not);
    if (p.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(left: sol, top: 4),
      child: Wrap(spacing: 4, runSpacing: 4, children: [
        for (final s in p)
          Builder(builder: (_) {
            final a = alerjiMi(s);
            final sonra = s.toLowerCase().contains('sonra getir');
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: a ? kirmizi : const Color(0xFFF59E0B).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('${a ? '⚠️ ' : (sonra ? '⏰ ' : '📝 ')}$s',
                  style: TextStyle(color: a ? Colors.white : const Color(0xFFD97706), fontSize: 11.5, fontWeight: FontWeight.w700)),
            );
          }),
      ]),
    );
  }

  static Widget _cip(TemaProvider t, String s, bool on, bool alj, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: on ? (alj ? kirmizi : t.mor1) : t.card2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? (alj ? kirmizi : t.mor1) : t.line, width: 1.3),
          ),
          child: Text(s, style: TextStyle(color: on ? Colors.white : t.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ),
      );

  static Widget _baslik(String s, Color c) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(s, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      );

  /// Ürün notu seç. Dönüş: yeni not ('' = notu temizle), null = vazgeçildi.
  static Future<String?> kalemNotSec(BuildContext context, {required String urunAd, String? mevcut, List<String> masaAlerji = const []}) {
    final t = Provider.of<TemaProvider>(context, listen: false);
    final secNot = <String>{};
    final secAlj = <String>{};
    final serbest = <String>[];
    for (final p in parcalar(mevcut)) {
      if (alerjiMi(p)) {
        secAlj.addAll(alerjiAdlari(p).where((a) => !masaAlerji.contains(a)));
      } else if (hizli.contains(p)) {
        secNot.add(p);
      } else {
        serbest.add(p);
      }
    }
    final aListe = [...alerjenler, ...secAlj.where((a) => !alerjenler.contains(a))];
    final ctrl = TextEditingController(text: serbest.join(' · '));
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('$urunAd — not', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              _baslik('HIZLI NOT', t.sub),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in hizli) _cip(t, s, secNot.contains(s), false, () => ss(() => secNot.contains(s) ? secNot.remove(s) : secNot.add(s))),
              ]),
              _baslik('⚠️ BU ÜRÜN İÇİN ALERJİ', kirmizi),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in aListe) _cip(t, s, secAlj.contains(s), true, () => ss(() => secAlj.contains(s) ? secAlj.remove(s) : secAlj.add(s))),
              ]),
              if (masaAlerji.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Masa alerjisi (${masaAlerji.join(', ')}) bu ürüne her durumda yazılır.',
                      style: const TextStyle(color: kirmizi, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                maxLength: 150,
                style: TextStyle(color: t.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Başka bir not (ör. mısır olmasın, sos ayrı)',
                  hintStyle: TextStyle(color: t.sub, fontSize: 13),
                  filled: true, fillColor: t.card2, counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub)))),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: t.mor1, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final notlar = [...hizli.where(secNot.contains), if (ctrl.text.trim().isNotEmpty) ctrl.text.trim()];
                      final alj = aListe.where(secAlj.contains).toList();
                      Navigator.pop(ctx, [...notlar, if (alj.isNotEmpty) 'ALERJİ: ${alj.join(', ')}'].join(' · '));
                    },
                    child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  /// Masa alerjisi seç. Dönüş: yeni liste (boş = kaldır), null = vazgeçildi.
  static Future<List<String>?> masaAlerjiSec(BuildContext context, List<String> mevcut) {
    final t = Provider.of<TemaProvider>(context, listen: false);
    final sec = <String>{...mevcut};
    final liste = [...alerjenler, ...mevcut.where((a) => !alerjenler.contains(a))];
    final ctrl = TextEditingController();
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        return Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('⚠️ Masa alerjisi', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Seçilen alerji bu masanın mutfağa gitmiş ve sonradan eklenecek BÜTÜN ürünlerine yazılır, fişte kırmızı uyarı olarak çıkar.',
                  style: TextStyle(color: t.sub, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final s in liste) _cip(t, s, sec.contains(s), true, () => ss(() => sec.contains(s) ? sec.remove(s) : sec.add(s))),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLength: 80,
                style: TextStyle(color: t.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Listede yoksa yazın (ör. Çilek, Domates)',
                  hintStyle: TextStyle(color: t.sub, fontSize: 13),
                  filled: true, fillColor: t.card2, counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub)))),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kirmizi, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      final l = liste.where(sec.contains).toList();
                      for (final x in ctrl.text.split(',')) {
                        if (x.trim().isNotEmpty && !l.contains(x.trim())) l.add(x.trim());
                      }
                      Navigator.pop(ctx, l);
                    },
                    child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ]),
          ),
        );
      }),
    );
  }

  /// Menü kaydına göre alerjen içeren ürün uyarısı (garson müşteriye sormalı)
  static Future<void> riskUyari(BuildContext context, List urunler, {String? ek}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ Alerji uyarısı', style: TextStyle(color: kirmizi, fontWeight: FontWeight.bold)),
        content: Text('Menü kaydına göre ${urunler.join(', ')} bu masanın alerjisine ait içerik barındırıyor.\n\n'
            '${ek ?? 'Müşteriye sorun; mutfağa ALERJİ uyarısı gidecek.'}'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anladım'))],
      ),
    );
  }
}
