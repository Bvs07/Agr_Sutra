import 'dart:typed_data';
 
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
 
import '../core/api_client.dart';
import '../models/product.dart';
 
class TranscribeResult {
  final String transcript;
  final String language;
  TranscribeResult(this.transcript, this.language);
}
 
class CatalogCopy {
  final String name;
  final String english;
  final String hindi;
  final String material;
  final bool usedAi;
  CatalogCopy(this.name, this.english, this.hindi, this.material, this.usedAi);
}
 
/// All product-related calls to the backend.
class ProductService {
  final ApiClient api;
  ProductService(this.api);
 
  Future<Uint8List> removeBackground(Uint8List photo) =>
      api.postMultipartForBytes('/ai/remove-background', files: [
        http.MultipartFile.fromBytes('image', photo, filename: 'photo.jpg'),
      ]);
 
  Future<TranscribeResult> transcribe(Uint8List wav, String languageLabel) async {
    final res = await api.postMultipart(
      '/ai/transcribe',
      fields: {'language': languageLabel},
      files: [
        http.MultipartFile.fromBytes('audio', wav,
            filename: 'voice.wav', contentType: MediaType('audio', 'wav')),
      ],
    );
    final transcript = res['transcript']?.toString();
    if (transcript == null || transcript.trim().isEmpty) {
      throw ApiException(
          (res['error'] ?? 'Could not understand the recording.').toString());
    }
    return TranscribeResult(transcript, (res['language'] ?? '').toString());
  }
 
  Future<CatalogCopy> catalogCopy({
    required String raw,
    required String category,
    required String material,
    required String sourceLanguage,
  }) async {
    final res = await api.post('/ai/catalog-copy', {
      'raw_text': raw,
      'category': category,
      'material': material,
      'source_language': sourceLanguage,
    });
    return CatalogCopy(
      (res['product_name'] ?? '').toString(),
      (res['english_desc'] ?? '').toString(),
      (res['hindi_desc'] ?? '').toString(),
      (res['material'] ?? '').toString(),
      res['used_ai'] == true,
    );
  }
 
  Future<int> suggestPrice({
    required String category,
    required String size,
    required double rawCost,
    required double laborCost,
  }) async {
    final res = await api.post('/ai/suggest-price', {
      'category': category,
      'size': size,
      'raw_cost': rawCost,
      'labor_cost': laborCost,
    });
    return ((res['suggested_price'] ?? 0) as num).toInt();
  }
 
  Future<String> createProduct({
    required Uint8List image,
    required String name,
    required String category,
    required String material,
    required int price,
    required int stock,
    required String englishDesc,
    required String hindiDesc,
    required String language,
  }) async {
    final res = await api.postMultipart(
      '/products',
      fields: {
        'product_name': name,
        'category': category,
        'material': material,
        'price': price.toString(),
        'stock': stock.toString(),
        'english_desc': englishDesc,
        'hindi_desc': hindiDesc,
        'language': language,
      },
      files: [
        http.MultipartFile.fromBytes('image', image, filename: 'product.png'),
      ],
    );
    return (res['product_id'] ?? '').toString();
  }
 
  Future<List<Product>> myProducts() async {
    final res = await api.get('/products?mine=true');
    return (res as List)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();
  }
 
  Future<void> updateProduct(String id, {String? status, int? stock}) async {
    await api.put('/products/$id', {
      if (status != null) 'status': status,
      if (stock != null) 'stock': stock,
    });
  }
}