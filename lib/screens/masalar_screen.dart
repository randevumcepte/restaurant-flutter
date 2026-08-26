import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'detay_screen.dart';

class MasalarScreen extends StatefulWidget {
  const MasalarScreen({super.key});

  @override
  State<MasalarScreen> createState() => _MasalarScreenState();
}

class _MasalarScreenState extends State<MasalarScreen> {
  List masalar = [];
  bool loading = true;
  String? _secilenBolge; // ust sekmede secili bolge
  final _f = NumberFormat.decimalPattern('tr');

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.masalar(auth.token!);
      if (!mounted) return;
      setState(() {
        masalar = (res['masalar'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _uyar(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // Bos masaya tiklaninca: kisi sor -> masa ac -> adisyon detayina git
  Future<void> _masaAc(Map m) async {
    final misafir = await _misafirSor(m['ad'].toString(), _n(m['kapasite']).toInt());
    if (misafir == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.masaAc(auth.token!, _n(m['id']).toInt(), misafir);
      if (!mounted) return;
      if (res['ok'] == 1 && res['adisyon_id'] != null) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetayScreen(tip: 'adisyon', id: _n(res['adisyon_id']).toInt(), baslikFallback: m['ad'].toString())));
        _yukle();
      } else {
        _uyar(res['hata']?.toString() ?? 'Masa açılamadı');
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      _uyar('Bağlantı hatası');
    }
  }

  Future<int?> _misafirSor(String masaAd, int kapasite) {
    int sayi = kapasite >= 1 && kapasite <= 20 ? kapasite : 2;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('$masaAd — Masa Aç', style: const TextStyle(fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Kaç kişi?', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi > 1) sayi--; }), icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 56, child: Text('$sayi', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi < 20) sayi++; }), icon: const Icon(Icons.add_circle_outline)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, sayi), child: const Text('Masayı Aç')),
          ],
        ),
      ),
    );
  }

  Color _renk(String durum) {
    switch (durum) {
      case 'dolu':
        return const Color(0xFFEEF2FF);
      case 'rezerve':
        return const Color(0xFFFFFBEB);
      case 'kirli':
        return const Color(0xFFFFF7ED);
      default:
        return Colors.white;
    }
  }

  Color _kenar(String durum) {
    switch (durum) {
      case 'dolu':
        return const Color(0xFFC7D2FE);
      case 'rezerve':
        return const Color(0xFFFDE68A);
      case 'kirli':
        return const Color(0xFFFED7AA);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bolgeye gore grupla
    final Map<String, List> gruplu = {};
    for (final m in masalar) {
      final b = (m['bolge'] ?? 'Salon').toString();
      gruplu.putIfAbsent(b, () => []).add(m);
    }
    final bolgeler = gruplu.keys.toList();
    final aktif = (_secilenBolge != null && bolgeler.contains(_secilenBolge)) ? _secilenBolge! : (bolgeler.isNotEmpty ? bolgeler.first : '');
    final aktifMasalar = gruplu[aktif] ?? [];
    final dolu = masalar.where((m) => m['adisyon_id'] != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Masalar  ($dolu / ${masalar.length} dolu)',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Bolge sekmeleri (buton gibi) — tiklayinca aninda o bolge (client-side, kasmaz)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bolgeler.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final b = bolgeler[i];
                      final secili = b == aktif;
                      final bDolu = (gruplu[b] ?? []).where((m) => m['adisyon_id'] != null).length;
                      return GestureDetector(
                        onTap: () => setState(() => _secilenBolge = b),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: secili ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: secili ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(children: [
                            Text(b, style: TextStyle(color: secili ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
                            if (bDolu > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: secili ? Colors.white24 : const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(10)),
                                child: Text('$bDolu', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Ipucu: surukle-birak
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Row(children: const [
                  Icon(Icons.touch_app_outlined, size: 14, color: Color(0xFF94A3B8)),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text('Dolu masayı basılı tutup sürükleyin — dolu masaya bırak: birleştir, boşa bırak: taşı',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  ),
                ]),
              ),
              // Secili bolgenin masalari
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0),
                    itemCount: aktifMasalar.length,
                    itemBuilder: (context, i) => _masaHucre(aktifMasalar[i] as Map),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _masaHucre(Map m) {
    final acik = m['adisyon_id'] != null;
    final birlesik = m['durum'].toString() == 'birlesik'; // baska masaya birlesmis kaynak masa
    // Dokununca ac/detay (mevcut davranis). Birlesik kaynak masa -> hedef hesabi acar.
    final tapCell = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (birlesik && m['birlesik_hedef_adisyon_id'] != null) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DetayScreen(tip: 'adisyon', id: _n(m['birlesik_hedef_adisyon_id']).toInt(), baslikFallback: m['birlesik_hedef_ad']?.toString() ?? m['ad'].toString())));
          _yukle();
        } else if (acik) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DetayScreen(tip: 'adisyon', id: _n(m['adisyon_id']).toInt(), baslikFallback: m['ad'].toString())));
          _yukle();
        } else {
          await _masaAc(m);
        }
      },
      child: _hucreGovde(m),
    );

    // Her masa birakma hedefi olabilir: dolu -> birlestir, bos -> tasi. Birlesik kaynak masa hedef OLAMAZ.
    return DragTarget<Map>(
      onWillAcceptWithDetails: (d) =>
          _n(d.data['id']).toInt() != _n(m['id']).toInt() && d.data['adisyon_id'] != null && !birlesik,
      onAcceptWithDetails: (d) => _birlestirVeyaTasi(d.data, m),
      builder: (ctx, cand, rej) {
        final hover = cand.isNotEmpty;
        // Sadece dolu masalar suruklenebilir (bos masanin hesabi yok)
        Widget cell = acik
            ? LongPressDraggable<Map>(
                data: m,
                feedback: _suruklenenGorunum(m),
                childWhenDragging: Opacity(opacity: 0.3, child: _hucreGovde(m)),
                child: tapCell,
              )
            : tapCell;
        if (hover) {
          // Uzerine gelince hedefi vurgula (dolu=mor birlestir, bos=mavi tasi)
          final vurguRenk = acik ? const Color(0xFF4F46E5) : const Color(0xFF0EA5E9);
          cell = DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: vurguRenk, width: 2.5),
              color: vurguRenk.withValues(alpha: 0.08),
            ),
            child: cell,
          );
        }
        return cell;
      },
    );
  }

  Widget _hucreGovde(Map m) {
    final acik = m['adisyon_id'] != null;
    final durum = m['durum'].toString();
    final birlesik = durum == 'birlesik';
    final grup = (m['birlesik_masalar'] as List?)?.map((e) => e.toString()).toList() ?? [];

    // Kaynak masa (baska masaya birlesmis, artik bos): gri, linkli
    if (birlesik) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m['ad'].toString(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), decoration: TextDecoration.lineThrough)),
            const SizedBox(height: 4),
            const Icon(Icons.merge_type, size: 15, color: Color(0xFF4F46E5)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text('${m['birlesik_hedef_ad'] ?? ''} ile birleşik',
                  textAlign: TextAlign.center,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: grup.length > 1 ? const Color(0xFFF5F3FF) : _renk(durum),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: grup.length > 1 ? const Color(0xFFC4B5FD) : _kenar(durum), width: grup.length > 1 ? 2 : 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Birlesikse "Masa 1 + Masa 2" rozeti, degilse normal masa adi
          if (grup.length > 1) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.merge_type, size: 12, color: Colors.white),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(grup.join(' + '),
                      textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ]),
            ),
            const SizedBox(height: 2),
            Text('birleşik masa', style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
          ] else ...[
            Text(m['ad'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('${m['kapasite']} kişi', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: acik
                ? Text(_n(m['tutar']) > 0 ? '${_f.format(_n(m['tutar']).round())} ₺' : 'açık',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))
                : const Text('boş', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
          ),
        ],
      ),
    );
  }

  // Suruklerken parmagin altinda gorunen kart
  Widget _suruklenenGorunum(Map m) => Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.drag_indicator, color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Text(m['ad'].toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (_n(m['tutar']) > 0) ...[
              const SizedBox(width: 8),
              Text('${_f.format(_n(m['tutar']).round())} ₺', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ]),
        ),
      );

  // Surukle-birak sonucu: hedef dolu ise birlestir, bos ise tasi.
  Future<void> _birlestirVeyaTasi(Map source, Map target) async {
    final auth = context.read<AuthProvider>();
    final hedefAcik = target['adisyon_id'] != null;

    if (hedefAcik) {
      final combined = _n(source['tutar']) + _n(target['tutar']);
      final onay = await _onayDialog(
        baslik: 'Masaları Birleştir',
        ikon: Icons.merge_type,
        renk: const Color(0xFF4F46E5),
        mesaj: '${source['ad']} hesabı ${target['ad']} masasına aktarılacak.\n'
            '${source['ad']} boşalacak, birleşik hesap ${target['ad']} masasında toplanacak.',
        vurgu: 'Birleşik toplam: ${_f.format(combined.round())} ₺',
        onayText: 'Birleştir',
      );
      if (onay != true) return;
      try {
        final res = await Api.masaBirlestir(auth.token!, _n(target['adisyon_id']).toInt(), _n(source['adisyon_id']).toInt());
        if (!mounted) return;
        _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '');
        if (res['ok'] == 1) _yukle();
      } on ApiYetkiHatasi {
        if (mounted) context.read<AuthProvider>().cikis();
      } catch (_) {
        _uyar('Bağlantı hatası');
      }
    } else {
      final onay = await _onayDialog(
        baslik: 'Masayı Taşı',
        ikon: Icons.swap_horiz,
        renk: const Color(0xFF0EA5E9),
        mesaj: '${source['ad']} hesabı boş ${target['ad']} masasına taşınacak.',
        vurgu: null,
        onayText: 'Taşı',
      );
      if (onay != true) return;
      try {
        final res = await Api.masaTasi(auth.token!, _n(source['adisyon_id']).toInt(), _n(target['id']).toInt());
        if (!mounted) return;
        _uyar(res['mesaj']?.toString() ?? res['hata']?.toString() ?? '');
        if (res['ok'] == 1) _yukle();
      } on ApiYetkiHatasi {
        if (mounted) context.read<AuthProvider>().cikis();
      } catch (_) {
        _uyar('Bağlantı hatası');
      }
    }
  }

  Future<bool?> _onayDialog({
    required String baslik,
    required IconData ikon,
    required Color renk,
    required String mesaj,
    String? vurgu,
    required String onayText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [Icon(ikon, color: renk), const SizedBox(width: 8), Text(baslik, style: const TextStyle(fontSize: 17))]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(mesaj, style: const TextStyle(color: Color(0xFF475569), height: 1.4)),
          if (vurgu != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text(vurgu, style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: renk), child: Text(onayText)),
        ],
      ),
    );
  }
}
