import 'package:geolocator/geolocator.dart';
 
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
 
  @override
  String toString() => message;
}
 
/// Asks for permission if needed and returns the phone's current position.
Future<Position> getCurrentPosition() async {
  final enabled = await Geolocator.isLocationServiceEnabled();
  if (!enabled) {
    throw LocationException(
        'Location is turned off. Please turn it on and try again.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw LocationException(
        'Location permission was denied. Please allow it in your settings.');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  );
}