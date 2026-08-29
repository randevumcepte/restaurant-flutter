import 'package:flutter/foundation.dart';

/// Ana alt menü sekme index'i (0=Özet, 1=Masalar, 2=Mutfak, 3=Paket).
/// HomeScreen bunu dinler; başka ekranlar (ör. Asistan) buraya yazıp
/// ana ekrana dönerek sekme değiştirebilir.
final ValueNotifier<int> anaSekme = ValueNotifier<int>(0);
