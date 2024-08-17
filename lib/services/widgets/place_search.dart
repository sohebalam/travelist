import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places;
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/place_search_delegate.dart';

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
      delegate: PlaceSearchDelegate(widget.placesService),
    );

    if (query != null && query.isNotEmpty) {
      try {
        final result = await widget.placesService.findAutocompletePredictions(
          query,
          widget.countriesEnabled ? ['uk'] : null,
        );

        if (result.predictions.isNotEmpty) {
          final placeId = result.predictions.first.placeId;
          final placeDetails = await widget.placesService.fetchPlace(placeId, [
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

            final marker = gmaps.Marker(
              markerId: gmaps.MarkerId(placeId),
              position: gmaps.LatLng(location.lat, location.lng),
              infoWindow: gmaps.InfoWindow(
                title: place.name ?? 'Unknown',
                snippet: address,
              ),
              onTap: () => widget.onPlaceSelected(
                gmaps.Marker(
                  markerId: gmaps.MarkerId(placeId),
                  position: gmaps.LatLng(location.lat, location.lng),
                  infoWindow: gmaps.InfoWindow(
                    title: place.name ?? 'Unknown',
                    snippet: address,
                  ),
                ),
              ),
            );

            widget.onPlaceSelected(marker);

            widget.mapController
                ?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(
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
                      fontSize:
                          MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                              14.0,
                    ),
                  ),
                ),
              ),
            );
          }
        }
      } catch (e) {
        widget.onError(e.toString());
      }
    }
  }
}
