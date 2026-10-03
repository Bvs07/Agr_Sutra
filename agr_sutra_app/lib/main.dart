import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'screens/buyer/buyer_shell.dart';
import 'screens/seller/seller_shell.dart';
import 'screens/welcome_screen.dart';
 
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const AgrSutraApp(),
    ),
  );
}
 
class AgrSutraApp extends StatelessWidget {
  const AgrSutraApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AGR Sutra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
      ),
      home: const RootGate(),
    );
  }
}
 
/// Decides what to show: loading, the app (logged in), or the welcome screen.
class RootGate extends StatelessWidget {
  const RootGate({super.key});
 
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.initializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.user;
    if (user == null) return const WelcomeScreen();
    return user.isSeller ? const SellerShell() : const BuyerShell();
  }
}