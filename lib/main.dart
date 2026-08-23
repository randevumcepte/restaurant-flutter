import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider()..yukle(),
      child: const RestoOsApp(),
    ),
  );
}

class RestoOsApp extends StatelessWidget {
  const RestoOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RestoOS Patron',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) =>
            auth.girisli ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }
}
