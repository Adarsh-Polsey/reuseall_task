
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
class JobRouteScreen extends StatefulWidget {
  const JobRouteScreen({super.key});
  
  @override
  State<JobRouteScreen> createState() => _JobRouteScreenState();
}

class _JobRouteScreenState extends State<JobRouteScreen> {
  late GoogleMapController mapController;
  LatLng? currentLocation;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
static const List<LatLng> pickupLocations = [
  LatLng(12.971598, 77.594566),
  LatLng(12.972819, 77.595212),
  LatLng(12.963842, 77.609043),
];

static const LatLng warehouseLocation = LatLng(12.961115, 77.600000);
  @override
  void initState() {
    super.initState();
    _initLocationAndMap();
  }

  Future<void> _initLocationAndMap() async {
    try {
      log("Requesting location permissions...");
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        log("Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        log("Location permission denied.");
        return;
      }

      log("Fetching current position...");
      Position position = await Geolocator.getCurrentPosition();
      currentLocation = LatLng(position.latitude, position.longitude);
      log("Current location: $currentLocation");

      markers.add(
        Marker(markerId: MarkerId("rider"), position: currentLocation!),
      );
      for (int i = 0; i < pickupLocations.length; i++) {
        markers.add(
          Marker(markerId: MarkerId("pickup$i"), position: pickupLocations[i]),
        );
      }
      markers.add(
        Marker(markerId: MarkerId("warehouse"), position: warehouseLocation),
      );

      await _drawRoute();

      setState(() {});
    } catch (e) {
      log("Error during location/map setup: $e");
    }
  }

  Future<void> _drawRoute() async {
    try {
      log("Requesting polyline from Directions API...");
      final PolylinePoints polylinePoints = PolylinePoints();
      final PolylineResult polyline = await polylinePoints
          .getRouteBetweenCoordinates(
            request: PolylineRequest(
              origin: PointLatLng(
                currentLocation!.latitude,
                currentLocation!.longitude,
              ),
              destination: PointLatLng(
                warehouseLocation.latitude,
                warehouseLocation.longitude,
              ),
              mode: TravelMode.driving,
              wayPoints:
                  pickupLocations
                      .map(
                        (e) => PolylineWayPoint(
                          location: '${e.latitude},${e.longitude}',
                        ),
                      )
                      .toList(),
            ),
            googleApiKey: 'AIzaSyDG7mXB-JgXTRrp8FIxg4myC4Kd6BVBORE',
          );

      if (polyline.status == 'OK' && polyline.points.isNotEmpty) {
        List<LatLng> routeCoords =
            polyline.points
                .map((e) => LatLng(e.latitude, e.longitude))
                .toList();

        log("Polyline fetched with ${routeCoords.length} points.");

        polylines.add(
          Polyline(
            polylineId: PolylineId("route"),
            color: Colors.blue,
            width: 5,
            points: routeCoords,
          ),
        );
        setState(() {});
      } else {
        log("Failed to fetch polyline: ${polyline.errorMessage}");
      }
    } catch (e) {
      log("Error while drawing route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          currentLocation == null
              ? Center(child: CircularProgressIndicator())
              : Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) => mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: currentLocation!,
                      zoom: 14,
                    ),
                    markers: markers,
                    polylines: polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ElevatedButton(
                      onPressed: _launchGoogleMaps,
                      child: Text("Navigate"),
                    ),
                  ),
                ],
              ),
    );
  }

  void _launchGoogleMaps() async {
    if (currentLocation == null) {
      log("Cannot launch maps: current location is null.");
      return;
    }

    final origin = "${currentLocation!.latitude},${currentLocation!.longitude}";
    final destination =
        "${warehouseLocation.latitude},${warehouseLocation.longitude}";
    final waypoints = pickupLocations
        .map((e) => "${e.latitude},${e.longitude}")
        .join('|');

    final url = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&waypoints=$waypoints",
    );

    log("Launching Google Maps URL: $url");

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      log("Could not launch Google Maps.");
    }
  }
}
