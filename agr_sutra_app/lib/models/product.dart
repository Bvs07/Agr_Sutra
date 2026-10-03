import '../core/config.dart';
 
class Product {
  final String productId;
  final String sellerId;
  final String sellerName;
  final String name;
  final String category;
  final String material;
  final int price;
  final int stock;
  final String englishDesc;
  final String hindiDesc;
  final String? imageUrl;
  final String status;
  final double avgRating;
  final int reviewCount;
 
  const Product({
    required this.productId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.category,
    required this.material,
    required this.price,
    required this.stock,
    required this.englishDesc,
    required this.hindiDesc,
    required this.imageUrl,
    required this.status,
    required this.avgRating,
    required this.reviewCount,
  });
 
  bool get isActive => status == 'Active';
 
  /// Full web address of the product photo (or null if it has none).
  String? get fullImageUrl =>
      imageUrl == null ? null : '${AppConfig.baseUrl}$imageUrl';
 
  factory Product.fromJson(Map<String, dynamic> j) => Product(
        productId: (j['product_id'] ?? '').toString(),
        sellerId: (j['seller_id'] ?? '').toString(),
        sellerName: (j['seller_name'] ?? '').toString(),
        name: (j['product_name'] ?? '').toString(),
        category: (j['category'] ?? '').toString(),
        material: (j['material'] ?? '').toString(),
        price: ((j['price'] ?? 0) as num).toInt(),
        stock: ((j['stock'] ?? 0) as num).toInt(),
        englishDesc: (j['english_desc'] ?? '').toString(),
        hindiDesc: (j['hindi_desc'] ?? '').toString(),
        imageUrl: j['image_url']?.toString(),
        status: (j['status'] ?? 'Active').toString(),
        avgRating: ((j['avg_rating'] ?? 0) as num).toDouble(),
        reviewCount: ((j['review_count'] ?? 0) as num).toInt(),
      );
}