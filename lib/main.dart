import 'package:flutter/material.dart';
import 'features/vault/screens/vault_gate.dart';

const navy = Color(0xFF071536);
const navy2 = Color(0xFF0D2148);
const teal = Color(0xFF009B83);
const tealLight = Color(0xFF16B99B);
const page = Color(0xFFF4F7FA);
const ink = Color(0xFF10213E);

void main() => runApp(const SanjAiApp());

class SanjAiApp extends StatelessWidget {
  const SanjAiApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Personal Document Vault', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true, brightness: Brightness.light, scaffoldBackgroundColor: page,
      colorScheme: ColorScheme.fromSeed(seedColor: teal, brightness: Brightness.light, primary: teal, secondary: navy, surface: Colors.white),
      appBarTheme: const AppBarTheme(backgroundColor: page, foregroundColor: ink, elevation: 0, centerTitle: false),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFE8EDF2)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xFFF5F8FA), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15)),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: teal.withOpacity(.12), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
    ),
    home: const VaultGate(),
  );
}
