import '../core/config.dart';
 
class AppOrder {
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final int totalAmount;
  final String status;
  final String createdAt;
  final String shippingAddress;
  final String paymentMethod;
  final String buyerName;
  final String sellerName;
  final String? imageUrl;
  final bool productReviewed; // buyer view
  final bool sellerReviewed; // buyer view
  final bool buyerReviewed; // seller view
 
  const AppOrder({
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.shippingAddress,
    required this.paymentMethod,
    required this.buyerName,
    required this.sellerName,
    required this.imageUrl,
    required this.productReviewed,
    required this.sellerReviewed,
    required this.buyerReviewed,
  });
 
  String get date => createdAt.split('T').first;
  String? get fullImageUrl =>
      imageUrl == null ? null : '${AppConfig.baseUrl}$imageUrl';
 
  factory AppOrder.fromJson(Map<String, dynamic> j) => AppOrder(
        orderId: (j['order_id'] ?? '').toString(),
        productId: (j['product_id'] ?? '').toString(),
        productName: (j['product_name'] ?? '').toString(),
        quantity: ((j['quantity'] ?? 0) as num).toInt(),
        totalAmount: ((j['total_amount'] ?? 0) as num).toInt(),
        status: (j['status'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        shippingAddress: (j['shipping_address'] ?? '').toString(),
        paymentMethod: (j['payment_method'] ?? '').toString(),
        buyerName: (j['buyer_name'] ?? '').toString(),
        sellerName: (j['seller_name'] ?? '').toString(),
        imageUrl: j['image_url']?.toString(),
        productReviewed: j['product_reviewed'] == true,
        sellerReviewed: j['seller_reviewed'] == true,
        buyerReviewed: j['buyer_reviewed'] == true,
      );
}