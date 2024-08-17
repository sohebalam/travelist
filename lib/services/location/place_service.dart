import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter/material.dart';

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
      future: _placesService.findAutocompletePredictions(
        query,
        ['uk'],
      ),
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
}

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
