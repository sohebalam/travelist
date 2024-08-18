import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter/material.dart';
import 'package:travelist/models/poi_model.dart';

class PlacesService {
  final FlutterGooglePlacesSdk _places;
  final LatLngBounds? _locationBias;

  PlacesService(String apiKey, this._locationBias)
      : _places = FlutterGooglePlacesSdk(apiKey);

  Future<FindAutocompletePredictionsResponse> findAutocompletePredictions(
      String query, List<String>? countries) {
    return _places.findAutocompletePredictions(
      query,
      countries: countries,
      locationBias: _locationBias,
    );
  }

  Future<FetchPlaceResponse> fetchPlace(
      String placeId, List<PlaceField> fields) {
    return _places.fetchPlace(placeId, fields: fields);
  }
}

class PlaceSearchDelegate extends SearchDelegate<Map<String, String>> {
  final PlacesService _placesService;

  PlaceSearchDelegate(this._placesService);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, {}));
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<places_sdk.FindAutocompletePredictionsResponse>(
      future: fetchPredictionsBasedOnLocation(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final predictions = snapshot.data!.predictions;

          return ListView.builder(
            itemCount: predictions.length,
            itemBuilder: (context, index) {
              final prediction = predictions[index];
              return ListTile(
                title: Text(prediction.primaryText),
                subtitle: Text(prediction.secondaryText ?? ''),
                onTap: () => close(context, {
                  'placeId': prediction.placeId,
                  'primaryText': prediction.primaryText,
                  'secondaryText': prediction.secondaryText ?? '',
                  'fullText': prediction.fullText,
                }),
              );
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

// Function to fetch predictions based on the user's current location
  Future<places_sdk.FindAutocompletePredictionsResponse>
      fetchPredictionsBasedOnLocation(String query) async {
    try {
      // Step 1: Get the current location
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low);

      // Step 2: Reverse geocode to get the country code
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      String? countryCode = placemarks.first.isoCountryCode;

      // Step 3: Use the country code in the autocomplete prediction
      return await _placesService.findAutocompletePredictions(
        query,
        countryCode != null ? [countryCode.toLowerCase()] : null,
      );
    } catch (e) {
      // Handle any errors that might occur during location fetching or geocoding
      print("Error fetching location or country code: $e");
      // Optionally return a default or empty response
      return _placesService.findAutocompletePredictions(
        query,
        ['uk'], // Fallback to 'uk' if there is an error
      );
    }
  }
}

class POIService {
  Future<void> addNearbyPlace(
    BuildContext context,
    String listId,
    String name,
    double latitude,
    double longitude,
    String address,
    List<POI> poiData, // Ensure poiData is a list of POI objects
    gmaps.LatLng? currentLocation,
    Function fetchPlaces, {
    String? description, // Optional description parameter
  }) async {
    if (poiData.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'You can only have up to 10 places of interest in the list.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to list'),
        content: Text('Do you want to add $name to your list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    // Create the POI instance with a temporary order
    POI newPOI = POI(
      id: '', // Firestore will generate this automatically
      name: name,
      latitude: latitude,
      longitude: longitude,
      address: address,
      order: poiData.length, // Assign a temporary order value
      description: description, // Optional description
    );

    try {
      // Add the POI to Firestore and retrieve the document ID
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('lists')
          .doc(listId)
          .collection('pois')
          .add(newPOI.toMap());

      // Update the POI instance with the generated ID
      newPOI = POI(
        id: docRef.id,
        name: name,
        latitude: latitude,
        longitude: longitude,
        address: address,
        order: poiData.length, // Assign a temporary order value
        description: description,
      );

      // Add the new POI to the local data
      poiData.add(newPOI);

      // Sort POIs by distance (including the new POI)
      if (currentLocation != null) {
        poiData.sort((a, b) {
          final distanceA = _calculateDistance(
              currentLocation, gmaps.LatLng(a.latitude, a.longitude));
          final distanceB = _calculateDistance(
              currentLocation, gmaps.LatLng(b.latitude, b.longitude));
          return distanceA.compareTo(distanceB);
        });

        // Update the order of each POI after sorting
        for (int i = 0; i < poiData.length; i++) {
          final poi = poiData[i];
          poiData[i] = POI(
            id: poi.id,
            name: poi.name,
            latitude: poi.latitude,
            longitude: poi.longitude,
            address: poi.address,
            order: i, // Assign the correct order based on the sorted position
            description: poi.description,
          );

          // Update the order in Firestore as well
          await FirebaseFirestore.instance
              .collection('lists')
              .doc(listId)
              .collection('pois')
              .doc(poi.id)
              .update({'order': i});
        }
      }

      // Notify the user that the POI was added
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${newPOI.name} added successfully.')),
      );

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
