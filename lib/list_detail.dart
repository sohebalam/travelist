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
  PolylinePoints polylinePoints = PolylinePoints();
  String? _googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    _fetchPlaces();
  }

  Future<void> _fetchPlaces() async {
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

    setState(() {});
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
            polylines: {
              Polyline(
                polylineId: PolylineId('route'),
                points: _routePoints,
                color: Colors.blue,
                width: 5,
              ),
            },
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
          ),
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
                        // Move camera to the selected marker
                        _mapController?.animateCamera(
                          CameraUpdate.newLatLng(
                            _markers[index].position,
                          ),
                        );
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
