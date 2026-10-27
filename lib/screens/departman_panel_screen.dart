import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';
import '../responsive.dart';

/// Jenerik DEPARTMAN PANELİ (Faz 2): giriş yapan kişinin yetkili olduğu KPI kartlarını gösterir.
/// Aynı ekran koduyla; satın almacı girince satın alma kartları, mutfakçı girince mutfak kartları dolar.
/// Backend: GET /api/departman/panel (mevcut /api/patron servisleri yeniden kullanılır — çift hesap yok).
class DepartmanPanelScreen extends StatefulWidget {
  const DepartmanPanelScreen({super.key});
  @override
  State<DepartmanPanelScreen> createState() => _DepartmanPanelScreenState();
}

class _DepartmanPanelScreenState extends State<DepartmanPanelScreen> {
  bool _yukleniyor = true;
  String? _hata;
  Map<String, dynamic> _veri = {};

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null || tok.isEmpty) {
      setState(() { _yukleniyor = false; _hata = 'Oturum bulunamadı'; });
      return;
    }
    try {
      final res = await Api.departmanPanel(tok);
      if (res['ok'] == 1) {
        _veri = Map<String, dynamic>.from(res);
      } else {
        _hata = res['hata']?.toString() ?? 'Yüklenemedi';
      }
    } catch (_) {
      _hata = 'Bağlantı hatası';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Color _hex(String? h, Color varsayilan) {
    if (h == null || h.isEmpty) return varsayilan;
    var s = h.replaceAll('#', '').trim();
    if (s.length == 6) s = 'FF$s';
    final v = int.tryParse(s, radix: 16);
    return v == null ? varsayilan : Color(v);
  }

  String _bicim(dynamic deger, String? tip) {
    final sayi = (deger is num) ? deger : num.tryParse('${deger ?? 0}') ?? 0;
    if (tip == 'para') {
      return '₺${sayi.round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';
    }
    return sayi.round().toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kartlar = (_veri['kartlar'] is List) ? _veri['kartlar'] as List : [];
    final dep = _veri['departman'] as Map<String, dynamic>?;
    final depAd = dep?['ad']?.toString() ?? (_veri['rol']?.toString() == 'sahip' ? 'Yönetim' : 'Panelim');
    final unvan = dep?['unvan']?.toString();
    final sorumlu = (dep?['sorumlu'] ?? 0) == 1;
    final altBaslik = (unvan != null && unvan.isNotEmpty)
        ? (sorumlu ? '$unvan · Sorumlu' : unvan)
        : (dep?['grup']?.toString());

    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    } else if (_hata != null) {
      govde = Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(_hata!, style: TextStyle(color: t.sub))));
    } else if (kartlar.isEmpty) {
      govde = Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text('Bu departman için gösterilecek veri yok.\nYetkiler departman yönetiminden ayarlanır.',
              textAlign: TextAlign.center, style: TextStyle(color: t.sub)),
        ),
      );
    } else {
      final genis = genisMi(context);
      final sutun = genis ? 3 : 2;
      govde = GridView.count(
        padding: const EdgeInsets.all(14),
        crossAxisCount: sutun,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.35,
        children: [
          for (final k in kartlar)
            _kart(t, Map<String, dynamic>.from(k as Map)),
        ],
      );
    }

    return MasaustuSayfa(
      baslik: depAd,
      altBaslik: altBaslik,
      ikon: Icons.dashboard_customize,
      geri: true,
      govde: govde,
    );
  }

  Widget _kart(TemaProvider t, Map<String, dynamic> k) {
    final renk = _hex(k['renk']?.toString(), t.mavi);
    final ikonAd = k['ikon']?.toString() ?? 'insights';
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
        boxShadow: t.golge,
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(_ikon(ikonAd), color: renk, size: 22),
          ),
          const Spacer(),
          Text(_bicim(k['deger'], k['tip']?.toString()),
              style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(k['baslik']?.toString() ?? '', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ],
      ),
    );
  }

  // Material ikon adını IconData'ya çevir (sık kullanılanlar; bilinmeyen -> insights).
  IconData _ikon(String ad) {
    switch (ad) {
      case 'payments': return Icons.payments;
      case 'inventory_2': return Icons.inventory_2;
      case 'receipt_long': return Icons.receipt_long;
      case 'restaurant': return Icons.restaurant;
      case 'groups': return Icons.groups;
      case 'account_balance': return Icons.account_balance;
      case 'point_of_sale': return Icons.point_of_sale;
      default: return Icons.insights;
    }
  }
}
