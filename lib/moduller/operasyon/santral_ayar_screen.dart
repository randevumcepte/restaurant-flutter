import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /santral-ayar — AI Santral aktarma & teslimat: aktarma aç/kapa, çalma stratejisi (hepsi/sırayla),
/// hedef listesi (dahili / cep-dış, SIP/PJSIP, trunk), zil süresi, Asterisk önizleme, teslimat bölgesi.
/// Kayıt: POST /santral-ayar-kaydet (web formunun aynısı; hedefler JSON metin).
class OpSantralAyarScreen extends StatelessWidget {
  const OpSantralAyarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/santral-ayar',
      baslik: 'Aktarma & Teslimat',
      ikon: Icons.phone_forwarded_outlined,
      altBaslik: 'AI "sizi yetkiliye bağlıyorum" dediğinde çağrı kime gitsin?',
      govde: (ctx, veri, yenile) => _OpSantralAyarForm(key: ValueKey(jsonEncode(veri['ay'])), veri: veri, yenile: yenile),
    );
  }
}

class _OpSantralAyarForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _OpSantralAyarForm({super.key, required this.veri, required this.yenile});
  @override
  State<_OpSantralAyarForm> createState() => _OpSantralAyarFormState();
}

class _Hedef {
  String tip;
  String teknoloji;
  final TextEditingController numara;
  final TextEditingController trunk;
  _Hedef({this.tip = 'dahili', this.teknoloji = 'SIP', String numara = '', String trunk = ''})
      : numara = TextEditingController(text: numara),
        trunk = TextEditingController(text: trunk);
}

class _OpSantralAyarFormState extends State<_OpSantralAyarForm> {
  late bool _aktif;
  late String _strateji;
  final List<_Hedef> _hedefler = [];
  final _zil = TextEditingController();
  final _teslimat = TextEditingController();
  bool _kaydediyor = false;

  @override
  void initState() {
    super.initState();
    final ay = harita(widget.veri['ay']);
    _aktif = ay.isEmpty || ay['aktarma_aktif'] == null || tamOku(ay['aktarma_aktif']) == 1;
    _strateji = metinOku(ay['strateji']) == 'sirali' ? 'sirali' : 'hepsi';
    _zil.text = '${ay['zil_sure'] ?? 30}';
    _teslimat.text = metinOku(ay['teslimat_bolge']);
    for (final h in liste(widget.veri['hedefler'])) {
      _hedefler.add(_Hedef(
        tip: metinOku(h['tip']) == 'dis' ? 'dis' : 'dahili',
        teknoloji: metinOku(h['teknoloji']) == 'PJSIP' ? 'PJSIP' : 'SIP',
        numara: metinOku(h['numara']),
        trunk: metinOku(h['trunk']),
      ));
    }
    if (_hedefler.isEmpty) _hedefler.add(_Hedef());
  }

  @override
  void dispose() {
    for (final h in _hedefler) {
      h.numara.dispose();
      h.trunk.dispose();
    }
    _zil.dispose();
    _teslimat.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _topla() => [
        for (final h in _hedefler)
          if (h.numara.text.trim().isNotEmpty)
            {'tip': h.tip, 'teknoloji': h.teknoloji, 'numara': h.numara.text.trim(), 'trunk': h.trunk.text.trim().isEmpty ? null : h.trunk.text.trim()},
      ];

  String _dial(Map<String, dynamic> h) =>
      (h['tip'] == 'dis' && h['trunk'] != null) ? '${h['teknoloji']}/${h['trunk']}/${h['numara']}' : '${h['teknoloji']}/${h['numara']}';

  Future<void> _kaydet() async {
    final zil = int.tryParse(_zil.text.trim()) ?? 30;
    setState(() => _kaydediyor = true);
    final ok = await kopruGonder(context, '/santral-ayar-kaydet', {
      'sube_id': widget.veri['subeId'],
      'aktarma_aktif': _aktif ? 1 : null,
      'strateji': _strateji,
      'hedefler': jsonEncode(_topla()),
      'zil_sure': zil.clamp(5, 120),
      'teslimat_bolge': _teslimat.text.trim(),
    }, basariMesaji: 'Ayarlar kaydedildi. Yeni çağrılarda geçerli.');
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (ok) widget.yenile();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final hedefler = _topla();
    final dials = hedefler.map(_dial).toList();
    final zil = _zil.text.trim().isEmpty ? '30' : _zil.text.trim();
    final genis = genisMi(context);

    final aktarma = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Aktarma', ikon: Icons.phone_forwarded_outlined),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          value: _aktif,
          activeTrackColor: t.yesil,
          onChanged: (v) => setState(() => _aktif = v),
          title: Text('Aktarma açık', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w600)),
          subtitle: Text('AI gerektiğinde çağrıyı yönlendirsin. Kapalıysa AI aktarmaz; kendisi çözmeye çalışır.', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
      ]),
    );

    Widget stratSec(String k, String baslik, String alt, IconData ikon) {
      final sec = _strateji == k;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _strateji = k),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: sec ? t.mor1.withValues(alpha: .10) : t.card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sec ? t.mor1 : t.line, width: sec ? 1.6 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(sec ? Icons.radio_button_checked : Icons.radio_button_off, color: sec ? t.mor1 : t.sub, size: 20),
                const SizedBox(width: 6),
                Icon(ikon, size: 18, color: sec ? t.mor1 : t.sub),
              ]),
              const SizedBox(height: 6),
              Text(baslik, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(alt, style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
        ),
      );
    }

    final strateji = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Çalma stratejisi', ikon: Icons.call_split),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          stratSec('hepsi', 'Hepsi aynı anda çalsın', 'Tüm dahililer birlikte çalar, ilk açan alır. En hızlı.', Icons.groups_outlined),
          const SizedBox(width: 10),
          stratSec('sirali', 'Sırayla çalsın', 'Önce 1., açmazsa 2., sonra 3.… Öncelik sırasıyla.', Icons.format_list_numbered),
        ]),
      ]),
    );

    Widget hedefSatir(int i) {
      final h = _hedefler[i];
      final dis = h.tip == 'dis';
      final tip = SizedBox(
        width: genis ? 150 : double.infinity,
        child: KSecim<String>('Tip', deger: h.tip, secenekler: const [('dahili', 'Dahili'), ('dis', 'Cep / dış')], onSec: (v) => setState(() => h.tip = v ?? 'dahili')),
      );
      final tek = SizedBox(
        width: genis ? 120 : double.infinity,
        child: KSecim<String>('Teknoloji', deger: h.teknoloji, secenekler: const [('SIP', 'SIP'), ('PJSIP', 'PJSIP')], onSec: (v) => setState(() => h.teknoloji = v ?? 'SIP')),
      );
      final num = _alan(t, dis ? 'Cep / sabit numara' : 'Dahili numara', h.numara, dis ? '05xxxxxxxxx' : '101');
      final trunk = dis ? _alan(t, 'Dış hat (trunk)', h.trunk, 'isteğe bağlı') : null;
      final sil = IconButton(
        tooltip: 'Hedefi kaldır',
        onPressed: () => setState(() {
          final x = _hedefler.removeAt(i);
          x.numara.dispose();
          x.trunk.dispose();
        }),
        icon: Icon(Icons.delete_outline, color: t.kirmizi),
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 0),
        decoration: BoxDecoration(color: t.card2.withValues(alpha: .5), borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
        child: genis
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 34, right: 8), child: Text('${i + 1}.', style: TextStyle(color: t.sub, fontWeight: FontWeight.w700))),
                tip, const SizedBox(width: 10),
                Expanded(child: num), const SizedBox(width: 10),
                tek,
                if (trunk != null) ...[const SizedBox(width: 10), Expanded(child: trunk)],
                Padding(padding: const EdgeInsets.only(top: 22), child: sil),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('Hedef ${i + 1}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  sil,
                ]),
                tip, num, tek, ?trunk,
              ]),
      );
    }

    final hedefKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Hedefler (dahili / cep)', ikon: Icons.dialpad, sag: KButon('Hedef ekle', ikon: Icons.add, ikincil: true, onTap: () => setState(() => _hedefler.add(_Hedef())))),
        if (_hedefler.isEmpty)
          const KBos(baslik: 'Henüz hedef yok', aciklama: 'Aktarılan çağrının çalacağı dahili ya da cep numarasını "Hedef ekle" ile tanımlayın. Hedef yoksa AI aktarma yapamaz.', ikon: Icons.phone_disabled_outlined),
        for (var i = 0; i < _hedefler.length; i++) hedefSatir(i),
        const SizedBox(height: 4),
        Text(
          _strateji == 'sirali' ? 'Sırayla: her hedef $zil sn çalar, açılmazsa sıradakine geçilir.' : 'Hepsi birlikte $zil sn çalar; ilk açan alır.',
          style: TextStyle(color: t.sub2, fontSize: 12.5),
        ),
        const SizedBox(height: 10),
        SizedBox(width: 180, child: _alan(t, 'Zil süresi (saniye)', _zil, '30', sayi: true)),
        Text('Aranacak hedefler (Asterisk\'e giden)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
          child: SelectableText(
            dials.isEmpty ? '—' : dials.join(_strateji == 'sirali' ? '  →  ' : '   +   '),
            style: TextStyle(color: t.ink, fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ]),
    );

    final teslimat = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Teslimat bölgesi', ikon: Icons.delivery_dining_outlined, alt: 'Nereye teslimat yapıyorsunuz? (AI bunu uygular)'),
        KAlan('Teslimat kuralı', _teslimat, satir: 4, ipucu: 'Örn: Sadece Bayraklı, Karşıyaka ve Çiğli\'ye teslimat yapıyoruz. Bu ilçeler dışına gönderim yok. Minimum sepet 150 TL.'),
        Text(
          'Kendi dilinizle doldurun (ilçeler / mahalleler / mesafe kuralı). AI sipariş adresini buna göre değerlendirir; bölge dışına nazikçe reddeder ve gel-al önerir. Boş bırakırsanız her adrese sipariş alır.',
          style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4),
        ),
      ]),
    );

    final asterisk = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Asterisk kurulumu', ikon: Icons.settings_phone_outlined),
        Text(
          'Aktarma için Asterisk\'e hiçbir şey yazmanıza gerek yok. Köprü, buraya girdiğiniz hedefleri okuyup çağrıyı kendisi arar (seçtiğiniz stratejiye göre) ve açan hattı arayanla birleştirir.\n\nTek gereken (restoran başına bir kez), gelen çağrının AI\'ya ulaşması için:',
          style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
          child: SelectableText('exten => s,1,Answer()\n same => n,Stasis(restaurant-santral-ai)\n same => n,Hangup()',
              style: TextStyle(color: t.ink, fontFamily: 'monospace', fontSize: 13)),
        ),
      ]),
    );

    final kaydet = KButon(_kaydediyor ? 'Kaydediliyor…' : 'Kaydet', ikon: Icons.save_outlined, renk: t.yesil, genis: true, yukleniyor: _kaydediyor, onTap: _kaydet);

    if (genis) {
      return KGovde(yenile: widget.yenile, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: Column(children: [aktarma, strateji, hedefKart])),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: Column(children: [teslimat, kaydet, const SizedBox(height: 12), asterisk])),
        ]),
      ]);
    }
    return KGovde(yenile: widget.yenile, children: [aktarma, strateji, hedefKart, teslimat, kaydet, const SizedBox(height: 12), asterisk]);
  }

  Widget _alan(TemaProvider t, String etiket, TextEditingController c, String ipucu, {bool sayi = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: sayi ? TextInputType.number : TextInputType.phone,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: t.ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: ipucu,
              hintStyle: TextStyle(color: t.sub),
              filled: true,
              fillColor: t.card2,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.mor1, width: 1.6)),
            ),
          ),
        ]),
      );
}
