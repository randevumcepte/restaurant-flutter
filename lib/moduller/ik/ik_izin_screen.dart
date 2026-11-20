import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';

/// /ik-izin — İzin Yönetimi (web ile aynı veri ve işlemler):
/// izin ekle / talep oluştur (yönetici doğrudan onaylayabilir), izin kayıtları (onayla / reddet + sebep / sil),
/// yıllık izin hakları (hak · kullanılan · kalan), personelin uygulamadan gönderdiği avans talepleri (onayla / reddet).
class IkIzinScreen extends StatefulWidget {
  const IkIzinScreen({super.key});
  @override
  State<IkIzinScreen> createState() => _IkIzinScreenState();
}

const _tipAd = {'yillik': 'Yıllık', 'hastalik': 'Hastalık (rapor)', 'ucretsiz': 'Ücretsiz', 'mazeret': 'Mazeret', 'dogum': 'Doğum/babalık', 'diger': 'Diğer'};
const _durumAd = {'talep': 'BEKLİYOR', 'onay': 'ONAYLI', 'ret': 'RET'};

String _gunYaz(dynamic v) {
  final d = sayiOku(v);
  return d == d.roundToDouble() ? '${d.round()}' : d.toStringAsFixed(1).replaceAll('.', ',');
}

class _IkIzinScreenState extends State<IkIzinScreen> {
  String _sekme = 'kayit';
  String _durumF = 'hepsi';

  Color _dRenk(TemaProvider t, String d) => d == 'onay' ? t.yesil : (d == 'ret' ? t.kirmizi : t.amber);

  @override
  Widget build(BuildContext context) {
    final yonetici = context.watch<AuthProvider>().patron;
    return KopruEkran(
      yol: '/ik-izin',
      baslik: 'İzin Yönetimi',
      ikon: Icons.event_available_outlined,
      fab: (c, v, yenile) => FloatingActionButton.extended(
        heroTag: 'ik_izin_ekle',
        onPressed: () => _izinForm(c, liste(v['personeller']), yonetici, yenile),
        icon: const Icon(Icons.add),
        label: const Text('İzin Ekle', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final izinler = liste(v['izinler']);
        final avans = liste(v['avansTalepleri']);
        final pers = liste(v['personeller']);
        final haklar = harita(v['haklar']);
        final bekIzin = izinler.where((i) => metinOku(i['durum']) == 'talep').length;
        final bekAvans = avans.where((i) => metinOku(i['durum']) == 'talep').length;
        final bugun = DateTime.now();
        final izinde = izinler.where((i) {
          if (metinOku(i['durum']) != 'onay') return false;
          final b = DateTime.tryParse(metinOku(i['baslangic'])), s = DateTime.tryParse(metinOku(i['bitis']));
          if (b == null || s == null) return false;
          final g = DateTime(bugun.year, bugun.month, bugun.day);
          return !g.isBefore(b) && !g.isAfter(s);
        }).length;
        return KGovde(yenile: yenile, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${metinOku(v['buYil'])} yılı · yıllık izin hakları İş Kanunu md.53\'e göre kıdemden hesaplanır.', style: TextStyle(color: t.sub, fontSize: 13)),
          ),
          KKpiIzgara([
            KKpi(etiket: 'Onay bekleyen izin', deger: '$bekIzin', ikon: Icons.pending_actions_outlined, renk: t.amber, onTap: () => setState(() { _sekme = 'kayit'; _durumF = 'talep'; })),
            KKpi(etiket: 'Bugün izinde', deger: '$izinde', ikon: Icons.beach_access_outlined, renk: t.mavi),
            KKpi(etiket: 'Bekleyen avans', deger: '$bekAvans', ikon: Icons.payments_outlined, renk: t.kirmizi, onTap: () => setState(() => _sekme = 'avans')),
            KKpi(etiket: 'Aktif personel', deger: '${pers.length}', ikon: Icons.people_outline, renk: t.mor1, onTap: () => setState(() => _sekme = 'hak')),
          ]),
          KCipler(
            secenekler: [('kayit', 'İzin kayıtları (${izinler.length})'), ('hak', 'Yıllık izin hakları'), ('avans', 'Avans talepleri${bekAvans > 0 ? ' ($bekAvans)' : ''}')],
            secili: _sekme,
            onSec: (k) => setState(() => _sekme = k),
          ),
          if (_sekme == 'kayit') ..._kayitlar(c, izinler, yonetici, yenile),
          if (_sekme == 'hak') ..._haklar(c, pers, haklar, metinOku(v['buYil'])),
          if (_sekme == 'avans') ..._avanslar(c, avans, yonetici, yenile),
        ]);
      },
    );
  }

  // ───────── izin kayıtları ─────────
  List<Widget> _kayitlar(BuildContext c, List<Map<String, dynamic>> izinler, bool yonetici, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final gor = _durumF == 'hepsi' ? izinler : izinler.where((i) => metinOku(i['durum']) == _durumF).toList();
    return [
      KCipler(
        secenekler: const [('hepsi', 'Tümü'), ('talep', 'Bekleyen'), ('onay', 'Onaylı'), ('ret', 'Reddedilen')],
        secili: _durumF,
        onSec: (k) => setState(() => _durumF = k),
      ),
      if (izinler.isEmpty)
        const KBos(
          ikon: Icons.event_available_outlined,
          baslik: 'Henüz izin kaydı yok',
          aciklama: 'Sağ alttaki "İzin Ekle" ile personel için izin girebilir ya da talep oluşturabilirsiniz. Personel de kendi uygulamasından (İK Self Servis) izin talebi gönderebilir.',
        )
      else if (gor.isEmpty)
        const KBos(ikon: Icons.filter_alt_off_outlined, baslik: 'Bu filtrede kayıt yok', aciklama: 'Üstteki filtreden "Tümü"nü seçin.')
      else
        for (final iz in gor)
          KKart(
            renk: _dRenk(t, metinOku(iz['durum'])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(metinOku(iz['personel_ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
                KRozet(_durumAd[metinOku(iz['durum'])] ?? 'BEKLİYOR', renk: _dRenk(t, metinOku(iz['durum']))),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                KRozet(_tipAd[metinOku(iz['tip'])] ?? metinOku(iz['tip']), renk: t.mavi),
                Text('${tarihYaz(iz['baslangic'], saat: false)} – ${tarihYaz(iz['bitis'], saat: false)} · ${_gunYaz(iz['gun'])} gün',
                    style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              if (metinOku(iz['aciklama']).isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 6), child: Text(metinOku(iz['aciklama']), style: TextStyle(color: t.sub, fontSize: 12.5))),
              if (metinOku(iz['durum']) == 'ret' && metinOku(iz['ret_sebep']).isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Ret: ${metinOku(iz['ret_sebep'])}', style: TextStyle(color: t.kirmizi, fontSize: 12.5))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
                if (yonetici && metinOku(iz['durum']) == 'talep') ...[
                  KButon('Onayla', ikon: Icons.check, renk: t.yesil, onTap: () async {
                    if (!await kOnay(c, '${metinOku(iz['personel_ad'])} için izin onaylansın mı?', evet: 'Onayla')) return;
                    if (!c.mounted) return;
                    if (await kopruGonder(c, '/ik-izin/karar', {'id': iz['id'], 'karar': 'onay'})) await yenile();
                  }),
                  KButon('Reddet', ikon: Icons.close, renk: t.kirmizi, ikincil: true, onTap: () => _ret(c, iz, yenile)),
                ],
                KButon('Sil', ikon: Icons.delete_outline, renk: t.sub, ikincil: true, onTap: () async {
                  if (!await kOnay(c, 'Bu izin kaydı silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                  if (!c.mounted) return;
                  if (await kopruGonder(c, '/ik-izin/sil', {'id': iz['id']})) await yenile();
                }),
              ]),
            ]),
          ),
    ];
  }

  Future<void> _ret(BuildContext c, Map<String, dynamic> iz, Future<void> Function() yenile) async {
    final sebep = TextEditingController();
    final ok = await kAltSayfa<bool>(c, baslik: 'İzin reddet', icerik: (cc) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${metinOku(iz['personel_ad'])} için izin reddediliyor.', style: TextStyle(color: cc.read<TemaProvider>().sub2, fontSize: 14)),
          ),
          KAlan('Sebep (opsiyonel)', sebep, ipucu: 'ör. yoğun dönem'),
          KButon('Reddet', ikon: Icons.close, renk: const Color(0xFFDC2626), genis: true, onTap: () => Navigator.pop(cc, true)),
        ]));
    if (ok != true || !c.mounted) return;
    if (await kopruGonder(c, '/ik-izin/karar', {'id': iz['id'], 'karar': 'ret', 'ret_sebep': sebep.text.trim()})) await yenile();
  }

  // ───────── yıllık haklar ─────────
  List<Widget> _haklar(BuildContext c, List<Map<String, dynamic>> pers, Map<String, dynamic> haklar, String yil) {
    final t = c.watch<TemaProvider>();
    if (pers.isEmpty) {
      return const [KBos(ikon: Icons.people_outline, baslik: 'Aktif personel yok', aciklama: 'Personel, Personel & Maaş ekranından eklenir.')];
    }
    return [
      KKart(
        child: Column(children: [
          for (final p in pers)
            Builder(builder: (_) {
              final h = harita(haklar['${p['id']}']);
              final hak = sayiOku(h['hak']), kul = sayiOku(h['kullanilan']), kal = sayiOku(h['kalan']);
              final oran = hak > 0 ? (kul / hak).clamp(0.0, 1.0) : 0.0;
              final r = oran >= .9 ? t.kirmizi : (oran >= .7 ? t.amber : t.mavi);
              return KSatir(
                onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/ik-sicil?id=${p['id']}', 'Sicil Kartı'))),
                solIkon: CircleAvatar(
                  radius: 18,
                  backgroundColor: t.mor1.withValues(alpha: .14),
                  child: Text(metinOku(p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
                ),
                baslik: metinOku(p['ad']),
                alt: hak > 0
                    ? '$yil hakkı ${_gunYaz(hak)} gün · kullanılan ${_gunYaz(kul)}'
                    : '1 yılı dolmadı ya da işe başlama tarihi girilmemiş (Personel & Maaş › Özlük)',
                sag: hak > 0
                    ? SizedBox(
                        width: 96,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${_gunYaz(kal)} gün', style: TextStyle(color: kal > 0 ? t.yesil : t.sub, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: LinearProgressIndicator(value: oran, minHeight: 6, backgroundColor: t.line, color: r),
                          ),
                        ]),
                      )
                    : Text('—', style: TextStyle(color: t.sub)),
              );
            }),
        ]),
      ),
    ];
  }

  // ───────── avans talepleri ─────────
  List<Widget> _avanslar(BuildContext c, List<Map<String, dynamic>> avans, bool yonetici, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    if (avans.isEmpty) {
      return const [
        KBos(
          ikon: Icons.payments_outlined,
          baslik: 'Avans talebi yok',
          aciklama: 'Personel, kendi uygulamasından (İK Self Servis) avans talebi gönderebilir; gelen talepler burada onaylanır.',
        ),
      ];
    }
    return [
      for (final a in avans)
        KKart(
          renk: _dRenk(t, metinOku(a['durum'])),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(a['personel_ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${tarihYaz(a['created_at'], saat: false)}${metinOku(a['aciklama']).isNotEmpty ? ' · ${metinOku(a['aciklama'])}' : ''}',
                      style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
              Text(tl(a['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              KRozet(_durumAd[metinOku(a['durum'])] ?? 'BEKLİYOR', renk: _dRenk(t, metinOku(a['durum']))),
            ]),
            if (yonetici && metinOku(a['durum']) == 'talep') ...[
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                KButon('Onayla', ikon: Icons.check, renk: t.yesil, onTap: () async {
                  if (!await kOnay(c, '${metinOku(a['personel_ad'])} için ${tl(a['tutar'], kisa: true)} avans onaylansın mı?',
                      aciklama: 'Kasadan çıkış ve gider kaydı otomatik işlenir.', evet: 'Onayla')) {
                    return;
                  }
                  if (!c.mounted) return;
                  if (await kopruGonder(c, '/ik-avans-karar', {'id': a['id'], 'karar': 'onay'})) await yenile();
                }),
                KButon('Reddet', ikon: Icons.close, renk: t.kirmizi, ikincil: true, onTap: () async {
                  if (!await kOnay(c, 'Avans talebi reddedilsin mi?', evet: 'Reddet', tehlikeli: true)) return;
                  if (!c.mounted) return;
                  if (await kopruGonder(c, '/ik-avans-karar', {'id': a['id'], 'karar': 'ret'})) await yenile();
                }),
              ]),
            ],
          ]),
        ),
    ];
  }

  // ───────── izin ekle formu ─────────
  Future<void> _izinForm(BuildContext c, List<Map<String, dynamic>> pers, bool yonetici, Future<void> Function() yenile) async {
    if (pers.isEmpty) {
      kToast(c, 'Aktif personel yok. Önce Personel & Maaş ekranından personel ekleyin.', hata: true);
      return;
    }
    int? pid;
    String tip = 'yillik';
    DateTime? bas, bit;
    final gun = TextEditingController();
    final aciklama = TextEditingController();
    bool onay = false;
    bool gonderiliyor = false;
    String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await kAltSayfa(c, baslik: 'İzin Ekle / Talep Oluştur', icerik: (cc) => StatefulBuilder(builder: (cc, ss) {
          final t = cc.watch<TemaProvider>();
          Widget tarihSec(String et, DateTime? d, ValueChanged<DateTime> sec) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(et, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: t.line)),
                      onPressed: () async {
                        final s = await showDatePicker(context: cc, initialDate: d ?? bas ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2035));
                        if (s != null) ss(() => sec(s));
                      },
                      icon: Icon(Icons.event, size: 18, color: t.mor1),
                      label: Text(d == null ? 'Seç' : tarihYaz(ymd(d), saat: false), style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              );
          final otoGun = (bas != null && bit != null && !bit!.isBefore(bas!)) ? bit!.difference(bas!).inDays + 1 : null;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Personel *', deger: pid, secenekler: [for (final p in pers) (tamOku(p['id']), '${metinOku(p['ad'])} (${metinOku(p['rol'])})')], onSec: (v) => ss(() => pid = v)),
            KSecim<String>('İzin tipi', deger: tip, secenekler: [for (final e in _tipAd.entries) (e.key, e.value)], onSec: (v) => ss(() => tip = v ?? 'yillik')),
            Row(children: [
              tarihSec('Başlangıç *', bas, (d) {
                bas = d;
                if (bit == null || bit!.isBefore(d)) bit = d;
              }),
              const SizedBox(width: 10),
              tarihSec('Bitiş *', bit, (d) => bit = d),
            ]),
            KAlan('Gün', gun, ipucu: otoGun == null ? 'boş = otomatik' : '$otoGun gün (otomatik)', klavye: const TextInputType.numberWithOptions(decimal: true)),
            KAlan('Açıklama (opsiyonel)', aciklama, ipucu: 'ör. yıllık izin'),
            if (yonetici)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: onay,
                activeColor: t.mor1,
                onChanged: (v) => ss(() => onay = v == true),
                title: Text('Doğrudan onayla', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('İşaretlemezseniz talep olarak "Bekliyor" kaydedilir.', style: TextStyle(color: t.sub, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: gonderiliyor, onTap: () async {
              if (pid == null || bas == null || bit == null) {
                kToast(cc, 'Personel, başlangıç ve bitiş seçin.', hata: true);
                return;
              }
              if (bit!.isBefore(bas!)) {
                kToast(cc, 'Bitiş, başlangıçtan önce olamaz.', hata: true);
                return;
              }
              ss(() => gonderiliyor = true);
              final ok = await kopruGonder(cc, '/ik-izin/kaydet', {
                'personel_id': pid,
                'tip': tip,
                'baslangic': ymd(bas!),
                'bitis': ymd(bit!),
                if (gun.text.trim().isNotEmpty) 'gun': gun.text.trim().replaceAll(',', '.'),
                'aciklama': aciklama.text.trim(),
                if (onay) 'durum': 'onay',
              });
              if (!cc.mounted) return;
              ss(() => gonderiliyor = false);
              if (ok) {
                Navigator.pop(cc);
                await yenile();
              }
            }),
          ]);
        }));
  }
}
