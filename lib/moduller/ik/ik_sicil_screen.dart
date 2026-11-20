import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// /ik-sicil?id=N — Personel Sicil Kartı (web ile aynı veri ve işlemler):
/// özlük özeti (kıdem, yıllık izin hakkı), zimmet (ekle / iade-geri al / sil), belge & sertifika
/// (ekle + dosya yükle / indir / sil, SKT uyarısı), eğitim (ekle / sil), avans-kesinti geçmişi, izin geçmişi.
/// `id` verilmezse önce personel seçtirilir.
class IkSicilScreen extends StatelessWidget {
  final String url;
  final int? personelId;
  const IkSicilScreen({super.key, this.url = '', this.personelId});

  int? get _id {
    if (personelId != null && personelId! > 0) return personelId;
    final q = Uri.tryParse(url)?.queryParameters['id'];
    final n = int.tryParse(q ?? '');
    return (n != null && n > 0) ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) return const _PersonelSec();
    return _SicilKart(id: id);
  }
}

/// id'siz açılışta personel seçimi (aktif personel listesi web /ik-izin verisinden)
class _PersonelSec extends StatefulWidget {
  const _PersonelSec();
  @override
  State<_PersonelSec> createState() => _PersonelSecState();
}

class _PersonelSecState extends State<_PersonelSec> {
  String _ara = '';
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/ik-izin',
      baslik: 'Sicil Kartı — personel seçin',
      ikon: Icons.folder_shared_outlined,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final pers = liste(v['personeller']).where((p) => metinOku(p['ad']).toLowerCase().contains(_ara.toLowerCase())).toList();
        return KGovde(yenile: yenile, children: [
          KAra(ipucu: 'Personel ara…', onDegis: (s) => setState(() => _ara = s)),
          if (pers.isEmpty)
            const KBos(ikon: Icons.people_outline, baslik: 'Personel bulunamadı', aciklama: 'Aktif personel Personel & Maaş ekranından eklenir.')
          else
            KKart(
              child: Column(children: [
                for (final p in pers)
                  KSatir(
                    solIkon: CircleAvatar(
                      radius: 18,
                      backgroundColor: t.mor1.withValues(alpha: .14),
                      child: Text(metinOku(p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
                    ),
                    baslik: metinOku(p['ad']),
                    alt: metinOku(p['rol']),
                    sag: Icon(Icons.chevron_right, color: t.sub),
                    onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => IkSicilScreen(personelId: tamOku(p['id'])))),
                  ),
              ]),
            ),
        ]);
      },
    );
  }
}

const _belgeTip = {
  'sozlesme': 'Sözleşme', 'kimlik': 'Kimlik', 'diploma': 'Diploma', 'saglik': 'Sağlık Raporu', 'hijyen': 'Hijyen/HACCP',
  'sertifika': 'Sertifika', 'ehliyet': 'Ehliyet', 'adli_sicil': 'Adli Sicil', 'diger': 'Diğer',
};
const _harTur = {'avans': 'Avans', 'odeme': 'Ödeme', 'prim': 'Prim', 'kesinti': 'Kesinti / İcra', 'ek_odeme': 'Ek Ödeme'};
const _izinDurum = {'talep': 'Bekliyor', 'onay': 'Onaylı', 'ret': 'Ret'};

String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class _SicilKart extends StatelessWidget {
  final int id;
  const _SicilKart({required this.id});

  /// SKT durumu: geçti / N gün kaldı (≤30)
  (String, Color)? _skt(TemaProvider t, dynamic v) {
    final d = DateTime.tryParse(metinOku(v));
    if (d == null) return null;
    final n = DateTime.now();
    final fark = DateTime(d.year, d.month, d.day).difference(DateTime(n.year, n.month, n.day)).inDays;
    if (fark < 0) return ('geçti', t.kirmizi);
    if (fark <= 30) return ('$fark gün kaldı', t.amber);
    return null;
  }

  void _ac(BuildContext c, String url, String ad) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/ik-sicil',
      q: {'id': '$id'},
      baslik: 'Sicil Kartı',
      ikon: Icons.folder_shared_outlined,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final per = harita(v['per']);
        if (per.isEmpty) {
          return const KBos(ikon: Icons.person_off_outlined, baslik: 'Personel bulunamadı', aciklama: 'Personel silinmiş ya da bu şubeye ait değil.');
        }
        final zimmet = liste(v['zimmet']);
        final belge = liste(v['belge']);
        final egitim = liste(v['egitim']);
        final hareket = liste(v['hareket']);
        final izinler = liste(v['izinler']);
        final pid = per['id'];

        Widget bilgi(String et, String d) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.isEmpty ? '—' : d, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(et, style: TextStyle(color: t.sub, fontSize: 11.5)),
              ]),
            );
        final bilgiler = [
          bilgi('Telefon', metinOku(per['telefon'])),
          bilgi('İşe başlama', metinOku(per['ise_baslama']).isEmpty ? '' : tarihYaz(per['ise_baslama'], saat: false)),
          bilgi('Kıdem', metinOku(v['kidem'])),
          bilgi('Yıllık izin hakkı', tamOku(v['yillikHak']) > 0 ? '${tamOku(v['yillikHak'])} gün' : ''),
          bilgi('Doğum tarihi', metinOku(per['dogum_tarihi']).isEmpty ? '' : tarihYaz(per['dogum_tarihi'], saat: false)),
          bilgi('TC kimlik', metinOku(per['tc'])),
          bilgi('IBAN', metinOku(per['iban'])),
          bilgi('Acil durum', [metinOku(per['acil_kisi']), if (metinOku(per['acil_tel']).isNotEmpty) '(${metinOku(per['acil_tel'])})'].where((x) => x.isNotEmpty).join(' ')),
        ];

        return KGovde(yenile: yenile, children: [
          // başlık
          KKart(
            renk: const Color(0xFF10B981),
            child: Row(children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF10B981).withValues(alpha: .15),
                child: Text(metinOku(per['ad'], '?').substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF10B981), fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(per['ad']), style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w800)),
                  Text([metinOku(per['rol']), metinOku(per['departman_unvan'])].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(color: t.sub, fontSize: 13)),
                ]),
              ),
              if (metinOku(per['aktif']) == '0') KRozet('Pasif', renk: t.sub),
            ]),
          ),
          // özlük
          KBaslik('Özlük', ikon: Icons.badge_outlined, renk: t.mavi,
              sag: TextButton(onPressed: () => _ac(c, '/personel', 'Personel & Maaş'), child: Text('Düzenle', style: TextStyle(color: t.mavi, fontWeight: FontWeight.w700)))),
          LayoutBuilder(builder: (ctx, cs) {
            final n = cs.maxWidth >= 900 ? 4 : 2;
            final g = (cs.maxWidth - 8 * (n - 1)) / n;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(spacing: 8, runSpacing: 8, children: [for (final b in bilgiler) SizedBox(width: g, child: b)]),
            );
          }),

          // zimmet
          KBaslik('Zimmet (${zimmet.length})', ikon: Icons.inventory_2_outlined,
              sag: TextButton.icon(onPressed: () => _zimmetForm(c, pid, yenile), icon: Icon(Icons.add, color: t.mor1), label: Text('Ekle', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)))),
          KKart(
            child: zimmet.isEmpty
                ? Text('Zimmet kaydı yok. Üniforma, telefon, anahtar gibi teslim edilen eşyaları "Ekle" ile girin.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final z in zimmet)
                      KSatir(
                        solIkon: Icon(metinOku(z['durum']) == 'iade' ? Icons.assignment_return_outlined : Icons.assignment_ind_outlined, color: t.sub),
                        baslik: '${metinOku(z['urun'])}${tamOku(z['adet']) > 1 ? ' ×${tamOku(z['adet'])}' : ''}',
                        alt: [
                          if (metinOku(z['teslim_tarihi']).isNotEmpty) '${tarihYaz(z['teslim_tarihi'], saat: false)} teslim',
                          if (metinOku(z['durum']) == 'iade' && metinOku(z['iade_tarihi']).isNotEmpty) '${tarihYaz(z['iade_tarihi'], saat: false)} iade',
                          if (metinOku(z['not']).isNotEmpty) metinOku(z['not']),
                        ].join(' · '),
                        sag: Row(mainAxisSize: MainAxisSize.min, children: [
                          KRozet(metinOku(z['durum']) == 'iade' ? 'İADE' : 'ZİMMETTE', renk: metinOku(z['durum']) == 'iade' ? t.sub : t.yesil),
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_vert, color: t.sub),
                            onSelected: (s) async {
                              if (s == 'durum') {
                                if (await kopruGonder(c, '/ik-sicil/zimmet-durum', {'id': z['id'], 'personel_id': pid})) await yenile();
                              } else {
                                if (!await kOnay(c, 'Zimmet kaydı silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                                if (!c.mounted) return;
                                if (await kopruGonder(c, '/ik-sicil/zimmet-sil', {'id': z['id'], 'personel_id': pid})) await yenile();
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(value: 'durum', child: Text(metinOku(z['durum']) == 'iade' ? 'Geri zimmetle' : 'İade alındı')),
                              const PopupMenuItem(value: 'sil', child: Text('Sil')),
                            ],
                          ),
                        ]),
                      ),
                  ]),
          ),

          // belge
          KBaslik('Belge & Sertifika (${belge.length})', ikon: Icons.description_outlined, renk: t.amber, alt: 'Son geçerliliği yaklaşanlar uyarılır',
              sag: TextButton.icon(onPressed: () => _belgeForm(c, pid, yenile), icon: Icon(Icons.upload_file, color: t.mor1), label: Text('Ekle', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)))),
          KKart(
            child: belge.isEmpty
                ? Text('Belge yok. Sözleşme, sağlık raporu, hijyen sertifikası gibi belgeleri "Ekle" ile girin; dosya da yükleyebilirsiniz.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final b in belge)
                      Builder(builder: (_) {
                        final s = _skt(t, b['son_gecerlilik']);
                        return KSatir(
                          solIkon: KRozet(_belgeTip[metinOku(b['tip'])] ?? metinOku(b['tip']), renk: t.amber),
                          baslik: metinOku(b['baslik']),
                          alt: [
                            if (metinOku(b['belge_tarihi']).isNotEmpty) tarihYaz(b['belge_tarihi'], saat: false),
                            if (metinOku(b['son_gecerlilik']).isNotEmpty) 'son: ${tarihYaz(b['son_gecerlilik'], saat: false)}',
                            if (metinOku(b['not']).isNotEmpty) metinOku(b['not']),
                          ].join(' · '),
                          sag: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (s != null) KRozet(s.$1, renk: s.$2),
                            if (metinOku(b['dosya']).isNotEmpty)
                              IconButton(tooltip: 'İndir', onPressed: () => _indir(c, b), icon: Icon(Icons.download_outlined, color: t.mavi)),
                            IconButton(
                              tooltip: 'Sil',
                              onPressed: () async {
                                if (!await kOnay(c, 'Belge silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                                if (!c.mounted) return;
                                if (await kopruGonder(c, '/ik-sicil/belge-sil', {'id': b['id'], 'personel_id': pid})) await yenile();
                              },
                              icon: Icon(Icons.delete_outline, color: t.kirmizi),
                            ),
                          ]),
                        );
                      }),
                  ]),
          ),

          // eğitim
          KBaslik('Eğitim (${egitim.length})', ikon: Icons.school_outlined, renk: t.yesil,
              sag: TextButton.icon(onPressed: () => _egitimForm(c, pid, yenile), icon: Icon(Icons.add, color: t.mor1), label: Text('Ekle', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)))),
          KKart(
            child: egitim.isEmpty
                ? Text('Eğitim kaydı yok. İSG, hijyen gibi eğitimleri "Ekle" ile girin; yenileme tarihi yaklaşınca uyarılır.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final e in egitim)
                      Builder(builder: (_) {
                        final s = _skt(t, e['son_gecerlilik']);
                        return KSatir(
                          solIkon: Icon(Icons.menu_book_outlined, color: t.sub),
                          baslik: metinOku(e['konu']),
                          alt: [
                            if (metinOku(e['egitim_tarihi']).isNotEmpty) tarihYaz(e['egitim_tarihi'], saat: false),
                            if (metinOku(e['veren']).isNotEmpty) metinOku(e['veren']),
                            if (metinOku(e['son_gecerlilik']).isNotEmpty) 'yenileme: ${tarihYaz(e['son_gecerlilik'], saat: false)}',
                            if (metinOku(e['not']).isNotEmpty) metinOku(e['not']),
                          ].join(' · '),
                          sag: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (s != null) KRozet(s.$1, renk: s.$2),
                            IconButton(
                              tooltip: 'Sil',
                              onPressed: () async {
                                if (!await kOnay(c, 'Eğitim kaydı silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
                                if (!c.mounted) return;
                                if (await kopruGonder(c, '/ik-sicil/egitim-sil', {'id': e['id'], 'personel_id': pid})) await yenile();
                              },
                              icon: Icon(Icons.delete_outline, color: t.kirmizi),
                            ),
                          ]),
                        );
                      }),
                  ]),
          ),

          // hareket
          KBaslik('Avans / İcra / Kesinti Geçmişi', ikon: Icons.payments_outlined, renk: t.kirmizi,
              sag: TextButton(onPressed: () => _ac(c, '/personel', 'Personel & Maaş'), child: Text('Yeni işlem', style: TextStyle(color: t.mavi, fontWeight: FontWeight.w700)))),
          KKart(
            child: hareket.isEmpty
                ? Text('Avans/kesinti kaydı yok. İcra kesintisi için Personel & Maaş\'tan "Kesinti" ekleyip açıklamaya "İcra" yazabilirsiniz.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final h in hareket)
                      KSatir(
                        solIkon: KRozet(_harTur[metinOku(h['tur'])] ?? metinOku(h['tur']), renk: _turRenk(t, metinOku(h['tur']))),
                        baslik: metinOku(h['aciklama'], '—'),
                        alt: tarihYaz(h['tarih'], saat: false),
                        sag: Text(tl(h['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ),
                  ]),
          ),

          // izin
          KBaslik('İzin Geçmişi', ikon: Icons.event_available_outlined, renk: t.mavi,
              sag: TextButton(onPressed: () => _ac(c, '/ik-izin', 'İzin Yönetimi'), child: Text('İzin Yönetimi', style: TextStyle(color: t.mavi, fontWeight: FontWeight.w700)))),
          KKart(
            child: izinler.isEmpty
                ? Text('İzin kaydı yok.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final iz in izinler)
                      KSatir(
                        solIkon: KRozet(_ilkBuyuk(metinOku(iz['tip'])), renk: t.mavi),
                        baslik: '${tarihYaz(iz['baslangic'], saat: false)} – ${tarihYaz(iz['bitis'], saat: false)}',
                        alt: '${sayiYaz(iz['gun'])} gün${metinOku(iz['aciklama']).isNotEmpty ? ' · ${metinOku(iz['aciklama'])}' : ''}',
                        sag: KRozet(_izinDurum[metinOku(iz['durum'])] ?? 'Bekliyor',
                            renk: metinOku(iz['durum']) == 'onay' ? t.yesil : (metinOku(iz['durum']) == 'ret' ? t.kirmizi : t.amber)),
                      ),
                  ]),
          ),
        ]);
      },
    );
  }

  static String _ilkBuyuk(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Color _turRenk(TemaProvider t, String tur) =>
      {'avans': t.amber, 'odeme': t.yesil, 'prim': t.mavi, 'kesinti': t.kirmizi, 'ek_odeme': t.mor1}[tur] ?? t.sub;

  // ───────── tarih seçici alanı ─────────
  static Widget _tarihAlan(BuildContext cc, String et, DateTime? d, void Function(void Function()) ss, ValueChanged<DateTime?> sec) {
    final t = cc.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(et, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: t.line)),
              onPressed: () async {
                final s = await showDatePicker(context: cc, initialDate: d ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime(2040));
                if (s != null) ss(() => sec(s));
              },
              icon: Icon(Icons.event, size: 18, color: t.mor1),
              label: Text(d == null ? 'Seç (opsiyonel)' : tarihYaz(_ymd(d), saat: false), style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
            ),
          ),
          if (d != null) IconButton(tooltip: 'Temizle', onPressed: () => ss(() => sec(null)), icon: Icon(Icons.close, color: t.sub)),
        ]),
      ]),
    );
  }

  Future<void> _zimmetForm(BuildContext c, dynamic pid, Future<void> Function() yenile) async {
    final urun = TextEditingController();
    final adet = TextEditingController(text: '1');
    final not = TextEditingController();
    DateTime? teslim = DateTime.now();
    await kAltSayfa(c, baslik: 'Zimmet Ekle', icerik: (cc) => StatefulBuilder(builder: (cc, ss) {
          final t = cc.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Zimmet', urun, ipucu: 'üniforma / telefon / anahtar …', zorunlu: true),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final o in const ['Üniforma', 'Telefon', 'Anahtar', 'Tablet', 'Önlük', 'Ayakkabı', 'Kart'])
                  ActionChip(
                    label: Text(o, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    backgroundColor: t.card2,
                    side: BorderSide(color: t.line),
                    onPressed: () => ss(() => urun.text = o),
                  ),
              ]),
            ),
            KAlan('Adet', adet, klavye: TextInputType.number),
            _tarihAlan(cc, 'Teslim tarihi', teslim, ss, (d) => teslim = d),
            KAlan('Not', not),
            KButon('Ekle', ikon: Icons.add, genis: true, onTap: () async {
              if (urun.text.trim().isEmpty) {
                kToast(cc, 'Zimmet adı boş olamaz.', hata: true);
                return;
              }
              final ok = await kopruGonder(cc, '/ik-sicil/zimmet', {
                'personel_id': pid,
                'urun': urun.text.trim(),
                'adet': adet.text.trim().isEmpty ? '1' : adet.text.trim(),
                if (teslim != null) 'teslim_tarihi': _ymd(teslim!),
                'not': not.text.trim(),
              });
              if (ok) {
                if (cc.mounted) Navigator.pop(cc);
                await yenile();
              }
            }),
          ]);
        }));
  }

  Future<void> _egitimForm(BuildContext c, dynamic pid, Future<void> Function() yenile) async {
    final konu = TextEditingController();
    final veren = TextEditingController();
    final not = TextEditingController();
    DateTime? tarih, yenileme;
    await kAltSayfa(c, baslik: 'Eğitim Ekle', icerik: (cc) => StatefulBuilder(builder: (cc, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Eğitim konusu', konu, ipucu: 'ör. İş Sağlığı ve Güvenliği', zorunlu: true),
            _tarihAlan(cc, 'Eğitim tarihi', tarih, ss, (d) => tarih = d),
            KAlan('Veren', veren),
            _tarihAlan(cc, 'Yenileme tarihi', yenileme, ss, (d) => yenileme = d),
            KAlan('Not', not),
            KButon('Ekle', ikon: Icons.add, genis: true, onTap: () async {
              if (konu.text.trim().isEmpty) {
                kToast(cc, 'Eğitim konusu boş olamaz.', hata: true);
                return;
              }
              final ok = await kopruGonder(cc, '/ik-sicil/egitim', {
                'personel_id': pid,
                'konu': konu.text.trim(),
                if (tarih != null) 'egitim_tarihi': _ymd(tarih!),
                if (yenileme != null) 'son_gecerlilik': _ymd(yenileme!),
                'veren': veren.text.trim(),
                'not': not.text.trim(),
              });
              if (ok) {
                if (cc.mounted) Navigator.pop(cc);
                await yenile();
              }
            }),
          ]);
        }));
  }

  Future<void> _belgeForm(BuildContext c, dynamic pid, Future<void> Function() yenile) async {
    String tip = 'diger';
    final baslik = TextEditingController();
    final not = TextEditingController();
    DateTime? belgeT, son;
    PlatformFile? dosya;
    bool yukleniyor = false;
    await kAltSayfa(c, baslik: 'Belge & Sertifika Ekle', icerik: (cc) => StatefulBuilder(builder: (cc, ss) {
          final t = cc.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<String>('Tip', deger: tip, secenekler: [for (final e in _belgeTip.entries) (e.key, e.value)], onSec: (v) => ss(() => tip = v ?? 'diger')),
            KAlan('Başlık', baslik, ipucu: 'ör. Hijyen Eğitim Sertifikası', zorunlu: true),
            Row(children: [
              Expanded(child: _tarihAlan(cc, 'Belge tarihi', belgeT, ss, (d) => belgeT = d)),
              const SizedBox(width: 10),
              Expanded(child: _tarihAlan(cc, 'Son geçerlilik', son, ss, (d) => son = d)),
            ]),
            KAlan('Not', not),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), side: BorderSide(color: t.line)),
                onPressed: () async {
                  final r = await FilePicker.platform.pickFiles(withData: true);
                  if (r != null && r.files.isNotEmpty) ss(() => dosya = r.files.first);
                },
                icon: Icon(dosya == null ? Icons.attach_file : Icons.check_circle_outline, color: dosya == null ? t.mor1 : t.yesil),
                label: Text(dosya == null ? 'Dosya seç (opsiyonel)' : dosya!.name, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
              ),
            ),
            KButon('Ekle', ikon: Icons.upload_file, genis: true, yukleniyor: yukleniyor, onTap: () async {
              if (baslik.text.trim().isEmpty) {
                kToast(cc, 'Belge başlığı boş olamaz.', hata: true);
                return;
              }
              ss(() => yukleniyor = true);
              final alanlar = <String, String>{
                'personel_id': '$pid',
                'tip': tip,
                'baslik': baslik.text.trim(),
                if (belgeT != null) 'belge_tarihi': _ymd(belgeT!),
                if (son != null) 'son_gecerlilik': _ymd(son!),
                'not': not.text.trim(),
              };
              final ok = await _belgeYukle(cc, alanlar, dosya);
              if (!cc.mounted) return;
              ss(() => yukleniyor = false);
              if (ok) {
                Navigator.pop(cc);
                await yenile();
              }
            }),
          ]);
        }));
  }

  /// Belge formu dosyalı (multipart) gider — köprünün form gönderimi dosya taşımadığı için burada.
  Future<bool> _belgeYukle(BuildContext c, Map<String, String> alanlar, PlatformFile? dosya) async {
    final tok = c.read<AuthProvider>().token;
    if (tok == null) return false;
    Uint8List? bayt = dosya?.bytes;
    if (dosya != null && bayt == null && !kIsWeb && dosya.path != null) {
      try {
        bayt = await File(dosya.path!).readAsBytes();
      } catch (_) {}
    }
    if (dosya == null || bayt == null) {
      if (!c.mounted) return false;
      return kopruGonder(c, '/ik-sicil/belge', alanlar, basariMesaji: 'Belge eklendi.');
    }
    try {
      final rq = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/ik-sicil/belge'))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $tok', 'X-Resteos-Kopru': '1'})
        ..fields.addAll(alanlar)
        ..files.add(http.MultipartFile.fromBytes('dosya', bayt, filename: dosya.name));
      final rs = await http.Response.fromStream(await rq.send().timeout(const Duration(seconds: 90)));
      if (rs.statusCode == 401) throw ApiYetkiHatasi();
      Map<String, dynamic> j = {};
      try {
        final d = jsonDecode(utf8.decode(rs.bodyBytes));
        if (d is Map) j = Map<String, dynamic>.from(d);
      } catch (_) {}
      final cv = KopruCevap(rs.statusCode, j.isEmpty ? {'ok': 0, 'hata': 'Sunucu yanıtı okunamadı (HTTP ${rs.statusCode}).'} : j);
      if (!c.mounted) return cv.ok;
      kToast(c, cv.ok ? (cv.mesaj ?? 'Belge eklendi.') : (cv.hata ?? 'Belge eklenemedi.'), hata: !cv.ok);
      return cv.ok;
    } on ApiYetkiHatasi {
      if (c.mounted) c.read<AuthProvider>().cikis();
      return false;
    } catch (_) {
      if (c.mounted) kToast(c, 'Dosya yüklenemedi; bağlantıyı kontrol edin.', hata: true);
      return false;
    }
  }

  Future<void> _indir(BuildContext c, Map<String, dynamic> b) async {
    final tok = c.read<AuthProvider>().token;
    if (tok == null) return;
    Uint8List? bayt;
    try {
      bayt = await KopruApi.dosya(tok, '/ik-belge-indir', q: {'id': '${b['id']}'});
    } on ApiYetkiHatasi {
      if (c.mounted) c.read<AuthProvider>().cikis();
      return;
    }
    if (!c.mounted) return;
    if (bayt == null) {
      kToast(c, 'Belge dosyası bulunamadı ya da indirilemedi.', hata: true);
      return;
    }
    final yol = metinOku(b['dosya']);
    final i = yol.lastIndexOf('.');
    final uz = i > 0 ? yol.substring(i + 1).toLowerCase() : 'dat';
    final ad = '${metinOku(b['baslik'], 'belge').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')}.$uz';
    try {
      if (uz == 'pdf') {
        await Printing.sharePdf(bytes: bayt, filename: ad);
        return;
      }
      final kayit = await FilePicker.platform.saveFile(dialogTitle: 'Belgeyi kaydet', fileName: ad, bytes: bayt);
      if (kayit == null) return;
      if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final f = File(kayit);
        if (!await f.exists() || await f.length() == 0) await f.writeAsBytes(bayt);
      }
      if (c.mounted) kToast(c, 'Kaydedildi.');
    } catch (_) {
      if (c.mounted) kToast(c, 'Dosya kaydedilemedi.', hata: true);
    }
  }
}

