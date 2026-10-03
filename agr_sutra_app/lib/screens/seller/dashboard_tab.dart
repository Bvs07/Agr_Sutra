import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../models/analytics.dart';
import '../../providers/auth_provider.dart';
import '../../services/seller_service.dart';
import '../../widgets/stars.dart';
import '../../widgets/stat_card.dart';
import '../profile_screen.dart';
 
class DashboardTab extends StatefulWidget {
  final int refreshKey;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenOrders;
  const DashboardTab({
    super.key,
    required this.refreshKey,
    required this.onAddProduct,
    required this.onOpenOrders,
  });
 
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}
 
class _DashboardTabState extends State<DashboardTab> {
  Analytics? _data;
  String? _error;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant DashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }
 
  Future<void> _load() async {
    try {
      final data =
          await SellerService(context.read<AuthProvider>().api).analytics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }
 
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final d = _data;
    final newOrders = d?.statusBreakdown['New'] ?? 0;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Welcome, ${user.fullName}!',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          if (d != null)
            StarDisplay(
                rating: d.ratingAverage, count: d.ratingCount, size: 18),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!),
          if (!user.hasLocation)
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: const Text('Share your location'),
                subtitle: const Text('Buyers can see where your craft is made.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
              ),
            ),
          if (d != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatCard(
                    icon: Icons.payments,
                    label: 'Total earned',
                    value: '₹${d.totalEarnings}'),
                StatCard(
                    icon: Icons.fiber_new,
                    label: 'New orders',
                    value: '$newOrders'),
                StatCard(
                    icon: Icons.receipt_long,
                    label: 'All orders',
                    value: '${d.totalOrders}'),
              ],
            ),
          const SizedBox(height: 16),
          if (newOrders > 0)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: ListTile(
                leading: const Icon(Icons.notifications_active),
                title: Text('You have $newOrders new order${newOrders == 1 ? '' : 's'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: widget.onOpenOrders,
              ),
            ),
          if (d != null && d.lowStock.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber, color: Colors.orange),
                title: Text('${d.lowStock.length} product(s) running low on stock'),
                subtitle: Text(d.lowStock.map((e) => e.name).take(3).join(', ')),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: widget.onAddProduct,
            icon: const Icon(Icons.add_a_photo),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Add a new product'),
            ),
          ),
        ],
      ),
    );
  }
}