import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
 
import '../core/api_client.dart';
import '../models/app_user.dart';
 
/// Keeps track of who is logged in, and runs the login / sign-up steps.
class AuthProvider extends ChangeNotifier {
  final ApiClient api = ApiClient();
 
  AppUser? user;
  bool initializing = true;
 
  // Filled in during the login flow
  String pendingPhone = '';
  String pendingEmail = '';
  String? signupToken;
  String? demoOtp; // demo mode: the server returns the code so you can test
 
  /// Called once when the app starts: restores a saved login, if any.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('token');
    if (saved != null) {
      api.token = saved;
      try {
        user = AppUser.fromJson(await api.get('/users/me'));
      } on ApiException catch (e) {
        if (e.statusCode == 401) {
          api.token = null;
          await prefs.remove('token');
        }
      }
    }
    initializing = false;
    notifyListeners();
  }
 
  Future<void> sendOtp({String phone = '', String email = ''}) async {
    final res = await api.post('/auth/send-otp', {
      if (phone.isNotEmpty) 'phone': phone,
      if (email.isNotEmpty) 'email': email,
    });
    pendingPhone = (res['phone'] ?? '').toString();
    pendingEmail = (res['email'] ?? '').toString();
    demoOtp = res['demo_otp']?.toString();
    notifyListeners();
  }
 
  /// Returns true if this is a NEW user (they must finish the profile screen).
  Future<bool> verifyOtp(String otp) async {
    final res = await api.post('/auth/verify-otp', {
      if (pendingPhone.isNotEmpty) 'phone': pendingPhone,
      if (pendingEmail.isNotEmpty) 'email': pendingEmail,
      'otp': otp,
    });
    if (res['is_new_user'] == true) {
      signupToken = res['signup_token'].toString();
      return true;
    }
    await _saveSession(res['access_token'].toString(), res['user']);
    return false;
  }
 
  Future<void> register({
    required String fullName,
    required String phone,
    required String email,
    required String pinCode,
    required String language,
    required String role,
  }) async {
    final res = await api.post('/auth/register', {
      'signup_token': signupToken,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'pin_code': pinCode,
      'language': language,
      'role': role,
    });
    await _saveSession(res['access_token'].toString(), res['user']);
  }
 
  Future<void> _saveSession(String token, dynamic userJson) async {
    api.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    user = AppUser.fromJson(userJson);
    signupToken = null;
    demoOtp = null;
    notifyListeners();
  }
 
  /// Saves profile changes (any field can be left out).
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? email,
    String? pinCode,
    String? language,
    double? latitude,
    double? longitude,
  }) async {
    final res = await api.put('/users/me', {
      if (fullName != null) 'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (pinCode != null) 'pin_code': pinCode,
      if (language != null) 'language': language,
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
    });
    user = AppUser.fromJson(res);
    notifyListeners();
  }
 
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    api.token = null;
    user = null;
    pendingPhone = '';
    pendingEmail = '';
    signupToken = null;
    notifyListeners();
  }
}