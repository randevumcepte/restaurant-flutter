import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /satinalma-islemleri — satın alma özelliklerinin kart ızgarası (hub). Her kart web adresiyle aynı ekranı açar.
class SatinalmaIslemleriScreen extends StatefulWidget {
  const SatinalmaIslemleriScreen({super.key});
  @override
  State<SatinalmaIslemleriScreen> createState() => _SatinalmaIslemleriScreenState();
}

const _gruplar = <(String, IconData, List<(String, String, String, String, Color)>)>[
  ('Günlük Süreç', Icons.play_circle_outline, [
    ('/departman-brief?dep=satinalma', 'wb_sunny', 'Sabah Brifingi', 'Günün özeti: ne acil, ne gecikti, ne risk — tek ekran', Color(0xFFF59E0B)),
    ('/siparis-onerisi', 'auto_awesome', 'Otomatik Sipariş Önerisi', 'AI, geçmiş tüketime göre ne sipariş edileceğini söyler', Color(0xFF8B5CF6)),
    ('/satinalma-talep', 'assignment', 'Satın Alma Talebi', 'Mutfak/depo talebi oluştur, onaya gönder', Color(0xFF6366F1)),
    ('/satinalma-siparis', 'shopping_cart_checkout', 'Sipariş İşlemleri', 'Tedarikçiye sipariş geç, PO oluştur, siparişleri yönet', Color(0xFF4F46E5)),
    ('/mal-kabul', 'inventory', 'Mal Kabul / İrsaliye', 'Gelen malı tart, say, stoğa düş', Color(0xFF10B981)),
    ('/fatura-eslestir', 'fact_check', 'Fatura Eşleştir (3-way)', 'PO ↔ İrsaliye ↔ Fatura üçlü karşılaştırma', Color(0xFFF59E0B)),
    ('/fatura-ocr', 'document_scanner', 'Fatura OCR (AI)', 'Faturayı fotoğraflayın, AI kalemleri çıkarsın', Color(0xFF7C3AED)),
  ]),
  ('Stok & Takip', Icons.inventory_2_outlined, [
    ('/stok', 'inventory_2', 'Stok & Satın Alma', 'Malzeme stoğu, par seviye, kritikler', Color(0xFF0EA5E9)),
    ('/sayim', 'fact_check', 'Sayım (Envanter)', 'Fiili sayım girin, kayıp/fazla çıksın', Color(0xFF06B6D4)),
    ('/parti-takip', 'event_busy', 'Parti / SKT Takip', 'Son kullanma tarihi yaklaşanları görün', Color(0xFFF43F5E)),
    ('/uretim-riski', 'warning_amber', 'Üretim Riski', 'Yarın hangi yemeği pişiremezsiniz — şimdi görün', Color(0xFFF59E0B)),
    ('/barkod', 'qr_code', 'Barkod Yönetim', 'Ürün/malzeme barkodları ekle, tara', Color(0xFF64748B)),
  ]),
  ('Fiyat & Analiz', Icons.trending_up, [
    ('/fiyat-radari', 'radar', 'Fiyat Radarı · Gizli Zam', 'Sessiz fiyat artışlarını anında yakalayın', Color(0xFFEC4899)),
    ('/hal-fiyatlari', 'storefront', 'Hal Fiyatları (siz vs hal)', 'Hal rayici ile aldığınız fiyatı karşılaştırın', Color(0xFF059669)),
    ('/satinalma-analiz', 'leaderboard', 'Satın Alma Analizi · Karne', 'Kalem/tedarikçi/kategori performans karnesi', Color(0xFF4F46E5)),
    ('/satinalma-butce', 'account_balance_wallet', 'Satın Alma Bütçe', 'Aylık bütçe takibi, aşımları önceden görün', Color(0xFF10B981)),
  ]),
  ('Tedarikçiler', Icons.handshake_outlined, [
    ('/tedarikci', 'local_shipping', 'Tedarikçiler', 'Firma listesi, iletişim, kalemler', Color(0xFF0EA5E9)),
    ('/tedarikci-karne', 'grading', 'Tedarikçi Karnesi', 'Zamanında teslim, fiyat, kalite skorları', Color(0xFF8B5CF6)),
    ('/eposta-hesaplari', 'alternate_email', 'E-posta Hesapları (RFQ)', 'Fiyat talebi için e-posta hesaplarını yönetin', Color(0xFF7C3AED)),
    ('/gelen-teklifler', 'mark_email_read', 'Gelen Teklifler (AI)', 'Tedarikçiden gelen teklifleri AI ile okuyun, karşılaştırın', Color(0xFF10B981)),
  ]),
  ('Akıllı Asistan', Icons.auto_awesome_outlined, [
    ('/satinalma-asistan', 'smart_toy', 'Satın Alma AI Asistanı', 'Sorun, veriden anında cevap alın — rapor üretin', Color(0xFF7C3AED)),
  ]),
];

class _SatinalmaIslemleriScreenState extends State<SatinalmaIslemleriScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final gruplar = [
      for (final g in _gruplar) (g.$1, g.$2, g.$3.where((k) => saIcerir('${k.$3} ${k.$4}', _q)).toList()),
    ].where((g) => g.$3.isNotEmpty).toList();
    return KSayfa(
      baslik: 'Satın Alma İşlemleri',
      ikon: Icons.apps,
      govde: KGovde(children: [
        const SaBilgi('Satın almanın tüm ekranları tek yerde: aşağıdan bir karta dokunun ya da arayın.', ikon: Icons.apps),
        KAra(ipucu: 'Özellik ara (ör. fatura, barkod, bütçe)…', onDegis: (s) => setState(() => _q = s)),
        if (gruplar.isEmpty) KBos(baslik: '"$_q" ile eşleşen özellik yok', aciklama: 'Farklı bir kelimeyle arayın.', ikon: Icons.search_off),
        for (final g in gruplar) ...[
          KBaslik(g.$1, ikon: g.$2, sag: KRozet('${g.$3.length}', renk: t.mor1)),
          SaIzgara([
            for (final k in g.$3)
              KKart(
                renk: k.$5,
                onTap: () => saAc(context, k.$1, k.$3),
                child: KSatir(cizgi: false, solIkon: KIkon(ikonAdi(k.$2, Icons.apps), renk: k.$5), baslik: k.$3, alt: k.$4, sag: Icon(Icons.chevron_right, color: t.sub)),
              ),
          ], minGenislik: 340),
        ],
      ]),
    );
  }
}
