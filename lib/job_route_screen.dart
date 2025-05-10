import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reuse_task/maps_webview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

class JobRouteScreen extends StatefulWidget {
  const JobRouteScreen({super.key});

  @override
  State<JobRouteScreen> createState() => _JobRouteScreenState();
}

class _JobRouteScreenState extends State<JobRouteScreen> {
  late GoogleMapController mapController;
  LatLng? currentLocation;
  List<LatLng> pickupLocations = [];
  late LatLng warehouseLocation;
  final Set<Marker> markers = {};
  final Set<Polyline> polylines = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initLocationAndMap();
  }

  Future<void> initLocationAndMap() async {
    try {
      await checkLocationPermission();
      await getCurrentLocation();
      generateLocations();
      createMarkers();
      await createRoute();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      showErrorSnackBar("Error setting up map: $e");
    }
  }

  Future<void> checkLocationPermission() async {
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

  Future<void> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition();
    currentLocation = LatLng(position.latitude, position.longitude);
  }

  void generateLocations() {
    pickupLocations = List.generate(
      3,
      (_) => generateNearbyLocation(currentLocation!, 5),
    );
    warehouseLocation = generateNearbyLocation(currentLocation!, 5);
  }

  LatLng generateNearbyLocation(LatLng center, double radiusInKm) {
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

  void createMarkers() {
    // Current location marker
    markers.add(
      Marker(
        markerId: const MarkerId("rider"),
        position: currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Warehouse"),
      ),
    );
  }

  Future<void> createRoute() async {
    // Create route connecting all points
    final List<LatLng> routePoints = [
      currentLocation!,
      ...pickupLocations,
      warehouseLocation,
    ];

    polylines.add(
      Polyline(
        polylineId: const PolylineId("deliveryroute"),
        color: Colors.blue,
        width: 5,
        points: routePoints,
      ),
    );
  }

  void navigateToGoogleMaps() async {
    if (currentLocation == null) return;

    final origin = "${currentLocation!.latitude},${currentLocation!.longitude}";
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
        showErrorSnackBar("Could not launch Google Maps");
      }
    } catch (e) {
      showErrorSnackBar("Navigation error: $e");
    }
  }

  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
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
                    zoomControlsEnabled: false,
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: buildNavigationButton(),
                  ),
                ],
              ),
    );
  }

  Widget buildNavigationButton() {
    return ElevatedButton(
      onPressed: navigateToGoogleMaps,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions),
          SizedBox(width: 8),
          Text(
            "Start Navigation",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
