import 'package:flutter/foundation.dart';
 
class AppConfig {
  /// Using a REAL phone on the same Wi-Fi as your PC?
  /// Put your PC's address here, for example: 'http://192.168.1.5:8000'
  /// (find it by running `ipconfig` and reading "IPv4 Address").
  /// Leave it empty for Chrome and the Android emulator.
  static const String baseUrlOverride = 'http://192.168.1.7:8000';
 
  static String get baseUrl {
    if (baseUrlOverride.isNotEmpty) return baseUrlOverride;
    if (kIsWeb) return 'http://localhost:8000'; // Chrome
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000'; // Android emulator -> your PC
    }
    return 'http://localhost:8000';
  }
}