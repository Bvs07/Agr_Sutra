import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../services/product_service.dart';
import '../../widgets/review_dialog.dart';
 
class MyListingsScreen extends StatefulWidget {
  /// Changing this number makes the list reload.
  final int refreshKey;
  const MyListingsScreen({super.key, required this.refreshKey});
 
  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}
 
class _MyListingsScreenState extends State<MyListingsScreen> {
  List<Product> _items = [];
  String? _error;
  bool _loading = true;
 
  ProductService get _service =>
      ProductService(context.read<AuthProvider>().api);
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant MyListingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }
 
  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.myProducts();
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<void> _setActive(Product p, bool active) async {
    try {
      await _service.updateProduct(p.productId,
          status: active ? 'Active' : 'Inactive');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  Future<void> _editStock(Product p) async {
    final controller = TextEditingController(text: p.stock.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock for ${p.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity in stock'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result < 0) return;
    try {
      await _service.updateProduct(p.productId, stock: result);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  /// Your own opening review gives a new product a starting point.
  /// It is shown on the product page but never counted in the average.
  Future<void> _openingReview(Product p) async {
    final input = await showReviewDialog(context, 'Opening review: ${p.name}');
    if (input == null) return;
    try {
      await BuyerService(context.read<AuthProvider>().api).submitReview(
        type: 'seller_initial',
        rating: input.rating,
        comment: input.comment,
        productId: p.productId,
      );
      _toast('Opening review added.');
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  void _showActions(Product p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Edit stock'),
              onTap: () {
                Navigator.pop(ctx);
                _editStock(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.star_outline),
              title: const Text('Add an opening review'),
              subtitle: const Text('Shown on the product page, not counted in the rating'),
              onTap: () {
                Navigator.pop(ctx);
                _openingReview(p);
              },
            ),
          ],
        ),
      ),
    );
  }
 
  Widget _thumb(Product p) {
    final url = p.fullImageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 60,
        child: url == null
            ? const Icon(Icons.image_not_supported)
            : Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.broken_image)),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(
          child: Text('No products yet.\nUse the Add Product tab to create one.',
              textAlign: TextAlign.center));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (context, i) {
          final p = _items[i];
          return Card(
            child: ListTile(
              leading: _thumb(p),
              title: Text(p.name),
              subtitle: Text('₹${p.price}  •  Stock ${p.stock}\n${p.category}'),
              isThreeLine: true,
              onTap: () => _showActions(p),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Switch(value: p.isActive, onChanged: (v) => _setActive(p, v)),
                  Text(p.isActive ? 'Active' : 'Hidden',
                      style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}