import 'package:flutter/material.dart';

/// Ana alt menü sekme index'i (0=Özet, 1=Masalar, 2=Mutfak, 3=Paket).
/// HomeScreen bunu dinler; başka ekranlar (ör. Asistan) buraya yazıp
/// ana ekrana dönerek sekme değiştirebilir.
final ValueNotifier<int> anaSekme = ValueNotifier<int>(0);

/// Telefon dış (home) Scaffold'unun key'i — yönetim drawer'ı burada.
/// Her sayfadan `anaScaffoldKey.currentState?.openDrawer()` ile açılır (sağ üst hamburger).
final GlobalKey<ScaffoldState> anaScaffoldKey = GlobalKey<ScaffoldState>();
