import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class DeviceLocationService {
  /// Gets the user's current device location using Google Maps API (not geolocator).
  static Future<LatLng?> getCurrentUserLocation(BuildContext context) async {
    final status = await Permission.location.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission is required for attendance.')),
      );
      return null;
    }
    try {
      const platform = MethodChannel('com.yourcompany.vip/location');
      final result = await platform.invokeMethod<Map>('getCurrentLocation');
      if (result != null && result['latitude'] != null && result['longitude'] != null) {
        return LatLng(result['latitude'], result['longitude']);
      }
      return null;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching location: $e')),
      );
      return null;
    }
  }
}
