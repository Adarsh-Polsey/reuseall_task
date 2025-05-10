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
  bool isMapStyleDark = false;

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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        position: currentLocation!,
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
        color: Theme.of(context).primaryColor.withValues(alpha: 0.8),
        width: 6,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        points: routePoints,
      ),
    );
  }

  void toggleMapStyle() async {
    isMapStyleDark = !isMapStyleDark;
    setState(() {});
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(15, 5, 15, 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: !isMapStyleDark ? Colors.black45 : Colors.white70,
              ),
              child: IconButton(
                icon: Icon(
                  isMapStyleDark ? Icons.light_mode : Icons.dark_mode,
                  color: isMapStyleDark ? Colors.black45 : Colors.white70,
                ),
                onPressed: toggleMapStyle,
                tooltip: isMapStyleDark ? 'Light mode' : 'Dark mode',
              ),
            ),
          ],
        ),
        body:
            isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text('Loading your route...'),
                    ],
                  ),
                )
                : Stack(
                  children: [
                    GoogleMap(
                      style:
                          isMapStyleDark
                              ? '[{"elementType":"geometry","stylers":[{"color":"#242f3e"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#746855"}]},{"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},{"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#263c3f"}]},{"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#6b9a76"}]},{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414e"}]},{"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#212a37"}]},{"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#9ca5b3"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},{"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#1f2835"}]},{"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f3d19c"}]},{"featureType":"transit","elementType":"geometry","stylers":[{"color":"#2f3948"}]},{"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#d59563"}]},{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},{"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#515c6d"}]},{"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}]'
                              : '[]',
                      onMapCreated: (controller) {
                        mapController = controller;
                        if (isMapStyleDark) {
                          toggleMapStyle();
                        }
                      },
                      initialCameraPosition: CameraPosition(
                        target: currentLocation!,
                        zoom: 14,
                      ),
                      markers: markers,
                      polylines: polylines,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                    ),
                    Positioned(
                      top: 100,
                      right: 16,
                      child: FloatingActionButton(
                        backgroundColor:
                            !isMapStyleDark ? Colors.black45 : Colors.white70,
                        onPressed: () {
                          mapController.animateCamera(
                            CameraUpdate.newLatLng(currentLocation!),
                          );
                        },
                        child: Icon(
                          Icons.my_location,
                          size: 20,
                          color:
                              isMapStyleDark ? Colors.black45 : Colors.white60,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      left: 24,
                      right: 24,
                      child: buildNavigationCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15.0),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          onTap: navigateToGoogleMaps,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color:
                                  !isMapStyleDark
                                      ? Colors.black.withAlpha(150)
                                      : Colors.white70,
                              shape: BoxShape.rectangle,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 5,
                                  children: [
                                    Icon(Icons.location_on, color: Colors.red),
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.yellow,
                                    ),
                                    Icon(
                                      Icons.location_on,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  spacing: 10,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "Origin",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isMapStyleDark
                                                ? Colors.black54
                                                : Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      "Pickup points",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isMapStyleDark
                                                ? Colors.black54
                                                : Colors.white70,
                                      ),
                                    ),
                                    Text(
                                      "Destination",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color:
                                            isMapStyleDark
                                                ? Colors.black54
                                                : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget buildNavigationCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Align(
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: navigateToGoogleMaps,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: !isMapStyleDark ? Colors.black54 : Colors.white60,
              shape: BoxShape.rectangle,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.navigation,
                  size: 25,
                  color: isMapStyleDark ? Colors.black87 : Colors.white70,
                ),
                Text(
                  "Start navigation",
                  style: TextStyle(
                    fontSize: 16,
                    color: isMapStyleDark ? Colors.black87 : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
