import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
 
import '../../core/api_client.dart';
import '../../models/analytics.dart';
import '../../providers/auth_provider.dart';
import '../../services/seller_service.dart';
import '../../widgets/bar_list.dart';
import '../../widgets/stat_card.dart';
 
class EarningsScreen extends StatefulWidget {
  final int refreshKey;
  const EarningsScreen({super.key, required this.refreshKey});
 
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}
 
class _EarningsScreenState extends State<EarningsScreen> {
  Analytics? _data;
  DateTimeRange? _range;
  String? _error;
  bool _loading = true;
 
  @override
  void initState() {
    super.initState();
    _load();
  }
 
  @override
  void didUpdateWidget(covariant EarningsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) _load();
  }
 
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SellerService(context.read<AuthProvider>().api)
          .analytics(from: _range?.start, to: _range?.end);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _range,
    );
    if (picked == null) return;
    setState(() => _range = picked);
    await _load();
  }
 
  String _d(DateTime d) => d.toIso8601String().split('T').first;
 
  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    final d = _data;
    if (d == null) {
      return Center(
        child: _loading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Could not load.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
      );
    }
    final byDate = d.earningsByDate.length > 14
        ? d.earningsByDate.sublist(d.earningsByDate.length - 14)
        : d.earningsByDate;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null
                      ? 'All dates'
                      : '${_d(_range!.start)}  to  ${_d(_range!.end)}'),
                ),
              ),
              if (_range != null)
                IconButton(
                  tooltip: 'Clear dates',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() => _range = null);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatCard(
                  icon: Icons.payments,
                  label: 'Earned (completed orders)',
                  value: '₹${d.totalEarnings}'),
              StatCard(
                  icon: Icons.hourglass_bottom,
                  label: 'Pending (new + processing)',
                  value: '₹${d.pendingAmount}'),
              StatCard(
                  icon: Icons.receipt_long,
                  label: 'Total orders',
                  value: '${d.totalOrders}'),
              StatCard(
                  icon: Icons.check_circle,
                  label: 'Completed orders',
                  value: '${d.completedOrders}'),
            ],
          ),
          const SizedBox(height: 16),
          _section('Earnings over time', BarList(items: byDate, prefix: '₹')),
          _section(
              'Orders by status',
              BarList(
                  items: d.statusBreakdown.entries
                      .where((e) => e.value > 0)
                      .toList())),
          _section('Top products', BarList(items: d.topProducts, prefix: '₹')),
          _section('Revenue by category',
              BarList(items: d.revenueByCategory, prefix: '₹')),
          _section(
            'Low stock alerts',
            d.lowStock.isEmpty
                ? const Text('All your active products are well stocked.')
                : Column(
                    children: [
                      for (final p in d.lowStock)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.warning_amber,
                              color: Colors.orange),
                          title: Text(p.name),
                          trailing: Text('${p.stock} left'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}