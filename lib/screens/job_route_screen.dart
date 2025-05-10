import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reuse_task/services/location_service.dart';
import 'package:reuse_task/services/map_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool isLoading = true;
  bool isMapStyleDark = false;
  String? routeDistance;
  String? routeDuration;
  bool isRouteInfoLoading = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      currentLocation = await LocationService.getCurrentLocation();
      _generateLocations();
      _setupMap();
      _fetchRouteInfo();
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      _showErrorSnackBar("Error setting up map: $e");
    }
  }

  Future<void> _fetchRouteInfo() async {
    try {
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/driving-car',
      );
      final headers = {
        'Authorization': dotenv.env['OPEN_MAP_API']!,
        'Content-Type': 'application/json',
      };

      final List<List<double>> coordinates = [
        [currentLocation!.longitude, currentLocation!.latitude],
        [warehouseLocation.longitude, warehouseLocation.latitude],
      ];

      final body = jsonEncode({'coordinates': coordinates});

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final summary = data['routes'][0]['summary'];

        setState(() {
          routeDistance =
              (summary['distance'] / 1000).toStringAsFixed(1) + ' km';
          routeDuration =
              (summary['duration'] / 60).toStringAsFixed(0) + ' min';
          isRouteInfoLoading = false;
        });
      } else {
        setState(() {
          isRouteInfoLoading = false;
        });
        _showErrorSnackBar("Error fetching route info: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isRouteInfoLoading = false;
      });
      _showErrorSnackBar("Error fetching route info: $e");
    }
  }

  void _generateLocations() {
    pickupLocations = List.generate(
      3,
      (_) => LocationService.generateNearbyLocation(currentLocation!, 5),
    );

    warehouseLocation = LocationService.generateNearbyLocation(
      currentLocation!,
      5,
    );
  }

  void _setupMap() {
    markers = MapService.createMarkers(
      currentLocation: currentLocation!,
      pickupLocations: pickupLocations,
      warehouseLocation: warehouseLocation,
    );

    polylines = MapService.createRoute(
      currentLocation: currentLocation!,
      pickupLocations: pickupLocations,
      warehouseLocation: warehouseLocation,
      color: Theme.of(
        context,
      ).primaryColor.withAlpha(204), 
    );
  }

  void _toggleMapStyle() {
    setState(() {
      isMapStyleDark = !isMapStyleDark;
    });
  }

  void _navigateToGoogleMaps() {
    if (currentLocation == null) return;

    MapService.navigateToGoogleMaps(
      context: context,
      currentLocation: currentLocation!,
      pickupLocations: pickupLocations,
      warehouseLocation: warehouseLocation,
      onError: _showErrorSnackBar,
    );
  }

  void _showErrorSnackBar(String message) {
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
        body: isLoading ? _buildLoadingView() : _buildMapView(),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Positioned(
      top: 10,
      left: 10,
      child: Container(
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
          onPressed: _toggleMapStyle,
          tooltip: isMapStyleDark ? 'Light mode' : 'Dark mode',
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Loading your route...'),
        ],
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          style:
              isMapStyleDark
                  ? MapService.darkMapStyle
                  : MapService.lightMapStyle,
          onMapCreated: (controller) {
            mapController = controller;
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
        _buildThemeToggle(),
        _buildMyLocationButton(),
        _buildRouteInfo(),
        _buildRouteDetails(),
        _buildNavigationButton(),
      ],
    );
  }

  Widget _buildMyLocationButton() {
    return Positioned(
      top: 70,
      left: 10,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: !isMapStyleDark ? Colors.black45 : Colors.white70,
        ),
        child: IconButton(
          onPressed: () {
            mapController.animateCamera(
              CameraUpdate.newLatLng(currentLocation!),
            );
          },
          icon: Icon(
            Icons.my_location,
            size: 20,
            color: isMapStyleDark ? Colors.black45 : Colors.white60,
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return Positioned(
      top: 10,
      left: 80,
      child: GestureDetector(
        onTap: _navigateToGoogleMaps,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                !isMapStyleDark ? Colors.black.withAlpha(150) : Colors.white70,
            shape: BoxShape.rectangle,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  SizedBox(height: 5),
                  Icon(Icons.location_on, color: Colors.red),
                  SizedBox(height: 5),
                  Icon(Icons.location_on, color: Colors.yellow),
                  SizedBox(height: 5),
                  Icon(Icons.location_on, color: Colors.green),
                ],
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Origin",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMapStyleDark ? Colors.black54 : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Pickup points",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMapStyleDark ? Colors.black54 : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Destination",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isMapStyleDark ? Colors.black54 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteDetails() {
    return Positioned(
      top: 10,
      right: 20,
      child: Center(
        child:
            isRouteInfoLoading
                ? Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: !isMapStyleDark ? Colors.black54 : Colors.white70,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color:
                              isMapStyleDark ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        'Loading route details...',
                        style: TextStyle(
                          color:
                              isMapStyleDark ? Colors.black54 : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
                : Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: !isMapStyleDark ? Colors.black54 : Colors.white70,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        textAlign: TextAlign.center,
                        "Origin\n->\ndestination",
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              isMapStyleDark ? Colors.black54 : Colors.white70,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car,
                            color:
                                isMapStyleDark
                                    ? Colors.black54
                                    : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            routeDistance ?? 'N/A',
                            style: TextStyle(
                              color:
                                  isMapStyleDark
                                      ? Colors.black54
                                      : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            color:
                                isMapStyleDark
                                    ? Colors.black54
                                    : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            routeDuration ?? 'N/A',
                            style: TextStyle(
                              color:
                                  isMapStyleDark
                                      ? Colors.black54
                                      : Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildNavigationButton() {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: _navigateToGoogleMaps,
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
              const SizedBox(width: 8),
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
    );
  }
}
