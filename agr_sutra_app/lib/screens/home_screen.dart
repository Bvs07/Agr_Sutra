import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../providers/auth_provider.dart';
 
/// Temporary home screen. We replace it with the real Seller and Buyer
/// screens in the next steps.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
 
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    return Scaffold(
      appBar: AppBar(
        title: Text(user.isSeller ? 'Seller Dashboard' : 'Marketplace'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Welcome, ${user.fullName}!',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(user.role)),
              Chip(label: Text(user.language)),
              if (user.pinCode.isNotEmpty) Chip(label: Text('PIN ${user.pinCode}')),
            ],
          ),
          const SizedBox(height: 24),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Login works and is connected to your backend.\n\n'
                'Coming next: product listing with the AI camera, marketplace, cart and orders.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}