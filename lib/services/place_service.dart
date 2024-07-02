import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

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
