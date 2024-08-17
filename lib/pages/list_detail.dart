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
import 'package:travelist/services/pages/list_detail_service.dart';
import 'package:travelist/services/secure_storage.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/bottom_navbar.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/location/poi_service.dart';
import 'package:travelist/services/widgets/place_search_delegate.dart';
import 'package:travelist/services/widgets/reorder_dialog.dart';
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
  gmaps.GoogleMapController? _mapController;
  List<gmaps.Marker> _markers = [];
  List<Map<String, dynamic>> _poiData = [];
  List<gmaps.LatLng> _polylinePoints = [];
  final List<gmaps.LatLng> _routePoints = [];
  final Set<gmaps.Polyline> _polylines = {};
  PolylinePoints polylinePoints = PolylinePoints();
  String? _googleMapsApiKey;
  bool _isLoading = false;
  String? _error;
  gmaps.LatLng? _currentLocation;
  final Completer<gmaps.GoogleMapController?> _controller = Completer();
  Location location = Location();
  LocationData? _currentPosition;
  StreamSubscription<LocationData>? locationSubscription;
  bool _isNavigationView = false;
  gmaps.LatLng? _navigationDestination;
  bool _userHasInteractedWithMap = false;
  List<gmd.DirectionLegStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  double _currentSliderValue = 0;
  String _distanceText = '';
  String _durationText = '';
  String _transportMode = 'driving';
  final bool _countriesEnabled = true;
  final bool _locationBiasEnabled = true;
  final bool _locationRestrictionEnabled = false;
  late final PlacesService _placesService;
  late final POIService _poiService;
  places.LatLngBounds? _locationBias;
  int _selectedIndex = 1;

  DurationService? _durationService;

  @override
  void initState() {
    super.initState();
    _initializeGoogleMapsApiKey().then((_) {
      if (_googleMapsApiKey != null) {
        _durationService = DurationService(_googleMapsApiKey!, _transportMode);
        _fetchPlaces();
        _getCurrentLocation();
      } else {
        setState(() {
          _error = 'Failed to initialize API key.';
        });
      }
    });
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGoogleMapsApiKey() async {
    final storage = SecureStorage();
    _googleMapsApiKey = await storage.getGoogleMapsKey();

    if (_googleMapsApiKey == null) {
      setState(() {
        _error = 'Google Maps API key is missing';
      });
      return;
    }

    gmd.GoogleMapsDirections.init(googleAPIKey: _googleMapsApiKey!);
    _placesService = PlacesService(_googleMapsApiKey!, _locationBias);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pop(context, 0);
    }
  }

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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$name has been added to your list.',
          style: TextStyle(
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
          ),
        ),
      ),
    );
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
          .orderBy('order') // Ensure POIs are fetched in the correct order
          .get();

      List<gmaps.Marker> markers = [];
      List<Map<String, dynamic>> poiData = [];
      List<gmaps.LatLng> points = [];

      for (var place in placesSnapshot.docs) {
        var placeData = place.data();
        var position =
            gmaps.LatLng(placeData['latitude'], placeData['longitude']);
        points.add(position);
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(place.id),
            position: position,
            infoWindow: gmaps.InfoWindow(
              title: placeData['name'],
              snippet: placeData['address'] ?? 'No address',
            ),
          ),
        );
        poiData.add({
          'id': place.id,
          'name': placeData['name'],
          'latitude': placeData['latitude'],
          'longitude': placeData['longitude'],
          'address': placeData['address'] ?? 'No address',
          'distance': _currentLocation != null
              ? _calculateDistance(_currentLocation!, position)
              : double.infinity,
          'order': placeData['order'] ?? 0, // Make sure to include the order
        });
      }

      setState(() {
        _markers = markers;
        _poiData = poiData;
        _polylinePoints = points;
        _isLoading = false;
      });

      if (_polylinePoints.isNotEmpty) {
        _getRoutePolyline();
        _setNearestDestination();
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
        _routePoints.addAll(points);
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

  Future<void> _navigateToSelectedLocation(
      gmaps.LatLng selectedLocation) async {
    if (_currentPosition == null) return;

    final directions = await gmd.getDirections(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      selectedLocation.latitude,
      selectedLocation.longitude,
      googleAPIKey: _googleMapsApiKey!,
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

  void _showReorderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReorderDialog(
          poiData: _poiData,
          listId: widget.listId,
          onSave: (reorderedPOIData) {
            setState(() {
              _poiData = reorderedPOIData;
            });
          },
        );
      },
    );
  }

  void _updatePOIOrderInFirestore() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _poiData.length; i++) {
      final poi = _poiData[i];
      final docRef = FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poi['id']);
      batch.update(docRef, {'order': i}); // Update the order field
    }
    await batch.commit();
  }

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

  void _deletePOI(String poiId) async {
    try {
      await FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poiId)
          .delete();

      setState(() {
        _poiData.removeWhere((poi) => poi['id'] == poiId);
        _markers.removeWhere((marker) => marker.markerId.value == poiId);
        _polylinePoints.removeWhere((point) => point == poiId);
      });

      _getRoutePolyline();
      _showSuccessSnackBar('POI deleted successfully.');
    } catch (e) {
      _showErrorSnackBar('Error deleting POI.');
    }
  }

  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

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

  void _confirmDeletePOI(String poiId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete POI'),
          content: Text('Are you sure you want to delete this POI?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deletePOI(poiId);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleNavigationView() {
    setState(() {
      _isNavigationView = !_isNavigationView;
    });
  }

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

    gmd.DurationValue durationValue = await _durationService!.getDuration(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listName,
          style: TextStyle(
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
          ),
        ),
      ),
      body: Semantics(
        label: 'List Details Page',
        child: _isLoading
            ? _buildLoadingSkeleton(context)
            : Stack(
                children: [
                  Semantics(
                    label: 'Map displaying points of interest',
                    child: gmaps.GoogleMap(
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
                  ),
                  if (_error != null)
                    Center(
                      child: Semantics(
                        label: 'Error message',
                        child: Text(
                          'Error: $_error',
                          style: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(14.0) ??
                                14.0,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Semantics(
                      label: 'Navigate to nearest location button',
                      child: FloatingActionButton(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
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
                        tooltip: 'Navigate to the nearest location',
                        child: const Icon(Icons.navigation_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Semantics(
                      label: 'Search for places button',
                      child: FloatingActionButton(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        onPressed: () {
                          _showSearch(context);
                        },
                        tooltip: 'Search for places',
                        child: const Icon(Icons.add),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    right: 10,
                    child: Column(
                      children: [
                        Semantics(
                          label: 'Zoom in button',
                          child: Container(
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
                              iconSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(20.0) ??
                                  20.0,
                              color: Colors.black87,
                              onPressed: () {
                                _mapController?.animateCamera(
                                    gmaps.CameraUpdate.zoomIn());
                              },
                              tooltip: 'Zoom in',
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Semantics(
                          label: 'Zoom out button',
                          child: Container(
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
                              iconSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(20.0) ??
                                  20.0,
                              color: Colors.black87,
                              onPressed: () {
                                _mapController?.animateCamera(
                                    gmaps.CameraUpdate.zoomOut());
                              },
                              tooltip: 'Zoom out',
                            ),
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
                              Semantics(
                                label: 'List of route points',
                                child: Text(
                                  'Route Points:',
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.maybeTextScalerOf(context)
                                                ?.scale(16.0) ??
                                            16.0,
                                  ),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                controller: scrollController,
                                itemCount: _poiData.length,
                                itemBuilder: (BuildContext context, int index) {
                                  double textSize = _poiData.length > 7
                                      ? MediaQuery.maybeTextScalerOf(context)
                                              ?.scale(14.0) ??
                                          14.0
                                      : MediaQuery.maybeTextScalerOf(context)
                                              ?.scale(16.0) ??
                                          16.0;

                                  String shortAddress = _poiData[index]
                                          ['address']
                                      .split(',')
                                      .reversed
                                      .take(2)
                                      .join(', ');

                                  return Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 0),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          vertical: 0, horizontal: 4.0),
                                      visualDensity: VisualDensity.compact,
                                      minVerticalPadding: 0,
                                      title: Semantics(
                                        label: 'Route point name',
                                        child: Text(
                                          '${index + 1}. ${_poiData[index]['name']}',
                                          style: TextStyle(
                                            fontSize: textSize,
                                          ),
                                        ),
                                      ),
                                      subtitle: Semantics(
                                        label: 'Route point address',
                                        child: Text(
                                          shortAddress,
                                          style:
                                              TextStyle(fontSize: textSize - 2),
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            color: AppColors.primaryColor,
                                            onPressed: () {
                                              _confirmDeletePOI(
                                                  _poiData[index]['id']);
                                            },
                                          ),
                                          const Icon(Icons.drag_handle),
                                        ],
                                      ),
                                      onTap: () {
                                        _showReorderDialog();
                                      },
                                    ),
                                  );
                                },
                              ),
                              if (_polylinePoints.length > 1)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Semantics(
                                        label:
                                            'Slider to adjust route point display',
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
                                              _calculateAndDisplayDistanceDuration(
                                                  value.toInt());
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Semantics(
                                        label: 'Distance to next point',
                                        child: Text(
                                          'Distance: $_distanceText',
                                          style: TextStyle(
                                            fontSize:
                                                MediaQuery.maybeTextScalerOf(
                                                            context)
                                                        ?.scale(14.0) ??
                                                    14.0,
                                          ),
                                        ),
                                      ),
                                      Semantics(
                                        label: 'Duration to next point',
                                        child: Text(
                                          'Duration: $_durationText',
                                          style: TextStyle(
                                            fontSize:
                                                MediaQuery.maybeTextScalerOf(
                                                            context)
                                                        ?.scale(14.0) ??
                                                    14.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Semantics(
                                        label: 'Driving mode button',
                                        child: IconButton(
                                          icon:
                                              const Icon(Icons.directions_car),
                                          onPressed: () {
                                            setState(() {
                                              _transportMode = 'driving';
                                              _durationService =
                                                  DurationService(
                                                      _googleMapsApiKey!,
                                                      _transportMode);
                                              _getRoutePolyline();
                                            });
                                          },
                                          color: _transportMode == 'driving'
                                              ? Colors.blue
                                              : Colors.grey,
                                          iconSize:
                                              MediaQuery.maybeTextScalerOf(
                                                          context)
                                                      ?.scale(20.0) ??
                                                  20.0,
                                        ),
                                      ),
                                      Semantics(
                                        label: 'Walking mode button',
                                        child: IconButton(
                                          icon:
                                              const Icon(Icons.directions_walk),
                                          onPressed: () {
                                            setState(() {
                                              _transportMode = 'walking';
                                              _durationService =
                                                  DurationService(
                                                      _googleMapsApiKey!,
                                                      _transportMode);
                                              _getRoutePolyline();
                                            });
                                          },
                                          color: _transportMode == 'walking'
                                              ? Colors.blue
                                              : Colors.grey,
                                          iconSize:
                                              MediaQuery.maybeTextScalerOf(
                                                          context)
                                                      ?.scale(20.0) ??
                                                  20.0,
                                        ),
                                      ),
                                      Semantics(
                                        label: 'Bicycling mode button',
                                        child: IconButton(
                                          icon:
                                              const Icon(Icons.directions_bike),
                                          onPressed: () {
                                            setState(() {
                                              _transportMode = 'bicycling';
                                              _durationService =
                                                  DurationService(
                                                      _googleMapsApiKey!,
                                                      _transportMode);
                                              _getRoutePolyline();
                                            });
                                          },
                                          color: _transportMode == 'bicycling'
                                              ? Colors.blue
                                              : Colors.grey,
                                          iconSize:
                                              MediaQuery.maybeTextScalerOf(
                                                          context)
                                                      ?.scale(20.0) ??
                                                  20.0,
                                        ),
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
      ),
      bottomNavigationBar: Semantics(
        label: 'Bottom navigation bar',
        child: BottomNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
          onLogoutTapped: () {},
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: 'Loading skeleton',
            child: Container().redacted(
              context: context,
              redact: true,
              configuration: RedactedConfiguration(
                animationDuration: const Duration(milliseconds: 800),
              ),
            ),
          ),
        ),
      ],
    );
  }

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
                  content: Semantics(
                    label: 'Snackbar message',
                    child: Text(
                      'Tap on the pin to add ${place.name ?? 'Unknown'} to your list.',
                      style: TextStyle(
                        fontSize: MediaQuery.maybeTextScalerOf(context)
                                ?.scale(14.0) ??
                            14.0,
                      ),
                    ),
                  ),
                ),
              );
            });
          }
        }
      } catch (e) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }
}
