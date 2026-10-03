import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
 
import '../../core/api_client.dart';
import '../../models/product_detail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/buyer_service.dart';
import '../../widgets/product_image.dart';
import '../../widgets/stars.dart';
import 'checkout_screen.dart';
 
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
 
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}
 
class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _detail;
  String? _error;
  int _qty = 1;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  Future<void> _load() async {
    try {
      final d = await BuyerService(context.read<AuthProvider>().api)
          .productDetail(widget.productId);
      if (mounted) setState(() => _detail = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }
 
  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
 
  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(d?.product.name ?? 'Product')),
      body: d == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center)),
            )
          : _content(d),
    );
  }
 
  Widget _content(ProductDetail d) {
    final p = d.product;
    final inStock = p.stock > 0;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
              height: 280,
              width: double.infinity,
              child: ProductImage(url: p.fullImageUrl, fit: BoxFit.contain)),
        ),
        const SizedBox(height: 16),
        Text(p.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text('₹${p.price}',
            style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        StarDisplay(rating: p.avgRating, count: p.reviewCount),
        const SizedBox(height: 6),
        Text(inStock ? '${p.stock} in stock' : 'Out of stock',
            style: TextStyle(color: inStock ? Colors.green : Colors.red)),
        const SizedBox(height: 4),
        Text('${p.category}${p.material.isEmpty ? '' : '  •  ${p.material}'}'),
        const Divider(height: 32),
        if (d.displayLanguage != 'English')
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Chip(label: Text('Shown in ${d.displayLanguage}')),
          ),
        Text(d.displayDesc.isEmpty ? 'No description.' : d.displayDesc),
        const Divider(height: 32),
        Text('Sold by', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(d.seller.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        StarDisplay(
            rating: d.seller.ratingAverage, count: d.seller.ratingCount),
        if (d.seller.pinCode.isNotEmpty) Text('PIN code ${d.seller.pinCode}'),
        if (d.seller.latitude != null && d.seller.longitude != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                    'https://www.google.com/maps?q=${d.seller.latitude},${d.seller.longitude}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.location_on),
              label: const Text('See where this craft is made'),
            ),
          ),
        const Divider(height: 32),
        if (inStock) ...[
          Row(
            children: [
              const Text('Quantity'),
              const SizedBox(width: 12),
              IconButton.outlined(
                onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_qty', style: theme.textTheme.titleMedium),
              ),
              IconButton.outlined(
                onPressed:
                    _qty < p.stock ? () => setState(() => _qty++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.read<CartProvider>().add(p, _qty);
                    _toast('Added to your cart.');
                  },
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text('Add to cart'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                        items: [CartItem(p, _qty)], fromCart: false),
                  )),
                  icon: const Icon(Icons.flash_on),
                  label: const Text('Buy now'),
                ),
              ),
            ],
          ),
        ],
        const Divider(height: 32),
        Text('Reviews', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (d.reviews.isEmpty) const Text('No reviews yet.'),
        for (final r in d.reviews)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StarDisplay(rating: r.rating.toDouble()),
                  const SizedBox(height: 4),
                  Text(
                    r.isSellerInitial
                        ? "Seller's opening review (not counted in the rating)"
                        : (r.reviewerName.isEmpty ? 'Buyer' : r.reviewerName),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  if (r.comment.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(r.comment),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}