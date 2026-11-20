import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

// ───────── web personel.blade.php ile aynı sabitler ─────────
const Map<String, String> kIkRolAd = {
  'sahip': 'Sahip', 'mudur': 'Müdür', 'satinalmaci': 'Satın Almacı', 'kasa': 'Kasa', 'garson': 'Garson', 'mutfak': 'Mutfak',
};
const Map<String, Color> kIkRolRenk = {
  'sahip': Color(0xFF7C3AED), 'mudur': Color(0xFF2563EB), 'satinalmaci': Color(0xFF0D9488),
  'kasa': Color(0xFFF59E0B), 'garson': Color(0xFF10B981), 'mutfak': Color(0xFFD97706),
};
Color ikRolRenk(String? rol) => kIkRolRenk[rol] ?? const Color(0xFF64748B);

/// POS işlem yetkileri (web $etiketler / $gruplar ile birebir)
const Map<String, String> kIkYetkiEtiket = {
  'adisyon_ac': 'Adisyon Aç', 'adisyon_kapat': 'Ödeme Al / Masa Kapat', 'adisyon_iptal': 'Adisyon İptal',
  'adisyon_bol': 'Adisyon Böl', 'adisyon_birlestir': 'Masa Birleştir', 'masa_tasima': 'Masa Taşıma',
  'iskonto': 'İskonto Uygula', 'ikram': 'İkram', 'urun_sil': 'Ürün Sil (Void)', 'fatura_kes': 'Fatura Kes',
  'geri_islem': 'Geriye Dönük İşlem', 'maliyet_gor': 'Maliyet Görebilir', 'rapor_gor': 'Rapor Görebilir',
};
const List<(String, IconData, List<String>)> kIkYetkiGruplar = [
  ('Adisyon', Icons.receipt_long_outlined, ['adisyon_ac', 'adisyon_kapat', 'adisyon_iptal', 'adisyon_bol', 'adisyon_birlestir', 'masa_tasima']),
  ('Para & Kayıp', Icons.payments_outlined, ['iskonto', 'ikram', 'urun_sil', 'fatura_kes']),
  ('Yönetim', Icons.insights, ['geri_islem', 'maliyet_gor', 'rapor_gor']),
];

/// Personelin yetki editörü — web /personel "Yetkiler" penceresinin aynısı (POST /personel/yetki).
/// Yetki seviyesi (kademe) şablonu, departman + ünvan + sorumlu, kategori kategori sayfa (gor_*) yetkileri,
/// POS işlem yetkileri + iskonto/ikram limitleri. "Tam yetki ver" kısayolu her şeyi açar.
class IkYetkiDuzenleScreen extends StatefulWidget {
  final Map<String, dynamic> personel;
  /// /personel sayfasının köprü verisi (kademeler, sayfaKategori, kademeSayfa, departmanlar ...)
  final Map<String, dynamic> sayfaVeri;
  const IkYetkiDuzenleScreen({super.key, required this.personel, required this.sayfaVeri});

  @override
  State<IkYetkiDuzenleScreen> createState() => _IkYetkiDuzenleScreenState();
}

class _IkYetkiDuzenleScreenState extends State<IkYetkiDuzenleScreen> {
  late String _kademe;
  late int _depId;
  late String _unvan;
  late bool _sorumlu;
  final Map<String, bool> _sayfa = {};
  final Map<String, bool> _yetki = {};
  final _iskontoC = TextEditingController();
  final _ikramC = TextEditingController();
  bool _kaydediliyor = false;
  bool _degisti = false;
  String _ara = '';

  Map<String, dynamic> get _v => widget.sayfaVeri;
  bool get _duzenleyebilir => _v['duzenleyebilir'] == true || _v['duzenleyebilir'] == 1;
  Map<String, dynamic> get _kademeler => harita(_v['kademeler']);
  Map<String, dynamic> get _sayfaKategori => harita(_v['sayfaKategori']);
  List<Map<String, dynamic>> get _departmanlar => liste(_v['departmanlar']);
  List<String> get _tumSayfa {
    final t = dizi(_v['tumSayfa']).map((e) => '$e').toList();
    if (t.isNotEmpty) return t;
    return [for (final g in _sayfaKategori.values) ...harita(g).keys];
  }

  List<String> _anahtarListe(dynamic harit, Object anahtar) {
    final h = harita(harit);
    return dizi(h['$anahtar']).map((e) => '$e').toList();
  }

  @override
  void initState() {
    super.initState();
    final p = widget.personel;
    _kademe = metinOku(p['kademe'], 'personel');
    _depId = tamOku(p['departman_id']);
    _unvan = metinOku(p['departman_unvan']);
    _sorumlu = tamOku(p['departman_sorumlu']) == 1;
    final sf = harita(p['sayfa']);
    for (final k in _tumSayfa) {
      _sayfa[k] = sf[k] == true || sf[k] == 1;
    }
    final y = harita(p['yetkiler']);
    for (final k in kIkYetkiEtiket.keys) {
      _yetki[k] = y[k] == true || y[k] == 1;
    }
    _iskontoC.text = sayiOku(p['iskonto_limit']).round().toString();
    _ikramC.text = sayiOku(p['ikram_limit']).round().toString();
  }

  @override
  void dispose() {
    _iskontoC.dispose();
    _ikramC.dispose();
    super.dispose();
  }

  void _degistir(VoidCallback f) {
    if (!_duzenleyebilir) return;
    setState(() {
      f();
      _degisti = true;
    });
  }

  // Seviye seçilince o seviyenin sayfaları işaretlenir (web kademeUygula)
  void _kademeUygula(String kd) {
    final lst = _anahtarListe(_v['kademeSayfa'], kd);
    _degistir(() {
      _kademe = kd;
      for (final k in _sayfa.keys.toList()) {
        _sayfa[k] = kd == 'sahip' || lst.contains(k);
      }
    });
  }

  // Departman (+ sorumlu ek) sayfaları (web departmanUygula). Departman "yok" ise mevcut işaretler korunur.
  void _departmanUygula() {
    if (_depId <= 0) return;
    final lst = _anahtarListe(_v['departmanSayfa'], _depId);
    if (_sorumlu) {
      for (final k in _anahtarListe(_v['departmanEk'], _depId)) {
        if (!lst.contains(k)) lst.add(k);
      }
    }
    for (final k in _sayfa.keys.toList()) {
      _sayfa[k] = lst.contains(k);
    }
  }

  Future<void> _tamYetki() async {
    final ad = metinOku(widget.personel['ad'], 'Bu personel');
    final ok = await kOnay(context, '$ad TAM YETKİLİ yapılsın mı?',
        evet: 'Tümünü ver',
        aciklama: 'Yetki seviyesi "Sahip" olur; bütün sayfalar ve bütün POS işlem yetkileri açılır, iskonto limiti %100 olur. '
            'Kaydet\'e basınca geçerli olur.\n\nNot: Rolü (ör. Müdür) personel kartındaki "Düzenle" ile ayrıca değiştirebilirsiniz.');
    if (!ok) return;
    _degistir(() {
      if (_kademeler.containsKey('sahip')) _kademe = 'sahip';
      for (final k in _sayfa.keys.toList()) {
        _sayfa[k] = true;
      }
      for (final k in _yetki.keys.toList()) {
        _yetki[k] = true;
      }
      _iskontoC.text = '100';
      if (sayiOku(_ikramC.text) < 100000) _ikramC.text = '100000';
    });
  }

  void _hepsiniKapat() {
    _degistir(() {
      for (final k in _sayfa.keys.toList()) {
        _sayfa[k] = false;
      }
      for (final k in _yetki.keys.toList()) {
        _yetki[k] = false;
      }
    });
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    final govde = <String, dynamic>{
      'id': widget.personel['id'],
      'kademe': _kademe,
      'iskonto_limit': sayiOku(_iskontoC.text).clamp(0, 100).toString(),
      'ikram_limit': sayiOku(_ikramC.text).clamp(0, 99999999).toString(),
      'departman_id': _depId,
      'departman_unvan': _depId > 0 ? _unvan : '',
    };
    // Web formu işaretsiz kutuyu hiç göndermez; sunucu "var mı" diye bakar → yalnız açık olanları gönder.
    if (_depId > 0 && _sorumlu) govde['departman_sorumlu'] = '1';
    _sayfa.forEach((k, v) {
      if (v) govde['sayfa_$k'] = '1';
    });
    _yetki.forEach((k, v) {
      if (v) govde['yetki_$k'] = '1';
    });
    final ok = await kopruGonder(context, '/personel/yetki', govde, basariMesaji: 'Yetkiler kaydedildi.');
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<bool> _cikisOnay() async {
    if (!_degisti) return true;
    return kOnay(context, 'Kaydedilmemiş değişiklikler var', evet: 'Çık', hayir: 'Kal', tehlikeli: true, aciklama: 'Kaydetmeden çıkarsanız yaptığınız değişiklikler kaybolur.');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final p = widget.personel;
    final acikSayfa = _sayfa.values.where((e) => e).length;
    final acikYetki = _yetki.values.where((e) => e).length;
    final rol = metinOku(p['rol']);
    final rolSahip = rol == 'sahip';

    final govde = KGovde(maxGenislik: 980, children: [
      // Kişi kartı
      KKart(
        renk: ikRolRenk(rol),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: ikRolRenk(rol).withValues(alpha: .16),
            child: Text(metinOku(p['ad'], '?').substring(0, 1).toUpperCase(), style: TextStyle(color: ikRolRenk(rol), fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(p['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                KRozet(kIkRolAd[rol] ?? rol, renk: ikRolRenk(rol)),
                KRozet('$acikSayfa / ${_sayfa.length} sayfa', renk: t.mavi, ikon: Icons.visibility_outlined),
                KRozet('$acikYetki / ${_yetki.length} işlem', renk: t.mor1, ikon: Icons.tune),
              ]),
            ]),
          ),
        ]),
      ),
      if (!_duzenleyebilir)
        KKart(
          renk: t.amber,
          child: Row(children: [
            Icon(Icons.lock_outline, color: t.amber),
            const SizedBox(width: 10),
            Expanded(child: Text('Yetki düzenlemeyi yalnızca işletme sahibi yapabilir. Burada mevcut yetkileri görüntülüyorsunuz.', style: TextStyle(color: t.sub2, fontSize: 13.5))),
          ]),
        ),
      if (rolSahip)
        KKart(
          renk: t.mor1,
          child: Text('Bu kişi işletme SAHİBİ — sahip her sayfayı her zaman görür; buradaki sayfa işaretleri onu kısıtlamaz.', style: TextStyle(color: t.sub2, fontSize: 13.5)),
        ),

      // Hızlı kısayollar
      if (_duzenleyebilir)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            KButon('Tümünü ver (tam yetki)', ikon: Icons.verified_user_outlined, renk: t.yesil, onTap: _tamYetki),
            KButon('Hepsini kapat', ikon: Icons.block, renk: t.kirmizi, ikincil: true, onTap: _hepsiniKapat),
          ]),
        ),

      // Seviye
      const KBaslik('Yetki Seviyesi', ikon: Icons.workspace_premium_outlined, alt: 'Seviye seçince sayfalar otomatik işaretlenir; sonra tek tek açıp kapatabilirsiniz.'),
      _kademeSecici(t),
      const SizedBox(height: 8),

      // Departman
      if (_departmanlar.isNotEmpty) ...[
        KBaslik('Departman', ikon: Icons.groups_outlined, renk: t.mavi,
            alt: 'Departman seçince o departmanın sayfaları işaretlenir; Sorumlu ise yönetim sayfaları da eklenir.'),
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Departman',
                deger: _depId,
                secenekler: [
                  (0, '— Departman yok —'),
                  for (final d in _departmanlar) (tamOku(d['id']), '${metinOku(d['grup']).isEmpty ? '' : '${metinOku(d['grup'])} › '}${metinOku(d['ad'])}'),
                ],
                onSec: (v) {
                  if (!_duzenleyebilir) return;
                  _degistir(() {
                    _depId = v ?? 0;
                    final uv = _anahtarListe(_v['departmanUnvan'], _depId);
                    if (!uv.contains(_unvan)) _unvan = '';
                    _departmanUygula();
                  });
                }),
            if (_depId > 0) ...[
              KSecim<String>('Ünvan / Kademe',
                  deger: _unvan,
                  secenekler: [
                    ('', '—'),
                    for (final (i, u) in _anahtarListe(_v['departmanUnvan'], _depId).indexed) (u, i == 0 ? '★ $u' : u),
                    if (_unvan.isNotEmpty && !_anahtarListe(_v['departmanUnvan'], _depId).contains(_unvan)) (_unvan, _unvan),
                  ],
                  onSec: (v) => _degistir(() => _unvan = v ?? '')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _sorumlu,
                activeThumbColor: t.amber,
                onChanged: _duzenleyebilir ? (v) => _degistir(() {
                      _sorumlu = v;
                      _departmanUygula();
                    }) : null,
                title: Text('Departman Sorumlusu', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text('Departmanın taleplerini onaylar; sorumluya ek sayfalar açılır.', style: TextStyle(color: t.sub, fontSize: 12.5)),
              ),
            ],
          ]),
        ),
      ],

      // Sayfalar
      KBaslik('Görebileceği Sayfalar (Menü)', ikon: Icons.visibility_outlined, alt: '$acikSayfa / ${_sayfa.length} açık'),
      KAra(ipucu: 'Sayfa ara…', onDegis: (s) => setState(() => _ara = s.toLowerCase().trim())),
      for (final e in _sayfaKategori.entries) _kategoriKart(t, e.key, harita(e.value)),

      // İşlem yetkileri
      const SizedBox(height: 6),
      KBaslik('İşlem Yetkileri (POS)', ikon: Icons.tune, alt: '$acikYetki / ${_yetki.length} açık'),
      for (final (baslik, ikon, keys) in kIkYetkiGruplar) _yetkiGrupKart(t, baslik, ikon, keys),
      if (_duzenleyebilir)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: KButon('Yetkileri Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediliyor, onTap: _kaydet),
        ),
    ]);

    return PopScope(
      canPop: !_degisti,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _cikisOnay() && context.mounted) {
          setState(() => _degisti = false);
          Navigator.pop(context);
        }
      },
      child: KSayfa(
        baslik: '${metinOku(p['ad'], 'Personel')} — Yetkiler',
        ikon: Icons.shield_outlined,
        araclar: [
          if (_duzenleyebilir)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                onPressed: _kaydediliyor ? null : _kaydet,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ],
        govde: govde,
      ),
    );
  }

  Widget _kademeSecici(TemaProvider t) {
    final kd = _kademeler.entries.toList();
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final e in kd)
        Builder(builder: (_) {
          final info = harita(e.value);
          final r = renkOku(info['renk'], t.mor1);
          final sec = e.key == _kademe;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _duzenleyebilir ? () => _kademeUygula(e.key) : null,
            child: Container(
              width: genisMi(context) ? 220 : double.infinity,
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: sec ? r.withValues(alpha: .14) : t.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sec ? r : t.line, width: sec ? 1.6 : 1),
              ),
              child: Row(children: [
                Icon(sec ? Icons.radio_button_checked : Icons.radio_button_off, color: sec ? r : t.sub, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(metinOku(info['ad'], e.key), style: TextStyle(color: sec ? r : t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(metinOku(info['aciklama']), style: TextStyle(color: t.sub, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          );
        }),
    ]);
  }

  Widget _kategoriKart(TemaProvider t, String kat, Map<String, dynamic> sayfalar) {
    final keys = sayfalar.keys.where((k) => _ara.isEmpty || metinOku(sayfalar[k]).toLowerCase().contains(_ara) || k.contains(_ara)).toList();
    if (keys.isEmpty) return const SizedBox.shrink();
    final acik = sayfalar.keys.where((k) => _sayfa[k] == true).length;
    final hepsi = acik == sayfalar.length;
    return KKart(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: genisMi(context) || _ara.isNotEmpty,
          key: PageStorageKey('kat_$kat${_ara.isNotEmpty}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          title: Text(kat, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text('$acik / ${sayfalar.length} açık', style: TextStyle(color: acik > 0 ? t.mor1 : t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
          trailing: _duzenleyebilir
              ? TextButton(
                  onPressed: () => _degistir(() {
                    for (final k in sayfalar.keys) {
                      _sayfa[k] = !hepsi;
                    }
                  }),
                  child: Text(hepsi ? 'Hepsini kapat' : 'Hepsini aç', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                )
              : null,
          children: [
            for (final k in keys)
              CheckboxListTile(
                dense: false,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                value: _sayfa[k] ?? false,
                activeColor: t.mor1,
                onChanged: _duzenleyebilir ? (v) => _degistir(() => _sayfa[k] = v ?? false) : null,
                title: Text(metinOku(sayfalar[k], k), style: TextStyle(color: t.ink, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _yetkiGrupKart(TemaProvider t, String baslik, IconData ikon, List<String> keys) {
    return KKart(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(children: [
            Icon(ikon, size: 18, color: t.mor1),
            const SizedBox(width: 8),
            Text(baslik, style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        for (final k in keys) ...[
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            value: _yetki[k] ?? false,
            activeThumbColor: t.mor1,
            onChanged: _duzenleyebilir ? (v) => _degistir(() => _yetki[k] = v) : null,
            title: Text(kIkYetkiEtiket[k] ?? k, style: TextStyle(color: t.ink, fontSize: 14)),
          ),
          if (k == 'iskonto' && (_yetki[k] ?? false)) _limitSatir(t, 'İskonto limiti (%)', _iskontoC, 'Üstü yönetici onayı ister'),
          if (k == 'ikram' && (_yetki[k] ?? false)) _limitSatir(t, 'İkram limiti (₺)', _ikramC, 'Üstü yönetici onayı ister'),
        ],
      ]),
    );
  }

  Widget _limitSatir(TemaProvider t, String etiket, TextEditingController c, String alt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(alt, style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            controller: c,
            enabled: _duzenleyebilir,
            keyboardType: TextInputType.number,
            onChanged: (_) => _degisti = true,
            style: TextStyle(color: t.ink, fontSize: 15),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: t.card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            ),
          ),
        ),
      ]),
    );
  }
}
