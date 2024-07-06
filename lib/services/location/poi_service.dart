import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter/material.dart';

class POIService {
  Future<void> addNearbyPlace(
    BuildContext context,
    String listId,
    String name,
    double latitude,
    double longitude,
    String address,
    List<Map<String, dynamic>> poiData,
    gmaps.LatLng? currentLocation,
    Function fetchPlaces,
  ) async {
    if (poiData.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'You can only have up to 10 places of interest in the list.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add to list'),
        content: Text('Do you want to add $name to your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Add'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('lists')
          .doc(listId)
          .collection('pois')
          .add({
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
      });

      poiData.add({
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'distance': currentLocation != null
            ? _calculateDistance(
                currentLocation, gmaps.LatLng(latitude, longitude))
            : double.infinity,
      });

      fetchPlaces();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
