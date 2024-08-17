import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:travelist/models/poi_model.dart';
import 'package:travelist/services/auth/auth_service.dart';
import 'package:travelist/services/location/recomendations.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/shared_functions.dart';

class HomePageService {
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> savePOIToList({
    required String? selectedListId,
    required POI poi,
    required Function(String) showErrorSnackBar,
    required Function(String) showSuccessSnackBar,
  }) async {
    if (selectedListId != null) {
      try {
        final listDocRef = _listsCollection.doc(selectedListId);
        final poiCollectionRef = listDocRef.collection('pois');

        // Get existing POIs to determine the correct order
        QuerySnapshot<Map<String, dynamic>> snapshot =
            await poiCollectionRef.orderBy('order').get();

        List<POI> existingPOIs =
            snapshot.docs.map((doc) => POI.fromFirestore(doc)).toList();

        // Determine the order for the new POI
        int newOrder = existingPOIs.length;

        // Create a new POI with the calculated order
        POI newPOI = POI(
          id: '',
          name: poi.name,
          latitude: poi.latitude,
          longitude: poi.longitude,
          address: poi.address,
          order: newOrder,
          description: poi.description,
        );

        // Add the POI to Firestore and retrieve the document ID
        DocumentReference docRef = await poiCollectionRef.add(newPOI.toMap());

        // Update the POI instance with the generated ID
        newPOI = POI(
          id: docRef.id,
          name: poi.name,
          latitude: poi.latitude,
          longitude: poi.longitude,
          address: poi.address,
          order: newOrder,
          description: poi.description,
        );

        // Debug print to ensure the POI is added correctly
        print('POI added to list successfully: ${newPOI.toMap()}');
        showSuccessSnackBar('POI added to list successfully.');
      } catch (e) {
        print('Error saving POI to list: $e'); // Debug print
        showErrorSnackBar('Error saving POI to list.');
      }
    } else {
      print('Selected list ID is null'); // Debug print
      showErrorSnackBar('Please select a list first.');
    }
  }

  Future<List<Map<String, dynamic>>> generatePOIs({
    required bool useCurrentLocation,
    required TextEditingController locationController,
    required GoogleMapController? mapController,
    required List<String>? interests,
    required Function(String) showErrorSnackBar,
    required Position? currentPosition,
  }) async {
    double? originalLat;
    double? originalLon;

    if (!useCurrentLocation && locationController.text.isEmpty) {
      showErrorSnackBar('Please enter a location');
      return [];
    }

    if (useCurrentLocation && currentPosition != null) {
      originalLat = currentPosition.latitude;
      originalLon = currentPosition.longitude;

      if (mapController != null) {
        mapController.animateCamera(CameraUpdate.newLatLng(
          LatLng(originalLat, originalLon),
        ));
      }
    } else {
      String location = locationController.text;

      try {
        var locationCoords = await getCoordinates(location);
        originalLat = locationCoords['lat'];
        originalLon = locationCoords['lon'];

        if (mapController != null &&
            originalLat != null &&
            originalLon != null) {
          mapController.animateCamera(CameraUpdate.newLatLng(
            LatLng(originalLat, originalLon),
          ));
        }
      } catch (e) {
        showErrorSnackBar('Invalid location');
        return [];
      }
    }

    if (originalLat == null || originalLon == null) {
      showErrorSnackBar(
          'Invalid coordinates, cannot proceed with POI generation');
      return [];
    }

    // Generate POIs
    List<Map<String, dynamic>> pois;
    try {
      pois = await fetchPOIs(
          '$originalLat,$originalLon', interests?.join(',') ?? '');
    } catch (e) {
      showErrorSnackBar('Locations not found, please try again');
      return [];
    }

    // Fetch address for each POI and save it
    for (var poi in pois) {
      try {
        Map<String, String> geocodeResult =
            await reverseGeocode(poi['latitude'], poi['longitude']);
        poi['address'] =
            geocodeResult['formattedAddress'] ?? 'No address available';
      } catch (e) {
        print('Error reverse geocoding POI: $e');
      }
    }

    return pois;
  }

  LatLngBounds calculateBounds(List<Marker> markers) {
    double southWestLat = markers.first.position.latitude;
    double southWestLng = markers.first.position.longitude;
    double northEastLat = markers.first.position.latitude;
    double northEastLng = markers.first.position.longitude;

    for (var marker in markers) {
      if (marker.position.latitude < southWestLat) {
        southWestLat = marker.position.latitude;
      }
      if (marker.position.longitude < southWestLng) {
        southWestLng = marker.position.longitude;
      }
      if (marker.position.latitude > northEastLat) {
        northEastLat = marker.position.latitude;
      }
      if (marker.position.longitude > northEastLng) {
        northEastLng = marker.position.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  Future<List<String>> loadUserInterests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return await AuthService().getUserInterests(user);
    }
    return [];
  }

  Future<List<POI>> fetchPOIsForList(String? selectedListId) async {
    if (selectedListId != null) {
      QuerySnapshot snapshot = await _listsCollection
          .doc(selectedListId)
          .collection('pois')
          .orderBy('order')
          .get();
      return snapshot.docs.map((doc) => POI.fromFirestore(doc)).toList();
    }
    return [];
  }

  Future<void> updatePOIOrder(
      String? selectedListId, String id, int order) async {
    if (selectedListId != null) {
      await _listsCollection
          .doc(selectedListId)
          .collection('pois')
          .doc(id)
          .update({'order': order});
    }
  }

  Future<void> saveUserInterests(List<String> userInterests) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'interests': userInterests,
      });
    }
  }
}
