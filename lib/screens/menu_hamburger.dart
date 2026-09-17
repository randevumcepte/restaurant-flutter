import 'package:flutter/material.dart';
import '../ana_sekme.dart';

/// Yönetim menüsünü (drawer) açan hamburger butonu — her sayfanın AppBar
/// actions'ına eklenir. Drawer dış (home) Scaffold'da olduğu için alt
/// sayfalardan da `anaScaffoldKey` ile açılır.
class MenuHamburger extends StatelessWidget {
  final Color? renk;
  const MenuHamburger({super.key, this.renk});
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Menü',
        onPressed: () => anaScaffoldKey.currentState?.openDrawer(),
        icon: Icon(Icons.menu, color: renk ?? IconTheme.of(context).color),
      );
}
