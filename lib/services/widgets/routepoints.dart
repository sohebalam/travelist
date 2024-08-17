import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:travelist/services/styles.dart';

class DraggableRoutePointsSheet extends StatelessWidget {
  final List<Map<String, dynamic>> poiData;
  final List<gmaps.LatLng> polylinePoints;
  final double currentSliderValue;
  final String distanceText;
  final String durationText;
  final String transportMode;
  final Function(int) calculateAndDisplayDistanceDuration;
  final Function(String) confirmDeletePOI;
  final Function() showReorderDialog;
  final Function(String) setTransportMode;

  const DraggableRoutePointsSheet({
    Key? key,
    required this.poiData,
    required this.polylinePoints,
    required this.currentSliderValue,
    required this.distanceText,
    required this.durationText,
    required this.transportMode,
    required this.calculateAndDisplayDistanceDuration,
    required this.confirmDeletePOI,
    required this.showReorderDialog,
    required this.setTransportMode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.1,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'List of route points',
                  child: Text(
                    'Route Points:',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                              16.0,
                    ),
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  controller: scrollController,
                  itemCount: poiData.length,
                  itemBuilder: (BuildContext context, int index) {
                    double textSize = poiData.length > 7
                        ? MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                            14.0
                        : MediaQuery.maybeTextScalerOf(context)?.scale(16.0) ??
                            16.0;

                    String shortAddress = poiData[index]['address']
                        .split(',')
                        .reversed
                        .take(2)
                        .join(', ');

                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 0),
                      child: ListTile(
                        dense: true,
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 0, horizontal: 4.0),
                        visualDensity: VisualDensity.compact,
                        minVerticalPadding: 0,
                        title: Semantics(
                          label: 'Route point name',
                          child: Text(
                            '${index + 1}. ${poiData[index]['name']}',
                            style: TextStyle(
                              fontSize: textSize,
                            ),
                          ),
                        ),
                        subtitle: Semantics(
                          label: 'Route point address',
                          child: Text(
                            shortAddress,
                            style: TextStyle(fontSize: textSize - 2),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete),
                              color: AppColors.primaryColor,
                              onPressed: () {
                                confirmDeletePOI(poiData[index]['id']);
                              },
                            ),
                            const Icon(Icons.drag_handle),
                          ],
                        ),
                        onTap: showReorderDialog,
                      ),
                    );
                  },
                ),
                if (polylinePoints.length > 1)
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: 'Slider to adjust route point display',
                          child: Slider(
                            value: currentSliderValue,
                            min: 0,
                            max: (polylinePoints.length - 1).toDouble(),
                            divisions: polylinePoints.length - 1,
                            label: (currentSliderValue + 1).round().toString(),
                            onChanged: (double value) {
                              calculateAndDisplayDistanceDuration(
                                  value.toInt());
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Distance to next point',
                          child: Text(
                            'Distance: $distanceText',
                            style: TextStyle(
                              fontSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(14.0) ??
                                  14.0,
                            ),
                          ),
                        ),
                        Semantics(
                          label: 'Duration to next point',
                          child: Text(
                            'Duration: $durationText',
                            style: TextStyle(
                              fontSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(14.0) ??
                                  14.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Semantics(
                          label: 'Driving mode button',
                          child: IconButton(
                            icon: const Icon(Icons.directions_car),
                            onPressed: () => setTransportMode('driving'),
                            color: transportMode == 'driving'
                                ? Colors.blue
                                : Colors.grey,
                            iconSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(20.0) ??
                                20.0,
                          ),
                        ),
                        Semantics(
                          label: 'Walking mode button',
                          child: IconButton(
                            icon: const Icon(Icons.directions_walk),
                            onPressed: () => setTransportMode('walking'),
                            color: transportMode == 'walking'
                                ? Colors.blue
                                : Colors.grey,
                            iconSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(20.0) ??
                                20.0,
                          ),
                        ),
                        Semantics(
                          label: 'Bicycling mode button',
                          child: IconButton(
                            icon: const Icon(Icons.directions_bike),
                            onPressed: () => setTransportMode('bicycling'),
                            color: transportMode == 'bicycling'
                                ? Colors.blue
                                : Colors.grey,
                            iconSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(20.0) ??
                                20.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
