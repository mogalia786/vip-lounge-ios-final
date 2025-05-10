import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AttendanceLocationService {
  static const String businessSettingsPath = 'business/settings';

  /// Fetches the business address (lat/lng) from Firestore.
  static Future<LatLng?> fetchBusinessLocation() async {
    final doc = await FirebaseFirestore.instance.doc(businessSettingsPath).get();
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null || !data.containsKey('latitude') || !data.containsKey('longitude')) return null;
    return LatLng(data['latitude'], data['longitude']);
  }

  /// Calculates the distance in meters between two coordinates using the Haversine formula.
  static double calculateDistanceMeters(LatLng start, LatLng end) {
    const earthRadius = 6371000.0; // meters
    double dLat = _deg2rad(end.latitude - start.latitude);
    double dLng = _deg2rad(end.longitude - start.longitude);
    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(start.latitude)) * cos(_deg2rad(end.latitude)) *
            sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Checks if the user is within the allowed distance from the business location.
  static Future<bool> isWithinAllowedDistance({
    required LatLng userLocation,
    double allowedDistanceMeters = 100.0, // Default 100m radius
  }) async {
    final businessLocation = await fetchBusinessLocation();
    if (businessLocation == null) return false;
    final distance = calculateDistanceMeters(userLocation, businessLocation);
    return distance <= allowedDistanceMeters;
  }
}
