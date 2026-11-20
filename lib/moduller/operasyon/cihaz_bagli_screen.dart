import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/yazici_servisi.dart';
import '../../ui/kit.dart';

/// Web /bagli-cihazlar — tanımlı cihazlar (yazıcı, ÖKC, terminal…), yazarkasa durumu, çevrimiçi ResteOS cihazları.
/// Web işlemleri: cihaz ekle (POST /bagli-cihazlar/ekle), düzenle (sahip/müdür: /api/patron/cihaz-kaydet tüm alanlar;
/// diğer: /bagli-cihazlar/ad yalnız ad), sil (/bagli-cihazlar/sil). 10 sn'de bir otomatik yenilenir.
/// Cihaz tarafı (yalnız uygulamada): LAN bağlantı testi (Socket) ve "Bu cihazın fiş yazıcısı yap" (YaziciServisi).
class OpBagliCihazlarScreen extends StatefulWidget {
  const OpBagliCihazlarScreen({super.key});

  @override
  State<OpBagliCihazlarScreen> createState() => _OpBagliCihazlarScreenState();
}

const List<(String, String, IconData)> _tipler = [
  ('yazici', 'Yazıcı (fiş/mutfak)', Icons.print_outlined),
  ('yazarkasa', 'Yazarkasa (ÖKC)', Icons.point_of_sale),
  ('terminal', 'Ödeme Terminali (POS)', Icons.credit_card),
  ('cekmece', 'Kasa Çekmecesi', Icons.inbox_outlined),
  ('bilgisayar', 'Bilgisayar / Kasa', Icons.computer),
  ('kds', 'Mutfak Ekranı (KDS)', Icons.tv),
  ('barkod', 'Barkod Okuyucu', Icons.qr_code_scanner),
  ('el_terminali', 'El Terminali', Icons.pan_tool_alt_outlined),
  ('tablet', 'Tablet', Icons.tablet_android),
  ('telefon', 'Telefon', Icons.smartphone),
  ('diger', 'Diğer', Icons.devices_other),
];

(String, String, IconData) _tip(String k) => _tipler.firstWhere((e) => e.$1 == k, orElse: () => _tipler.last);

class _OpBagliCihazlarScreenState extends State<OpBagliCihazlarScreen> {
  final Map<String, bool?> _test = {}; // 'ip:port' → true/false/null (deneniyor)

  Future<void> _baglantiTest(String ip, int port) async {
    final k = '$ip:$port';
    setState(() => _test[k] = null);
    bool ok = false;
    Socket? s;
    try {
      s = await Socket.connect(ip, port, timeout: const Duration(seconds: 4));
      ok = true;
    } catch (_) {
      ok = false;
    } finally {
      try {
        s?.destroy();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _test[k] = ok);
    kToast(context, ok ? 'Bağlantı başarılı ($k)' : 'Ulaşılamadı ($k) — bu cihaz yazıcıyla aynı ağda mı, IP doğru mu?', hata: !ok);
  }

  Future<void> _yaziciYap(Map<String, dynamic> c) async {
    final ok = await kOnay(context, '"${metinOku(c['ad'])}" bu cihazın fiş yazıcısı olsun mu?',
        evet: 'Ayarla', aciklama: 'Bu telefon / bilgisayardan basılan hesap fişi ${metinOku(c['ip'])}:${metinOku(c['port'], '9100')} adresine gider. Diğer cihazlar etkilenmez.');
    if (!ok) return;
    final y = YaziciServisi();
    await y.yukle();
    y.ip = metinOku(c['ip']);
    y.port = int.tryParse(metinOku(c['port'])) ?? 9100;
    await y.kaydet();
    if (mounted) kToast(context, '"${metinOku(c['ad'])}" bu cihazın baskı yazıcısı olarak ayarlandı.');
  }

  Future<void> _sil(Map<String, dynamic> c, Future<void> Function() yenile) async {
    final ok = await kOnay(context, '"${metinOku(c['ad'])}" silinsin mi?', evet: 'Sil', tehlikeli: true);
    if (!ok || !mounted) return;
    if (await kopruGonder(context, '/bagli-cihazlar/sil', {'id': c['id']}, basariMesaji: 'Cihaz silindi.')) await yenile();
  }

  Future<void> _form(Map<String, dynamic>? mevcut, Future<void> Function() yenile) async {
    final patron = context.read<AuthProvider>().patron;
    final adC = TextEditingController(text: metinOku(mevcut?['ad']));
    final ipC = TextEditingController(text: metinOku(mevcut?['ip']));
    final portC = TextEditingController(text: metinOku(mevcut?['port']));
    final markaC = TextEditingController(text: metinOku(mevcut?['marka']));
    final seriC = TextEditingController(text: metinOku(mevcut?['seri_no']));
    final notC = TextEditingController(text: metinOku(mevcut?['notlar']));
    String tip = metinOku(mevcut?['tip'], 'yazici');
    bool aktif = mevcut == null ? true : mevcut['aktif'] != false;
    bool gonderiliyor = false;
    final yalnizAd = mevcut != null && !patron;
    final tamam = await kAltSayfa<bool>(
      context,
      baslik: mevcut == null ? 'Cihaz Ekle' : 'Cihazı Düzenle',
      icerik: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final t = ctx.watch<TemaProvider>();
        Future<void> kaydet() async {
          if (adC.text.trim().isEmpty) {
            kToast(ctx, 'Cihaz adı gerekli.', hata: true);
            return;
          }
          setSt(() => gonderiliyor = true);
          final alanlar = {
            'ad': adC.text.trim(),
            'tip': tip,
            'ip': ipC.text.trim(),
            'port': portC.text.trim(),
            'marka': markaC.text.trim(),
            'seri_no': seriC.text.trim(),
            'notlar': notC.text.trim(),
            'aktif': aktif ? '1' : '0',
          };
          bool ok;
          if (mevcut == null) {
            ok = await kopruGonder(context, '/bagli-cihazlar/ekle', alanlar, basariMesaji: 'Cihaz eklendi.');
          } else if (patron) {
            ok = await kopruGonder(context, '/api/patron/cihaz-kaydet', {'id': '${mevcut['id']}', ...alanlar}, basariMesaji: 'Cihaz güncellendi.');
          } else {
            ok = await kopruGonder(context, '/bagli-cihazlar/ad', {'id': '${mevcut['id']}', 'ad': adC.text.trim()}, basariMesaji: 'Cihaz adı güncellendi.');
          }
          if (!ctx.mounted) return;
          setSt(() => gonderiliyor = false);
          if (ok) Navigator.pop(ctx, true);
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (yalnizAd)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Mevcut cihazın yalnız adını değiştirebilirsiniz; diğer bilgileri işletme sahibi / müdürü düzenler.', style: TextStyle(color: t.sub, fontSize: 13)),
            ),
          if (!yalnizAd) ...[
            Text('Cihaz türü', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (k, ad, ik) in _tipler)
                ChoiceChip(
                  avatar: Icon(ik, size: 17, color: tip == k ? Colors.white : t.sub2),
                  label: Text(ad, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tip == k ? Colors.white : t.sub2)),
                  selected: tip == k,
                  showCheckmark: false,
                  selectedColor: t.mor1,
                  backgroundColor: t.card2,
                  side: BorderSide(color: tip == k ? t.mor1 : t.line),
                  onSelected: (_) => setSt(() => tip = k),
                ),
            ]),
            const SizedBox(height: 14),
          ],
          KAlan('Cihaz adı', adC, ipucu: 'örn. Mutfak Yazıcısı', zorunlu: true),
          if (!yalnizAd) ...[
            Row(children: [
              Expanded(flex: 3, child: KAlan('IP adresi', ipC, ipucu: '192.168.1.50', klavye: TextInputType.url)),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: KAlan('Port', portC, ipucu: '9100', klavye: TextInputType.number)),
            ]),
            Row(children: [
              Expanded(child: KAlan('Marka / model', markaC, ipucu: 'isteğe bağlı')),
              const SizedBox(width: 10),
              Expanded(child: KAlan('Seri no', seriC, ipucu: 'isteğe bağlı')),
            ]),
            KAlan('Not', notC, ipucu: 'isteğe bağlı açıklama', satir: 2),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: aktif,
              activeTrackColor: t.yesil,
              onChanged: (x) => setSt(() => aktif = x),
              title: Text('Aktif (kullanımda)', style: TextStyle(color: t.ink, fontSize: 14.5)),
            ),
          ],
          const SizedBox(height: 6),
          KButon(mevcut == null ? 'Ekle' : 'Kaydet', ikon: Icons.save_outlined, onTap: kaydet, yukleniyor: gonderiliyor, genis: true),
        ]);
      }),
    );
    if (tamam == true) await yenile();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/bagli-cihazlar',
      baslik: 'Bağlı Cihazlar',
      ikon: Icons.devices_outlined,
      otomatik: const Duration(seconds: 10),
      fab: (ctx, v, yenile) => FloatingActionButton.extended(onPressed: () => _form(null, yenile), icon: const Icon(Icons.add), label: const Text('Cihaz Ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final cihazlar = liste(v['cihazlar']);
        final manuel = cihazlar.where((c) => c['manuel'] == true).toList();
        final canli = cihazlar.where((c) => c['manuel'] != true).toList();
        final online = canli.where((c) => c['online'] == true).length;
        final yk = harita(v['yazarkasa']);
        final esik = tamOku(v['esikSn']);
        final sutun = genisMi(ctx) ? 2 : 1;
        Widget izgara(List<Widget> k) {
          if (sutun == 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: k);
          return LayoutBuilder(builder: (c, s) {
            final w = (s.maxWidth - 12) / 2;
            return Wrap(spacing: 12, children: [for (final x in k) SizedBox(width: w, child: x)]);
          });
        }

        return KGovde(yenile: yenile, children: [
          if (v['hata'] == true)
            KKart(renk: t.kirmizi, child: Text('Cihaz bilgileri yüklenemedi (cihaz tablosu henüz oluşmamış olabilir).', style: TextStyle(color: t.kirmizi, fontSize: 13.5))),
          KKpiIzgara([
            KKpi(etiket: 'Çevrimiçi', deger: '$online', alt: 'son $esik sn içinde sinyal', ikon: Icons.wifi, renk: t.yesil),
            KKpi(etiket: 'Tanımlı cihaz', deger: '${manuel.length}', ikon: Icons.power_outlined, renk: t.mor1),
            KKpi(etiket: 'Toplam', deger: '${cihazlar.length}', ikon: Icons.devices_outlined, renk: t.sub2),
          ]),
          KBaslik('Tanımlı Cihazlar', ikon: Icons.power_outlined, alt: 'Yazıcı, yazarkasa, terminal… IP/port ile'),
          if (manuel.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Henüz cihaz tanımlanmadı',
                aciklama: '"Cihaz Ekle" ile yazıcı, yazarkasa, ödeme terminali vb. ekleyip IP / port girebilirsiniz. Sonra bu cihazdan bağlantıyı test edebilirsiniz.',
                ikon: Icons.devices_other,
                aksiyon: KButon('Cihaz Ekle', ikon: Icons.add, onTap: () => _form(null, yenile)),
              ),
            )
          else
            izgara([for (final c in manuel) _manuelKart(t, c, yenile)]),
          if (yk.isNotEmpty) ...[
            const SizedBox(height: 6),
            KBaslik('Yazarkasa (ÖKC)', ikon: Icons.point_of_sale),
            _yazarkasaKart(t, yk),
          ],
          const SizedBox(height: 6),
          KBaslik('Çevrimiçi Cihazlar (ResteOS)', ikon: Icons.phonelink, renk: t.yesil, alt: '10 sn\'de bir yenilenir',
              sag: KRozet('$online / ${canli.length}', renk: t.yesil)),
          if (canli.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Sinyal gönderen cihaz yok',
                aciklama: 'ResteOS uygulaması açık olan her telefon / tablet / bilgisayar burada otomatik görünür. Henüz hiçbir cihaz sinyal göndermedi.',
                ikon: Icons.wifi_off,
              ),
            )
          else
            izgara([for (final c in canli) _canliKart(t, c)]),
        ]);
      },
    );
  }

  Widget _manuelKart(TemaProvider t, Map<String, dynamic> c, Future<void> Function() yenile) {
    final aktif = c['aktif'] != false;
    final (_, tipAd, ik) = _tip(metinOku(c['tip'], 'diger'));
    final renk = aktif ? t.yesil : t.sub;
    final ip = metinOku(c['ip']);
    final port = metinOku(c['port']);
    final portNo = int.tryParse(port) ?? 9100;
    final k = '$ip:$portNo';
    final testVar = _test.containsKey(k);
    final testSonuc = _test[k];
    return KKart(
      renk: renk,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KIkon(ik, renk: renk),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(c['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
              Text('$tipAd${metinOku(c['marka']).isNotEmpty ? ' · ${metinOku(c['marka'])}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
              if (ip.isNotEmpty) Text('IP: $ip${port.isNotEmpty ? ':$port' : ''}', style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
              if (metinOku(c['seri_no']).isNotEmpty) Text('Seri no: ${metinOku(c['seri_no'])}', style: TextStyle(color: t.sub, fontSize: 12)),
              if (metinOku(c['notlar']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(metinOku(c['notlar']), style: TextStyle(color: t.sub2, fontSize: 12.5))),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            KRozet(aktif ? 'Aktif' : 'Pasif', renk: renk),
            if (testVar) ...[
              const SizedBox(height: 6),
              testSonuc == null
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : KRozet(testSonuc ? 'Ulaşıldı' : 'Ulaşılamadı', renk: testSonuc ? t.yesil : t.kirmizi, ikon: testSonuc ? Icons.check_circle_outline : Icons.cancel_outlined),
            ],
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (ip.isNotEmpty) KButon('Test', ikon: Icons.wifi_tethering, ikincil: true, renk: t.mavi, onTap: () => _baglantiTest(ip, portNo)),
          if (ip.isNotEmpty && metinOku(c['tip']) == 'yazici') KButon('Bu cihazın yazıcısı yap', ikon: Icons.print_outlined, ikincil: true, renk: t.yesil, onTap: () => _yaziciYap(c)),
          KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _form(c, yenile)),
          KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () => _sil(c, yenile)),
        ]),
      ]),
    );
  }

  Widget _yazarkasaKart(TemaProvider t, Map<String, dynamic> yk) {
    final durum = metinOku(yk['durum'], 'kapali');
    final (et, renk) = switch (durum) {
      'online' => ('Bağlı', t.yesil),
      'hata' => ('HATA', t.kirmizi),
      'test' => ('Test / simülasyon', t.amber),
      'bekliyor' => ('Aktif · fiş yok', t.amber),
      _ => ('Kapalı', t.sub),
    };
    return KKart(
      renk: renk,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        KIkon(Icons.point_of_sale, renk: renk),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Yazarkasa${metinOku(yk['marka']).isNotEmpty ? ' · ${metinOku(yk['marka'])}' : ''}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            if (yk['aktif'] == true && metinOku(yk['ip']).isNotEmpty)
              Text('IP: ${metinOku(yk['ip'])}${metinOku(yk['port']).isNotEmpty ? ':${metinOku(yk['port'])}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
            if (metinOku(yk['mesaj']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(metinOku(yk['mesaj']), style: TextStyle(color: t.sub2, fontSize: 13))),
            if (metinOku(yk['son_fis']).isNotEmpty) Text('Son mali fiş: ${metinOku(yk['son_fis'])}', style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        KRozet(et, renk: renk),
      ]),
    );
  }

  Widget _canliKart(TemaProvider t, Map<String, dynamic> c) {
    final online = c['online'] == true;
    final renk = online ? t.yesil : t.kirmizi;
    final (_, tipAd, ik) = _tip(metinOku(c['tip'], 'diger'));
    final rol = metinOku(c['rol']);
    final surum = metinOku(c['surum']);
    return KKart(
      renk: renk,
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          KIkon(ik, renk: t.sub2),
          Positioned(right: -2, top: -2, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: renk, shape: BoxShape.circle, border: Border.all(color: t.card, width: 2)))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metinOku(c['ad'], '—'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
            Text('${metinOku(c['platform'], tipAd)}${metinOku(c['ip']).isNotEmpty ? ' · ${metinOku(c['ip'])}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5)),
            if (rol.isNotEmpty || surum.isNotEmpty)
              Text([if (rol.isNotEmpty) '${rol[0].toUpperCase()}${rol.substring(1)}', if (surum.isNotEmpty) 'v$surum'].join(' · '), style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          KRozet(online ? 'Bağlı' : 'Kopuk', renk: renk),
          const SizedBox(height: 4),
          Text(metinOku(c['son_gorulme']), style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
      ]),
    );
  }
}
