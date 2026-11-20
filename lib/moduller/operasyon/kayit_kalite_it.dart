import 'package:flutter/material.dart';
import '../../kopru/ekran_kayit.dart';
import 'it_kayit_screen.dart';
import 'kalite_departman_is_screen.dart';
import 'kalite_it_defter.dart';
import 'kalite_kayit_screen.dart';

/// Kalite/HACCP + IT ekranları.
void kayitOperasyonKaliteIt() {
  // /kalite: HACCP kontrol listesi (web departman_is view'ı, kod=kalite) — açık işler + geçmiş
  EkranKayit.tam('/kalite', (u, a) => const KaliteDepartmanIsScreen());

  // /kalite-kayit?tip=… (tek ekran, tip url'den; ekranda sekmeyle değişir)
  EkranKayit.tam('/kalite-kayit', (u, a) => KaliteKayitScreen(key: ValueKey(u), tip: kaliteItUrlTip(u, 'numune')));
  for (final tip in const ['numune', 'ilaclama', 'kalibrasyon', 'tedarikci_belge', 'denetim']) {
    EkranKayit.tam('/kalite-kayit?tip=$tip', (u, a) => KaliteKayitScreen(key: ValueKey(u), tip: tip));
  }

  // /it-kayit?tip=… (tek ekran, tip url'den)
  EkranKayit.tam('/it-kayit', (u, a) => ItKayitScreen(key: ValueKey(u), tip: kaliteItUrlTip(u, 'ariza')));
  for (final tip in const ['ariza', 'lisans', 'yedek', 'kvkk', 'bakim']) {
    EkranKayit.tam('/it-kayit?tip=$tip', (u, a) => ItKayitScreen(key: ValueKey(u), tip: tip));
  }
}
