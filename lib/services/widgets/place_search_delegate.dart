import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:travelist/services/location/place_service.dart';

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
