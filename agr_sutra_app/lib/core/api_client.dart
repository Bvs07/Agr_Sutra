import 'dart:convert';
import 'dart:typed_data';
 
import 'package:http/http.dart' as http;
 
import 'config.dart';
 
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
 
  @override
  String toString() => message;
}
 
/// Talks to the FastAPI backend. Holds the login token and attaches it to every call.
class ApiClient {
  String? token;
 
  Uri _uri(String path) => Uri.parse('${AppConfig.baseUrl}$path');
 
  Map<String, String> get _authHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};
 
  Map<String, String> get _jsonHeaders =>
      {'Content-Type': 'application/json', ..._authHeaders};
 
  Future<dynamic> get(String path) async => _decodeOrThrow(
      await _run(() => http.get(_uri(path), headers: _jsonHeaders)));
 
  Future<dynamic> post(String path, Map<String, dynamic> body) async =>
      _decodeOrThrow(await _run(() =>
          http.post(_uri(path), headers: _jsonHeaders, body: jsonEncode(body))));
 
  Future<dynamic> put(String path, Map<String, dynamic> body) async =>
      _decodeOrThrow(await _run(() =>
          http.put(_uri(path), headers: _jsonHeaders, body: jsonEncode(body))));
 
  /// Upload files + form fields (used for photos and voice). Returns JSON.
  Future<dynamic> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    required List<http.MultipartFile> files,
  }) async =>
      _decodeOrThrow(await _run(() => _multipart(path, fields, files),
          seconds: 180));
 
  /// Same, but the server answers with a file (the cleaned photo).
  Future<Uint8List> postMultipartForBytes(
    String path, {
    Map<String, String> fields = const {},
    required List<http.MultipartFile> files,
  }) async {
    final res = await _run(() => _multipart(path, fields, files), seconds: 180);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    _decodeOrThrow(res); // throws the server's error message
    throw ApiException('Unexpected response from the server.');
  }
 
  Future<http.Response> _multipart(String path, Map<String, String> fields,
      List<http.MultipartFile> files) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(_authHeaders);
    req.fields.addAll(fields);
    req.files.addAll(files);
    return http.Response.fromStream(await req.send());
  }
 
  Future<http.Response> _run(Future<http.Response> Function() request,
      {int seconds = 30}) async {
    try {
      return await request().timeout(Duration(seconds: seconds));
    } catch (_) {
      throw ApiException(
          'Cannot reach the server. Check that the backend is running and that the address in config.dart is correct.');
    }
  }
 
  dynamic _decodeOrThrow(http.Response res) {
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(_errorMessage(data, res.statusCode), res.statusCode);
  }
 
  String _errorMessage(dynamic data, int code) {
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        return (d.first['msg'] ?? 'Invalid input').toString();
      }
    }
    return 'Something went wrong (error $code).';
  }
}