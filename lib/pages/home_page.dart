import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travelist/models/poi_model.dart';
import 'package:travelist/services/auth/auth_service.dart';
import 'package:travelist/services/location/recomendations.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/pages/home_service.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/services/styles.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController locationController = TextEditingController();
  TextEditingController interestsController = TextEditingController();
  TextEditingController newListController = TextEditingController();
  final HomePageService _homePageService = HomePageService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool useCurrentLocation = false;
  bool customSearch = false;
  List<Marker> _markers = [];
  List<Map<String, dynamic>> _poiList = [];
  GoogleMapController? _mapController;
  String? _selectedListId;
  String? _selectedListName;
  bool _showNewListFields = false;
  bool _isLoading = false;
  String? _error;
  List<String> userInterests = [];

  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');
  PlacesService? _placesService;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadApiKeys();
    _loadUserInterests();
  }

  Future<void> _loadApiKeys() async {
    String? googlePlacesApiKey =
        await _secureStorage.read(key: 'GOOGLE_PLACES_API_KEY');

    if (googlePlacesApiKey == null || googlePlacesApiKey.isEmpty) {
      print('Missing API keys in secure storage');
      return;
    }

    setState(() {
      _placesService = PlacesService(googlePlacesApiKey, null);
    });
  }

  Future<void> _loadUserInterests() async {
    List<String> interests = await _homePageService.loadUserInterests();
    setState(() {
      userInterests = interests;
      if (userInterests.isEmpty) {
        customSearch = true;
      }
    });
  }

  Future<void> saveUserInterests(List<String> interests) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Debugging print to verify user ID and interests
        print("Saving interests for user ${user.uid}: $interests");

        // Set the user's interests in Firestore, merging with existing data
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'interests': interests,
        }, SetOptions(merge: true));

        print("Interests successfully saved to Firestore.");
      } catch (e) {
        // Log any errors
        print("Error saving interests: $e");
      }
    } else {
      print("No user is currently signed in.");
    }
  }

  void _addInterest(String interest) async {
    if (interest.trim().isEmpty) return; // Directly return if interest is empty

    try {
      // Convert interest to lowercase and trim spaces before adding
      String sanitizedInterest = interest.trim().toLowerCase();

      // Update the local list and Firestore
      await updateUserInterests([sanitizedInterest]);

      // Update the local state (optional, if you need to update the UI immediately)
      setState(() {
        if (!userInterests.contains(sanitizedInterest)) {
          userInterests.add(sanitizedInterest);
          // Ensure the local list does not exceed 10 items
          if (userInterests.length > 10) {
            userInterests = userInterests.sublist(0, 10);
          }
        }
      });

      // Clear the TextField
      interestsController.clear();
    } catch (e) {
      print('Error adding interest: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add interest',
            style: TextStyle(
              fontSize:
                  MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
            ),
          ),
        ),
      );
    }
  }

  Future<void> _generatePOIs({List<String>? interests}) async {
    setState(() {
      _isLoading = true;
    });

    Position? currentPosition;
    if (useCurrentLocation) {
      try {
        currentPosition = await _homePageService.determinePosition();
      } catch (e) {
        print('Error determining position: $e');
        _showErrorSnackBar('Error determining position');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    List<Map<String, dynamic>> pois = await _homePageService.generatePOIs(
      useCurrentLocation: useCurrentLocation,
      locationController: locationController,
      mapController: _mapController,
      interests: interests,
      showErrorSnackBar: _showErrorSnackBar,
      currentPosition: currentPosition,
    );

    setState(() {
      _markers = pois.map((poi) {
        return Marker(
          markerId: MarkerId('${poi['latitude']},${poi['longitude']}'),
          position: LatLng(poi['latitude'], poi['longitude']),
          infoWindow: InfoWindow(
            title: poi['name'],
            snippet: poi['description'],
            onTap: () {
              print('Marker tapped: ${poi['name']}');
              _showAddToListDialog(poi);
            },
          ),
        );
      }).toList();

      _poiList = pois;
      _isLoading = false;
    });

    _updateCameraPosition();
  }

  void _updateCameraPosition() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds bounds = _homePageService.calculateBounds(_markers);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  void _showAddToListDialog(Map<String, dynamic> poi) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return StreamBuilder<QuerySnapshot>(
              stream: _listsCollection
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                bool hasLists =
                    snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                return AlertDialog(
                  title: Text('Add POI to List'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasLists) ...[
                        SwitchListTile(
                          title: Text('Create new list'),
                          value: _showNewListFields,
                          onChanged: (value) {
                            setState(() {
                              _showNewListFields = value;
                            });
                          },
                        ),
                      ],
                      if (!hasLists || _showNewListFields) ...[
                        TextField(
                          controller: newListController,
                          decoration: InputDecoration(
                            labelText: 'Enter new list name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await createList(
                                newListController.text, _listsCollection);
                            newListController.clear();
                          },
                          child: Text('Create New List'),
                        ),
                      ],
                      if (hasLists && !_showNewListFields)
                        DropdownButton<String>(
                          hint: Text('Select List'),
                          value: _selectedListId,
                          items: snapshot.data!.docs.map((list) {
                            var listData = list.data() as Map<String, dynamic>;
                            return DropdownMenuItem<String>(
                              value: list.id,
                              child: Text(listData.containsKey('list')
                                  ? listData['list']
                                  : 'Unnamed List'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedListId = value!;
                              _selectedListName = (snapshot.data!.docs
                                  .firstWhere((element) => element.id == value)
                                  .data() as Map<String, dynamic>)['list'];
                            });
                          },
                        ),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_selectedListId != null) {
                          // Assuming `poi` is a Map<String, dynamic>
                          POI poiObject =
                              POI.fromMap(poi); // Convert map to POI

                          await _homePageService.savePOIToList(
                            selectedListId: _selectedListId,
                            poi:
                                poiObject, // Pass the POI object instead of the map
                            showErrorSnackBar: _showErrorSnackBar,
                            showSuccessSnackBar: _showSuccessSnackBar,
                          );
                          Navigator.of(context).pop();
                        } else {
                          _showErrorSnackBar('Please select a list first.');
                        }
                      },
                      child: Text('Add to List'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _savePOIToList(
      Map<String, dynamic> poi, gmaps.LatLng currentLocation) async {
    if (_selectedListId != null && !_isLoading) {
      _isLoading = true; // Set loading to true to prevent multiple triggers
      try {
        // Fetch the existing POIs from the selected list
        List<POI> existingPOIs =
            await _homePageService.fetchPOIsForList(_selectedListId);

        // Convert the map to a POI object
        POI newPOI = POI.fromMap(poi);

        // Add the new POI temporarily to the list for distance calculation
        existingPOIs.add(newPOI);

        // Sort the POIs by distance from the current location
        existingPOIs.sort((a, b) {
          final distanceA = _calculateDistance(
              currentLocation, gmaps.LatLng(a.latitude, a.longitude));
          final distanceB = _calculateDistance(
              currentLocation, gmaps.LatLng(b.latitude, b.longitude));
          return distanceA.compareTo(distanceB);
        });

        // Determine the new POI's order based on its position in the sorted list
        int newOrder = existingPOIs.indexOf(newPOI);

        // Update the POI with the correct order
        newPOI = newPOI.copyWith(order: newOrder);

        // Update the order in the original list as well (if necessary)
        for (int i = 0; i < existingPOIs.length; i++) {
          if (existingPOIs[i].id != newPOI.id) {
            existingPOIs[i] = existingPOIs[i].copyWith(order: i);
          }
        }

        // Save the new POI to the list
        await _homePageService.savePOIToList(
          selectedListId: _selectedListId,
          poi: newPOI,
          showErrorSnackBar: _showErrorSnackBar,
          showSuccessSnackBar: _showSuccessSnackBar,
        );

        // Optionally, update all POIs in the list with their new orders in the database
        for (var poi in existingPOIs) {
          if (poi.id != newPOI.id) {
            await _homePageService.updatePOIOrder(
                _selectedListId, poi.id, poi.order);
          }
        }
      } finally {
        _isLoading = false; // Ensure loading is reset after the operation
      }
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

  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _selectList(String listId) {
    setState(() {
      _selectedListId = listId;
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  LatLngBounds _calculateBounds(List<Marker> markers) {
    double southWestLat = markers.first.position.latitude;
    double southWestLng = markers.first.position.longitude;
    double northEastLat = markers.first.position.latitude;
    double northEastLng = markers.first.position.longitude;

    for (var marker in markers) {
      if (marker.position.latitude < southWestLat) {
        southWestLat = marker.position.latitude;
      }
      if (marker.position.longitude < southWestLng) {
        southWestLng = marker.position.longitude;
      }
      if (marker.position.latitude > northEastLat) {
        northEastLat = marker.position.latitude;
      }
      if (marker.position.longitude > northEastLng) {
        northEastLng = marker.position.longitude;
      }
    }

    return LatLngBounds(
      southwest: LatLng(southWestLat, southWestLng),
      northeast: LatLng(northEastLat, northEastLng),
    );
  }

  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: MediaQuery.maybeTextScalerOf(context)?.scale(14.0) ?? 14.0,
        ),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _showSearch(BuildContext context) async {
    final result = await showSearch<Map<String, String>>(
      context: context,
      delegate: PlaceSearchDelegate(_placesService!),
    );

    if (result != null && result.isNotEmpty) {
      final placeId = result['placeId'];
      final primaryText = result['primaryText'];
      final secondaryText = result['secondaryText'];

      if (placeId != null) {
        try {
          // Fetch the place details using the placeId
          final placeDetails = await _placesService!.fetchPlace(placeId, [
            places_sdk.PlaceField.Location,
            places_sdk.PlaceField.Name,
            places_sdk.PlaceField.Address,
          ]);

          final place = placeDetails.place;
          if (place != null && place.latLng != null) {
            final location = place.latLng!;
            final address =
                place.address ?? secondaryText ?? 'No address available';

            setState(() {
              _markers.add(
                gmaps.Marker(
                  markerId: gmaps.MarkerId(placeId),
                  position: gmaps.LatLng(location.lat, location.lng),
                  infoWindow: gmaps.InfoWindow(
                    title: primaryText ?? 'Unknown',
                    snippet: address,
                  ),
                  onTap: () {
                    _confirmAddPlace(
                      primaryText ?? 'Unknown',
                      location.lat,
                      location.lng,
                      address,
                    );
                  },
                ),
              );
              _mapController?.animateCamera(gmaps.CameraUpdate.newLatLngZoom(
                gmaps.LatLng(location.lat, location.lng),
                14.0,
              ));
            });

            // Show a Snackbar with a message to tap the pin
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
          print("Error in place picker: $e");
          setState(() {
            _error = e.toString();
          });
        }
      } else {
        print("No place ID found.");
      }
    }
  }

  void _confirmAddPlace(String name, double lat, double lng, String address,
      {String? description}) {
    if (lat.isNaN || lng.isNaN) {
      print('Invalid coordinates for POI: $name');
      return;
    }

    // Create a POI instance using the POI model
    final poi = POI(
      id: '', // The ID will be generated when the POI is added to Firestore
      name: name,
      latitude: lat,
      longitude: lng,
      address: address,
      order: 0, // Initial order value; this may be updated later
      description: description ?? 'No description provided',
    );

    // Convert POI object to a Map<String, dynamic> before passing it to the dialog
    _showAddToListDialog(poi.toMap());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Semantics(
                          label: "Enter location",
                          child: !useCurrentLocation
                              ? TextField(
                                  controller: locationController,
                                  decoration: InputDecoration(
                                    labelText: 'Enter location',
                                    labelStyle: TextStyle(
                                      fontSize:
                                          MediaQuery.maybeTextScalerOf(context)
                                                  ?.scale(16.0) ??
                                              16.0,
                                    ),
                                    floatingLabelBehavior:
                                        FloatingLabelBehavior.auto,
                                    border: OutlineInputBorder(),
                                  ),
                                )
                              : Container(),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Semantics(
                        label: "Use current location",
                        child: Row(
                          children: [
                            Switch(
                              activeTrackColor: AppColors.primaryColor,
                              activeColor: Colors.white,
                              value: useCurrentLocation,
                              onChanged: (value) {
                                setState(() {
                                  useCurrentLocation = value;
                                });
                              },
                            ),
                            Icon(
                              Icons.my_location,
                              color: useCurrentLocation
                                  ? AppColors.secondaryColor
                                  : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (userInterests.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            onPressed: () =>
                                _generatePOIs(interests: userInterests),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 0.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: AppColors.secondaryColor,
                                    size:
                                        MediaQuery.of(context).size.width < 360
                                            ? 14.0
                                            : 16.0,
                                  ),
                                  SizedBox(
                                    width: 5.0,
                                  ),
                                  Flexible(
                                    child: Text(
                                      'Points of interest',
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    360
                                                ? 14.0
                                                : 16.0,
                                        color: AppColors.secondaryColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Custom Search',
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 360
                                          ? 12.0
                                          : 14.0,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 5,
                            ),
                            Switch(
                              activeTrackColor: AppColors.primaryColor,
                              activeColor: Colors.white,
                              value: customSearch,
                              onChanged: (value) {
                                setState(() {
                                  customSearch = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                if (customSearch)
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Semantics(
                              label: "Enter interests",
                              child: TextField(
                                controller: interestsController,
                                decoration: InputDecoration(
                                  labelText: 'Enter interests',
                                  labelStyle: TextStyle(
                                    fontSize:
                                        MediaQuery.maybeTextScalerOf(context)
                                                ?.scale(16.0) ??
                                            16.0,
                                  ),
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (value) {
                                  print("onSubmitted triggered with: $value");
                                  _addInterest(value.trim());
                                },
                                onEditingComplete: () {
                                  print("onEditingComplete triggered");
                                  _addInterest(interestsController.text.trim());
                                },
                              )),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                // Add the interest first
                                String interest =
                                    interestsController.text.trim();
                                if (interest.isNotEmpty) {
                                  _addInterest(interest);
                                }

                                // Then generate POIs using the updated interests
                                _generatePOIs(interests: [interest]);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(48, 48),
                              ),
                              child: Semantics(
                                label: "Search for interests",
                                child: Icon(
                                  Icons.search,
                                  color: AppColors.secondaryColor,
                                  size: MediaQuery.maybeTextScalerOf(context)
                                          ?.scale(16.0) ??
                                      16.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(51.509865, -0.118092),
                      zoom: 13,
                    ),
                    markers: Set.from(_markers),
                    onMapCreated: (controller) {
                      setState(() {
                        _mapController = controller;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),
            _poiList.isNotEmpty
                ? DraggableScrollableSheet(
                    initialChildSize: 0.1,
                    minChildSize: 0.1,
                    maxChildSize: 0.8,
                    builder: (BuildContext context,
                        ScrollController scrollController) {
                      return Container(
                        color: Colors.white,
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _poiList.length,
                          itemBuilder: (BuildContext context, int index) {
                            return Semantics(
                              label:
                                  "Point of Interest: ${_poiList[index]['name']}",
                              child: ListTile(
                                title: Text(
                                  _poiList[index]['name'],
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.maybeTextScalerOf(context)
                                                ?.scale(16.0) ??
                                            16.0,
                                  ),
                                ),
                                subtitle: Text(
                                  _poiList[index]['description'],
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.maybeTextScalerOf(context)
                                                ?.scale(14.0) ??
                                            14.0,
                                  ),
                                ),
                                onTap: () {
                                  _showAddToListDialog(_poiList[index]);
                                  print('Tapped: ${_poiList[index]['name']}');
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  )
                : Container(),
            Positioned(
              top: customSearch ? 210 : 140,
              left: 10,
              child: SizedBox(
                width: 150,
                child: Semantics(
                  label: "Find nearby places",
                  child: ElevatedButton(
                    onPressed: () {
                      _showSearch(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 4.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add,
                          color: AppColors.tertiryColor,
                          size: MediaQuery.maybeTextScalerOf(context)
                                  ?.scale(16.0) ??
                              16.0,
                        ),
                        SizedBox(width: 3),
                        Text(
                          'Nearby Places',
                          style: TextStyle(
                            fontSize: MediaQuery.maybeTextScalerOf(context)
                                    ?.scale(16.0) ??
                                16.0,
                            color: AppColors.tertiryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
