import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// /profilim — Profilim (web profilim ile aynı veri): avatar (yükle / kaldır → /profilim-foto, alan adı `foto`),
/// özet kartlar (izin, hakediş, yetkili alan, belgeler, eğitimler → detay pencereleri), kişisel bilgiler (düzenle → /profilim-kaydet),
/// hesap & güvenlik (PIN değiştir → /profilim-pin-degistir, güvenlik işlemleri, bağlı cihazlar + çıkış → /profilim-cihaz-sil, son girişler),
/// yetki/limitler, hareketler defteri, çalışma özeti + rozetler, vardiyalar.
class ProfilimScreen extends StatefulWidget {
  const ProfilimScreen({super.key});
  @override
  State<ProfilimScreen> createState() => _ProfilimScreenState();
}

const _rolAd = {'sahip': 'Sahip', 'mudur': 'Müdür', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak', 'satinalmaci': 'Satın Almacı', 'satinalma': 'Satın Almacı'};
const _turEtiket = {'avans': 'Avans', 'odeme': 'Ödeme', 'prim': 'Prim', 'kesinti': 'Kesinti', 'ek_odeme': 'Ek ödeme'};

class _ProfilimScreenState extends State<ProfilimScreen> {
  final _k = GlobalKey<KopruEkranState>();
  bool _fotoYukleniyor = false;

  String _sure(dynamic dk) {
    final d = tamOku(dk);
    final s = d ~/ 60, m = d % 60;
    return s > 0 ? '${s}s ${m}dk' : '${m}dk';
  }

  String _gun(dynamic g) {
    final d = sayiOku(g);
    if (d == d.roundToDouble()) return '${d.round()}';
    return d.toStringAsFixed(1).replaceAll('.', ',');
  }

  String _zamanKisa(dynamic z) {
    final d = DateTime.tryParse(metinOku(z).replaceFirst(' ', 'T'));
    if (d == null) return '—';
    final n = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == n.year && d.month == n.month && d.day == n.day) return hm;
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')} $hm';
  }

  Uint8List? _foto(Map<String, dynamic> p) {
    final f = metinOku(p['foto']);
    if (!f.startsWith('data:image')) return null;
    final i = f.indexOf(',');
    if (i < 0) return null;
    try {
      return base64Decode(f.substring(i + 1));
    } catch (_) {
      return null;
    }
  }

  // ───────── Fotoğraf ─────────
  Future<void> _fotoMenu(BuildContext c, bool fotoVar) async {
    final t = c.read<TemaProvider>();
    final secim = await kAltSayfa<String>(c, baslik: 'Profil fotoğrafı', icerik: (s) => Column(children: [
          KSatir(solIkon: KIkon(Icons.photo_library_outlined, renk: t.mor1), baslik: 'Galeriden / dosyadan seç', alt: 'JPG, PNG ya da WEBP · en çok 2 MB', onTap: () => Navigator.pop(s, 'galeri')),
          if (!genisMi(c)) KSatir(solIkon: KIkon(Icons.photo_camera_outlined, renk: t.mavi), baslik: 'Kamerayla çek', onTap: () => Navigator.pop(s, 'kamera')),
          if (fotoVar) KSatir(solIkon: KIkon(Icons.delete_outline, renk: t.kirmizi), baslik: 'Fotoğrafı kaldır', onTap: () => Navigator.pop(s, 'sil'), cizgi: false),
        ]));
    if (secim == null || !c.mounted) return;
    if (secim == 'sil') {
      if (!await kOnay(c, 'Fotoğraf kaldırılsın mı?', tehlikeli: true, evet: 'Kaldır')) return;
      if (!c.mounted) return;
      if (await kopruGonder(c, '/profilim-foto', {'sil': 1}, basariMesaji: 'Fotoğraf kaldırıldı.')) _k.currentState?.yukle();
      return;
    }
    final x = await ImagePicker().pickImage(source: secim == 'kamera' ? ImageSource.camera : ImageSource.gallery, maxWidth: 1000, maxHeight: 1000, imageQuality: 85);
    if (x == null || !c.mounted) return;
    final bayt = await x.readAsBytes();
    if (bayt.length > 2 * 1024 * 1024) {
      if (c.mounted) kToast(c, 'Dosya çok büyük (en çok 2 MB).', hata: true);
      return;
    }
    if (!c.mounted) return;
    setState(() => _fotoYukleniyor = true);
    final (ok, mesaj) = await _fotoGonder(c, bayt, x.name);
    if (!mounted) return;
    setState(() => _fotoYukleniyor = false);
    if (c.mounted) kToast(c, mesaj, hata: !ok);
    if (ok) _k.currentState?.yukle();
  }

  /// Web formu gibi multipart: alan adı `foto`. Köprü başlıkları ile (Bearer + X-Resteos-Kopru) → {ok, mesaj|hata}
  Future<(bool, String)> _fotoGonder(BuildContext c, Uint8List bayt, String ad) async {
    final tok = c.read<AuthProvider>().token;
    if (tok == null) return (false, 'Oturum bulunamadı.');
    final uz = ad.toLowerCase();
    final tur = uz.endsWith('.png') ? 'png' : (uz.endsWith('.webp') ? 'webp' : 'jpeg');
    try {
      final rq = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/profilim-foto'))
        ..headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $tok', 'X-Resteos-Kopru': '1'})
        ..files.add(http.MultipartFile.fromBytes('foto', bayt, filename: ad.isEmpty ? 'profil.$tur' : ad));
      final r = await http.Response.fromStream(await rq.send().timeout(const Duration(seconds: 60)));
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map) {
        final ok = j['ok'] == 1 || j['ok'] == true;
        return (ok, metinOku(ok ? j['mesaj'] : j['hata'], ok ? 'Fotoğraf güncellendi.' : 'Yüklenemedi.'));
      }
      return (false, 'Sunucu yanıtı okunamadı.');
    } catch (_) {
      return (false, 'İnternet bağlantısı yok ya da sunucuya ulaşılamadı.');
    }
  }

  // ───────── Formlar ─────────
  void _duzenle(BuildContext c, Map<String, dynamic> p, String ibanMask) {
    kAltSayfa(c, baslik: 'Kişisel Bilgileri Düzenle', icerik: (s) => _BilgiForm(p: p, ibanMask: ibanMask, kaydedildi: () {
          Navigator.of(s).maybePop();
          _k.currentState?.yukle();
        }));
  }

  void _pin(BuildContext c) {
    kAltSayfa(c, baslik: 'PIN Değiştir', icerik: (s) => _PinForm(kaydedildi: () {
          Navigator.of(s).maybePop();
          _k.currentState?.yukle();
        }));
  }

  void _liste(BuildContext c, String baslik, List<Widget> satirlar, String bos) {
    final t = c.read<TemaProvider>();
    kAltSayfa(c, baslik: baslik, icerik: (s) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (satirlar.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(bos, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13.5))) else ...satirlar,
        ]));
  }

  Future<void> _cihazSil(BuildContext c, Map<String, dynamic> cz) async {
    if (!await kOnay(c, 'Bu cihazdan çıkış yapılsın mı?', tehlikeli: true, evet: 'Çıkış yap', aciklama: '${metinOku(cz['platform'], 'Cihaz').toUpperCase()} · ${metinOku(cz['token_son'])}')) return;
    if (!c.mounted) return;
    if (await kopruGonder(c, '/profilim-cihaz-sil', {'id': cz['id']}, basariMesaji: 'Cihaz oturumu kaldırıldı.')) {
      if (c.mounted) Navigator.of(c).maybePop();
      _k.currentState?.yukle();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/profilim',
      baslik: 'Profilim',
      ikon: Icons.account_circle_outlined,
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  Widget _govde(BuildContext c, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final p = harita(v['p']);
    final dep = harita(v['dep']);
    final sube = harita(v['subeRow']);
    final mesai = harita(v['mesai']);
    final hesap = harita(v['hesap']);
    final sicil = harita(v['sicil']);
    final bugun = harita(v['bugun']);
    final atama = harita(v['atamaOzet']);
    final yetki = harita(v['yetki']);
    final sonraki = harita(v['sonraki']);
    final ibanMask = metinOku(v['ibanMask']);
    final akis = liste(v['akis']);
    final girisler = liste(v['girisler']);
    final guvenlik = liste(v['guvenlikLog']);
    final cihazlar = liste(v['cihazlar']);
    final hareketler = liste(v['hareketler']);
    final belgeler = liste(v['belgeler']);
    final egitimler = liste(v['egitimler']);
    final vardiya = liste(v['vardiya']);
    final rozetler = liste(v['rozetler']);
    final foto = _foto(p);
    final rol = metinOku(p['rol']);
    final kalanIzin = (sayiOku(v['hak']) - sayiOku(v['kullanilan'])).clamp(0, 9999);
    final alanMetin = atama.isEmpty ? 'Atama yok' : '${tamOku(atama['bolge'])} Bölge - ${tamOku(atama['masa'])} Masa';
    final bugunToplam = sayiOku(bugun['ciro']) + sayiOku(bugun['masa']) + sayiOku(bugun['cagri']) + sayiOku(bugun['bahsis']);
    final genis = genisMi(c);
    final sonGiris = girisler.isEmpty ? null : girisler.first['zaman'];
    final sonIslem = akis.where((a) => a['giris'] != true).map((a) => a['zaman']).firstOrNull;

    Widget avatar(double boyut) => Container(
          width: boyut,
          height: boyut,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
            boxShadow: [BoxShadow(color: const Color(0xFF6D28D9).withValues(alpha: .28), blurRadius: 18, offset: const Offset(0, 8))],
            image: foto == null ? null : DecorationImage(image: MemoryImage(foto), fit: BoxFit.cover),
          ),
          child: foto == null ? Icon(Icons.person, color: Colors.white, size: boyut * .5) : null,
        );

    // ── ÜST KART
    final hero = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: _fotoYukleniyor ? null : () => _fotoMenu(c, foto != null),
            child: Stack(children: [
              avatar(84),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: t.card, shape: BoxShape.circle, boxShadow: t.golge, border: Border.all(color: t.line)),
                  child: _fotoYukleniyor
                      ? Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: t.mor1))
                      : Icon(Icons.edit, size: 16, color: t.mor1),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(p['ad'], 'Personel'), style: TextStyle(color: t.ink, fontSize: 21, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${_rolAd[rol] ?? (rol.isEmpty ? 'Personel' : rol)}  •  ${metinOku(dep['ad'], 'ResteOS')}', style: TextStyle(color: t.sub, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                KRozet('Aktif', renk: t.yesil, ikon: Icons.circle),
                if (mesai['acik'] == true) KRozet('Mesaide · ${_sure(mesai['dakika'])}', renk: t.yesil, ikon: Icons.radio_button_checked),
                if (dep['sorumlu'] == true || dep['sorumlu'] == 1) KRozet('Departman sorumlusu', renk: t.amber, ikon: Icons.star),
                if (metinOku(p['ise_baslama']).isNotEmpty) KRozet('${tarihYaz(p['ise_baslama'], saat: false)}\'dan beri', renk: t.sub2, ikon: Icons.event_available_outlined),
                if (metinOku(v['dahili']).isNotEmpty) KRozet('Dahili ${metinOku(v['dahili'])}', renk: t.sub2, ikon: Icons.phone_in_talk_outlined),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 16, runSpacing: 8, children: [
          _meta(t, Icons.calendar_month_outlined, 'Son Giriş', sonGiris == null ? '—' : tarihYaz(sonGiris)),
          _meta(t, Icons.schedule, 'Son İşlem', sonIslem == null ? '—' : tarihYaz(sonIslem)),
          _meta(t, Icons.storefront_outlined, 'Şube', metinOku(sube['ad'], '—')),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('Profili Düzenle', ikon: Icons.edit, onTap: () => _duzenle(c, p, ibanMask)),
          KButon('PIN Değiştir', ikon: Icons.lock_outline, ikincil: true, onTap: () => _pin(c)),
          KButon('Bağlı Cihazlar', ikon: Icons.devices_outlined, ikincil: true, onTap: () => _cihazlar(c, cihazlar)),
        ]),
      ]),
    );

    // ── 5 ÖZET
    final kpi = KKpiIzgara([
      KKpi(etiket: 'İzin Bakiyesi', deger: '${_gun(kalanIzin)} gün', ikon: Icons.calendar_month_outlined, renk: const Color(0xFF7C3AED), onTap: () => _liste(c, 'İzin Bakiyesi', [
            KSatir(baslik: 'Yıllık hak', sag: Text('${_gun(v['hak'])} gün', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            KSatir(baslik: 'Kullanılan', sag: Text('${_gun(v['kullanilan'])} gün', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            KSatir(baslik: 'Kalan', sag: Text('${_gun(kalanIzin)} gün', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w800)), cizgi: false),
          ], '')),
      KKpi(etiket: 'Hakediş', deger: tl(hesap['hakedis'], kisa: true), ikon: Icons.account_balance_wallet_outlined, renk: const Color(0xFF0EA5E9), onTap: () => _hakedis(c, hesap, hareketler)),
      KKpi(etiket: 'Yetkili Olduğun Alan', deger: alanMetin, ikon: Icons.location_on_outlined, renk: const Color(0xFF10B981)),
      KKpi(
          etiket: 'Belgeler (toplam / SKT yakın)',
          deger: '${tamOku(sicil['belge'])} / ${tamOku(sicil['skt_yaklasan'])}',
          ikon: Icons.description_outlined,
          renk: const Color(0xFFF59E0B),
          onTap: () => _liste(c, 'Belgelerim', [
                for (final b in belgeler)
                  Builder(builder: (_) {
                    final skt = DateTime.tryParse(metinOku(b['son_gecerlilik']));
                    final yakin = skt != null && skt.isBefore(DateTime.now().add(const Duration(days: 30)));
                    return KSatir(
                      solIkon: Icon(Icons.description_outlined, color: t.sub),
                      baslik: metinOku(b['baslik'], metinOku(b['tip'])),
                      sag: Text('SKT ${tarihYaz(b['son_gecerlilik'], saat: false)}', style: TextStyle(color: yakin ? t.kirmizi : t.sub2, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    );
                  }),
              ], 'Kayıtlı belge yok. Sağlık/hijyen belgelerin İK tarafından personel sicilinden girilir.')),
      KKpi(
          etiket: 'Eğitimler',
          deger: '${tamOku(sicil['egitim'])} Sertifika',
          ikon: Icons.school_outlined,
          renk: const Color(0xFFF43F5E),
          onTap: () => _liste(c, 'Eğitimlerim', [
                for (final e in egitimler)
                  KSatir(
                    solIkon: Icon(Icons.school_outlined, color: t.sub),
                    baslik: metinOku(e['konu']),
                    alt: metinOku(e['veren']),
                    sag: Text(tarihYaz(e['egitim_tarihi'], saat: false), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
              ], 'Kayıtlı eğitim yok. Aldığın eğitimler İK tarafından personel sicilinden girilir.')),
    ]);

    Widget bilgi(IconData ik, String e, String d) => KSatir(solIkon: Icon(ik, size: 19, color: t.sub), baslik: e, sag: Flexible(child: Text(d.isEmpty ? '—' : d, textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700))));

    final kisisel = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Kişisel Bilgiler', ikon: Icons.person_outline, sag: TextButton.icon(onPressed: () => _duzenle(c, p, ibanMask), icon: const Icon(Icons.edit, size: 16), label: const Text('Düzenle'))),
        bilgi(Icons.call_outlined, 'Telefon', metinOku(p['telefon'])),
        bilgi(Icons.event_outlined, 'Doğum Tarihi', metinOku(p['dogum_tarihi']).isEmpty ? '' : tarihYaz(p['dogum_tarihi'], saat: false)),
        bilgi(Icons.credit_card, 'IBAN', metinOku(p['iban'])),
        bilgi(Icons.account_balance_outlined, 'Mevcut IBAN', ibanMask),
        bilgi(Icons.contact_emergency_outlined, 'Acil durumda aranacak kişi', metinOku(p['acil_kisi'])),
        bilgi(Icons.phone_in_talk_outlined, 'Acil telefon', metinOku(p['acil_tel'])),
      ]),
    );

    Widget gv(IconData ik, Color r, String b, String a, VoidCallback f) => KSatir(solIkon: KIkon(ik, renk: r), baslik: b, alt: a, sag: Icon(Icons.chevron_right, color: t.sub), onTap: f);
    final guvenlikKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Hesap & Güvenlik', ikon: Icons.shield_outlined),
        gv(Icons.lock_outline, const Color(0xFF8B5CF6), 'PIN Değiştir', 'Hesabınızın PIN kodunu değiştirin', () => _pin(c)),
        gv(Icons.verified_user_outlined, const Color(0xFF10B981), 'Son Güvenlik İşlemleri', 'Hesap hareketlerinizi görüntüleyin', () => _liste(c, 'Son Güvenlik İşlemleri', [
              for (final g in guvenlik) KSatir(solIkon: Icon(Icons.verified_user_outlined, color: t.sub), baslik: metinOku(g['metin']), sag: Text(tarihYaz(g['zaman']), style: TextStyle(color: t.sub2, fontSize: 12.5))),
            ], 'Henüz güvenlik işlemi yok. PIN, kişisel bilgi ve cihaz değişiklikleri burada listelenir.')),
        gv(Icons.desktop_windows_outlined, const Color(0xFF7C3AED), 'Bağlı Cihazlar', 'Hesabınıza bağlı cihazları yönetin', () => _cihazlar(c, cihazlar)),
        gv(Icons.schedule, const Color(0xFF6D28D9), 'Son Girişler', 'Son giriş yaptığınız zamanları görün', () => _liste(c, 'Son Girişler', [
              for (final g in girisler)
                KSatir(
                  solIkon: Icon(Icons.login, color: t.sub),
                  baslik: metinOku(g['metin']),
                  alt: metinOku(g['ip']),
                  sag: Text(tarihYaz(g['zaman']), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
            ], 'Giriş kaydı bir sonraki girişten itibaren burada görünür.')),
        gv(Icons.notifications_outlined, const Color(0xFF7C3AED), 'Bildirim Tercihleri', 'Bildirim ayarlarınızı düzenleyin', () => aiGit(c, '/bildirim-ayar', baslik: 'Bildirim Tercihleri')),
      ]),
    );

    final yetkiKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Yetki & Limitlerim', ikon: Icons.star_outline),
        KSatir(solIkon: Icon(Icons.sell_outlined, color: t.sub), baslik: 'İndirim limiti', sag: _durum(t, sayiOku(yetki['iskonto_limit']) > 0 ? yuzde(yetki['iskonto_limit']) : null)),
        KSatir(solIkon: Icon(Icons.card_giftcard, color: t.sub), baslik: 'İkram limiti', sag: _durum(t, sayiOku(yetki['ikram_limit']) > 0 ? tl(yetki['ikram_limit'], kisa: true) : null)),
        KSatir(solIkon: Icon(Icons.location_on_outlined, color: t.sub), baslik: 'Sorumlu olduğun alan', sag: Text(alanMetin, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13))),
        KSatir(solIkon: Icon(Icons.apartment, color: t.sub), baslik: 'Departman', sag: Text(metinOku(dep['ad'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13)), cizgi: false),
      ]),
    );

    final akisKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Hareketler Defteri', ikon: Icons.receipt_long_outlined,
            sag: akis.length > 5 ? TextButton(onPressed: () => _liste(c, 'Hareketler Defteri', [for (final a in akis) _akisSatir(t, a)], ''), child: const Text('Tümünü gör →')) : null),
        if (akis.isEmpty) Text('Henüz kayıtlı hareket yok. Giriş, masa açma, ödeme ve mesai kayıtların burada listelenir.', style: TextStyle(color: t.sub, fontSize: 13)) else for (final a in akis.take(5)) _akisSatir(t, a),
      ]),
    );

    Widget tile(Color r, IconData ik, String e, String d, String a) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(ik, size: 16, color: r), const SizedBox(width: 5), Expanded(child: Text(e, style: TextStyle(color: r, fontSize: 12.5, fontWeight: FontWeight.w700)))]),
            const SizedBox(height: 6),
            Text(d, style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(a, style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        );
    final simdi = DateTime.now();
    final calisma = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Çalışma Özetim', ikon: Icons.insights, sag: KRozet('Bugün ${simdi.day.toString().padLeft(2, '0')}.${simdi.month.toString().padLeft(2, '0')}.${simdi.year}', renk: t.sub)),
        AiIzgara(minGenislik: 170, ara: 8, cocuklar: [
          tile(const Color(0xFF10B981), Icons.schedule, 'Mesai', mesai['acik'] == true || tamOku(mesai['dakika']) > 0 ? _sure(mesai['dakika']) : 'Kapalı',
              metinOku(mesai['giris']).isEmpty ? 'Henüz açmadın' : 'Giriş ${metinOku(mesai['giris'])}'),
          tile(const Color(0xFF4F46E5), Icons.event, 'Sonraki Vardiya', sonraki.isEmpty ? '—' : '${metinOku(sonraki['bas'])}–${metinOku(sonraki['bit'])}',
              sonraki.isEmpty ? 'Programda yok' : '${metinOku(sonraki['gun'])} ${metinOku(sonraki['tarih_kisa'])}'),
          tile(const Color(0xFFF59E0B), Icons.account_balance_wallet_outlined, 'Bu Ay Net', tl(hesap['net'], kisa: true), 'Hakediş ${tl(hesap['hakedis'], kisa: true)}'),
          tile(const Color(0xFF64748B), Icons.inventory_2_outlined, 'Zimmetim', '${tamOku(sicil['zimmet'])} öğe', 'Üzerimdeki demirbaş'),
          if (bugunToplam > 0) ...[
            tile(const Color(0xFF10B981), Icons.payments_outlined, 'Satış', tl(bugun['ciro'], kisa: true), 'Bugün'),
            tile(const Color(0xFF4F46E5), Icons.table_restaurant_outlined, 'Masa', '${tamOku(bugun['masa'])}', 'Bugün'),
            tile(const Color(0xFF8B5CF6), Icons.notifications_active_outlined, 'Çağrı', '${tamOku(bugun['cagri'])}', 'Bugün'),
            tile(const Color(0xFFF59E0B), Icons.star_outline, 'Bahşiş', tl(bugun['bahsis'], kisa: true), 'Bugün'),
          ],
        ]),
        if (rozetler.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [for (final r in rozetler) KRozet('${metinOku(r['ikon'])} ${metinOku(r['ad'])}', renk: renkOku(r['renk']))]),
        ],
      ]),
    );

    final vardiyaKart = KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KBaslik('Vardiyalarım', ikon: Icons.event, sag: KRozet('${vardiya.length}', renk: t.sub)),
        if (vardiya.isEmpty)
          Text('Önümüzdeki 2 haftada vardiya programlanmamış. Vardiyalar yönetici tarafından İK > Vardiya ekranından girilir.', style: TextStyle(color: t.sub, fontSize: 13))
        else
          for (final x in vardiya)
            KSatir(
              solIkon: Icon(Icons.today, size: 19, color: t.sub),
              baslik: '${metinOku(x['gun'])} ${metinOku(x['tarih_kisa'])}',
              sag: Text('${metinOku(x['bas'])}–${metinOku(x['bit'])}${metinOku(x['pozisyon']).isEmpty ? '' : ' · ${metinOku(x['pozisyon'])}'}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('İzin iste', ikon: Icons.beach_access_outlined, renk: const Color(0xFF14B8A6), onTap: () => aiGit(c, '/ik-izin', baslik: 'İzin')),
          KButon('Puantajım', ikon: Icons.history, renk: const Color(0xFF4F46E5), onTap: () => aiGit(c, '/puantaj', baslik: 'Puantaj')),
        ]),
      ]),
    );

    final baglanti = (dep['id'] != null && ['sahip', 'mudur'].contains(rol))
        ? KKart(
            renk: cssRenk(c, dep['renk']),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KBaslik('Yönettiğin Bağlantılar', ikon: Icons.hub_outlined, renk: cssRenk(c, dep['renk'])),
              ZenginMetin('**${metinOku(dep['ad'])}** departmanının mail (SMTP/IMAP) ve WhatsApp hesaplarını buradan yönet. Bu ayarlar **kişisel değildir** — tüm departman adına kullanılır.',
                  stil: TextStyle(color: t.sub, fontSize: 13, height: 1.5)),
              const SizedBox(height: 10),
              KButon('${metinOku(dep['ad'])} Bağlantı Ayarları', ikon: Icons.settings_outlined, renk: cssRenk(c, dep['renk']),
                  onTap: () => aiGit(c, '/departman-baglanti?dep=${metinOku(dep['id'])}', baslik: 'Bağlantı Ayarları')),
            ]),
          )
        : null;

    if (genis) {
      Widget iki(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)]);
      return KGovde(yenile: yenile, children: [
        hero,
        kpi,
        iki(kisisel, guvenlikKart),
        iki(yetkiKart, akisKart),
        calisma,
        iki(vardiyaKart, baglanti ?? const SizedBox.shrink()),
      ]);
    }
    return KGovde(yenile: yenile, children: [hero, kpi, kisisel, guvenlikKart, calisma, vardiyaKart, yetkiKart, akisKart, ?baglanti]);
  }

  Widget _meta(TemaProvider t, IconData ik, String e, String d) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ik, size: 18, color: t.mor1),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e, style: TextStyle(color: t.sub, fontSize: 11.5)),
          Text(d, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ]);

  Widget _durum(TemaProvider t, String? d) => d == null ? Text('–', style: TextStyle(color: t.sub, fontWeight: FontWeight.w700)) : KRozet(d, renk: t.yesil);

  Widget _akisSatir(TemaProvider t, Map<String, dynamic> a) => KSatir(
        solIkon: Container(width: 9, height: 9, decoration: BoxDecoration(color: a['giris'] == true ? t.mavi : t.mor1, shape: BoxShape.circle)),
        baslik: metinOku(a['metin']),
        sag: Text(_zamanKisa(a['zaman']), style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  void _hakedis(BuildContext c, Map<String, dynamic> h, List<Map<String, dynamic>> hareketler) {
    final t = c.read<TemaProvider>();
    Widget sat(String k, String v, {bool kalin = false}) => KSatir(baslik: k, sag: Text(v, style: TextStyle(color: kalin ? t.mor1 : t.ink, fontWeight: kalin ? FontWeight.w800 : FontWeight.w700)));
    _liste(c, 'Bu Ay Hakediş', [
      sat('Maaş', tl(h['maas'], kisa: true)),
      sat('Prim', tl(sayiOku(h['prim_hesap']) + sayiOku(h['prim_manuel']), kisa: true)),
      sat('Ek ödeme', tl(h['ek_odeme'], kisa: true)),
      sat('Kesinti', '−${tl(h['kesinti'], kisa: true)}'),
      sat('Hakediş', tl(h['hakedis'], kisa: true), kalin: true),
      sat('Avans + Ödenen', '−${tl(sayiOku(h['avans']) + sayiOku(h['odenen']), kisa: true)}'),
      sat('Net', tl(h['net'], kisa: true), kalin: true),
      Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 4), child: Text('Son maaş hareketleri', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800))),
      if (hareketler.isEmpty)
        Padding(padding: const EdgeInsets.all(10), child: Text('Henüz kayıt yok.', style: TextStyle(color: t.sub, fontSize: 13)))
      else
        for (final x in hareketler)
          Builder(builder: (_) {
            final yesil = ['odeme', 'prim', 'ek_odeme'].contains(metinOku(x['tur']));
            final r = yesil ? t.yesil : t.kirmizi;
            return KSatir(
              solIkon: Icon(yesil ? Icons.arrow_downward : Icons.arrow_upward, color: r, size: 19),
              baslik: _turEtiket[metinOku(x['tur'])] ?? metinOku(x['tur']),
              alt: metinOku(x['aciklama']).isEmpty ? tarihYaz(x['tarih'], saat: false) : metinOku(x['aciklama']),
              sag: Text('${yesil ? '+' : '−'}${tl(x['tutar'], kisa: true)}', style: TextStyle(color: r, fontWeight: FontWeight.w800)),
            );
          }),
    ], '');
  }

  void _cihazlar(BuildContext c, List<Map<String, dynamic>> cihazlar) {
    final t = c.read<TemaProvider>();
    _liste(c, 'Bağlı Cihazlar', [
      for (final cz in cihazlar)
        KSatir(
          solIkon: Icon(metinOku(cz['platform']) == 'ios' ? Icons.phone_iphone : (metinOku(cz['platform']) == 'android' ? Icons.phone_android : Icons.devices_outlined), color: t.sub),
          baslik: '${metinOku(cz['platform'], 'Cihaz').toUpperCase()} · ${metinOku(cz['token_son'])}',
          alt: tarihYaz(cz['tarih']),
          sag: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: t.kirmizi, minimumSize: const Size(44, 40)),
            onPressed: () => _cihazSil(c, cz),
            icon: const Icon(Icons.logout, size: 16),
            label: const Text('Çıkış', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
    ], 'Kayıtlı cihaz yok. Uygulamaya giriş yapıp bildirim izni verdiğin cihazlar burada listelenir.');
  }
}

/// Kişisel bilgi formu (/profilim-kaydet: telefon, dogum_tarihi, iban, acil_kisi, acil_tel)
class _BilgiForm extends StatefulWidget {
  final Map<String, dynamic> p;
  final String ibanMask;
  final VoidCallback kaydedildi;
  const _BilgiForm({required this.p, required this.ibanMask, required this.kaydedildi});
  @override
  State<_BilgiForm> createState() => _BilgiFormState();
}

class _BilgiFormState extends State<_BilgiForm> {
  late final _tel = TextEditingController(text: metinOku(widget.p['telefon']));
  late final _iban = TextEditingController(text: metinOku(widget.p['iban']));
  late final _acilK = TextEditingController(text: metinOku(widget.p['acil_kisi']));
  late final _acilT = TextEditingController(text: metinOku(widget.p['acil_tel']));
  DateTime? _dogum;
  bool _gonder = false;

  @override
  void initState() {
    super.initState();
    _dogum = DateTime.tryParse(metinOku(widget.p['dogum_tarihi']));
  }

  @override
  void dispose() {
    _tel.dispose();
    _iban.dispose();
    _acilK.dispose();
    _acilT.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _kaydet() async {
    setState(() => _gonder = true);
    final ok = await kopruGonder(context, '/profilim-kaydet', {
      'telefon': _tel.text.trim(),
      'dogum_tarihi': _dogum == null ? '' : _ymd(_dogum!),
      'iban': _iban.text.trim(),
      'acil_kisi': _acilK.text.trim(),
      'acil_tel': _acilT.text.trim(),
    }, basariMesaji: 'Kişisel bilgiler güncellendi.');
    if (!mounted) return;
    setState(() => _gonder = false);
    if (ok) widget.kaydedildi();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KAlan('Telefon', _tel, ipucu: '05xx…', klavye: TextInputType.phone),
      Text('Doğum tarihi', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(44, 46), alignment: Alignment.centerLeft),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _dogum ?? DateTime(1995), firstDate: DateTime(1940), lastDate: DateTime.now());
              if (d != null) setState(() => _dogum = d);
            },
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(_dogum == null ? 'Seçilmedi' : tarihYaz(_ymd(_dogum!), saat: false)),
          ),
        ),
        if (_dogum != null) IconButton(tooltip: 'Temizle', onPressed: () => setState(() => _dogum = null), icon: const Icon(Icons.close)),
      ]),
      const SizedBox(height: 12),
      KAlan('IBAN (TR…)', _iban, ipucu: 'TR00 0000 …'),
      if (widget.ibanMask.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Mevcut IBAN: ${widget.ibanMask}', style: TextStyle(color: t.sub, fontSize: 12.5))),
      KAlan('Acil durumda aranacak kişi', _acilK),
      KAlan('Acil telefon', _acilT, ipucu: '05xx…', klavye: TextInputType.phone),
      KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _gonder, onTap: _kaydet),
    ]);
  }
}

/// PIN değiştirme formu (/profilim-pin-degistir: eski, yeni, yeni2)
class _PinForm extends StatefulWidget {
  final VoidCallback kaydedildi;
  const _PinForm({required this.kaydedildi});
  @override
  State<_PinForm> createState() => _PinFormState();
}

class _PinFormState extends State<_PinForm> {
  final _eski = TextEditingController();
  final _yeni = TextEditingController();
  final _yeni2 = TextEditingController();
  bool _gonder = false;

  @override
  void dispose() {
    _eski.dispose();
    _yeni.dispose();
    _yeni2.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    final y = _yeni.text.trim();
    if (_eski.text.trim().isEmpty || y.isEmpty) return kToast(context, 'Tüm alanlar zorunlu.', hata: true);
    if (!RegExp(r'^\d{4,8}$').hasMatch(y)) return kToast(context, 'PIN 4-8 haneli rakam olmalı.', hata: true);
    if (y != _yeni2.text.trim()) return kToast(context, 'Yeni PIN tekrarı tutmuyor.', hata: true);
    setState(() => _gonder = true);
    final ok = await kopruGonder(context, '/profilim-pin-degistir', {'eski': _eski.text.trim(), 'yeni': y, 'yeni2': _yeni2.text.trim()}, basariMesaji: 'PIN değiştirildi.');
    if (!mounted) return;
    setState(() => _gonder = false);
    if (ok) widget.kaydedildi();
  }

  Widget _alan(TemaProvider t, String e, TextEditingController k) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: k,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 8,
          style: TextStyle(color: t.ink, fontSize: 16, letterSpacing: 4),
          decoration: InputDecoration(
            labelText: e,
            counterText: '',
            filled: true,
            fillColor: t.card2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _alan(t, 'Mevcut PIN', _eski),
      _alan(t, 'Yeni PIN (4-8 hane)', _yeni),
      _alan(t, 'Yeni PIN (tekrar)', _yeni2),
      KButon('PIN\'i değiştir', ikon: Icons.lock_reset, renk: const Color(0xFF8B5CF6), genis: true, yukleniyor: _gonder, onTap: _kaydet),
    ]);
  }
}
