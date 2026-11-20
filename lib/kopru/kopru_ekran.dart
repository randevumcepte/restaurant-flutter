import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import '../ui/kit.dart';
import 'kopru_api.dart';

/// Web sayfasını köprüden yükleyip gövdeye veren kabuk: yükleniyor / hata / yetkisiz / aşağı çek-yenile.
/// Her taşınan ekran bunu kullanır → davranış her yerde aynı.
class KopruEkran extends StatefulWidget {
  final String yol;
  final Map<String, String>? q;
  final String baslik;
  final IconData ikon;
  final String? altBaslik;
  final Widget Function(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile) govde;
  final List<Widget> Function(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile)? araclar;
  final Widget Function(BuildContext context, Map<String, dynamic> veri, Future<void> Function() yenile)? fab;
  /// Kabuksuz (başka bir ekranın içinde sekme olarak) kullan
  final bool kabuksuz;
  /// Otomatik yenileme aralığı (canlı ekranlar için; null = kapalı)
  final Duration? otomatik;
  const KopruEkran({
    super.key,
    required this.yol,
    required this.baslik,
    required this.govde,
    this.q,
    this.ikon = Icons.dashboard_outlined,
    this.altBaslik,
    this.araclar,
    this.fab,
    this.kabuksuz = false,
    this.otomatik,
  });

  @override
  State<KopruEkran> createState() => KopruEkranState();
}

class KopruEkranState extends State<KopruEkran> {
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _yetkisiz = false;
  bool _yukleniyor = true;
  Map<String, String>? _q;
  DateTime? _sonYukleme;

  Map<String, String>? get q => _q;
  Map<String, dynamic>? get veri => _veri;

  @override
  void initState() {
    super.initState();
    _q = widget.q;
    yukle();
    if (widget.otomatik != null) _zamanla();
  }

  void _zamanla() {
    Future.delayed(widget.otomatik!, () {
      if (!mounted) return;
      // Ekran görünürken sessiz yenile
      if (ModalRoute.of(context)?.isCurrent ?? true) yukle(sessiz: true);
      _zamanla();
    });
  }

  @override
  void didUpdateWidget(covariant KopruEkran oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.yol != widget.yol || oldWidget.q.toString() != widget.q.toString()) {
      _q = widget.q;
      yukle();
    }
  }

  /// Sorgu parametrelerini değiştirip yeniden yükle (filtre / dönem / sekme)
  Future<void> sorgu(Map<String, String> yeni, {bool birlestir = true}) async {
    _q = birlestir ? {...?_q, ...yeni} : yeni;
    await yukle();
  }

  Future<void> yukle({bool sessiz = false}) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    if (!sessiz && mounted) setState(() { _yukleniyor = _veri == null; _hata = null; });
    try {
      final c = await KopruApi.al(tok, widget.yol, q: _q);
      if (!mounted) return;
      setState(() {
        _yukleniyor = false;
        _sonYukleme = DateTime.now();
        if (c.ok) {
          _veri = c.veri;
          _hata = null;
          _yetkisiz = false;
        } else if (!sessiz || _veri == null) {
          _yetkisiz = c.yetkisiz;
          _hata = c.hata;
          if (c.yetkisiz) _veri = null;
        }
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget icerik;
    if (_yukleniyor && _veri == null) {
      icerik = const KYukleniyor();
    } else if (_veri == null) {
      icerik = KHata(_hata ?? 'Bilinmeyen hata', tekrar: yukle, yetkisiz: _yetkisiz);
    } else {
      icerik = Column(children: [
        if (_hata != null)
          Material(
            color: const Color(0xFFFEF3C7),
            child: InkWell(
              onTap: yukle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.wifi_off, size: 16, color: Color(0xFF92400E)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Güncellenemedi: $_hata — dokunun, tekrar deneyin', style: const TextStyle(color: Color(0xFF92400E), fontSize: 12.5, fontWeight: FontWeight.w600))),
                ]),
              ),
            ),
          ),
        Expanded(child: widget.govde(context, _veri!, yukle)),
      ]);
    }
    if (widget.kabuksuz) return icerik;
    return KSayfa(
      baslik: widget.baslik,
      ikon: widget.ikon,
      altBaslik: widget.altBaslik ?? (_sonYukleme == null ? null : null),
      araclar: [
        if (_veri != null && widget.araclar != null) ...widget.araclar!(context, _veri!, yukle),
        IconButton(tooltip: 'Yenile', onPressed: yukle, icon: const Icon(Icons.refresh)),
      ],
      fab: (_veri != null && widget.fab != null) ? widget.fab!(context, _veri!, yukle) : null,
      govde: icerik,
    );
  }
}

/// Web formunu gönder: başarıda yeşil, hatada kırmızı bildirim. Başarılıysa true.
Future<bool> kopruGonder(BuildContext context, String yol, Map<String, dynamic> veri, {String? basariMesaji, bool json = false}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return false;
  try {
    final c = json ? await KopruApi.gonderJson(tok, yol, veri) : await KopruApi.gonder(tok, yol, veri);
    if (!context.mounted) return c.ok;
    if (c.ok) {
      kToast(context, c.mesaj ?? basariMesaji ?? 'Kaydedildi.');
    } else {
      kToast(context, c.hata ?? 'İşlem yapılamadı.', hata: true);
    }
    return c.ok;
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return false;
  }
}

/// Web formunu gönder ve cevabın tamamını al (ekran sonucu kullanacaksa)
Future<KopruCevap?> kopruGonderCevap(BuildContext context, String yol, Map<String, dynamic> veri, {bool json = false, bool sessiz = false}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return null;
  try {
    final c = json ? await KopruApi.gonderJson(tok, yol, veri) : await KopruApi.gonder(tok, yol, veri);
    if (!sessiz && context.mounted && !c.ok) kToast(context, c.hata ?? 'İşlem yapılamadı.', hata: true);
    return c;
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  }
}

// ───────── veri okuma kısayolları (view verisi dinamik gelir) ─────────
List<Map<String, dynamic>> liste(dynamic v) {
  if (v is List) return [for (final x in v) if (x is Map) Map<String, dynamic>.from(x)];
  if (v is Map) return [for (final x in v.values) if (x is Map) Map<String, dynamic>.from(x)];
  return const [];
}

Map<String, dynamic> harita(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return const {};
}

List<dynamic> dizi(dynamic v) {
  if (v is List) return v;
  if (v is Map) return v.values.toList();
  return const [];
}
