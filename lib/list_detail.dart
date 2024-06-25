import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:location/location.dart' as loc;
import 'package:location/location.dart';
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
  loc.Location location = loc.Location();
  loc.LocationData? _currentPosition;
  StreamSubscription<loc.LocationData>? locationSubscription;

  bool _isNavigationView = false;
  LatLng? _navigationDestination;
  bool _userHasInteractedWithMap = false;

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
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

      if (polylinePoints.isNotEmpty && !_userHasInteractedWithMap) {
        _getRoutePolyline();
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(polylinePoints),
            50,
          ),
        );
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

    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      PointLatLng start = PointLatLng(
          _polylinePoints[i].latitude, _polylinePoints[i].longitude);
      PointLatLng end = PointLatLng(
          _polylinePoints[i + 1].latitude, _polylinePoints[i + 1].longitude);

      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        _googleMapsApiKey!,
        start,
        end,
      );

      if (result.points.isNotEmpty) {
        result.points.forEach((PointLatLng point) {
          _routePoints.add(LatLng(point.latitude, point.longitude));
        });
      } else {
        print(result.errorMessage);
      }
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
    final url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&key=$apiKey';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final points = data['routes'][0]['overview_polyline']['points'];
      final decodedPoints = _decodePolyline(points);

      final polyline = Polyline(
        polylineId: PolylineId('navigation_route'),
        color: Colors.green,
        width: 5,
        points: decodedPoints,
      );

      setState(() {
        _polylines.add(polyline);
        _navigationDestination = selectedLocation;
        _isNavigationView = true;
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            _calculateBounds(decodedPoints),
            50,
          ),
        );
      });
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  Future<void> _getCurrentLocation() async {
    bool _serviceEnabled;
    loc.PermissionStatus _permissionGranted;
    final GoogleMapController? controller = await _controller.future;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == loc.PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != loc.PermissionStatus.granted) {
        return;
      }
    }

    if (_permissionGranted == loc.PermissionStatus.granted) {
      _currentPosition = await location.getLocation();
      setState(() {
        _currentLocation =
            LatLng(_currentPosition!.latitude!, _currentPosition!.longitude!);
      });

      locationSubscription =
          location.onLocationChanged.listen((loc.LocationData currentLocation) {
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
          if (_isNavigationView && _navigationDestination != null)
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                width: 50,
                height: 50,
                decoration:
                    BoxDecoration(shape: BoxShape.circle, color: Colors.blue),
                child: Center(
                  child: IconButton(
                    icon: Icon(
                      Icons.navigation_outlined,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      final url =
                          'google.navigation:q=${_navigationDestination!.latitude},${_navigationDestination!.longitude}&key=$_googleMapsApiKey';
                      if (await canLaunch(url)) {
                        await launch(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
