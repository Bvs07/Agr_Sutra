int _int(dynamic v) => v is num ? v.toInt() : 0;
 
class LowStockItem {
  final String productId;
  final String name;
  final int stock;
  const LowStockItem(this.productId, this.name, this.stock);
}
 
class Analytics {
  final int totalEarnings;
  final int totalOrders;
  final int completedOrders;
  final int pendingAmount;
  final double ratingAverage;
  final int ratingCount;
  final List<MapEntry<String, int>> earningsByDate;
  final Map<String, int> statusBreakdown;
  final List<MapEntry<String, int>> topProducts; // label includes units sold
  final List<MapEntry<String, int>> revenueByCategory;
  final List<LowStockItem> lowStock;
 
  const Analytics({
    required this.totalEarnings,
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingAmount,
    required this.ratingAverage,
    required this.ratingCount,
    required this.earningsByDate,
    required this.statusBreakdown,
    required this.topProducts,
    required this.revenueByCategory,
    required this.lowStock,
  });
 
  factory Analytics.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] ?? {}) as Map;
    final rating = (j['store_rating'] ?? {}) as Map;
    final status = (j['status_breakdown'] ?? {}) as Map;
    return Analytics(
      totalEarnings: _int(totals['total_earnings']),
      totalOrders: _int(totals['total_orders']),
      completedOrders: _int(totals['completed_orders']),
      pendingAmount: _int(totals['pending_amount']),
      ratingAverage: rating['average'] is num ? (rating['average'] as num).toDouble() : 0,
      ratingCount: _int(rating['count']),
      earningsByDate: ((j['earnings_by_date'] ?? []) as List)
          .map((e) => MapEntry((e['date'] ?? '').toString(), _int(e['amount'])))
          .toList(),
      statusBreakdown:
          status.map((k, v) => MapEntry(k.toString(), _int(v))),
      topProducts: ((j['top_products'] ?? []) as List)
          .map((e) => MapEntry(
              '${e['product_name']} (${_int(e['units'])} sold)', _int(e['revenue'])))
          .toList(),
      revenueByCategory: ((j['revenue_by_category'] ?? []) as List)
          .map((e) => MapEntry((e['category'] ?? '').toString(), _int(e['revenue'])))
          .toList(),
      lowStock: ((j['low_stock'] ?? []) as List)
          .map((e) => LowStockItem((e['product_id'] ?? '').toString(),
              (e['product_name'] ?? '').toString(), _int(e['stock'])))
          .toList(),
    );
  }
}