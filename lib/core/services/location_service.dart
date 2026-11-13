import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Check if location services are enabled on the device.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  /// Request location permission if not already granted.
  /// Returns the resulting [LocationPermission] status.
  Future<LocationPermission> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission;
  }

  /// Returns true if the app has at least "while in use" location permission.
  Future<bool> hasPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  /// Get the current device position.
  /// Returns null if services are disabled, permission is denied, or any error occurs.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      final permission = await requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      // Never crash: return null for any GPS error.
      return null;
    }
  }

  /// Convenience: Returns latitude and longitude as a record, or null values.
  Future<({double? latitude, double? longitude})> getCoordinates() async {
    final position = await getCurrentPosition();
    return (latitude: position?.latitude, longitude: position?.longitude);
  }
}
