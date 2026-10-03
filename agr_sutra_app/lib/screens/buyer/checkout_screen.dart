import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/buyer_service.dart';
 
class CheckoutScreen extends StatefulWidget {
  final List<CartItem> items;
 
  /// true when checking out the whole cart (the cart is emptied afterwards);
  /// false for "Buy now" on a single product.
  final bool fromCart;
  const CheckoutScreen({super.key, required this.items, required this.fromCart});
 
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}
 
class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _payments = ['Cash on Delivery', 'UPI', 'Card'];
  final _address = TextEditingController();
  String _payment = _payments.first;
  bool _loading = false;
 
  int get _total => widget.items.fold(0, (sum, i) => sum + i.subtotal);
 
  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }
 
  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  Future<void> _place() async {
    final address = _address.text.trim();
    if (address.length < 5) {
      _toast('Please enter your full delivery address.');
      return;
    }
    setState(() => _loading = true);
    try {
      final cart = context.read<CartProvider>();
      await BuyerService(context.read<AuthProvider>().api).placeOrders(
        items: widget.items
            .map((i) => MapEntry(i.product.productId, i.quantity))
            .toList(),
        address: address,
        paymentMethod: _payment,
      );
      if (widget.fromCart) cart.clear();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Order placed!'),
          content: const Text('You can track it in the My Orders tab.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Order summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final i in widget.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(i.product.name),
                subtitle: Text('${i.quantity} x ₹${i.product.price}'),
                trailing: Text('₹${i.subtotal}'),
              ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: Theme.of(context).textTheme.titleMedium),
                Text('₹$_total', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _address,
              maxLines: 3,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Delivery address'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _payment,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), labelText: 'Payment method'),
              items: _payments
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _payment = v ?? _payments.first),
            ),
            if (_payment != 'Cash on Delivery')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Demo build: online payment is simulated, no money is charged.',
                    style: TextStyle(fontSize: 12)),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _place,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Place order  •  ₹$_total'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}