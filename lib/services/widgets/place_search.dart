import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/styles.dart';

class PlaceSearchWidget extends StatefulWidget {
  final PlacesService placesService;
  final Function(gmaps.Marker) onPlaceSelected;
  final gmaps.GoogleMapController? mapController;
  final Function(String) onError;
  final bool countriesEnabled;

  const PlaceSearchWidget({
    Key? key,
    required this.placesService,
    required this.onPlaceSelected,
    required this.mapController,
    required this.onError,
    this.countriesEnabled = true,
  }) : super(key: key);

  @override
  _PlaceSearchWidgetState createState() => _PlaceSearchWidgetState();
}

class _PlaceSearchWidgetState extends State<PlaceSearchWidget> {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: AppColors.primaryColor,
      foregroundColor: Colors.white,
      onPressed: () async {
        await _showSearch(context);
      },
      tooltip: 'Search for places',
      child: const Icon(Icons.add),
    );
  }

  Future<void> _showSearch(BuildContext context) async {
    final query = await showSearch<String>(
      context: context,
      delegate: _PlaceSearchDelegate(
          widget.placesService,
          widget.onPlaceSelected,
          widget.mapController,
          widget.onError,
          widget.countriesEnabled),
    );

    // Additional logic can be added here if needed after search
  }
}

class _PlaceSearchDelegate extends SearchDelegate<String> {
  final PlacesService placesService;
  final Function(gmaps.Marker) onPlaceSelected;
  final gmaps.GoogleMapController? mapController;
  final Function(String) onError;
  final bool countriesEnabled;

  _PlaceSearchDelegate(this.placesService, this.onPlaceSelected,
      this.mapController, this.onError, this.countriesEnabled);

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
        onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) {
    return Container(); // No results view needed, as we handle selection in suggestions.
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return FutureBuilder<places.FindAutocompletePredictionsResponse>(
      future: placesService.findAutocompletePredictions(
        query,
        countriesEnabled ? ['uk'] : null,
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
                onTap: () async {
                  try {
                    final placeDetails = await placesService.fetchPlace(
                      prediction.placeId,
                      [
                        places.PlaceField.Location,
                        places.PlaceField.Name,
                        places.PlaceField.Address,
                      ],
                    );

                    final place = placeDetails.place;
                    if (place != null && place.latLng != null) {
                      final location = place.latLng!;
                      final address = place.address ?? 'No address available';

                      final marker = gmaps.Marker(
                        markerId: gmaps.MarkerId(prediction.placeId),
                        position: gmaps.LatLng(location.lat, location.lng),
                        infoWindow: gmaps.InfoWindow(
                          title: place.name ?? 'Unknown',
                          snippet: address,
                        ),
                      );

                      onPlaceSelected(marker);

                      mapController
                          ?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(
                        gmaps.LatLng(location.lat, location.lng),
                        14.0,
                      ));

                      close(context, query);
                    }
                  } catch (e) {
                    onError(e.toString());
                  }
                },
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
