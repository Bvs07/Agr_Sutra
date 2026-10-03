import 'product.dart';
 
class ReviewItem {
  final String reviewerName;
  final int rating;
  final String comment;
  final String createdAt;
  final bool isSellerInitial;
 
  const ReviewItem({
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.isSellerInitial,
  });
 
  factory ReviewItem.fromJson(Map<String, dynamic> j) => ReviewItem(
        reviewerName: (j['reviewer_name'] ?? '').toString(),
        rating: ((j['rating'] ?? 0) as num).toInt(),
        comment: (j['comment'] ?? '').toString(),
        createdAt: (j['created_at'] ?? '').toString(),
        isSellerInitial: j['is_seller_initial'] == true,
      );
}
 
class SellerInfo {
  final String name;
  final String pinCode;
  final double? latitude;
  final double? longitude;
  final double ratingAverage;
  final int ratingCount;
 
  const SellerInfo({
    required this.name,
    required this.pinCode,
    required this.latitude,
    required this.longitude,
    required this.ratingAverage,
    required this.ratingCount,
  });
 
  factory SellerInfo.fromJson(Map<String, dynamic> j) {
    final rating = j['rating'];
    return SellerInfo(
      name: (j['full_name'] ?? '').toString(),
      pinCode: (j['pin_code'] ?? '').toString(),
      latitude: j['latitude'] is num ? (j['latitude'] as num).toDouble() : null,
      longitude:
          j['longitude'] is num ? (j['longitude'] as num).toDouble() : null,
      ratingAverage:
          rating is Map ? ((rating['average'] ?? 0) as num).toDouble() : 0,
      ratingCount: rating is Map ? ((rating['count'] ?? 0) as num).toInt() : 0,
    );
  }
}
 
class ProductDetail {
  final Product product;
  final String displayDesc;
  final String displayLanguage;
  final SellerInfo seller;
  final List<ReviewItem> reviews;
 
  const ProductDetail({
    required this.product,
    required this.displayDesc,
    required this.displayLanguage,
    required this.seller,
    required this.reviews,
  });
 
  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        product: Product.fromJson(j['product'] as Map<String, dynamic>),
        displayDesc: (j['display_desc'] ?? '').toString(),
        displayLanguage: (j['display_language'] ?? 'English').toString(),
        seller: SellerInfo.fromJson(j['seller'] as Map<String, dynamic>),
        reviews: ((j['reviews'] ?? []) as List)
            .map((e) => ReviewItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}