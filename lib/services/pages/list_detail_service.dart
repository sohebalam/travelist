// duration_service.dart

import 'package:google_maps_directions/google_maps_directions.dart' as gmd;

class DurationService {
  final String googleMapsApiKey;
  final String transportMode;

  DurationService(this.googleMapsApiKey, this.transportMode);

  // Get duration based on transport mode
  Future<gmd.DurationValue> getDuration(
      double startLat, double startLng, double endLat, double endLng) async {
    gmd.Directions directions = await gmd.getDirections(
      startLat,
      startLng,
      endLat,
      endLng,
      language: "en",
      googleAPIKey: googleMapsApiKey,
    );

    gmd.DirectionRoute route = directions.shortestRoute;
    gmd.DurationValue drivingDuration = route.legs.first.duration;

    switch (transportMode) {
      case 'walking':
        return _durationWalking(drivingDuration);
      case 'bicycling':
        return _durationBicycling(drivingDuration);
      case 'driving':
      default:
        return drivingDuration;
    }
  }

  // Calculate duration for walking
  Future<gmd.DurationValue> _durationWalking(
      gmd.DurationValue drivingDuration) async {
    int walkingDurationSeconds = (drivingDuration.seconds * 5).toInt();
    return gmd.DurationValue(
      text: _formatDuration(walkingDurationSeconds),
      seconds: walkingDurationSeconds,
    );
  }

  // Calculate duration for bicycling
  Future<gmd.DurationValue> _durationBicycling(
      gmd.DurationValue drivingDuration) async {
    int bicyclingDurationSeconds = (drivingDuration.seconds * 2).toInt();
    return gmd.DurationValue(
      text: _formatDuration(bicyclingDurationSeconds),
      seconds: bicyclingDurationSeconds,
    );
  }

  // Format duration in hours and minutes
  String _formatDuration(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    if (hours > 0) {
      return '$hours hrs $minutes mins';
    } else {
      return '$minutes mins';
    }
  }
}
