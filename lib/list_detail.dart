import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:google_maps_directions/google_maps_directions.dart' as gmd;
import 'package:url_launcher/url_launcher.dart';

class ListDetailsPage extends StatefulWidget {
  final String listId;
  final String listName;

  ListDetailsPage({required this.listId, required this.listName});

  @override
  _ListDetailsPageState createState() => _ListDetailsPageState();
}

class _ListDetailsPageState extends State<ListDetailsPage> {
  GoogleMapController? _mapController; // Controller for Google Map
  List<Marker> _markers = []; // List of markers on the map
  List<LatLng> _polylinePoints = []; // List of points for the polyline
  List<LatLng> _routePoints = []; // Points for the route polyline
  Set<Polyline> _polylines = {}; // Set of polylines to be drawn on the map
  PolylinePoints polylinePoints = PolylinePoints(); // For decoding polylines
  String? _googleMapsApiKey; // Google Maps API Key
  bool _isLoading = false; // Loading state
  String? _error; // Error message
  LatLng? _currentLocation; // Current location of the user
  final Completer<GoogleMapController?> _controller =
      Completer(); // Completer for map controller
  Location location = Location(); // Location instance for getting location data
  LocationData? _currentPosition; // Current position of the user
  StreamSubscription<LocationData>?
      locationSubscription; // Subscription for location changes

  bool _isNavigationView = false; // Flag for navigation view
  LatLng? _navigationDestination; // Destination for navigation
  bool _userHasInteractedWithMap =
      false; // Flag for user interaction with the map
  List<gmd.DirectionLegStep> _navigationSteps = []; // Steps for navigation
  int _currentStepIndex = 0; // Current step index in navigation

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv
        .env['GOOGLE_MAPS_API_KEY']; // Get API key from environment variables
    gmd.GoogleMapsDirections.init(
        googleAPIKey:
            _googleMapsApiKey!); // Initialize Google Maps Directions API
    _fetchPlaces(); // Fetch places from Firestore
    _getCurrentLocation(); // Get current location of the user
  }

  @override
  void dispose() {
    locationSubscription?.cancel(); // Cancel location subscription on dispose
    super.dispose();
  }

  // Fetch places from Firestore
  Future<void> _fetchPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var placesSnapshot = await FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .get();

      List<Marker> markers = [];
      List<LatLng> polylinePoints = [];

      // Add markers and polyline points
      for (var place in placesSnapshot.docs) {
        var placeData = place.data();
        var position = LatLng(placeData['latitude'], placeData['longitude']);
        markers.add(
          Marker(
            markerId: MarkerId(place.id),
            position: position,
            infoWindow: InfoWindow(title: placeData['name']),
          ),
        );
        polylinePoints.add(position);
      }

      setState(() {
        _markers = markers;
        _polylinePoints = polylinePoints;
        _isLoading = false;
      });

      if (polylinePoints.isNotEmpty) {
        _getRoutePolyline(); // Get polyline for the route
        _setNearestDestination(); // Set nearest destination for navigation
        if (!_userHasInteractedWithMap) {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngBounds(
              _calculateBounds(polylinePoints),
              50,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // Get polyline for the route
  Future<void> _getRoutePolyline() async {
    if (_polylinePoints.length < 2) return;

    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      LatLng start = _polylinePoints[i];
      LatLng end = _polylinePoints[i + 1];

      gmd.Directions directions = await gmd.getDirections(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
        language: "en",
      );

      gmd.DirectionRoute route = directions.shortestRoute;
      List<LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _routePoints.addAll(points);
      });
    }

    setState(() {
      _polylines.add(
        Polyline(
          polylineId: PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: _routePoints,
        ),
      );
    });
  }

  // Calculate bounds for the map
  LatLngBounds _calculateBounds(List<LatLng> points) {
    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) {
        southWestLat = point.latitude;
      }
      if (point.longitude < southWestLng) {
        southWestLng = point.longitude;
      }
      if (point.latitude > northEastLat) {
        northEastLat = point.latitude;
      }
      if (point.longitude > northEastLng) {
        northEastLng = point.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  Future<void> _addPOIFromGooglePlaces() async {
    // Implement your logic to add POI from Google Places
  }

  Future<void> _recommendPOIsUsingOpenAI() async {
    // Implement your logic to get POI recommendations from OpenAI
  }

  // Navigate to the selected location
  Future<void> _navigateToSelectedLocation(LatLng selectedLocation) async {
    if (_currentPosition == null) return;

    final apiKey = _googleMapsApiKey;
    final origin =
        '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination =
        '${selectedLocation.latitude},${selectedLocation.longitude}';
    final directions = await gmd.getDirections(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      selectedLocation.latitude,
      selectedLocation.longitude,
      googleAPIKey: apiKey,
    );

    if (directions.routes.isNotEmpty) {
      final route = directions.shortestRoute;
      final steps = route.shortestLeg.steps;
      List<LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.add(
          Polyline(
            polylineId: PolylineId('navigation_route'),
            color: Colors.green,
            width: 5,
            points: points,
          ),
        );
        _navigationDestination = selectedLocation;
        _isNavigationView = true;
        _navigationSteps = steps;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(points),
            50,
          ),
        );
      });

      locationSubscription =
          location.onLocationChanged.listen((LocationData currentLocation) {
        _updateNavigation(currentLocation);
      });
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  // Update navigation based on current location
  void _updateNavigation(LocationData currentLocation) {
    setState(() {
      _currentLocation =
          LatLng(currentLocation.latitude!, currentLocation.longitude!);
    });

    if (_navigationSteps.isNotEmpty) {
      gmd.DirectionLegStep currentStep = _navigationSteps[_currentStepIndex];
      double distanceToNextStep = _calculateDistance(
        _currentLocation!,
        LatLng(
          currentStep.endLocation.lat,
          currentStep.endLocation.lng,
        ),
      );

      if (distanceToNextStep < 20) {
        if (_currentStepIndex < _navigationSteps.length - 1) {
          setState(() {
            _currentStepIndex++;
          });
        } else {
          locationSubscription?.cancel();
        }
      }
    }

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentLocation!,
          zoom: 16,
        ),
      ),
    );
  }

  // Calculate distance between two points
  double _calculateDistance(LatLng start, LatLng end) {
    const double p = 0.017453292519943295; // Pi/180
    final double a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - cos((end.longitude - start.longitude) * p)) /
            2;

    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Get current location of the user
  Future<void> _getCurrentLocation() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    final GoogleMapController? controller = await _controller.future;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    if (_permissionGranted == PermissionStatus.granted) {
      _currentPosition = await location.getLocation();
      setState(() {
        _currentLocation =
            LatLng(_currentPosition!.latitude!, _currentPosition!.longitude!);
      });

      locationSubscription =
          location.onLocationChanged.listen((LocationData currentLocation) {
        if (!_userHasInteractedWithMap) {
          controller?.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target:
                  LatLng(currentLocation.latitude!, currentLocation.longitude!),
              zoom: 16,
            ),
          ));
        }

        if (mounted) {
          setState(() {
            _currentLocation =
                LatLng(currentLocation.latitude!, currentLocation.longitude!);
          });
        }
      });
    }
  }

  // Toggle between map view and navigation view
  void _toggleNavigationView() {
    setState(() {
      _isNavigationView = !_isNavigationView;
    });
  }

  // Set nearest destination for navigation
  void _setNearestDestination() {
    if (_currentLocation == null || _polylinePoints.isEmpty) return;

    double minDistance = double.infinity;
    LatLng? nearestPoint;

    for (LatLng point in _polylinePoints) {
      double distance = _calculateDistance(_currentLocation!, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    if (nearestPoint != null) {
      _navigateToSelectedLocation(nearestPoint);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        actions: [
          if (_isNavigationView)
            IconButton(
              icon: Icon(Icons.map),
              onPressed: _toggleNavigationView,
              tooltip: 'Switch to map view',
            )
          else
            IconButton(
              icon: Icon(Icons.navigation),
              onPressed: _toggleNavigationView,
              tooltip: 'Switch to navigation view',
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(51.509865, -0.118092),
              zoom: 13,
            ),
            markers: Set.from(_markers),
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              _controller.complete(controller);
              if (_polylinePoints.isNotEmpty && !_userHasInteractedWithMap) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    _calculateBounds(_polylinePoints),
                    50,
                  ),
                );
              }
            },
            myLocationEnabled: true,
            onCameraMove: (CameraPosition position) {
              _userHasInteractedWithMap = true;
            },
          ),
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text('Error: $_error')),
          Positioned(
            top: 10,
            right: 10,
            child: FloatingActionButton(
              onPressed: () async {
                if (_navigationDestination == null) {
                  _setNearestDestination();
                }
                final url =
                    'google.navigation:q=${_navigationDestination!.latitude},${_navigationDestination!.longitude}&key=$_googleMapsApiKey';
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: Icon(Icons.navigation_outlined),
              tooltip: 'Navigate to the nearest location',
            ),
          ),
          Positioned(
            top: 80,
            right: 10,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  },
                  child: Icon(Icons.zoom_in),
                  tooltip: 'Zoom in',
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  },
                  child: Icon(Icons.zoom_out),
                  tooltip: 'Zoom out',
                ),
              ],
            ),
          ),
          if (!_isNavigationView)
            DraggableScrollableSheet(
              initialChildSize: 0.1,
              minChildSize: 0.1,
              maxChildSize: 0.8,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                return Container(
                  color: Colors.white,
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _markers.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title:
                            Text(_markers[index].infoWindow.title ?? 'No name'),
                        subtitle: Text(
                            'Lat: ${_markers[index].position.latitude}, Lng: ${_markers[index].position.longitude}'),
                        onTap: () {
                          _navigateToSelectedLocation(_markers[index].position);
                        },
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
