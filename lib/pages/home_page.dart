// Importing necessary packages for Flutter, Google Maps, Firebase, and other services, and components and shared functions.
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:travelist/services/auth/auth_service.dart';
import 'package:travelist/services/location/location_service.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/shared_functions.dart';
import 'package:travelist/services/styles.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:travelist/services/location/poi_service.dart';
import 'package:travelist/services/widgets/place_search_delegate.dart';

// HomePage is a stateful widget that displays the main screen of the app
class HomePage extends StatefulWidget {
  const HomePage({super.key}); // Constructor for HomePage

  @override
  _HomePageState createState() => _HomePageState(); // Create state for HomePage
}

// State class for HomePage
class _HomePageState extends State<HomePage> {
  // Controllers for handling input fields
  TextEditingController locationController = TextEditingController();
  TextEditingController interestsController = TextEditingController();
  TextEditingController newListController = TextEditingController();

  // Variables to manage various states in the UI
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

  // Firebase Firestore collection reference for storing lists
  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');
  PlacesService?
      _placesService; // Service for handling place-related operations
  final POIService _poiService = POIService(); // Service for handling POIs

  // Initialize state and load necessary data
  @override
  void initState() {
    super.initState();
    _loadEnv(); // Load environment variables
    _loadUserInterests(); // Load user interests from Firestore
  }

  // Load environment variables, including API keys
  Future<void> _loadEnv() async {
    await dotenv.load();
    String? apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      print('Missing API keys in .env file');
      return;
    }
    setState(() {
      _placesService = PlacesService(apiKey, null);
    });
  }

  // Load user interests from Firestore
  Future<void> _loadUserInterests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      List<String> interests = await AuthService().getUserInterests(user);
      setState(() {
        userInterests = interests;
        if (userInterests.isEmpty) {
          customSearch = true;
        }
      });
    }
  }

  // Generate POIs based on user's location or custom input
  void _generatePOIs({List<String>? interests}) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    // Check if a location is provided or the user's current location is available
    if (!useCurrentLocation && locationController.text.isEmpty) {
      _showErrorSnackBar('Please enter a location');
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
      return;
    }

    Position? position;

    if (useCurrentLocation) {
      try {
        position = await _determinePosition(); // Get user's current position
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ));
        }
      } catch (e) {
        print('Error determining position: $e');
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
        _showErrorSnackBar('Error determining position');
        return;
      }
    } else {
      String location = locationController.text;
      List<String> latLng = location.split(',');
      if (latLng.length == 2) {
        double latitude = double.tryParse(latLng[0].trim()) ?? 0.0;
        double longitude = double.tryParse(latLng[1].trim()) ?? 0.0;
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(
            LatLng(latitude, longitude),
          ));
        }
      }
    }

    // Determine the location string to be used in POI search
    String location = useCurrentLocation && position != null
        ? '${position.latitude}, ${position.longitude}'
        : locationController.text;

    // Update user interests in Firestore only if it's from custom search
    if (customSearch && interests != null && interests.isNotEmpty) {
      await updateUserInterests(interests);
    }

    List<Map<String, dynamic>> pois = [];
    try {
      pois = await fetchPOIs(
          location,
          interests?.join(',') ??
              ''); // Fetch POIs based on location and interests
    } catch (e) {
      print('Error fetching POIs: $e');
      _showErrorSnackBar('Locations not found, please try again');
    }

    setState(() {
      // Convert POIs to markers for displaying on the map
      _markers = pois.map((poi) {
        return Marker(
          markerId: MarkerId('${poi['latitude']},${poi['longitude']}'),
          position: LatLng(poi['latitude'], poi['longitude']),
          infoWindow: InfoWindow(
            title: poi['name'],
            snippet: poi['description'],
            onTap: () {
              print('Marker tapped: ${poi['name']}');
              _showAddToListDialog(poi); // Show dialog to add POI to list
            },
          ),
        );
      }).toList();

      _poiList = pois; // Store the list of POIs
      _isLoading = false; // Hide loading indicator
    });

    _updateCameraPosition(); // Update the camera position on the map
  }

  // Show a dialog to add a POI to a list
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
                  title: const Text('Add POI to List'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasLists) ...[
                        SwitchListTile(
                          title: const Text('Create new list'),
                          value: _showNewListFields,
                          onChanged: (value) {
                            setState(() {
                              _showNewListFields =
                                  value; // Toggle new list fields visibility
                            });
                          },
                        ),
                      ],
                      if (!hasLists || _showNewListFields) ...[
                        TextField(
                          controller: newListController,
                          decoration: const InputDecoration(
                            labelText: 'Enter new list name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            await createList(
                                newListController.text, _listsCollection);
                            newListController.clear(); // Clear input field
                          },
                          child: const Text('Create New List'),
                        ),
                      ],
                      if (hasLists && !_showNewListFields)
                        DropdownButton<String>(
                          hint: const Text('Select List'),
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
                        Navigator.of(context).pop(); // Close the dialog
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_selectedListId != null) {
                          final listDoc =
                              await _listsCollection.doc(_selectedListId).get();
                          final poiCollectionRef = _listsCollection
                              .doc(_selectedListId)
                              .collection('pois');
                          final poiCount =
                              (await poiCollectionRef.get()).docs.length;

                          if (poiCount >= 10) {
                            _showErrorSnackBar(
                                'This list already has 10 POIs.');
                          } else {
                            _savePOIToList(
                                poi); // Save the POI to the selected list
                            Navigator.of(context).pop(); // Close the dialog
                          }
                        }
                      },
                      child: const Text('Add to List'),
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

  // Save a POI to the selected list
  void _savePOIToList(Map<String, dynamic> poi) async {
    if (_selectedListId != null) {
      try {
        final listDocRef = _listsCollection.doc(_selectedListId);
        final poiCollectionRef = listDocRef.collection('pois');

        // Add the new POI to the pois subcollection
        await poiCollectionRef.add(poi);

        _showSuccessSnackBar('POI added to list successfully.');
      } catch (e) {
        print('Error saving POI to list: $e');
        _showErrorSnackBar('Error saving POI to list.');
      }
    }
  }

  // Show a success message using a Snackbar
  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Select a list to add POIs to
  void _selectList(String listId) {
    setState(() {
      _selectedListId = listId; // Set the selected list ID
    });
  }

  // Determine the user's current position using Geolocator
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // Check for location permissions
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

    return await Geolocator.getCurrentPosition(); // Get the current position
  }

  // Update the camera position to show all markers on the map
  void _updateCameraPosition() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds bounds = _calculateBounds(_markers); // Calculate map bounds

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
          bounds, 50), // Animate the camera to show all markers
    );
  }

  // Calculate the bounds of the map to fit all markers
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

  // Show an error message using a Snackbar
  void _showErrorSnackBar(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Show the place search dialog
  void _showSearch(BuildContext context) async {
    final query = await showSearch<String>(
      context: context,
      delegate: PlaceSearchDelegate(_placesService!),
    );

    if (query != null && query.isNotEmpty) {
      try {
        final result = await _placesService!.findAutocompletePredictions(
          query,
          null,
        );

        if (result.predictions.isNotEmpty) {
          final placeId = result.predictions.first.placeId;
          final placeDetails = await _placesService!.fetchPlace(placeId, [
            places_sdk.PlaceField.Location,
            places_sdk.PlaceField.Name,
            places_sdk.PlaceField.Address,
          ]);

          final place = placeDetails.place;
          if (place != null && place.latLng != null) {
            final location = place.latLng!;
            final address = place.address ?? 'No address available';

            setState(() {
              // Add a marker for the selected place
              _markers.add(
                Marker(
                  markerId: MarkerId(placeId),
                  position: LatLng(location.lat, location.lng),
                  infoWindow: InfoWindow(
                    title: place.name ?? 'Unknown',
                    snippet: address,
                  ),
                  onTap: () => _confirmAddPlace(
                    place.name ?? 'Unknown',
                    location.lat,
                    location.lng,
                    address,
                  ),
                ),
              );
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                LatLng(location.lat, location.lng),
                14.0,
              ));
            });
          }
        } else {
          print("No predictions found.");
        }
      } catch (e) {
        print("Error in place picker: $e");
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  // Confirm adding a place to the list
  void _confirmAddPlace(
      String name, double lat, double lng, String description) {
    final poi = {
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'description': description,
    };
    _showAddToListDialog(poi); // Show dialog to add the place to a list
  }

  // Build method to create the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // First row: Location input and "Use My Location" switch
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: !useCurrentLocation
                            ? TextField(
                                controller: locationController,
                                decoration: const InputDecoration(
                                  labelText: 'Enter location',
                                  floatingLabelBehavior:
                                      FloatingLabelBehavior.auto,
                                  border: OutlineInputBorder(),
                                ),
                              )
                            : Container(), // Empty container to maintain layout
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Switch(
                            activeTrackColor: AppColors.primaryColor,
                            activeColor: Colors.white,
                            value: useCurrentLocation,
                            onChanged: (value) {
                              setState(() {
                                useCurrentLocation =
                                    value; // Toggle use current location
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
                  ],
                ),

                // Second row: "Search by My Interests" button and "Custom Search" switch
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
                              padding:
                                  EdgeInsets.zero, // Remove default padding
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 0.0), // Add custom padding
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search,
                                      color: AppColors.secondaryColor),
                                  const SizedBox(
                                      width:
                                          5.0), // Space between icon and text
                                  const Text(
                                    'Points of interest',
                                    style: TextStyle(
                                        color: AppColors.secondaryColor),
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
                            const Text('Custom Search'),
                            SizedBox(
                              width: 5,
                            ),
                            Switch(
                              activeTrackColor: AppColors.primaryColor,
                              activeColor: Colors.white,
                              value: customSearch,
                              onChanged: (value) {
                                setState(() {
                                  customSearch = value; // Toggle custom search
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Third row: Custom search field and search button
                if (customSearch)
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: TextField(
                            controller: interestsController,
                            decoration: const InputDecoration(
                              labelText: 'Enter interests',
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () => _generatePOIs(
                                  interests: [interestsController.text.trim()]),
                              child: const Icon(Icons.search,
                                  color: AppColors.secondaryColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Google Map widget to display the map and markers
                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(51.509865, -0.118092), // Default location
                      zoom: 13,
                    ),
                    markers: Set.from(_markers), // Set of markers on the map
                    onMapCreated: (controller) {
                      setState(() {
                        _mapController = controller; // Set the map controller
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(), // Show loading indicator
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
                            return ListTile(
                              title: Text(_poiList[index]['name']),
                              subtitle: Text(_poiList[index]['description']),
                              onTap: () {
                                _showAddToListDialog(_poiList[index]);
                                print('Tapped: ${_poiList[index]['name']}');
                              },
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
                width: 150, // Adjust the width as needed
                child: ElevatedButton(
                  onPressed: () {
                    _showSearch(context); // Show the place search dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10.0,
                        vertical: 4.0), // Adjust padding as needed
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add,
                        color: AppColors.tertiryColor,
                      ),
                      SizedBox(width: 3),
                      Text(
                        'Nearby Places',
                        style: TextStyle(
                          color:
                              AppColors.tertiryColor, // Change text color here
                        ),
                      ),
                    ],
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
