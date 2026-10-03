import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../profile_screen.dart';
import 'cart_screen.dart';
import 'marketplace_screen.dart';
import 'my_orders_screen.dart';
 
/// The buyer's main screen: Marketplace, Cart and My Orders tabs.
class BuyerShell extends StatefulWidget {
  const BuyerShell({super.key});
 
  @override
  State<BuyerShell> createState() => _BuyerShellState();
}
 
class _BuyerShellState extends State<BuyerShell> {
  int _index = 0;
  int _marketRefresh = 0;
  int _ordersRefresh = 0;
 
  static const _titles = ['Marketplace', 'My Cart', 'My Orders'];
 
  void _select(int i) {
    setState(() {
      _index = i;
      if (i == 0) _marketRefresh++;
      if (i == 2) _ordersRefresh++;
    });
  }
 
  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().count;
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
            onPressed: () {
              context.read<CartProvider>().clear();
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          MarketplaceScreen(refreshKey: _marketRefresh),
          const CartScreen(),
          MyOrdersScreen(refreshKey: _ordersRefresh),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          const NavigationDestination(icon: Icon(Icons.storefront), label: 'Shop'),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}