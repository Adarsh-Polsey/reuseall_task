import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reuse_task/screens/maps_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class MapService {
  static const String darkMapStyle = '[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]';
  static const String lightMapStyle = '[]';

  static Set<Marker> createMarkers({
    required LatLng currentLocation,
    required List<LatLng> pickupLocations,
    required LatLng warehouseLocation,
  }) {
    final Set<Marker> markers = {};
    
    // Current location marker
    markers.add(
      Marker(
        markerId: const MarkerId("rider"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: currentLocation,
        infoWindow: const InfoWindow(title: "Your Location"),
      ),
    );

    // Pickup location markers
    for (int i = 0; i < pickupLocations.length; i++) {
      markers.add(
        Marker(
          markerId: MarkerId("pickup$i"),
          position: pickupLocations[i],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(title: "Pickup ${i + 1}"),
        ),
      );
    }

    // Warehouse marker
    markers.add(
      Marker(
        markerId: const MarkerId("warehouse"),
        position: warehouseLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Warehouse"),
      ),
    );
    
    return markers;
  }
  
  static Set<Polyline> createRoute({
    required LatLng currentLocation,
    required List<LatLng> pickupLocations,
    required LatLng warehouseLocation,
    required Color color,
  }) {
    final Set<Polyline> polylines = {};
    
    final List<LatLng> routePoints = [
      currentLocation,
      ...pickupLocations,
      warehouseLocation,
    ];

    polylines.add(
      Polyline(
        polylineId: const PolylineId("deliveryroute"),
        color: color,
        width: 6,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        points: routePoints,
      ),
    );
    
    return polylines;
  }
  
  static Future<void> navigateToGoogleMaps({
    required BuildContext context,
    required LatLng currentLocation,
    required List<LatLng> pickupLocations,
    required LatLng warehouseLocation,
    required Function(String) onError,
  }) async {
    final origin = "${currentLocation.latitude},${currentLocation.longitude}";
    final destination =
        "${warehouseLocation.latitude},${warehouseLocation.longitude}";
    final waypoints = pickupLocations
        .map((e) => "${e.latitude},${e.longitude}")
        .join('|');

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints",
    );

    try {
      if (await canLaunchUrl(url)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapsWebview(url: url.toString()),
          ),
        );
      } else {
        onError("Could not launch Google Maps");
      }
    } catch (e) {
      onError("Navigation error: $e");
    }
  }
}
