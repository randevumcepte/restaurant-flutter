import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restoos_patron/providers/auth_provider.dart';
import 'package:restoos_patron/screens/login_screen.dart';

void main() {
  testWidgets('Giris ekrani acilir', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    expect(find.text('RestoOS Patron'), findsOneWidget);
    expect(find.text('Giriş'), findsOneWidget);
  });
}
