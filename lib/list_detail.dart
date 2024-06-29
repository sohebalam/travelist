import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  GoogleMapController? _mapController;
  List<Marker> _markers = [];
  List<LatLng> _polylinePoints = [];
  List<LatLng> _routePoints = [];
  Set<Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  String? _googleMapsApiKey;
  bool _isLoading = false;
  String? _error;
  LatLng? _currentLocation;
  final Completer<GoogleMapController?> _controller = Completer();
  Location location = Location();
  LocationData? _currentPosition;
  StreamSubscription<LocationData>? locationSubscription;

  bool _isNavigationView = false;
  LatLng? _navigationDestination;
  bool _userHasInteractedWithMap = false;
  List<gmd.DirectionLegStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  double _currentSliderValue = 0;
  String _distanceText = '';
  String _durationText = '';
  String _transportMode = 'driving';

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    gmd.GoogleMapsDirections.init(googleAPIKey: _googleMapsApiKey!);
    _fetchPlaces();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

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
        _getRoutePolyline();
        _setNearestDestination();
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

  Future<void> _getRoutePolyline() async {
    if (_polylinePoints.length < 2) return;

    _routePoints.clear();
    _polylines.clear();

    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      LatLng start = _polylinePoints[i];
      LatLng end = _polylinePoints[i + 1];

      gmd.Directions directions = await gmd.getDirections(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
        language: "en",
        googleAPIKey: _googleMapsApiKey!,
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

    if (_routePoints.isNotEmpty) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          _calculateBounds(_routePoints),
          50,
        ),
      );
    }

    _calculateAndDisplayDistanceDuration(_currentSliderValue.toInt());
  }

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

  double _calculateDistance(LatLng start, LatLng end) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        cos((end.latitude - start.latitude) * p) / 2 +
        cos(start.latitude * p) *
            cos(end.latitude * p) *
            (1 - cos((end.longitude - start.longitude) * p)) /
            2;

    return 12742 * asin(sqrt(a));
  }

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

  void _toggleNavigationView() {
    setState(() {
      _isNavigationView = !_isNavigationView;
    });
  }

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

  Future<void> _calculateAndDisplayDistanceDuration(int index) async {
    if (index >= _polylinePoints.length - 1) return;

    LatLng start = _polylinePoints[index];
    LatLng end = _polylinePoints[index + 1];

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

  Future<gmd.DurationValue> _durationWalking(
      gmd.DurationValue drivingDuration) async {
    // Simulate walking duration (typically 1/5th the speed of driving)
    int walkingDurationSeconds = (drivingDuration.seconds * 5).toInt();
    return gmd.DurationValue(
      text: _formatDuration(walkingDurationSeconds),
      seconds: walkingDurationSeconds,
    );
  }

  Future<gmd.DurationValue> _durationBicycling(
      gmd.DurationValue drivingDuration) async {
    // Simulate bicycling duration (typically 1/2 the speed of driving)
    int bicyclingDurationSeconds = (drivingDuration.seconds * 2).toInt();
    return gmd.DurationValue(
      text: _formatDuration(bicyclingDurationSeconds),
      seconds: bicyclingDurationSeconds,
    );
  }

  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hrs $minutes mins';
    } else {
      return '$minutes mins';
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
          DraggableScrollableSheet(
            initialChildSize: 0.3,
            minChildSize: 0.1,
            maxChildSize: 0.8,
            builder: (BuildContext context, ScrollController scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Container(
                  color: Colors.white,
                  padding: EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Route Points:'),
                      ListView.builder(
                        controller: scrollController,
                        shrinkWrap: true,
                        itemCount: _polylinePoints.length,
                        itemBuilder: (BuildContext context, int index) {
                          return ListTile(
                            title: Text(
                                _markers[index].infoWindow.title ?? 'No name'),
                            subtitle: Text(
                                'Lat: ${_polylinePoints[index].latitude}, Lng: ${_polylinePoints[index].longitude}'),
                            onTap: () {
                              _calculateAndDisplayDistanceDuration(index);
                            },
                          );
                        },
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _currentSliderValue,
                              min: 0,
                              max: (_polylinePoints.length - 1).toDouble(),
                              divisions: _polylinePoints.length - 1,
                              label:
                                  (_currentSliderValue + 1).round().toString(),
                              onChanged: (double value) {
                                setState(() {
                                  _currentSliderValue = value;
                                  _calculateAndDisplayDistanceDuration(
                                      value.toInt());
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
                                icon: Icon(Icons.directions_car),
                                onPressed: () {
                                  setState(() {
                                    _transportMode = 'driving';
                                    _getRoutePolyline();
                                  });
                                },
                                color: _transportMode == 'driving'
                                    ? Colors.blue
                                    : Colors.grey,
                                iconSize: 20,
                              ),
                              IconButton(
                                icon: Icon(Icons.directions_walk),
                                onPressed: () {
                                  setState(() {
                                    _transportMode = 'walking';
                                    _getRoutePolyline();
                                  });
                                },
                                color: _transportMode == 'walking'
                                    ? Colors.blue
                                    : Colors.grey,
                                iconSize: 20,
                              ),
                              IconButton(
                                icon: Icon(Icons.directions_bike),
                                onPressed: () {
                                  setState(() {
                                    _transportMode = 'bicycling';
                                    _getRoutePolyline();
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
    );
  }
}
