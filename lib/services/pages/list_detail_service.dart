// duration_service.dart

import 'package:flutter/material.dart';
import 'package:google_maps_directions/google_maps_directions.dart' as gmd;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:location/location.dart';
import 'dart:async';

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

class UtilsService {
  gmaps.LatLng calculateCentroid(List<gmaps.LatLng> points) {
    double latSum = 0;
    double lngSum = 0;

    for (var point in points) {
      latSum += point.latitude;
      lngSum += point.longitude;
    }

    return gmaps.LatLng(latSum / points.length, lngSum / points.length);
  }

  gmaps.LatLngBounds calculateBounds(List<gmaps.LatLng> points) {
    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) {
        southWestLat = point.latitude;
      }
      if (point.longitude < southWestLng) {
        southWestLng = point.longitude;
      }
      if (point.latitude > northEastLat) {
        northEastLat = point.latitude;
      }
      if (point.longitude > northEastLng) {
        northEastLng = point.longitude;
      }
    }

    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(southWestLat, southWestLng),
      northeast: gmaps.LatLng(northEastLat, northEastLng),
    );
  }

  double calculateDistance(gmaps.LatLng start, gmaps.LatLng end) {
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

class MapsService {
  final String googleMapsApiKey;
  late final gmaps.GoogleMapController? mapController;

  MapsService(this.googleMapsApiKey, this.mapController);

  Future<void> getRoutePolyline(
    List<gmaps.LatLng> polylinePoints,
    Set<gmaps.Polyline> polylines,
    Function(List<gmaps.LatLng>) updateRoutePoints,
    Function(gmaps.LatLngBounds) updateCameraBounds,
  ) async {
    List<gmaps.LatLng> routePoints = [];

    for (int i = 0; i < polylinePoints.length - 1; i++) {
      gmaps.LatLng start = polylinePoints[i];
      gmaps.LatLng end = polylinePoints[i + 1];

      gmd.Directions directions = await gmd.getDirections(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
        language: "en",
        googleAPIKey: googleMapsApiKey,
      );

      gmd.DirectionRoute route = directions.shortestRoute;
      List<gmaps.LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => gmaps.LatLng(point.latitude, point.longitude))
          .toList();

      routePoints.addAll(points);
    }

    polylines.add(
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        color: Colors.blue,
        width: 5,
        points: routePoints,
      ),
    );

    updateRoutePoints(routePoints);

    if (routePoints.isNotEmpty) {
      gmaps.LatLngBounds bounds = calculateBounds(routePoints);
      mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
      );
      updateCameraBounds(bounds);
    }
  }

  Future<void> navigateToSelectedLocation(
    gmaps.LatLng selectedLocation,
    gmaps.LatLng? currentLocation,
    Function(Set<gmaps.Polyline>) updatePolylines,
    Function(bool) setIsNavigationView,
    Function(List<gmd.DirectionLegStep>) setNavigationSteps,
    Function(gmaps.LatLngBounds) updateCameraBounds,
    Location location,
  ) async {
    if (currentLocation == null) return;

    final directions = await gmd.getDirections(
      currentLocation.latitude,
      currentLocation.longitude,
      selectedLocation.latitude,
      selectedLocation.longitude,
      googleAPIKey: googleMapsApiKey,
    );

    if (directions.routes.isNotEmpty) {
      final route = directions.shortestRoute;
      final steps = route.shortestLeg.steps;
      List<gmaps.LatLng> points = PolylinePoints()
          .decodePolyline(route.overviewPolyline.points)
          .map((point) => gmaps.LatLng(point.latitude, point.longitude))
          .toList();

      updatePolylines({
        gmaps.Polyline(
          polylineId: const gmaps.PolylineId('navigation_route'),
          color: Colors.green,
          width: 5,
          points: points,
        ),
      });

      setIsNavigationView(true);
      setNavigationSteps(steps);

      gmaps.LatLngBounds bounds = calculateBounds(points);
      mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
      );
      updateCameraBounds(bounds);

      location.onLocationChanged.listen((LocationData currentLocation) {
        // Update navigation logic here
      });
    } else {
      throw Exception('Failed to fetch directions');
    }
  }

  gmaps.LatLngBounds calculateBounds(List<gmaps.LatLng> points) {
    double southWestLat = points.first.latitude;
    double southWestLng = points.first.longitude;
    double northEastLat = points.first.latitude;
    double northEastLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < southWestLat) {
        southWestLat = point.latitude;
      }
      if (point.longitude < southWestLng) {
        southWestLng = point.longitude;
      }
      if (point.latitude > northEastLat) {
        northEastLat = point.latitude;
      }
      if (point.longitude > northEastLng) {
        northEastLng = point.longitude;
      }
    }

    return gmaps.LatLngBounds(
      southwest: gmaps.LatLng(southWestLat, southWestLng),
      northeast: gmaps.LatLng(northEastLat, northEastLng),
    );
  }
}
