import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../providers/auth_provider.dart';
import '../profile_screen.dart';
import 'add_product_screen.dart';
import 'dashboard_tab.dart';
import 'earnings_screen.dart';
import 'my_listings_screen.dart';
import 'seller_orders_screen.dart';
 
/// The seller's main screen: five bottom tabs.
class SellerShell extends StatefulWidget {
  const SellerShell({super.key});
 
  @override
  State<SellerShell> createState() => _SellerShellState();
}
 
class _SellerShellState extends State<SellerShell> {
  int _index = 0;
  int _tick = 0; // changes on every tab switch, so data tabs reload
 
  static const _titles = [
    'Dashboard',
    'Add Product',
    'My Listings',
    'Orders',
    'Earnings',
  ];
 
  void _select(int i) {
    setState(() {
      _index = i;
      _tick++;
    });
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            tooltip: 'My profile',
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardTab(
            refreshKey: _tick,
            onAddProduct: () => _select(1),
            onOpenOrders: () => _select(3),
          ),
          AddProductScreen(onPublished: () => _select(2)),
          MyListingsScreen(refreshKey: _tick),
          SellerOrdersScreen(refreshKey: _tick),
          EarningsScreen(refreshKey: _tick),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.add_a_photo), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Listings'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Earnings'),
        ],
      ),
    );
  }
}