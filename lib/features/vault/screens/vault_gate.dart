import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/vault_service.dart';
import 'vault_screen.dart';

class VaultGate extends StatefulWidget {
  const VaultGate({super.key});

  @override
  State<VaultGate> createState() => _VaultGateState();
}

class _VaultGateState extends State<VaultGate> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = LocalAuthentication();
  bool _configured = false;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkVault();
  }

  Future<void> _checkVault() async {
    final configured = await VaultService.instance.isConfigured();
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _loading = false;
    });
  }

  Future<void> _submitPin() async {
    setState(() { _busy = true; _error = null; });
    try {
      if (!_configured) {
        if (_pinController.text.length < 6) {
          throw Exception('Choose a PIN with at least 6 digits.');
        }
        if (_pinController.text != _confirmController.text) {
          throw Exception('The PINs do not match.');
        }
        await VaultService.instance.setupPin(_pinController.text);
      } else {
        final ok = await VaultService.instance.verifyPin(_pinController.text);
        if (!ok) throw Exception('Incorrect PIN. Please try again.');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    setState(() { _busy = true; _error = null; });
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      if (!supported || !canCheck) throw Exception('Biometric authentication is not set up on this device.');
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your SANJ AI Family Document Vault',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (!ok) return;
      await VaultService.instance.unlockAfterBiometric();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VaultScreen()));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF009B83);
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: accent)));
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24), child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420), child: Column(children: [
            Image.asset('assets/branding/sanj_ai_logo.png', height: 105, fit: BoxFit.contain),
            const SizedBox(height: 22),
            Container(width: 66, height: 66, decoration: BoxDecoration(color: accent.withOpacity(.10), shape: BoxShape.circle), child: const Icon(Icons.lock_outline, color: accent, size: 30)),
            const SizedBox(height: 18),
            Text(_configured ? 'Welcome back' : 'Set up your private space', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: Color(0xFF10213E))),
            const SizedBox(height: 7),
            Text(_configured ? 'Unlock your family document vault' : 'Create a master PIN to protect your documents', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF7A8799))),
            const SizedBox(height: 28),
            TextField(controller: _pinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 12, decoration: const InputDecoration(labelText: 'Master PIN', prefixIcon: Icon(Icons.password), counterText: '')),
            if (!_configured) ...[const SizedBox(height: 12), TextField(controller: _confirmController, obscureText: true, keyboardType: TextInputType.number, maxLength: 12, decoration: const InputDecoration(labelText: 'Confirm master PIN', prefixIcon: Icon(Icons.verified_user_outlined), counterText: ''))],
            if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Colors.redAccent))],
            const SizedBox(height: 18), SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _submitPin, style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)), child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_configured ? 'UNLOCK SANJ AI' : 'CREATE SECURE SPACE'))),
            if (_configured) TextButton.icon(onPressed: _busy ? null : _biometric, icon: const Icon(Icons.fingerprint, color: accent, size: 26), label: const Text('Unlock with fingerprint')),
            const SizedBox(height: 16), const Text('YOUR LIFE. YOUR DATA. YOUR AI.\nYour documents are encrypted and stored on this device.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF8792A3), fontSize: 11, height: 1.6)),
          ]),
        ),
      ))),
    );
  }
}
