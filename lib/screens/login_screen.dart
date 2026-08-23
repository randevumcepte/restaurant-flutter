import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pin = TextEditingController();
  String? _hata;

  Future<void> _giris() async {
    setState(() => _hata = null);
    final err = await context.read<AuthProvider>().girisYap(_pin.text.trim());
    if (err != null && mounted) setState(() => _hata = err);
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍔', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              const Text('RestoOS Patron',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const Text('Yönetici girişi', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 28),
              TextField(
                controller: _pin,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _giris(),
                style: const TextStyle(fontSize: 22, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: 'PIN',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_hata!, style: const TextStyle(color: Color(0xFFDC2626))),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: auth.loading ? null : _giris,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Giriş', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Demo PIN: 1001 (Sahip) · 1002 (Müdür)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
