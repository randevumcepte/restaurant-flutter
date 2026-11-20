import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';

/// WhatsApp köprüsünden (bridge) gelen oturum durumu — web'deki durumYenile() ile aynı yorum.
class OpWaDurum {
  final bool bagli;
  final bool qrBekliyor;
  final String numara;
  final String status;
  final String? hata;
  const OpWaDurum({this.bagli = false, this.qrBekliyor = false, this.numara = '', this.status = '', this.hata});

  /// Köprü cevabı: {ok, status, body:{connected, phone|number|jid, status|state, qr}}
  factory OpWaDurum.coz(Map<String, dynamic> j) {
    final b = harita(j['body']).isNotEmpty ? harita(j['body']) : j;
    final tel = metinOku(b['phone'] ?? b['number'] ?? b['jid']);
    final st = metinOku(b['status'] ?? b['state']);
    // GERÇEK giriş = connected VE numara geldi (whatsmeow'da connected çoğu zaman yalnız sokete bağlı demek)
    final bagli = b['connected'] == true && tel.isNotEmpty;
    final qr = !bagli && (metinOku(b['qr']).isNotEmpty || st.toLowerCase().contains('qr') || b['connected'] == true);
    final err = metinOku(b['error']);
    return OpWaDurum(bagli: bagli, qrBekliyor: qr, numara: tel, status: st, hata: err.isEmpty ? null : err);
  }

  /// Rozet metni (wa-hatlar ekranındaki canlı durum dili)
  String get etiket {
    if (bagli) return 'Bağlı';
    switch (status) {
      case 'logged-out':
        return 'Çıkış yapılmış — QR okut';
      case 'disconnected':
        return 'Bağlantı koptu';
      case 'stream-replaced':
        return 'Başka cihazda açıldı';
    }
    if (hata == 'sidecar-ayarlanmadi') return 'Sunucu ayarlı değil';
    if (qrBekliyor) return 'QR bekleniyor';
    return 'Bağlı değil';
  }

  bool get kopuk => !bagli && ['logged-out', 'disconnected', 'stream-replaced'].contains(status);
}

/// Hata metnini kullanıcı diline çevir
String opWaHataMetni(String? h) {
  if (h == null || h.isEmpty) return '';
  if (h == 'sidecar-ayarlanmadi') return 'WhatsApp sunucusu (bridge) ayarlı değil. Sistem yöneticisinin WhatsApp sunucu adresini ve servis anahtarını girmesi gerekiyor.';
  return h;
}

/// QR / telefon numarasıyla bağlama penceresi.
/// /whatsapp → ek = {'sube': id}, uçlar /api/wa/... ; /wa-hatlar → ek = {'hat': id}, uçlar /api/wa-hat/...
/// Bağlanınca true döner.
Future<bool?> opWaBaglanDialog(BuildContext context, {required String baslik, required String onek, required Map<String, String> ek}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _BaglanDialog(baslik: baslik, onek: onek, ek: ek),
  );
}

class _BaglanDialog extends StatefulWidget {
  final String baslik;
  final String onek;
  final Map<String, String> ek;
  const _BaglanDialog({required this.baslik, required this.onek, required this.ek});
  @override
  State<_BaglanDialog> createState() => _BaglanDialogState();
}

class _BaglanDialogState extends State<_BaglanDialog> {
  String _qr = '';
  String _durumYazi = 'QR hazırlanıyor…';
  String? _numara;
  String? _hata;
  String? _pairKod;
  String? _pairHata;
  bool _pairYukleniyor = false;
  bool _bitti = false;
  Timer? _qrT;
  Timer? _durumT;
  final _tel = TextEditingController();

  String? get _tok => context.read<AuthProvider>().token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _basla());
  }

  @override
  void dispose() {
    _qrT?.cancel();
    _durumT?.cancel();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _basla() async {
    final tok = _tok;
    if (tok == null) return;
    try {
      final c = await KopruApi.gonderJson(tok, '${widget.onek}/baglan', widget.ek);
      final b = harita(c.j['body']);
      final q = metinOku(b['qr']);
      if (q.isNotEmpty && mounted) setState(() => _qr = q);
      final e = metinOku(b['error']);
      if (e.isNotEmpty && mounted) setState(() => _hata = opWaHataMetni(e));
    } catch (_) {}
    Future.delayed(const Duration(milliseconds: 900), _qrGetir);
    _qrT = Timer.periodic(const Duration(milliseconds: 2500), (_) => _qrGetir());
    _durumT = Timer.periodic(const Duration(seconds: 3), (_) => _durumKontrol());
  }

  Future<void> _qrGetir() async {
    final tok = _tok;
    if (tok == null || !mounted || _bitti) return;
    try {
      final c = await KopruApi.al(tok, '${widget.onek}/qr', q: {...widget.ek, '_': '${DateTime.now().millisecondsSinceEpoch}'});
      final b = harita(c.j['body']).isNotEmpty ? harita(c.j['body']) : c.j;
      final v = metinOku(b['qr'] ?? b['qrcode'] ?? b['code'] ?? b['image']);
      if (v.isNotEmpty && mounted && v != _qr) setState(() => _qr = v);
    } catch (_) {}
  }

  Future<void> _durumKontrol() async {
    final tok = _tok;
    if (tok == null || !mounted || _bitti) return;
    try {
      final c = await KopruApi.al(tok, '${widget.onek}/durum', q: {...widget.ek, '_': '${DateTime.now().millisecondsSinceEpoch}'});
      final d = OpWaDurum.coz(c.j);
      if (!mounted) return;
      if (d.bagli) {
        _bitti = true;
        _qrT?.cancel();
        _durumT?.cancel();
        setState(() {
          _numara = d.numara;
          _durumYazi = 'Bağlandı! (${d.numara})';
        });
        Future.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) Navigator.pop(context, true);
        });
      } else {
        setState(() {
          _durumYazi = d.qrBekliyor ? 'QR\'ı telefonunuzla tarayın…' : 'QR hazırlanıyor…';
          if (d.hata != null) _hata = opWaHataMetni(d.hata);
        });
      }
    } catch (_) {}
  }

  Future<void> _pair() async {
    final tel = _tel.text.trim();
    if (tel.isEmpty) {
      setState(() => _pairHata = 'Telefon numarası girin.');
      return;
    }
    final tok = _tok;
    if (tok == null) return;
    setState(() {
      _pairYukleniyor = true;
      _pairHata = null;
      _pairKod = null;
    });
    try {
      await KopruApi.gonderJson(tok, '${widget.onek}/baglan', widget.ek);
      // Köprü "pairing-not-ready" derse birkaç kez dene (web ile aynı)
      for (var i = 0; i < 4; i++) {
        final c = await KopruApi.gonderJson(tok, '${widget.onek}/pair', {...widget.ek, 'phone': tel});
        final b = harita(c.j['body']).isNotEmpty ? harita(c.j['body']) : c.j;
        final kod = metinOku(b['code'] ?? b['pairCode'] ?? b['pairingCode']);
        if (kod.isNotEmpty) {
          if (mounted) setState(() => _pairKod = kod);
          Future.delayed(const Duration(seconds: 2), _durumKontrol);
          break;
        }
        await Future.delayed(const Duration(milliseconds: 2500));
        if (!mounted) return;
      }
      if (_pairKod == null && mounted) setState(() => _pairHata = 'Kod üretilemedi, tekrar deneyin (oturum hazırlanıyor olabilir).');
    } catch (_) {
      if (mounted) setState(() => _pairHata = 'Bağlantı hatası.');
    }
    if (mounted) setState(() => _pairYukleniyor = false);
  }

  Widget _qrGorsel() {
    if (_numara != null) return const Center(child: Icon(Icons.check_circle, size: 90, color: Color(0xFF16A34A)));
    if (_qr.isEmpty) return const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3)));
    if (_qr.startsWith('data:')) {
      try {
        final b64 = _qr.substring(_qr.indexOf(',') + 1);
        return Image.memory(base64Decode(b64), fit: BoxFit.contain, gaplessPlayback: true);
      } catch (_) {
        return const Center(child: Text('QR çizilemedi', style: TextStyle(color: Colors.black54)));
      }
    }
    return QrImageView(data: _qr, version: QrVersions.auto, backgroundColor: Colors.white, padding: EdgeInsets.zero);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Dialog(
      backgroundColor: t.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.qr_code_2, color: Color(0xFF25D366)),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.baslik, style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => Navigator.pop(context, _numara != null), icon: Icon(Icons.close, color: t.sub)),
            ]),
            Text('Telefonunuzda WhatsApp → Ayarlar → Bağlı Cihazlar → Cihaz Bağla ile QR\'ı okutun. QR 30-60 sn geçerlidir, otomatik yenilenir.',
                style: TextStyle(color: t.sub, fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 240,
                height: 240,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                child: _qrGorsel(),
              ),
            ),
            const SizedBox(height: 12),
            Text(_durumYazi, textAlign: TextAlign.center, style: TextStyle(color: _numara != null ? const Color(0xFF16A34A) : t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
            if (_hata != null) ...[
              const SizedBox(height: 8),
              Text(_hata!, textAlign: TextAlign.center, style: TextStyle(color: t.kirmizi, fontSize: 12.5)),
            ],
            const SizedBox(height: 16),
            Divider(color: t.line),
            const SizedBox(height: 8),
            Text('QR okutamıyor musunuz? Telefon numarasıyla bağlanın', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Numarayı yazın, bir kod üretelim. Telefonda WhatsApp → Bağlı Cihazlar → Cihaz Bağla → "Telefon numarasıyla bağla" deyip kodu girin.',
                style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: KAlan('Telefon', _tel, ipucu: '05XX XXX XX XX', klavye: TextInputType.phone)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: KButon(_pairKod == null ? 'Kod Üret' : 'Yeni Kod', ikon: Icons.pin_outlined, yukleniyor: _pairYukleniyor, onTap: _pair),
              ),
            ]),
            if (_pairKod != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Text('Telefonunuza girilecek kod:', style: TextStyle(color: t.sub, fontSize: 12.5)),
                  const SizedBox(height: 4),
                  SelectableText(_pairKod!, style: TextStyle(color: t.ink, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 4, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('Kod kısa süre geçerlidir. Bağlanınca bu pencere kendiliğinden kapanır.', textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12)),
                ]),
              ),
            if (_pairHata != null) Text(_pairHata!, style: TextStyle(color: t.kirmizi, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}
