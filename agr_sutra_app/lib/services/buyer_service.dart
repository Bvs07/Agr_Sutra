import '../core/api_client.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_detail.dart';
 
/// Marketplace, checkout, orders and reviews (buyer side).
class BuyerService {
  final ApiClient api;
  BuyerService(this.api);
 
  Future<List<Product>> marketplace({
    String search = '',
    String category = '',
    String sort = 'newest',
  }) async {
    final query = Uri(queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (category.isNotEmpty && category != 'All') 'category': category,
      'sort': sort,
    }).query;
    final res = await api.get('/products?$query');
    return (res as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }
 
  Future<ProductDetail> productDetail(String id) async {
    final res = await api.get('/products/$id');
    return ProductDetail.fromJson(res as Map<String, dynamic>);
  }
 
  /// items: list of {productId, quantity}. Returns the new order IDs.
  Future<List<String>> placeOrders({
    required List<MapEntry<String, int>> items,
    required String address,
    required String paymentMethod,
  }) async {
    final res = await api.post('/orders', {
      'items': items
          .map((e) => {'product_id': e.key, 'quantity': e.value})
          .toList(),
      'shipping_address': address,
      'payment_method': paymentMethod,
    });
    return ((res['order_ids'] ?? []) as List).map((e) => e.toString()).toList();
  }
 
  Future<List<AppOrder>> myOrders() async {
    final res = await api.get('/orders');
    return (res as List)
        .map((e) => AppOrder.fromJson(e as Map<String, dynamic>))
        .toList();
  }
 
  Future<void> setOrderStatus(String orderId, String status) async {
    await api.put('/orders/$orderId/status', {'status': status});
  }
 
  /// type: product | seller | buyer | seller_initial
  Future<void> submitReview({
    required String type,
    required int rating,
    required String comment,
    String? orderId,
    String? productId,
  }) async {
    await api.post('/reviews', {
      'review_type': type,
      'rating': rating,
      'comment': comment,
      if (orderId != null) 'order_id': orderId,
      if (productId != null) 'product_id': productId,
    });
  }
}