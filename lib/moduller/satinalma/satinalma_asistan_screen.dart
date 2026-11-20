import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _raporlar = [('kritik', 'Kritik Stok'), ('zam', 'Gizli Zamlar'), ('tedarikci', 'Tedarikçi Karnesi'), ('harcama', 'Aylık Harcama'), ('siparis', 'Açık Siparişler'), ('talep', 'Talepler')];
const _hazir = [
  'Bu hafta ne almalıyım?', 'En çok nereye harcıyorum?', 'Gizli zam var mı?', 'Hangi malzemede fire fazla?', 'Hangi tedarikçiyle pazarlık etmeliyim?', 'Siparişlerimde geciken var mı?',
  'kritik stokları siparişe çevir', 'geciken tedarikçileri hatırlat', 'bekleyen mal kabullerini onayla',
];

/// Web /satinalma-asistan — satın alma AI sohbeti (konuşma hafızası son 8 mesaj), Excel rapor indirme, AI eylem önerisi + "İşlemi Yap" onayı.
class SatinalmaAsistanScreen extends StatefulWidget {
  const SatinalmaAsistanScreen({super.key});
  @override
  State<SatinalmaAsistanScreen> createState() => _SatinalmaAsistanScreenState();
}

class _Mesaj {
  final String metin;
  final bool ben;
  final List<Map<String, dynamic>> exportlar;
  final Map<String, dynamic>? eylem;
  String? eylemSonuc;
  bool? eylemOk;
  bool yurutuluyor = false;
  _Mesaj(this.metin, this.ben, {this.exportlar = const [], this.eylem});
}

class _SatinalmaAsistanScreenState extends State<SatinalmaAsistanScreen> {
  final List<_Mesaj> _m = [];
  final _k = TextEditingController();
  final _scroll = ScrollController();
  bool _mesgul = false;

  void _asagi() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  Future<void> _sor([String? metin]) async {
    final soru = (metin ?? _k.text).trim();
    if (soru.isEmpty || _mesgul) return;
    _k.clear();
    final gecmis = [for (final x in _m.where((x) => x.metin.isNotEmpty)) {'rol': x.ben ? 'user' : 'ai', 'metin': x.metin}];
    setState(() {
      _m.add(_Mesaj(soru, true));
      _mesgul = true;
    });
    _asagi();
    final c = await saGonder(context, '/satinalma-asistan/sor', {'soru': soru, 'gecmis': gecmis.length > 8 ? gecmis.sublist(gecmis.length - 8) : gecmis}, sessiz: true, hataSessiz: true);
    if (!mounted) return;
    final j = c?.j ?? const {};
    setState(() {
      _mesgul = false;
      _m.add(_Mesaj(metinOku(j['cevap'], c == null ? 'Bağlantı hatası, tekrar deneyin.' : 'Cevap alınamadı.'), false,
          exportlar: liste(j['exportlar']), eylem: harita(j['eylem_oneri'])['log_id'] != null ? harita(j['eylem_oneri']) : null));
    });
    _asagi();
  }

  Future<void> _eylemYap(_Mesaj m) async {
    setState(() => m.yurutuluyor = true);
    final c = await saGonder(context, '/api/ai-eylem/onayla', {'log_id': m.eylem!['log_id']}, sessiz: true, hataSessiz: true);
    if (!mounted) return;
    final s = harita(c?.j['sonuc']);
    setState(() {
      m.yurutuluyor = false;
      m.eylemOk = s['ok'] == true || s['ok'] == 1;
      m.eylemSonuc = metinOku(s['mesaj'], c == null ? 'Bağlantı hatası.' : 'Sonuç alınamadı.');
    });
  }

  void _indir(String tip, String ad) => saDosyaIndir(context, '/satinalma-asistan/excel', 'satinalma-$tip.xlsx', q: {'tip': tip});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return KSayfa(
      baslik: 'Satın Alma AI Asistanı',
      ikon: Icons.smart_toy_outlined,
      araclar: [
        PopupMenuButton<String>(
          tooltip: 'Excel rapor indir',
          icon: const Icon(Icons.table_view_outlined),
          onSelected: (x) => _indir(x, ''),
          itemBuilder: (_) => [for (final r in _raporlar) PopupMenuItem(value: r.$1, child: Text(r.$2))],
        ),
        if (_m.isNotEmpty) IconButton(tooltip: 'Yeni sohbet', onPressed: () => setState(_m.clear), icon: const Icon(Icons.delete_sweep_outlined)),
      ],
      govde: Column(children: [
        Expanded(
          child: _m.isEmpty
              ? KGovde(children: [
                  KBos(
                    baslik: 'Satın almayla ilgili her şeyi sorun',
                    aciklama: 'Veriden anında cevap verir; isterseniz işlemi sizin için yapar (siz onaylarsınız) ya da raporu Excel\'e aktarır.',
                    ikon: Icons.smart_toy_outlined,
                  ),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    for (final h in _hazir) ActionChip(label: Text(h, style: TextStyle(color: t.sub2, fontSize: 13)), onPressed: () => _sor(h), backgroundColor: t.card, side: BorderSide(color: t.line)),
                  ]),
                ])
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  itemCount: _m.length + (_mesgul ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i >= _m.length) {
                      return Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(8), child: Text('AI düşünüyor…', style: TextStyle(color: t.sub, fontStyle: FontStyle.italic))));
                    }
                    final m = _m[i];
                    return Align(
                      alignment: m.ben ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: Column(crossAxisAlignment: m.ben ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: m.ben ? t.mor1 : t.card,
                              borderRadius: BorderRadius.circular(16),
                              border: m.ben ? null : Border.all(color: t.line),
                            ),
                            child: SelectableText(m.metin.replaceAll('**', ''), style: TextStyle(color: m.ben ? Colors.white : t.ink, fontSize: 14.5, height: 1.4)),
                          ),
                          if (m.exportlar.isNotEmpty)
                            Wrap(spacing: 6, runSpacing: 6, children: [
                              for (final e in m.exportlar) ActionChip(avatar: const Icon(Icons.table_view_outlined, size: 16), label: Text(metinOku(e['ad'], metinOku(e['tip']))), onPressed: () => _indir(metinOku(e['tip']), metinOku(e['ad']))),
                            ]),
                          if (m.eylem != null)
                            KKart(
                              renk: t.mor1,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Text('İsterseniz bunu sizin için yapabilirim:', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(metinOku(m.eylem!['ozet']), style: TextStyle(color: t.sub2, fontSize: 13.5)),
                                const SizedBox(height: 4),
                                Text('Onayınız imzalı log\'a yazılır, geri alınamaz.', style: TextStyle(color: t.sub, fontSize: 12)),
                                const SizedBox(height: 8),
                                if (m.eylemSonuc == null)
                                  KButon('İşlemi Yap', ikon: Icons.check, renk: t.yesil, yukleniyor: m.yurutuluyor, onTap: () => _eylemYap(m))
                                else
                                  Text(m.eylemSonuc!, style: TextStyle(color: m.eylemOk == true ? t.yesil : t.kirmizi, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _k,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sor(),
                  style: TextStyle(color: t.ink),
                  decoration: InputDecoration(hintText: 'Sorunuzu yazın… (ör. "biber için fiyat sor")', hintStyle: TextStyle(color: t.sub), border: InputBorder.none),
                ),
              ),
              IconButton.filled(onPressed: _mesgul ? null : () => _sor(), icon: const Icon(Icons.send), style: IconButton.styleFrom(backgroundColor: t.mor1)),
            ]),
          ),
        ),
      ]),
    );
  }
}
