import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'wa_baglan_dialog.dart';

/// Web /wa-hatlar — çoklu WhatsApp hattı (müşteri / satın alma / yönetim / genel).
/// Sahip/müdür: hat ekle, düzenle (ad/amaç/sahip), varsayılan yap, aktif/pasif, sil.
/// Herkes (kendi hattı): QR ile bağlan / telefon koduyla eşleştir, bağlantıyı kes, canlı durum.
class OpWaHatlarScreen extends StatelessWidget {
  const OpWaHatlarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/wa-hatlar',
      baslik: 'WhatsApp Hatları',
      ikon: Icons.forum_outlined,
      govde: (ctx, veri, yenile) => _HatGovde(veri: veri, yenile: yenile),
      fab: (ctx, veri, yenile) => veri['isAdmin'] == true
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF25D366),
              onPressed: () => _hatFormu(ctx, veri, null, yenile),
              icon: const Icon(Icons.add_link, color: Colors.white),
              label: const Text('Yeni Hat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
    );
  }
}

const _amacEt = {'musteri': 'Müşteri', 'satinalma': 'Satın Alma', 'yonetim': 'Yönetim', 'genel': 'Genel'};
const _amacRenk = {'musteri': Color(0xFF4F46E5), 'satinalma': Color(0xFF7C3AED), 'yonetim': Color(0xFF0EA5E9), 'genel': Color(0xFF64748B)};
const _amacIkon = {'musteri': Icons.restaurant, 'satinalma': Icons.shopping_cart_outlined, 'yonetim': Icons.badge_outlined, 'genel': Icons.assignment_outlined};

/// Yeni hat / düzenle formu (web: /wa-hatlar/ekle ve /wa-hatlar/guncelle)
Future<void> _hatFormu(BuildContext context, Map<String, dynamic> veri, Map<String, dynamic>? hat, Future<void> Function() yenile) async {
  final ad = TextEditingController(text: metinOku(hat?['ad']));
  String amac = metinOku(hat?['amac'], 'satinalma');
  String pid = hat == null ? '' : (tamOku(hat['personel_id']) == 0 ? '' : '${tamOku(hat['personel_id'])}');
  final personeller = liste(veri['personeller']);
  await kAltSayfa(context, baslik: hat == null ? 'Yeni Hat Ekle' : 'Hattı Düzenle', icerik: (c) {
    return StatefulBuilder(builder: (c, ss) {
      final t = c.read<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (hat == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Her hat ayrı bir WhatsApp numarasıdır. Ekledikten sonra hattın sahibi kendi hesabından girip QR ile bağlar.',
                style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
          ),
        KAlan('Hat Adı', ad, ipucu: 'örn. Satın Alma Hattı / Müdür Ahmet', zorunlu: true),
        KSecim<String>('Amaç', deger: amac, secenekler: [for (final e in _amacEt.entries) (e.key, e.value)], onSec: (v) => ss(() => amac = v ?? 'genel')),
        KSecim<String>('Sahip (opsiyonel)', deger: pid, secenekler: [
          ('', '— yok —'),
          for (final p in personeller) ('${tamOku(p['id'])}', '${metinOku(p['ad'])} (${metinOku(p['rol'])})'),
        ], onSec: (v) => ss(() => pid = v ?? '')),
        KButon(hat == null ? 'Ekle' : 'Kaydet', ikon: hat == null ? Icons.add : Icons.save_outlined, genis: true, renk: const Color(0xFF25D366), onTap: () async {
          if (ad.text.trim().isEmpty) {
            kToast(c, 'Hat adı girin.', hata: true);
            return;
          }
          final ok = await kopruGonder(c, hat == null ? '/wa-hatlar/ekle' : '/wa-hatlar/guncelle', {
            if (hat != null) 'id': tamOku(hat['id']),
            'ad': ad.text.trim(),
            'amac': amac,
            'personel_id': pid,
          });
          if (ok && c.mounted) {
            Navigator.pop(c);
            await yenile();
          }
        }),
      ]);
    });
  });
  ad.dispose();
}

class _HatGovde extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _HatGovde({required this.veri, required this.yenile});
  @override
  State<_HatGovde> createState() => _HatGovdeState();
}

class _HatGovdeState extends State<_HatGovde> {
  final Map<int, OpWaDurum> _canli = {};
  Timer? _t;

  List<Map<String, dynamic>> get _hatlar => liste(widget.veri['hatlar']);
  bool get _admin => widget.veri['isAdmin'] == true;

  @override
  void initState() {
    super.initState();
    _canliTazele();
    // Her hattın CANLI durumu: açılışta + dakikada bir (kopan hat kırmızı uyarıyla görünsün)
    _t = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _canliTazele();
    });
  }

  @override
  void didUpdateWidget(covariant _HatGovde oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.veri != widget.veri) _canliTazele();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _canliTazele() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    await Future.wait([
      for (final h in _hatlar)
        () async {
          final id = tamOku(h['id']);
          try {
            final c = await KopruApi.al(tok, '/api/wa-hat/durum', q: {'hat': '$id', '_': '${DateTime.now().millisecondsSinceEpoch}'});
            if (c.durum == 403) return;
            if (mounted) setState(() => _canli[id] = OpWaDurum.coz(c.j));
          } catch (_) {}
        }(),
    ]);
  }

  Future<void> _qr(Map<String, dynamic> h) async {
    final ok = await opWaBaglanDialog(context, baslik: '${metinOku(h['ad'])} — Bağla', onek: '/api/wa-hat', ek: {'hat': '${tamOku(h['id'])}'});
    if (ok == true) {
      if (mounted) kToast(context, 'Hat bağlandı.');
      await widget.yenile();
    } else {
      _canliTazele();
    }
  }

  Future<void> _kes(Map<String, dynamic> h) async {
    if (!await kOnay(context, 'Bağlantı kesilsin mi?', tehlikeli: true, evet: 'Kes', aciklama: 'Bu hattın WhatsApp bağlantısı kesilir. Tekrar bağlamak için QR okutmanız gerekir.')) return;
    if (!mounted) return;
    final c = await kopruGonderCevap(context, '/api/wa-hat/cikis', {'hat': tamOku(h['id'])}, json: true, sessiz: true);
    if (!mounted) return;
    kToast(context, c == null || c.durum == 403 ? 'Bu hat için yetkiniz yok.' : 'Bağlantı kesildi.', hata: c == null || c.durum == 403);
    await widget.yenile();
  }

  Future<void> _guncelle(Map<String, dynamic> h, Map<String, dynamic> alan, String mesaj) async {
    final ok = await kopruGonder(context, '/wa-hatlar/guncelle', {'id': tamOku(h['id']), ...alan}, basariMesaji: mesaj);
    if (ok) await widget.yenile();
  }

  Future<void> _sil(Map<String, dynamic> h) async {
    if (!await kOnay(context, '"${metinOku(h['ad'])}" silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: 'Hat silinir ve WhatsApp bağlantısı da kesilir.')) return;
    if (!mounted) return;
    final ok = await kopruGonder(context, '/wa-hatlar/sil', {'id': tamOku(h['id'])}, basariMesaji: 'Hat silindi.');
    if (ok) await widget.yenile();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final hatlar = _hatlar;
    final bagliSay = hatlar.where((h) => (_canli[tamOku(h['id'])]?.bagli) ?? metinOku(h['durum']) == 'bagli').length;
    return KGovde(
      yenile: () async {
        await widget.yenile();
        await _canliTazele();
      },
      children: [
        KKart(
          renk: const Color(0xFF25D366),
          child: Text(
            _admin
                ? 'Çoklu WhatsApp hattı: müşteri yazışmaları (sipariş, hatırlatma, kampanya) müşteri hattından; tedarikçi teklifleri satın alma hattından; onay/yönetim bildirimleri yönetim hattından gider. Her hat ayrı bir WhatsApp numarasıdır — sahibi (departman sorumlusu) kendi hesabından girip kendi şirket telefonuyla QR okutarak bağlar.'
                : 'Sana atanan WhatsApp hattı: aşağıdaki hattı kendi şirket telefonunla QR okutarak bağla. Bağlantı koparsa yine buradan "Bağlan / QR" ile yeniden bağlarsın — yöneticiyi beklemene gerek yok.',
            style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45),
          ),
        ),
        if (widget.veri['sidecarVar'] == false)
          KKart(
            renk: t.kirmizi,
            child: Row(children: [
              Icon(Icons.warning_amber_outlined, color: t.kirmizi),
              const SizedBox(width: 10),
              Expanded(
                child: Text('WhatsApp sunucusu (bridge) ayarlı değil. Sistem yöneticisinin WhatsApp sunucu adresini ve servis anahtarını girmesi gerekiyor; hat bağlama onsuz çalışmaz.',
                    style: TextStyle(color: t.ink, fontSize: 13, height: 1.4)),
              ),
            ]),
          ),
        if (hatlar.isNotEmpty)
          KKpiIzgara([
            KKpi(etiket: 'Toplam hat', deger: '${hatlar.length}', ikon: Icons.dns_outlined, renk: t.mor1),
            KKpi(etiket: 'Bağlı', deger: '$bagliSay', ikon: Icons.link, renk: const Color(0xFF16A34A)),
            KKpi(etiket: 'Bağlı değil', deger: '${hatlar.length - bagliSay}', ikon: Icons.link_off, renk: hatlar.length - bagliSay > 0 ? t.kirmizi : t.sub),
          ]),
        KBaslik('Hatlar (${hatlar.length})', ikon: Icons.dns_outlined, renk: const Color(0xFF25D366)),
        if (hatlar.isEmpty)
          KBos(
            baslik: _admin ? 'Henüz WhatsApp hattı yok' : 'Sana atanmış bir WhatsApp hattı yok',
            aciklama: _admin
                ? 'Sağ alttaki "Yeni Hat" ile müşteri, satın alma veya yönetim hattı ekleyin; ardından "Bağlan / QR" ile telefonu bağlayın.'
                : 'Yöneticinin bu ekrandan bir hat oluşturup sahip olarak seni ataması gerekiyor.',
            ikon: Icons.forum_outlined,
          )
        else
          LayoutBuilder(builder: (c, k) {
            final n = k.maxWidth >= 900 ? 2 : 1;
            final g = (k.maxWidth - 12 * (n - 1)) / n;
            return Wrap(spacing: 12, runSpacing: 0, children: [for (final h in hatlar) SizedBox(width: g, child: _hatKart(t, h))]);
          }),
      ],
    );
  }

  Widget _hatKart(TemaProvider t, Map<String, dynamic> h) {
    final id = tamOku(h['id']);
    final amac = metinOku(h['amac'], 'genel');
    final ar = _amacRenk[amac] ?? t.sub;
    final aktif = tamOku(h['aktif']) == 1;
    final canli = _canli[id];
    final dbDurum = metinOku(h['durum']);
    // Canlı durum varsa onu, yoksa kayıtlı durumu göster
    final bagli = canli?.bagli ?? dbDurum == 'bagli';
    final kopuk = canli != null ? canli.kopuk : ['cikis', 'kopuk'].contains(dbDurum);
    final etiket = canli != null
        ? canli.etiket
        : (dbDurum == 'bagli' ? 'Bağlı' : (dbDurum == 'cikis' ? 'Çıkış yapılmış — QR okut' : (dbDurum == 'kopuk' ? 'Bağlantı koptu' : 'Bekliyor')));
    final dRenk = bagli ? const Color(0xFF16A34A) : (kopuk ? t.kirmizi : t.amber);
    final numara = canli?.numara.isNotEmpty == true ? canli!.numara : metinOku(h['numara']);
    final genis = genisMi(context);
    return KKart(
      renk: dRenk,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          KIkon(_amacIkon[amac] ?? Icons.forum_outlined, renk: ar, boyut: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(metinOku(h['ad']), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold))),
                if (tamOku(h['varsayilan']) == 1) Padding(padding: const EdgeInsets.only(left: 6), child: Tooltip(message: 'Varsayılan', child: Icon(Icons.star, size: 18, color: t.amber))),
                if (!aktif) Padding(padding: const EdgeInsets.only(left: 6), child: Text('(pasif)', style: TextStyle(color: t.kirmizi, fontSize: 12, fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                KRozet(_amacEt[amac] ?? amac, renk: ar),
                KRozet(etiket, renk: dRenk, ikon: bagli ? Icons.circle : (kopuk ? Icons.error_outline : Icons.radio_button_unchecked)),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  if (metinOku(h['sahip_ad']).isNotEmpty) 'Sahip: ${metinOku(h['sahip_ad'])}',
                  if (numara.isNotEmpty) 'Numara: $numara',
                ].join(' · ').ifEmpty('Sahip atanmamış · numara henüz bağlanmadı'),
                style: TextStyle(color: t.sub, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: t.line),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('Bağlan / QR', ikon: Icons.qr_code_2, renk: const Color(0xFF25D366), onTap: () => _qr(h)),
          KButon('Bağlantıyı kes', ikon: Icons.link_off, ikincil: true, renk: t.sub2, onTap: () => _kes(h)),
          if (_admin && genis) ..._adminButonlar(t, h, aktif),
        ]),
        if (_admin && !genis)
          Align(
            alignment: Alignment.centerRight,
            child: PopupMenuButton<String>(
              tooltip: 'Diğer işlemler',
              color: t.card,
              icon: Icon(Icons.more_horiz, color: t.sub2),
              onSelected: (k) => _adminIslem(k, h, aktif),
              itemBuilder: (c) => [
                PopupMenuItem(value: 'varsayilan', child: Text('Varsayılan yap', style: TextStyle(color: t.ink))),
                PopupMenuItem(value: 'aktif', child: Text(aktif ? 'Pasifleştir' : 'Aktifleştir', style: TextStyle(color: t.ink))),
                PopupMenuItem(value: 'duzenle', child: Text('Düzenle', style: TextStyle(color: t.ink))),
                PopupMenuItem(value: 'sil', child: Text('Sil', style: TextStyle(color: t.kirmizi))),
              ],
            ),
          ),
      ]),
    );
  }

  List<Widget> _adminButonlar(TemaProvider t, Map<String, dynamic> h, bool aktif) => [
        if (tamOku(h['varsayilan']) != 1) KButon('Varsayılan yap', ikon: Icons.star_outline, ikincil: true, renk: t.amber, onTap: () => _adminIslem('varsayilan', h, aktif)),
        KButon(aktif ? 'Pasifleştir' : 'Aktifleştir', ikon: aktif ? Icons.pause_circle_outline : Icons.play_circle_outline, ikincil: true, renk: t.sub2, onTap: () => _adminIslem('aktif', h, aktif)),
        KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _adminIslem('duzenle', h, aktif)),
        KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () => _adminIslem('sil', h, aktif)),
      ];

  void _adminIslem(String k, Map<String, dynamic> h, bool aktif) {
    switch (k) {
      case 'varsayilan':
        _guncelle(h, {'varsayilan': 1}, 'Varsayılan hat güncellendi.');
      case 'aktif':
        _guncelle(h, {'aktif': aktif ? 0 : 1}, aktif ? 'Hat pasifleştirildi.' : 'Hat aktifleştirildi.');
      case 'duzenle':
        _hatFormu(context, widget.veri, h, widget.yenile);
      case 'sil':
        _sil(h);
    }
  }
}

extension on String {
  String ifEmpty(String y) => isEmpty ? y : this;
}
