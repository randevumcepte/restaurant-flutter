import 'package:flutter/widgets.dart';

/// Masaustu/tablet-yatay esigi. Altinda TELEFON duzeni, ustunde MASAUSTU duzeni
/// (sol sabit menu + cok sutunlu pano) devreye girer. Tek kod tabani, iki yuz.
const double kGenisEsik = 1000;

/// Ekran bu genislikten genisse masaustu duzeni gosterilir.
bool genisMi(BuildContext context) => MediaQuery.sizeOf(context).width >= kGenisEsik;
