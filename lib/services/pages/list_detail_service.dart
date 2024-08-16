import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class ListDetailsService {
  final String listId;

  ListDetailsService(this.listId);

  Future<List<Map<String, dynamic>>> fetchPlaces(gmaps.LatLng? currentLocation,
      void Function(String) showErrorSnackBar) async {
    try {
      var placesSnapshot = await FirebaseFirestore.instance
          .collection('lists')
          .doc(listId)
          .collection('pois')
          .get();

      List<Map<String, dynamic>> poiData = [];
      for (var place in placesSnapshot.docs) {
        var placeData = place.data();
        var position =
            gmaps.LatLng(placeData['latitude'], placeData['longitude']);
        poiData.add({
          'id': place.id,
          'name': placeData['name'],
          'latitude': placeData['latitude'],
          'longitude': placeData['longitude'],
          'address': placeData['address'] ?? 'No address',
          'distance': currentLocation != null
              ? _calculateDistance(currentLocation, position)
              : double.infinity,
        });
      }
      poiData.sort((a, b) => a['distance'].compareTo(b['distance']));
      return poiData;
    } catch (e) {
      showErrorSnackBar('Failed to fetch places: $e');
      return [];
    }
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
}
