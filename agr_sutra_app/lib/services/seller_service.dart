import '../core/api_client.dart';
import '../models/analytics.dart';
 
class SellerService {
  final ApiClient api;
  SellerService(this.api);
 
  String _date(DateTime d) => d.toIso8601String().split('T').first;
 
  Future<Analytics> analytics({DateTime? from, DateTime? to}) async {
    final query = Uri(queryParameters: {
      if (from != null) 'date_from': _date(from),
      if (to != null) 'date_to': _date(to),
    }).query;
    final res = await api
        .get('/sellers/me/analytics${query.isEmpty ? '' : '?$query'}');
    return Analytics.fromJson(res as Map<String, dynamic>);
  }
}