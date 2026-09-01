import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/tema_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..yukle()),
        ChangeNotifierProvider(create: (_) => TemaProvider()),
      ],
      child: const RestoOsApp(),
    ),
  );
}

class RestoOsApp extends StatelessWidget {
  const RestoOsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final koyu = context.watch<TemaProvider>().koyu;
    return MaterialApp(
      title: 'ResteOS Patron',
      debugShowCheckedModeBanner: false,
      themeMode: koyu ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF3F5FA),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0B1020),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, auth, child) =>
            auth.girisli ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}
