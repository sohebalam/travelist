import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Make sure to load your Google Maps API key from .env file
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  Set<Polyline> _polylines = {}; // Define _polylines here
  PolylinePoints polylinePoints = PolylinePoints();
  String? _googleMapsApiKey;
  bool _isLoading = false;
  String? _error;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    _fetchPlaces();
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
    if (_currentLocation == null) return;

    final apiKey = _googleMapsApiKey;
    final origin =
        '${_currentLocation!.latitude},${_currentLocation!.longitude}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(51.509865, -0.118092), // Default location
              zoom: 13,
            ),
            markers: Set.from(_markers),
            polylines: _polylines, // Use _polylines here
            onMapCreated: (controller) {
              _mapController = controller;
              if (_polylinePoints.isNotEmpty) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngBounds(
                    _calculateBounds(_polylinePoints),
                    50,
                  ),
                );
              }
            },
            myLocationEnabled: true,
            onCameraMove: (position) {
              _currentLocation = position.target;
            },
          ),
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else if (_error != null)
            Center(child: Text('Error: $_error')),
          DraggableScrollableSheet(
            initialChildSize: 0.1,
            minChildSize: 0.1,
            maxChildSize: 0.8,
            builder: (BuildContext context, ScrollController scrollController) {
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
                        // Navigate to the selected marker
                        _navigateToSelectedLocation(_markers[index].position);
                      },
                    );
                  },
                ),
              );
            },
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Column(
              children: [
                FloatingActionButton(
                  onPressed: _addPOIFromGooglePlaces,
                  child: Icon(Icons.add_location_alt),
                  tooltip: 'Add POI from Google Places',
                ),
                SizedBox(height: 10),
                FloatingActionButton(
                  onPressed: _recommendPOIsUsingOpenAI,
                  child: Icon(Icons.lightbulb),
                  tooltip: 'Recommend POIs using OpenAI',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
