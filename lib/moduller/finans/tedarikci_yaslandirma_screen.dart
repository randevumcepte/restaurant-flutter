import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _zRenk = {'Hemen': Color(0xFFF43F5E), 'Bu hafta': Color(0xFFD97706), '2 hafta içinde': Color(0xFF3B82F6), 'Vadesinde': Color(0xFF10B981)};

/// /tedarikci-yaslandirma — ödenmemiş alış faturaları vadesine göre + ödeme önceliği planı (kural → AI arka planda)
class TedarikciYaslandirmaScreen extends StatelessWidget {
  const TedarikciYaslandirmaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/tedarikci-yaslandirma',
      baslik: 'Tedarikçi Yaşlandırma',
      ikon: Icons.hourglass_bottom,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final y = harita(v['y']);
    final plan = v['plan'] is Map ? harita(v['plan']) : null;
    final patron = v['patronMu'] == true || v['patronMu'] == 1;
    final ted = liste(y['tedarikciler']);
    final toplam = sayiOku(y['toplam']);
    final faturaSay = ted.fold<int>(0, (a, s) => a + liste(s['faturalar']).length);
    String yz(dynamic x) => toplam > 0 ? '%${(sayiOku(x) / toplam * 100).round()}' : '';
    final dilim = [
      ('Gecikmiş', y['gecikmis'], const Color(0xFFF43F5E), 'Vadesi geçmiş', Icons.error_outline),
      ('Bu hafta', y['hafta'], const Color(0xFFF59E0B), '0–7 gün içinde', Icons.schedule),
      ('8–30 gün', y['ay'], const Color(0xFF3B82F6), 'Bu ay içinde', Icons.date_range),
      ('31+ gün', y['ileri'], const Color(0xFF10B981), 'Vadesi uzak', Icons.event_available_outlined),
    ];

    return KGovde(yenile: yenile, maxGenislik: 1240, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam borç', deger: tl(toplam, kisa: true), alt: '${ted.length} tedarikçi · $faturaSay açık fatura', ikon: Icons.account_balance_wallet_outlined, renk: const Color(0xFF6366F1)),
        for (final d in dilim) KKpi(etiket: d.$1, deger: tl(d.$2, kisa: true), alt: '${d.$4}${toplam > 0 ? ' · ${yz(d.$2)}' : ''}', ikon: d.$5, renk: d.$3),
      ]),
      if (toplam > 0) ...[
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Vade dağılımı', ikon: Icons.donut_large),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 14,
                child: Row(children: [
                  for (final d in dilim)
                    if (sayiOku(d.$2) > 0) Expanded(flex: (sayiOku(d.$2) / toplam * 1000).round().clamp(1, 1000), child: Container(color: d.$3)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final d in dilim)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: d.$3, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('${d.$1} ${yz(d.$2)} · ${tl(d.$2, kisa: true)}', style: TextStyle(color: t.sub2, fontSize: 12.5)),
                ]),
            ]),
          ]),
        ),
        if (plan != null) _PlanKart(plan: plan),
      ],
      KBaslik('Tedarikçi borçları', ikon: Icons.local_shipping_outlined, sag: KRozet('${ted.length}', renk: t.mor1)),
      if (ted.isEmpty)
        const KKart(
          child: KBos(
            baslik: 'Ödenmemiş alış faturası yok',
            aciklama: 'Borç görünmüyor. Alış faturaları Mal Kabul / Gelen e-Fatura ekranlarından girildikçe burada vadesine göre listelenir; "ödendi" işaretlenenler listeden düşer.',
            ikon: Icons.check_circle_outline,
          ),
        )
      else
        for (final s in ted) _tedKart(context, t, s, patron, yenile),
      const FNot('Borç = ödenmemiş alış faturaları. Vade, faturadaki vade tarihinden; yoksa tedarikçinin ödeme vadesi gününden hesaplanır. Ödeme yaptığınızda faturayı "ödendi" işaretleyin, listeden düşer.'),
    ]);
  }

  Widget _tedKart(BuildContext context, TemaProvider t, Map<String, dynamic> s, bool patron, Future<void> Function() yenile) {
    final f = liste(s['faturalar']);
    final gec = sayiOku(s['gecikmis']) > 0;
    String h(dynamic x) => sayiOku(x) > 0 ? tl(x, kisa: true) : '–';
    return KKart(
      renk: gec ? t.kirmizi : (sayiOku(s['hafta']) > 0 ? t.amber : t.yesil),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          iconColor: t.sub,
          collapsedIconColor: t.sub,
          title: Text(metinOku(s['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              KRozet('Toplam ${tl(s['toplam'], kisa: true)}', renk: t.mor1),
              if (gec) KRozet('Gecikmiş ${h(s['gecikmis'])}', renk: t.kirmizi),
              if (sayiOku(s['hafta']) > 0) KRozet('Bu hafta ${h(s['hafta'])}', renk: t.amber),
              if (sayiOku(s['ay']) > 0) KRozet('8–30 gün ${h(s['ay'])}', renk: t.mavi),
              if (sayiOku(s['ileri']) > 0) KRozet('31+ gün ${h(s['ileri'])}', renk: t.yesil),
              KRozet('${f.length} fatura', renk: t.sub),
            ]),
          ),
          children: [
            for (final x in f)
              KSatir(
                baslik: '${metinOku(x['no']).isEmpty ? '#${x['id']}' : metinOku(x['no'])} · ${tarihYaz(x['tarih'], saat: false)}',
                alt: _gunYaz(tamOku(x['gun'])),
                sag: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tl(x['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  if (patron)
                    IconButton(
                      tooltip: 'Ödendi işaretle',
                      icon: Icon(Icons.check_circle_outline, color: t.yesil),
                      onPressed: () => _odendi(context, yenile, {'fatura_id': x['id']}, 'Bu fatura ödendi olarak işaretlensin mi?'),
                    ),
                ]),
              ),
            if (patron && f.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
                child: KButon('Tümü ödendi', ikon: Icons.done_all, ikincil: true, renk: t.yesil, genis: true,
                    onTap: () => _odendi(context, yenile, {'tedarikci_id': s['id']}, '${metinOku(s['ad'])} için tüm açık faturalar ödendi olarak işaretlensin mi?')),
              ),
          ],
        ),
      ),
    );
  }

  static String _gunYaz(int g) => g < 0 ? '${g.abs()} gün gecikmiş' : (g == 0 ? 'vadesi bugün' : '$g gün kaldı');

  Future<void> _odendi(BuildContext context, Future<void> Function() yenile, Map<String, dynamic> veri, String soru) async {
    if (!await kOnay(context, soru, evet: 'Ödendi')) return;
    if (!context.mounted) return;
    if (await kopruGonder(context, '/tedarikci-yaslandirma/odendi', veri, basariMesaji: 'Ödendi olarak işaretlendi.')) {
      await yenile();
    }
  }
}

/// Ödeme önceliği planı: önce kural tabanlı (sayfadan), AI planı arka planda gelince yerini alır.
class _PlanKart extends StatefulWidget {
  final Map<String, dynamic> plan;
  const _PlanKart({required this.plan});
  @override
  State<_PlanKart> createState() => _PlanKartState();
}

class _PlanKartState extends State<_PlanKart> {
  Map<String, dynamic>? _ai;
  bool _yukleniyor = true;
  bool _hata = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _aiAl());
  }

  Future<void> _aiAl() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() { _yukleniyor = true; _hata = false; });
    try {
      final c = await KopruApi.al(tok, '/tedarikci-yaslandirma/ai');
      if (!mounted) return;
      final j = c.j;
      final adim = liste(j['adimlar']);
      setState(() {
        _yukleniyor = false;
        if (c.ok && adim.isNotEmpty) {
          _ai = j;
        } else {
          _hata = true;
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) setState(() { _yukleniyor = false; _hata = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final p = _ai ?? widget.plan;
    final adimlar = liste(p['adimlar']);
    return KKart(
      renk: const Color(0xFF6366F1),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Ödeme önceliği planı', ikon: Icons.auto_awesome_outlined, renk: const Color(0xFF6366F1),
            sag: KRozet(_ai != null ? 'AI Nakit Danışmanı' : 'Kural tabanlı', renk: _ai != null ? const Color(0xFF6366F1) : t.sub, ikon: _ai != null ? Icons.auto_awesome : Icons.rule)),
        if (metinOku(p['ozet']).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, color: t.amber, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(metinOku(p['ozet']), style: TextStyle(color: t.ink, fontSize: 14, height: 1.4))),
            ]),
          ),
        for (var i = 0; i < adimlar.length; i++) _adim(t, i + 1, adimlar[i]),
        const SizedBox(height: 4),
        if (_yukleniyor)
          Row(children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.mor1)),
            const SizedBox(width: 8),
            Text('AI Nakit Danışmanı planı hazırlıyor…', style: TextStyle(color: t.sub, fontSize: 12.5)),
          ])
        else if (_hata)
          Row(children: [
            Icon(Icons.info_outline, size: 15, color: t.sub),
            const SizedBox(width: 6),
            Expanded(child: Text('AI planı şu an alınamadı, kural tabanlı plan gösteriliyor.', style: TextStyle(color: t.sub, fontSize: 12.5))),
            TextButton(onPressed: _aiAl, child: const Text('Tekrar dene')),
          ]),
      ]),
    );
  }

  Widget _adim(TemaProvider t, int no, Map<String, dynamic> a) {
    final z = metinOku(a['zaman']);
    final zc = _zRenk[z] ?? const Color(0xFF6366F1);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: zc, width: 4)), color: zc.withValues(alpha: .06)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 13, backgroundColor: zc, child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(metinOku(a['tedarikci']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
              if (z.isNotEmpty) KRozet(z, renk: zc),
              if (sayiOku(a['tutar']) > 0) Text(tl(a['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
            if (metinOku(a['neden']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Neden: ${metinOku(a['neden'])}', style: TextStyle(color: t.sub2, fontSize: 13))),
            if (metinOku(a['aksiyon']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Ne yapmalı: ${metinOku(a['aksiyon'])}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600))),
          ]),
        ),
      ]),
    );
  }
}
