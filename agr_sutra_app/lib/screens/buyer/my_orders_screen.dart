import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../widgets/product_image.dart';
import '../../widgets/review_dialog.dart';
import '../../widgets/status_chip.dart';
 
class MyOrdersScreen extends StatefulWidget {
  final int refreshKey;
  const MyOrdersScreen({super.key, required this.refreshKey});
 
  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}
 
class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<AppOrder> _orders = [];
  String? _error;
  bool _loading = true;
 
  BuyerService get _service => BuyerService(context.read<AuthProvider>().api);
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant MyOrdersScreen oldWidget) {
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
      final orders = await _service.myOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<void> _cancel(AppOrder o) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, cancel')),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _service.setOrderStatus(o.orderId, 'Cancelled');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  Future<void> _rate(AppOrder o, String type) async {
    final title = type == 'product'
        ? 'Rate "${o.productName}"'
        : 'Rate the seller (${o.sellerName})';
    final input = await showReviewDialog(context, title);
    if (input == null) return;
    try {
      await _service.submitReview(
        type: type,
        rating: input.rating,
        comment: input.comment,
        orderId: o.orderId,
      );
      _toast('Thank you for your review!');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    if (_loading && _orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _orders.isEmpty) {
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
    if (_orders.isEmpty) {
      return const Center(child: Text('You have not placed any orders yet.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (_, i) {
          final o = _orders[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                            width: 64,
                            height: 64,
                            child: ProductImage(url: o.fullImageUrl)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.productName,
                                style:
                                    const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${o.quantity} x  •  ₹${o.totalAmount}'),
                            Text('Seller: ${o.sellerName}',
                                style: const TextStyle(fontSize: 12)),
                            Text('${o.date}  •  ${o.paymentMethod}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      StatusChip(status: o.status),
                    ],
                  ),
                  if (o.status == 'New' ||
                      (o.status == 'Completed' &&
                          (!o.productReviewed || !o.sellerReviewed)))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          if (o.status == 'New')
                            OutlinedButton(
                                onPressed: () => _cancel(o),
                                child: const Text('Cancel order')),
                          if (o.status == 'Completed' && !o.productReviewed)
                            FilledButton.tonal(
                                onPressed: () => _rate(o, 'product'),
                                child: const Text('Rate product')),
                          if (o.status == 'Completed' && !o.sellerReviewed)
                            FilledButton.tonal(
                                onPressed: () => _rate(o, 'seller'),
                                child: const Text('Rate seller')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}