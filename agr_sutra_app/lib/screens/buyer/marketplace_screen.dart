import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../widgets/product_image.dart';
import '../../widgets/stars.dart';
import 'product_detail_screen.dart';
 
class MarketplaceScreen extends StatefulWidget {
  /// Changing this number makes the list reload.
  final int refreshKey;
  const MarketplaceScreen({super.key, required this.refreshKey});
 
  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}
 
class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const _sortOptions = {
    'Newest': 'newest',
    'Price: low to high': 'price_low',
    'Price: high to low': 'price_high',
    'Top rated': 'rating',
  };
 
  final _search = TextEditingController();
  String _category = 'All';
  String _sortLabel = 'Newest';
  List<Product> _items = [];
  String? _error;
  bool _loading = true;
 
  BuyerService get _service => BuyerService(context.read<AuthProvider>().api);
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant MarketplaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }
 
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
 
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.marketplace(
        search: _search.text.trim(),
        category: _category,
        sort: _sortOptions[_sortLabel]!,
      );
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
 
  Widget _card(Product p) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProductDetailScreen(productId: p.productId)));
          if (mounted) _load(); // stock may have changed
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                  width: double.infinity,
                  child: ProductImage(url: p.fullImageUrl)),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('₹${p.price}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  StarDisplay(rating: p.avgRating, count: p.reviewCount, size: 14),
                  const SizedBox(height: 2),
                  Text(p.stock > 0 ? 'by ${p.sellerName}' : 'Out of stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: p.stock > 0 ? null : Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            children: [
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _load(),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: 'Search crafts, materials...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _search.clear();
                      _load();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Category',
                          isDense: true),
                      items: ['All', ...kCategories]
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _category = v ?? 'All');
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _sortLabel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Sort by',
                          isDense: true),
                      items: _sortOptions.keys
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        setState(() => _sortLabel = v ?? 'Newest');
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(child: _body()),
      ],
    );
  }
 
  Widget _body() {
    if (_loading && _items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const Center(child: Text('No products found.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          childAspectRatio: 0.66,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _items.length,
        itemBuilder: (_, i) => _card(_items[i]),
      ),
    );
  }
}