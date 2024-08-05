import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'dart:math' show cos, sqrt, asin;
import 'package:google_maps_directions/google_maps_directions.dart' as gmd;
import 'package:redacted/redacted.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/bottom_navbar.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/location/poi_service.dart';
import 'package:travelist/services/widgets/place_search_delegate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;

class ListDetailsPage extends StatefulWidget {
  final String listId;
  final String listName;

  const ListDetailsPage(
      {super.key, required this.listId, required this.listName});

  @override
  _ListDetailsPageState createState() => _ListDetailsPageState();
}

class _ListDetailsPageState extends State<ListDetailsPage> {
  gmaps.GoogleMapController? _mapController; // Controller for Google Map
  List<gmaps.Marker> _markers =
      []; // List of markers to be displayed on the map
  List<Map<String, dynamic>> _poiData =
      []; // List of Points of Interest (POI) data
  List<gmaps.LatLng> _polylinePoints =
      []; // List of points for drawing polyline
  final List<gmaps.LatLng> _routePoints =
      []; // List of route points for navigation
  final Set<gmaps.Polyline> _polylines = {}; // Set of polylines on the map
  PolylinePoints polylinePoints =
      PolylinePoints(); // PolylinePoints object for decoding polyline
  String? _googleMapsApiKey;
  bool _isLoading = false;
  String? _error;
  gmaps.LatLng? _currentLocation; // User's current location
  final Completer<gmaps.GoogleMapController?> _controller =
      Completer(); // Completer for map controller
  Location location =
      Location(); // Location object for accessing location services
  LocationData? _currentPosition; // User's current position data
  StreamSubscription<LocationData>?
      locationSubscription; // Subscription for location updates

  bool _isNavigationView = false;
  gmaps.LatLng? _navigationDestination;
  bool _userHasInteractedWithMap =
      false; // Flag to indicate if user has interacted with the map
  List<gmd.DirectionLegStep> _navigationSteps = []; // List of navigation steps
  int _currentStepIndex = 0;
  double _currentSliderValue = 0;
  String _distanceText = '';
  String _durationText = '';
  String _transportMode = 'driving'; // Transport mode for navigation

  final bool _countriesEnabled = true; // Flag to enable country filtering
  final bool _locationBiasEnabled = true;
  final bool _locationRestrictionEnabled =
      false; // Flag to enable location restriction

  late final PlacesService
      _placesService; // Service for place-related operations
  late final POIService _poiService; // Service for POI-related operations
  places.LatLngBounds? _locationBias; // Location bias for place searches

  int _selectedIndex = 1; // Selected index for bottom navigation bar

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    gmd.GoogleMapsDirections.init(
        googleAPIKey: _googleMapsApiKey!); // Initialize Google Maps Directions
    _placesService = PlacesService(
        _googleMapsApiKey!, _locationBias); // Initialize PlacesService
    _poiService = POIService(); // Initialize POIService
    _fetchPlaces();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    locationSubscription?.cancel(); // Cancel location subscription
    super.dispose();
  }

  // Handle bottom navigation item tap
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pop(context, 0); // Navigate back to previous page
    }
  }

  // Calculate centroid of a list of LatLng points
  gmaps.LatLng _calculateCentroid(List<gmaps.LatLng> points) {
    double latSum = 0;
    double lngSum = 0;

    for (var point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return gmaps.LatLng(latSum / points.length, lngSum / points.length);
  }

  // Fetch places data from Firestore
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
          .get(); // Get POIs from Firestore

      List<gmaps.Marker> markers = [];
      List<Map<String, dynamic>> poiData = [];
      List<gmaps.LatLng> points = [];

      for (var place in placesSnapshot.docs) {
        var placeData = place.data();
        var position =
            gmaps.LatLng(placeData['latitude'], placeData['longitude']);
        points.add(position);
        poiData.add({
          'id': place.id,
          'name': placeData['name'],
          'latitude': placeData['latitude'],
          'longitude': placeData['longitude'],
          'address': placeData['address'] ?? 'No address',
          'distance': _currentLocation != null
              ? _calculateDistance(_currentLocation!, position)
              : double.infinity,
        });
      }

      poiData.sort((a, b) =>
          a['distance'].compareTo(b['distance'])); // Sort POIs by distance

      for (var poi in poiData) {
        var position = gmaps.LatLng(poi['latitude'], poi['longitude']);
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(poi['id']),
            position: position,
            infoWindow: gmaps.InfoWindow(
              title: poi['name'],
              snippet: poi['address'],
            ),
            onTap: () => _confirmAddPlace(
              poi['name'],
              poi['latitude'],
              poi['longitude'],
              poi['address'],
            ),
          ),
        );
      }

      setState(() {
        _markers = markers; // Set markers
        _poiData = poiData; // Set POI data
        _polylinePoints = points; // Set polyline points
        _isLoading = false; // Set loading state to false
      });

      if (points.isNotEmpty) {
        final centralLocation = _calculateCentroid(points);
        _locationBias = places.LatLngBounds(
          southwest: places.LatLng(
              lat: centralLocation.latitude - 0.01,
              lng: centralLocation.longitude - 0.01),
          northeast: places.LatLng(
              lat: centralLocation.latitude + 0.01,
              lng: centralLocation.longitude + 0.01),
        );
      } else if (_currentLocation != null) {
        _locationBias = places.LatLngBounds(
          southwest: places.LatLng(
              lat: _currentLocation!.latitude - 0.01,
              lng: _currentLocation!.longitude - 0.01),
          northeast: places.LatLng(
              lat: _currentLocation!.latitude + 0.01,
              lng: _currentLocation!.longitude + 0.01),
        );
      }

      if (_polylinePoints.isNotEmpty) {
        _getRoutePolyline(); // Get polyline route
        _setNearestDestination(); // Set nearest destination
        if (!_userHasInteractedWithMap) {
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngBounds(
              _calculateBounds(_polylinePoints),
              50,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString(); // Set error message
        _isLoading = false; // Set loading state to false
      });
    }
  }

  // Get route polyline for the current list of points
  Future<void> _getRoutePolyline() async {
    if (_polylinePoints.length < 2) return;

    _routePoints.clear(); // Clear route points
    _polylines.clear(); // Clear existing polylines

    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      gmaps.LatLng start = _polylinePoints[i];
      gmaps.LatLng end = _polylinePoints[i + 1];

      gmd.Directions directions = await gmd.getDirections(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
        language: "en",
        googleAPIKey: _googleMapsApiKey!,
      );

      gmd.DirectionRoute route = directions.shortestRoute;
      List<gmaps.LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => gmaps.LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _routePoints.addAll(points); // Add route points
      });
    }

    setState(() {
      _polylines.add(
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('route'),
          color: Colors.blue,
          width: 5,
          points: _routePoints,
        ),
      );
    });

    if (_routePoints.isNotEmpty) {
      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(
          _calculateBounds(_routePoints),
          50,
        ),
      );
    }

    _calculateAndDisplayDistanceDuration(_currentSliderValue.toInt());
  }

  // Calculate bounds for a list of LatLng points
  gmaps.LatLngBounds _calculateBounds(List<gmaps.LatLng> points) {
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

    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(southWestLat, southWestLng),
      northeast: gmaps.LatLng(northEastLat, northEastLng),
    );
  }

  // Navigate to the selected location
  Future<void> _navigateToSelectedLocation(
      gmaps.LatLng selectedLocation) async {
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
      List<gmaps.LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => gmaps.LatLng(point.latitude, point.longitude))
          .toList();

      setState(() {
        _polylines.add(
          gmaps.Polyline(
            polylineId: const gmaps.PolylineId('navigation_route'),
            color: Colors.green,
            width: 5,
            points: points,
          ),
        );
        _navigationDestination = selectedLocation;
        _isNavigationView = true;
        _navigationSteps = steps;
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(
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

  // Update navigation based on the current location
  void _updateNavigation(LocationData currentLocation) {
    setState(() {
      _currentLocation =
          gmaps.LatLng(currentLocation.latitude!, currentLocation.longitude!);
    });

    if (_navigationSteps.isNotEmpty) {
      gmd.DirectionLegStep currentStep = _navigationSteps[_currentStepIndex];
      double distanceToNextStep = _calculateDistance(
        _currentLocation!,
        gmaps.LatLng(
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
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: _currentLocation!,
          zoom: 16,
        ),
      ),
    );
  }

  // Calculate distance between two LatLng points
  double _calculateDistance(gmaps.LatLng start, gmaps.LatLng end) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - cos((end.longitude - start.longitude) * p)) /
            2;

    return 12742 * asin(sqrt(a));
  }

  // Get the current location of the user
  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    final gmaps.GoogleMapController? controller = await _controller.future;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    if (permissionGranted == PermissionStatus.granted) {
      _currentPosition = await location.getLocation();
      setState(() {
        _currentLocation = gmaps.LatLng(
            _currentPosition!.latitude!, _currentPosition!.longitude!);
      });

      locationSubscription =
          location.onLocationChanged.listen((LocationData currentLocation) {
        if (!_userHasInteractedWithMap) {
          controller?.animateCamera(gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: gmaps.LatLng(
                  currentLocation.latitude!, currentLocation.longitude!),
              zoom: 16,
            ),
          ));
        }

        if (mounted) {
          setState(() {
            _currentLocation = gmaps.LatLng(
                currentLocation.latitude!, currentLocation.longitude!);
          });
        }
      });
    }
  }

  // Toggle the navigation view state
  void _toggleNavigationView() {
    setState(() {
      _isNavigationView = !_isNavigationView;
    });
  }

  // Set the nearest destination from the current location
  void _setNearestDestination() {
    if (_currentLocation == null || _polylinePoints.isEmpty) return;

    double minDistance = double.infinity;
    gmaps.LatLng? nearestPoint;

    for (gmaps.LatLng point in _polylinePoints) {
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

  // Calculate and display distance and duration for the route
  Future<void> _calculateAndDisplayDistanceDuration(int index) async {
    if (index >= _polylinePoints.length - 1) return;

    gmaps.LatLng start = _polylinePoints[index];
    gmaps.LatLng end = _polylinePoints[index + 1];

    gmd.DistanceValue distanceValue = await gmd.distance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
      googleAPIKey: _googleMapsApiKey!,
    );

    gmd.DurationValue durationValue = await _getDuration(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    setState(() {
      _distanceText = distanceValue.text;
      _durationText = durationValue.text;
    });
  }

  // Get duration based on transport mode
  Future<gmd.DurationValue> _getDuration(
      double startLat, double startLng, double endLat, double endLng) async {
    gmd.Directions directions = await gmd.getDirections(
      startLat,
      startLng,
      endLat,
      endLng,
      language: "en",
      googleAPIKey: _googleMapsApiKey!,
    );

    gmd.DirectionRoute route = directions.shortestRoute;
    gmd.DurationValue drivingDuration = route.legs.first.duration;

    switch (_transportMode) {
      case 'walking':
        return _durationWalking(drivingDuration);
      case 'bicycling':
        return _durationBicycling(drivingDuration);
      case 'driving':
      default:
        return drivingDuration;
    }
  }

  // Calculate duration for walking
  Future<gmd.DurationValue> _durationWalking(
      gmd.DurationValue drivingDuration) async {
    int walkingDurationSeconds = (drivingDuration.seconds * 5).toInt();
    return gmd.DurationValue(
      text: _formatDuration(walkingDurationSeconds),
      seconds: walkingDurationSeconds,
    );
  }

  // Calculate duration for bicycling
  Future<gmd.DurationValue> _durationBicycling(
      gmd.DurationValue drivingDuration) async {
    int bicyclingDurationSeconds = (drivingDuration.seconds * 2).toInt();
    return gmd.DurationValue(
      text: _formatDuration(bicyclingDurationSeconds),
      seconds: bicyclingDurationSeconds,
    );
  }

  // Format duration in hours and minutes
  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hrs $minutes mins';
    } else {
      return '$minutes mins';
    }
  }

  // Confirm adding a place to the list
  Future<void> _confirmAddPlace(
      String name, double latitude, double longitude, String address) async {
    await _poiService.addNearbyPlace(
      context,
      widget.listId,
      name,
      latitude,
      longitude,
      address,
      _poiData,
      _currentLocation,
      _fetchPlaces,
    );
  }

  // Show a dialog to reorder points of interest
  void _showReorderDialog() {
    List<Map<String, dynamic>> reorderedPOIData = List.from(_poiData);
    int _draggingIndex = -1;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text("Reorder Points of Interest"),
              content: Container(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: reorderedPOIData.length,
                  itemBuilder: (context, index) {
                    double textSize = reorderedPOIData.length > 5 ? 14 : 16;

                    return DragTarget<Map<String, dynamic>>(
                      builder: (context, candidateData, rejectedData) {
                        return Draggable<Map<String, dynamic>>(
                          data: reorderedPOIData[index],
                          childWhenDragging: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 0.0, horizontal: 1.0),
                              dense: true, // Makes ListTile compact
                              minVerticalPadding:
                                  0, // Reduces vertical space inside ListTile

                              leading: Text(
                                '${index + 1}.',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: textSize,
                                ),
                              ),
                              title: Text(
                                reorderedPOIData[index]['name'],
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: textSize,
                                ),
                              ),
                            ),
                          ),
                          feedback: Material(
                            child: Container(
                              width: MediaQuery.of(context).size.width - 20,
                              padding: const EdgeInsets.all(1.0),
                              color: Colors.blueAccent,
                              child: ListTile(
                                dense: true,
                                leading: Text(
                                  '${index + 1}.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: textSize,
                                  ),
                                ),
                                title: Text(
                                  reorderedPOIData[index]['name'],
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: textSize,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: ListTile(
                              dense: true,
                              minVerticalPadding: 0,
                              leading: Text(
                                '${index + 1}.',
                                style: TextStyle(
                                  fontSize: textSize,
                                ),
                              ),
                              title: Text(
                                reorderedPOIData[index]['name'],
                                style: TextStyle(
                                  fontSize: textSize,
                                ),
                              ),
                              trailing: const Icon(Icons.drag_handle),
                            ),
                          ),
                          onDragStarted: () {
                            setState(() {
                              _draggingIndex = index;
                            });
                          },
                          onDragEnd: (details) {
                            setState(() {
                              _draggingIndex = -1;
                            });
                          },
                        );
                      },
                      onWillAcceptWithDetails:
                          (DragTargetDetails<Map<String, dynamic>> details) {
                        return details.data != reorderedPOIData[index];
                      },
                      onAcceptWithDetails:
                          (DragTargetDetails<Map<String, dynamic>> details) {
                        final oldIndex = reorderedPOIData.indexOf(details.data);
                        setState(() {
                          if (oldIndex != index) {
                            var movedItem = reorderedPOIData.removeAt(oldIndex);
                            reorderedPOIData.insert(index, movedItem);
                            print('Reordered item from $oldIndex to $index');
                            print('Reordered list: $reorderedPOIData');
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _poiData = reorderedPOIData;
                    });
                    _updatePOIOrderInFirestore(); // Update the order of POIs in Firestore
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Update the order of POIs in Firestore
  void _updatePOIOrderInFirestore() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _poiData.length; i++) {
      final poi = _poiData[i];
      final docRef = FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poi['id']);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      body: _isLoading
          ? _buildLoadingSkeleton(context)
          : Stack(
              children: [
                gmaps.GoogleMap(
                    initialCameraPosition: const gmaps.CameraPosition(
                      target: gmaps.LatLng(51.509865, -0.118092),
                      zoom: 13,
                    ),
                    markers: Set.from(_markers),
                    polylines: _polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _controller.complete(controller);
                      if (_polylinePoints.isNotEmpty &&
                          !_userHasInteractedWithMap) {
                        _mapController?.animateCamera(
                          gmaps.CameraUpdate.newLatLngBounds(
                            _calculateBounds(_polylinePoints),
                            50,
                          ),
                        );
                      }
                    },
                    myLocationEnabled: true,
                    onCameraMove: (gmaps.CameraPosition position) {
                      _userHasInteractedWithMap = true;
                    },
                    zoomControlsEnabled: false),
                if (_error != null) Center(child: Text('Error: $_error')),
                Positioned(
                  top: 10,
                  right: 10,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      if (_navigationDestination == null) {
                        _setNearestDestination(); // Set the nearest destination
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
                    tooltip: 'Navigate to the nearest location',
                    child: const Icon(Icons.navigation_outlined),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: FloatingActionButton(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    onPressed: () {
                      _showSearch(context); // Show search dialog
                    },
                    tooltip: 'Search for places',
                    child: const Icon(Icons.add),
                  ),
                ),
                Positioned(
                  top: 80,
                  right: 10,
                  child: Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.tertiryColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add),
                          iconSize: 20,
                          color: Colors.black87,
                          onPressed: () {
                            _mapController
                                ?.animateCamera(gmaps.CameraUpdate.zoomIn());
                          },
                          tooltip: 'Zoom in',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.tertiryColor,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 5,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.remove),
                          iconSize: 20,
                          color: Colors.black87,
                          onPressed: () {
                            _mapController
                                ?.animateCamera(gmaps.CameraUpdate.zoomOut());
                          },
                          tooltip: 'Zoom out',
                        ),
                      ),
                    ],
                  ),
                ),
                DraggableScrollableSheet(
                  initialChildSize: 0.3,
                  minChildSize: 0.1,
                  maxChildSize: 0.8,
                  builder: (BuildContext context,
                      ScrollController scrollController) {
                    return SingleChildScrollView(
                      controller: scrollController,
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Route Points:'),
                            ListView.builder(
                              shrinkWrap: true,
                              controller: scrollController,
                              itemCount: _poiData.length,
                              itemBuilder: (BuildContext context, int index) {
                                double textSize = _poiData.length > 7 ? 14 : 16;
                                return Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 0, horizontal: 4.0),
                                    visualDensity: VisualDensity.compact,
                                    minVerticalPadding: 0,
                                    title: Text(
                                      '${index + 1}. ${_poiData[index]['name']}',
                                      style: TextStyle(
                                        fontSize: textSize,
                                      ),
                                    ),
                                    subtitle: Text(
                                      _poiData[index]['address'],
                                      style: TextStyle(fontSize: textSize - 2),
                                    ),
                                    trailing: const Icon(Icons.drag_handle),
                                    onTap: () {
                                      _showReorderDialog(); // Show reorder dialog
                                    },
                                  ),
                                );
                              },
                            ),
                            if (_polylinePoints.length > 1)
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: _currentSliderValue,
                                      min: 0,
                                      max: (_polylinePoints.length - 1)
                                          .toDouble(),
                                      divisions: _polylinePoints.length - 1,
                                      label: (_currentSliderValue + 1)
                                          .round()
                                          .toString(),
                                      onChanged: (double value) {
                                        setState(() {
                                          _currentSliderValue = value;
                                          _calculateAndDisplayDistanceDuration(value
                                              .toInt()); // Update distance and duration display
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Distance: $_distanceText'),
                                    Text('Duration: $_durationText'),
                                  ],
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.directions_car),
                                      onPressed: () {
                                        setState(() {
                                          _transportMode = 'driving';
                                          _getRoutePolyline(); // Get route polyline for driving
                                        });
                                      },
                                      color: _transportMode == 'driving'
                                          ? Colors.blue
                                          : Colors.grey,
                                      iconSize: 20,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.directions_walk),
                                      onPressed: () {
                                        setState(() {
                                          _transportMode = 'walking';
                                          _getRoutePolyline(); // Get route polyline for walking
                                        });
                                      },
                                      color: _transportMode == 'walking'
                                          ? Colors.blue
                                          : Colors.grey,
                                      iconSize: 20,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.directions_bike),
                                      onPressed: () {
                                        setState(() {
                                          _transportMode = 'bicycling';
                                          _getRoutePolyline(); // Get route polyline for bicycling
                                        });
                                      },
                                      color: _transportMode == 'bicycling'
                                          ? Colors.blue
                                          : Colors.grey,
                                      iconSize: 20,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
        onLogoutTapped: () {},
      ),
    );
  }

  // Build loading skeleton while data is being fetched
  Widget _buildLoadingSkeleton(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container().redacted(
            context: context,
            redact: true,
            configuration: RedactedConfiguration(
              animationDuration: const Duration(milliseconds: 800),
            ),
          ),
        ),
      ],
    );
  }

  // Show search dialog for searching places
  void _showSearch(BuildContext context) async {
    final query = await showSearch<String>(
      context: context,
      delegate: PlaceSearchDelegate(_placesService),
    );

    if (query != null && query.isNotEmpty) {
      try {
        final result = await _placesService.findAutocompletePredictions(
          query,
          _countriesEnabled ? ['uk'] : null,
        );

        if (result.predictions.isNotEmpty) {
          final placeId = result.predictions.first.placeId;
          final placeDetails = await _placesService.fetchPlace(placeId, [
            places.PlaceField.Address,
            places.PlaceField.AddressComponents,
            places.PlaceField.Location,
            places.PlaceField.Name,
            places.PlaceField.OpeningHours,
            places.PlaceField.PhotoMetadatas,
            places.PlaceField.PlusCode,
            places.PlaceField.PriceLevel,
            places.PlaceField.Rating,
            places.PlaceField.UserRatingsTotal,
            places.PlaceField.UTCOffset,
            places.PlaceField.Viewport,
            places.PlaceField.WebsiteUri,
          ]);

          final place = placeDetails.place;
          if (place != null && place.latLng != null) {
            final location = place.latLng!;
            final address = place.address ?? 'No address available';
            setState(() {
              _markers.add(
                gmaps.Marker(
                  markerId: gmaps.MarkerId(placeId),
                  position: gmaps.LatLng(location.lat, location.lng),
                  infoWindow: gmaps.InfoWindow(
                    title: place.name ?? 'Unknown',
                    snippet: address,
                  ),
                  onTap: () => _confirmAddPlace(
                    place.name ?? 'Unknown',
                    location.lat,
                    location.lng,
                    address,
                  ),
                ),
              );
              _mapController?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(
                gmaps.LatLng(location.lat, location.lng),
                14.0,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'Tap on the pin to add ${place.name ?? 'Unknown'} to your list.'),
                ),
              );
            });
          }
        } else {}
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }
}
