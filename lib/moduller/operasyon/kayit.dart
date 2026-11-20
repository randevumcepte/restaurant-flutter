// ignore_for_file: unused_import
import 'package:flutter/material.dart';
import '../../kopru/ekran_kayit.dart';
import 'kayit_kalite_it.dart';
import 'kayit_santral.dart';
import 'kayit_iletisim.dart';
import 'kayit_masa.dart';
import 'kayit_sistem.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
/// Operasyon modülü: Kalite/HACCP + IT + AI Santral + Ayarlar & Entegrasyon.
void kayitOperasyon() {
  kayitOperasyonKaliteIt();
  kayitOperasyonSantral();
  kayitOperasyonIletisim();
  kayitOperasyonMasa();
  kayitOperasyonSistem();
}
