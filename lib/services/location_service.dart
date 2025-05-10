
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {

  static Future<LatLng> getCurrentLocation() async {
    await _checkLocationPermission();
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  }

  static Future<void> _checkLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled");
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Location permissions permanently denied");
    }
  }
  
  static LatLng generateNearbyLocation(LatLng center, double radiusInKm) {
    final random = Random();
    final u = random.nextDouble();
    final v = random.nextDouble();
    final w = radiusInKm / 111.0 * sqrt(u);
    final t = 2 * pi * v;
    final x = w * cos(t);
    final y = w * sin(t);
    final newLat = center.latitude + x;
    final newLng = center.longitude + y / cos(center.latitude * pi / 180);
    return LatLng(newLat, newLng);
  }
}
