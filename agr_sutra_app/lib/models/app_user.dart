class AppUser {
  final String userId;
  final String fullName;
  final String phone;
  final String email;
  final String pinCode;
  final String language;
  final String role;
  final double? latitude;
  final double? longitude;
  final double ratingAverage;
  final int ratingCount;
 
  const AppUser({
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.pinCode,
    required this.language,
    required this.role,
    this.latitude,
    this.longitude,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });
 
  bool get isSeller => role == 'Seller';
  bool get hasLocation => latitude != null && longitude != null;
 
  factory AppUser.fromJson(Map<String, dynamic> j) {
    final rating = j['rating'];
    return AppUser(
      userId: (j['user_id'] ?? '').toString(),
      fullName: (j['full_name'] ?? '').toString(),
      phone: (j['phone'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      pinCode: (j['pin_code'] ?? '').toString(),
      language: (j['language'] ?? 'English').toString(),
      role: (j['role'] ?? 'Buyer').toString(),
      latitude: j['latitude'] is num ? (j['latitude'] as num).toDouble() : null,
      longitude:
          j['longitude'] is num ? (j['longitude'] as num).toDouble() : null,
      ratingAverage:
          rating is Map ? ((rating['average'] ?? 0) as num).toDouble() : 0,
      ratingCount: rating is Map ? ((rating['count'] ?? 0) as num).toInt() : 0,
    );
  }
}