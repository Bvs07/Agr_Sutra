import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../services/buyer_service.dart';
import '../../widgets/product_image.dart';
import '../../widgets/review_dialog.dart';
import '../../widgets/status_chip.dart';
 
/// Incoming orders for the seller. (Uses the same /orders call as buyers;
/// the server returns the right orders for the logged-in role.)
class SellerOrdersScreen extends StatefulWidget {
  final int refreshKey;
  const SellerOrdersScreen({super.key, required this.refreshKey});
 
  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}
 
class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const _filters = ['All', 'New', 'Processing', 'Completed', 'Cancelled'];
  List<AppOrder> _orders = [];
  String _filter = 'All';
  String? _error;
  bool _loading = true;
 
  BuyerService get _service => BuyerService(context.read<AuthProvider>().api);
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant SellerOrdersScreen oldWidget) {
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
 
  Future<void> _setStatus(AppOrder o, String status) async {
    if (status == 'Cancelled') {
      final sure = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text('The stock will be returned to your listing.'),
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
    }
    try {
      await _service.setOrderStatus(o.orderId, status);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  Future<void> _rateBuyer(AppOrder o) async {
    final input = await showReviewDialog(context, 'Rate buyer (${o.buyerName})');
    if (input == null) return;
    try {
      await _service.submitReview(
        type: 'buyer',
        rating: input.rating,
        comment: input.comment,
        orderId: o.orderId,
      );
      _toast('Buyer rated.');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }
 
  Widget _card(AppOrder o) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${o.quantity} x  •  ₹${o.totalAmount}'),
                      Text('Buyer: ${o.buyerName}',
                          style: const TextStyle(fontSize: 12)),
                      Text('${o.date}  •  ${o.paymentMethod}',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                StatusChip(status: o.status),
              ],
            ),
            const SizedBox(height: 8),
            Text('Deliver to: ${o.shippingAddress}',
                style: const TextStyle(fontSize: 12)),
            if (o.status == 'New' ||
                o.status == 'Processing' ||
                (o.status == 'Completed' && !o.buyerReviewed))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (o.status == 'New')
                      FilledButton(
                          onPressed: () => _setStatus(o, 'Processing'),
                          child: const Text('Start processing')),
                    if (o.status == 'Processing')
                      FilledButton(
                          onPressed: () => _setStatus(o, 'Completed'),
                          child: const Text('Mark completed')),
                    if (o.status == 'New' || o.status == 'Processing')
                      OutlinedButton(
                          onPressed: () => _setStatus(o, 'Cancelled'),
                          child: const Text('Cancel')),
                    if (o.status == 'Completed' && !o.buyerReviewed)
                      FilledButton.tonal(
                          onPressed: () => _rateBuyer(o),
                          child: const Text('Rate buyer')),
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
    final shown = _filter == 'All'
        ? _orders
        : _orders.where((o) => o.status == _filter).toList();
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _body(shown)),
      ],
    );
  }
 
  Widget _body(List<AppOrder> shown) {
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
    if (shown.isEmpty) {
      return const Center(child: Text('No orders here yet.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: shown.length,
        itemBuilder: (_, i) => _card(shown[i]),
      ),
    );
  }
}