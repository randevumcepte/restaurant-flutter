import 'package:flutter/material.dart';
import '../ana_sekme.dart';
import '../moduller/ai/bildirim_merkezi_screen.dart';

/// Yönetim menüsünü (drawer) açan hamburger butonu — her sayfanın AppBar
/// actions'ına eklenir. Drawer dış (home) Scaffold'da olduğu için alt
/// sayfalardan da `anaScaffoldKey` ile açılır. Yanında bildirim zili (web panel zili ile aynı kutu).
class MenuHamburger extends StatelessWidget {
  final Color? renk;
  const MenuHamburger({super.key, this.renk});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        BildirimZili(renk: renk ?? IconTheme.of(context).color),
        IconButton(
          tooltip: 'Menü',
          onPressed: () => anaScaffoldKey.currentState?.openDrawer(),
          icon: Icon(Icons.menu, color: renk ?? IconTheme.of(context).color),
        ),
      ]);
}
