import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'package:location/location.dart';
import 'package:google_maps_directions/google_maps_directions.dart' as gmd;
import 'package:redacted/redacted.dart';
import 'package:travelist/models/poi_model.dart';
import 'package:travelist/services/pages/list_detail_service.dart';
import 'package:travelist/services/secure_storage.dart';
import 'package:travelist/services/styles.dart';
import 'package:travelist/services/widgets/bottom_navbar.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/widgets/reorder_dialog.dart';
import 'package:travelist/services/widgets/routepoints.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;

class ListDetailsPage extends StatefulWidget {
  final String listId;
  final String listName;

  const ListDetailsPage(
      {super.key, required this.listId, required this.listName});

  @override
  _ListDetailsPageState createState() => _ListDetailsPageState();
}

class _ListDetailsPageState extends State<ListDetailsPage> {
  gmaps.GoogleMapController? _mapController;
  List<gmaps.Marker> _markers = [];
  List<Map<String, dynamic>> _poiData = [];
  List<gmaps.LatLng> _polylinePoints = [];
  final List<gmaps.LatLng> _routePoints = [];
  final Set<gmaps.Polyline> _polylines = {};
  String? _googleMapsApiKey;
  bool _isLoading = false;
  String? _error;
  gmaps.LatLng? _currentLocation;
  final Completer<gmaps.GoogleMapController?> _controller = Completer();
  Location location = Location();
  LocationData? _currentPosition;
  StreamSubscription<LocationData>? locationSubscription;
  bool _isNavigationView = false;
  gmaps.LatLng? _navigationDestination;
  bool _userHasInteractedWithMap = false;
  List<gmd.DirectionLegStep> _navigationSteps = [];
  int _currentStepIndex = 0;
  double _currentSliderValue = 0;
  String _distanceText = '';
  String _durationText = '';
  String _transportMode = 'driving';
  final bool _countriesEnabled = true;
  final bool _locationBiasEnabled = true;
  final bool _locationRestrictionEnabled = false;
  late final PlacesService _placesService;
  late final POIService _poiService;
  places_sdk.LatLngBounds? _locationBias;
  int _selectedIndex = 1;

  DurationService? _durationService;
  gmaps.Marker? _tappedMarker; // Variable to track the selected marker
  MapsService? _mapsService;
  final UtilsService _utilsService = UtilsService();

  @override
  void initState() {
    super.initState();
    _poiService = POIService();
    _initializeGoogleMapsApiKey().then((_) {
      if (_googleMapsApiKey != null) {
        _mapsService = MapsService(_googleMapsApiKey!, _mapController);
        _durationService = DurationService(_googleMapsApiKey!, _transportMode);
        _fetchPlaces();
        _getCurrentLocation();
      } else {
        setState(() {
          _error = 'Failed to initialize API key.';
        });
      }
    });
  }

  @override
  void dispose() {
    locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeGoogleMapsApiKey() async {
    final storage = SecureStorage();
    _googleMapsApiKey = await storage.getGoogleMapsKey();

    if (_googleMapsApiKey == null) {
      setState(() {
        _error = 'Google Maps API key is missing';
      });
      return;
    }

    gmd.GoogleMapsDirections.init(googleAPIKey: _googleMapsApiKey!);
    _placesService = PlacesService(_googleMapsApiKey!, _locationBias);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Navigator.pop(context, 0);
    }
  }

  Future<void> _confirmAddPlace(
      String name, double latitude, double longitude, String address) async {
    bool shouldAdd = await _showAddPlaceDialog(name, address);

    if (shouldAdd) {
      // Convert _poiData from List<Map<String, dynamic>> to List<POI> if necessary
      List<POI> convertedPoiData = _poiData.map((data) {
        return POI(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          latitude: data['latitude'] ?? 0.0,
          longitude: data['longitude'] ?? 0.0,
          address: data['address'] ?? '',
          order: data['order'] ?? 0,
          description: data['description'],
        );
      }).toList();

      await _poiService.addNearbyPlace(
        context,
        widget.listId,
        name,
        latitude,
        longitude,
        address,
        convertedPoiData,
        _currentLocation,
        _fetchPlaces,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name has been added to your list.',
            style: TextStyle(
                fontSize:
                    MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0),
          ),
        ),
      );
    }
  }

  Future<bool> _showAddPlaceDialog(String name, String address) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Add POI'),
              content: Text('Do you want to add "$name" to your list?'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Add'),
                ),
              ],
            );
          },
        ) ??
        false; // Return false if the dialog is dismissed without choosing an option
  }

  Future<void> _fetchPlaces() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var placesSnapshot = await FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .orderBy('order')
          .get();

      List<gmaps.Marker> markers = [];
      List<Map<String, dynamic>> poiData = [];
      List<gmaps.LatLng> points = [];

      for (var place in placesSnapshot.docs) {
        var placeData = place.data();
        var position =
            gmaps.LatLng(placeData['latitude'], placeData['longitude']);
        points.add(position);
        markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(place.id),
            position: position,
            infoWindow: gmaps.InfoWindow(
              title: placeData['name'],
              snippet: placeData['address'] ?? 'No address',
              onTap: () {
                _confirmAddPlace(
                  placeData['name'],
                  placeData['latitude'],
                  placeData['longitude'],
                  placeData['address'] ?? 'No address',
                );
              },
            ),
            onTap: () {
              setState(() {
                _tappedMarker = gmaps.Marker(
                  markerId: gmaps.MarkerId(place.id),
                  position: position,
                  infoWindow: gmaps.InfoWindow(
                    title: placeData['name'],
                    snippet: placeData['address'] ?? 'No address',
                  ),
                );
              });
              _confirmAddPlace(
                placeData['name'],
                placeData['latitude'],
                placeData['longitude'],
                placeData['address'] ?? 'No address',
              );
            },
          ),
        );
        poiData.add({
          'id': place.id,
          'name': placeData['name'],
          'latitude': placeData['latitude'],
          'longitude': placeData['longitude'],
          'address': placeData['address'] ?? 'No address',
          'distance': _currentLocation != null
              ? _utilsService.calculateDistance(_currentLocation!, position)
              : double.infinity,
          'order': placeData['order'] ?? 0,
        });
      }

      setState(() {
        _markers = markers;
        _poiData = poiData;
        _polylinePoints = points;
        _isLoading = false;
      });

      if (_polylinePoints.isNotEmpty) {
        _getRoutePolyline();
        _setNearestDestination();
        if (!_userHasInteractedWithMap) {
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngBounds(
              _utilsService.calculateBounds(_polylinePoints),
              50,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _getRoutePolyline() async {
    if (_mapsService == null || _polylinePoints.length < 2) return;

    _routePoints.clear();
    _polylines.clear();

    await _mapsService!.getRoutePolyline(
      _polylinePoints,
      _polylines,
      (List<gmaps.LatLng> points) {
        setState(() {
          _routePoints.addAll(points);
        });
      },
      (gmaps.LatLngBounds bounds) {
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      },
    );

    _calculateAndDisplayDistanceDuration(_currentSliderValue.toInt());
  }

  Future<void> _navigateToSelectedLocation(
      gmaps.LatLng selectedLocation) async {
    if (_mapsService == null || _currentPosition == null) return;

    await _mapsService!.navigateToSelectedLocation(
      selectedLocation,
      _currentLocation,
      (Set<gmaps.Polyline> polylines) {
        setState(() {
          _polylines.addAll(polylines);
        });
      },
      (bool isNavigationView) {
        setState(() {
          _isNavigationView = isNavigationView;
        });
      },
      (List<gmd.DirectionLegStep> steps) {
        setState(() {
          _navigationSteps = steps;
        });
      },
      (gmaps.LatLngBounds bounds) {
        _mapController?.animateCamera(
          gmaps.CameraUpdate.newLatLngBounds(bounds, 50),
        );
      },
      location,
    );
  }

  void _showReorderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ReorderDialog(
          poiData: _poiData,
          listId: widget.listId,
          onSave: (reorderedPOIData) {
            setState(() {
              _poiData = reorderedPOIData;
            });
          },
        );
      },
    );
  }

  void _updatePOIOrderInFirestore() async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < _poiData.length; i++) {
      final poi = _poiData[i];
      final docRef = FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poi['id']);
      batch.update(docRef, {'order': i});
    }
    await batch.commit();
  }

  void _updateNavigation(LocationData currentLocation) {
    setState(() {
      _currentLocation =
          gmaps.LatLng(currentLocation.latitude!, currentLocation.longitude!);
    });

    if (_navigationSteps.isNotEmpty) {
      gmd.DirectionLegStep currentStep = _navigationSteps[_currentStepIndex];
      double distanceToNextStep = _utilsService.calculateDistance(
        _currentLocation!,
        gmaps.LatLng(
          currentStep.endLocation.lat,
          currentStep.endLocation.lng,
        ),
      );

      if (distanceToNextStep < 20) {
        if (_currentStepIndex < _navigationSteps.length - 1) {
          setState(() {
            _currentStepIndex++;
          });
        } else {
          locationSubscription?.cancel();
        }
      }
    }

    _mapController?.animateCamera(
      gmaps.CameraUpdate.newCameraPosition(
        gmaps.CameraPosition(
          target: _currentLocation!,
          zoom: 16,
        ),
      ),
    );
  }

  void _deletePOI(String poiId) async {
    try {
      await FirebaseFirestore.instance
          .collection('lists')
          .doc(widget.listId)
          .collection('pois')
          .doc(poiId)
          .delete();

      setState(() {
        _poiData.removeWhere((poi) => poi['id'] == poiId);
        _markers.removeWhere((marker) => marker.markerId.value == poiId);
        _polylinePoints.removeWhere((point) => point == poiId);
      });

      _getRoutePolyline();
      _showSuccessSnackBar('POI deleted successfully.');
    } catch (e) {
      _showErrorSnackBar('Error deleting POI.');
    }
  }

  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    final gmaps.GoogleMapController? controller = await _controller.future;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    if (permissionGranted == PermissionStatus.granted) {
      _currentPosition = await location.getLocation();
      setState(() {
        _currentLocation = gmaps.LatLng(
            _currentPosition!.latitude!, _currentPosition!.longitude!);
      });

      locationSubscription =
          location.onLocationChanged.listen((LocationData currentLocation) {
        if (!_userHasInteractedWithMap) {
          controller?.animateCamera(gmaps.CameraUpdate.newCameraPosition(
            gmaps.CameraPosition(
              target: gmaps.LatLng(
                  currentLocation.latitude!, currentLocation.longitude!),
              zoom: 16,
            ),
          ));
        }

        if (mounted) {
          setState(() {
            _currentLocation = gmaps.LatLng(
                currentLocation.latitude!, currentLocation.longitude!);
          });
        }
      });
    }
  }

  void _confirmDeletePOI(String poiId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete POI'),
          content: Text('Are you sure you want to delete this POI?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _deletePOI(poiId);
                Navigator.of(context).pop();
              },
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _toggleNavigationView() {
    setState(() {
      _isNavigationView = !_isNavigationView;
    });
  }

  void _setNearestDestination() {
    if (_currentLocation == null || _polylinePoints.isEmpty) return;

    double minDistance = double.infinity;
    gmaps.LatLng? nearestPoint;

    for (gmaps.LatLng point in _polylinePoints) {
      double distance =
          _utilsService.calculateDistance(_currentLocation!, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }

    if (nearestPoint != null) {
      setState(() {
        _navigationDestination = nearestPoint;
      });
    }
  }

  Future<void> _calculateAndDisplayDistanceDuration(int index) async {
    if (index >= _polylinePoints.length - 1) return;

    gmaps.LatLng start = _polylinePoints[index];
    gmaps.LatLng end = _polylinePoints[index + 1];

    gmd.DistanceValue distanceValue = await gmd.distance(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
      googleAPIKey: _googleMapsApiKey!,
    );

    gmd.DurationValue durationValue = await _durationService!.getDuration(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    setState(() {
      _distanceText = distanceValue.text;
      _durationText = durationValue.text;
    });
  }

  Future<void> _showPlaceSearch(BuildContext context) async {
    final result = await showSearch<Map<String, String>>(
      context: context,
      delegate: PlaceSearchDelegate(_placesService),
    );

    if (result != null && result.isNotEmpty) {
      final placeId = result['placeId'];
      final primaryText = result['primaryText'];
      final secondaryText = result['secondaryText'];

      try {
        // Fetch the place details using the placeId
        final placeDetails = await _placesService.fetchPlace(placeId!, [
          places_sdk.PlaceField.Location,
          places_sdk.PlaceField.Name,
          places_sdk.PlaceField.Address,
        ]);

        final place = placeDetails.place;
        if (place != null && place.latLng != null) {
          final location = place.latLng!;
          final address =
              place.address ?? secondaryText ?? 'No address available';

          final marker = gmaps.Marker(
            markerId: gmaps.MarkerId(placeId),
            position: gmaps.LatLng(location.lat, location.lng),
            infoWindow: gmaps.InfoWindow(
              title: primaryText ?? 'Unknown',
              snippet: address,
              onTap: () {
                _confirmAddPlace(
                  primaryText ?? 'Unknown',
                  location.lat,
                  location.lng,
                  address,
                );
              },
            ),
            onTap: () {
              _confirmAddPlace(
                primaryText ?? 'Unknown',
                location.lat,
                location.lng,
                address,
              );
            },
          );

          setState(() {
            _markers.add(marker);
          });

          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(
              gmaps.LatLng(location.lat, location.lng),
              14.0,
            ),
          );

          // Show a Snackbar after adding the marker
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Tap the pin on the map to add it to your list.',
                style: TextStyle(
                  fontSize:
                      MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ??
                          14.0,
                ),
              ),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e) {
        _showErrorSnackBar('Error fetching place details: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.listName,
          style: TextStyle(
            fontSize:
                MediaQuery.maybeTextScalerOf(context)?.scale(18.0) ?? 18.0,
          ),
        ),
      ),
      body: Semantics(
        label: 'List Details Page',
        child: _isLoading
            ? _buildLoadingSkeleton(context)
            : Stack(
                children: [
                  Semantics(
                    label: 'Map displaying points of interest',
                    child: gmaps.GoogleMap(
                      initialCameraPosition: const gmaps.CameraPosition(
                        target: gmaps.LatLng(51.509865, -0.118092),
                        zoom: 13,
                      ),
                      markers: Set.from(_markers),
                      polylines: _polylines,
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _controller.complete(controller);
                        _mapsService?.mapController = controller;
                        if (_polylinePoints.isNotEmpty &&
                            !_userHasInteractedWithMap) {
                          _mapController?.animateCamera(
                            gmaps.CameraUpdate.newLatLngBounds(
                              _utilsService.calculateBounds(_polylinePoints),
                              50,
                            ),
                          );
                        }
                      },
                      onTap: (gmaps.LatLng position) async {
                        final String name = 'New POI';
                        final String address = 'No address available';

                        setState(() {
                          final marker = gmaps.Marker(
                            markerId: gmaps.MarkerId(
                                '${position.latitude},${position.longitude}'),
                            position: position,
                            infoWindow: gmaps.InfoWindow(
                              title: name,
                              snippet: address,
                              onTap: () {
                                _confirmAddPlace(
                                  name,
                                  position.latitude,
                                  position.longitude,
                                  address,
                                );
                              },
                            ),
                          );

                          _markers.add(marker);
                        });

                        await _mapController?.showMarkerInfoWindow(
                          gmaps.MarkerId(
                              '${position.latitude},${position.longitude}'),
                        );
                      },
                      myLocationEnabled: true,
                      onCameraMove: (gmaps.CameraPosition position) {
                        _userHasInteractedWithMap = true;
                      },
                      zoomControlsEnabled: false,
                    ),
                  ),
                  if (_error != null)
                    Center(
                      child: Semantics(
                        label: 'Error message',
                        child: Text(
                          'Error: $_error',
                          style: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(14.0) ??
                                14.0,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Semantics(
                      label: 'Navigate to nearest location button',
                      child: FloatingActionButton(
                        backgroundColor: AppColors.primaryColor,
                        foregroundColor: Colors.white,
                        onPressed: () async {
                          // Ensure we have the nearest destination set
                          if (_navigationDestination == null) {
                            _setNearestDestination();
                          }

                          if (_navigationDestination != null) {
                            final url =
                                'google.navigation:q=${_navigationDestination!.latitude},${_navigationDestination!.longitude}&key=$_googleMapsApiKey';
                            final uri = Uri.parse(url);

                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            } else {
                              _showErrorSnackBar(
                                  'Could not launch Google Maps for navigation.');
                            }
                          } else {
                            _showErrorSnackBar(
                                'No destination found for navigation.');
                          }
                        },
                        tooltip: 'Navigate to the nearest location',
                        child: const Icon(Icons.navigation_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 80,
                    right: 10,
                    child: Column(
                      children: [
                        Semantics(
                          label: 'Zoom in button',
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.tertiryColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              iconSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(20.0) ??
                                  20.0,
                              color: Colors.black87,
                              onPressed: () {
                                _mapController?.animateCamera(
                                    gmaps.CameraUpdate.zoomIn());
                              },
                              tooltip: 'Zoom in',
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Semantics(
                          label: 'Zoom out button',
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.tertiryColor,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.remove),
                              iconSize: MediaQuery.maybeTextScalerOf(context)
                                      ?.scale(20.0) ??
                                  20.0,
                              color: Colors.black87,
                              onPressed: () {
                                _mapController?.animateCamera(
                                    gmaps.CameraUpdate.zoomOut());
                              },
                              tooltip: 'Zoom out',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: FloatingActionButton(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      onPressed: () async {
                        await _showPlaceSearch(context);
                      },
                      tooltip: 'Search for places',
                      child: const Icon(Icons.add_location_alt),
                    ),
                  ),
                  DraggableRoutePointsSheet(
                    poiData: _poiData,
                    polylinePoints: _polylinePoints,
                    currentSliderValue: _currentSliderValue,
                    distanceText: _distanceText,
                    durationText: _durationText,
                    transportMode: _transportMode,
                    calculateAndDisplayDistanceDuration:
                        _calculateAndDisplayDistanceDuration,
                    confirmDeletePOI: _confirmDeletePOI,
                    showReorderDialog: _showReorderDialog,
                    setTransportMode: (String mode) {
                      setState(() {
                        _transportMode = mode;
                        _durationService =
                            DurationService(_googleMapsApiKey!, _transportMode);
                        _getRoutePolyline();
                      });
                    },
                  ),
                ],
              ),
      ),
      bottomNavigationBar: Semantics(
        label: 'Bottom navigation bar',
        child: BottomNavBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
          onLogoutTapped: () {},
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: 'Loading skeleton',
            child: Container().redacted(
              context: context,
              redact: true,
              configuration: RedactedConfiguration(
                animationDuration: const Duration(milliseconds: 800),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
