import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth
import 'package:travelist/services/location/location_service.dart';
import 'package:travelist/services/location/place_service.dart';
import 'package:travelist/services/styles.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:travelist/services/location/poi_service.dart'; // Import POIService

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController locationController = TextEditingController();
  TextEditingController interestsController = TextEditingController();
  TextEditingController newListController = TextEditingController();
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
  final POIService _poiService = POIService();

  @override
  void initState() {
    super.initState();
    _loadEnv();
    _loadUserInterests();
  }

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

  Future<void> _loadUserInterests() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userSnapshot.exists) {
        UserModel userModel =
            UserModel.fromJson(userSnapshot.data() as Map<String, dynamic>);
        setState(() {
          userInterests = userModel.interests;
        });
      }
    }
  }

  Future<void> updateUserInterests(List<String> interests) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);
        DocumentSnapshot userSnapshot = await userDoc.get();

        if (userSnapshot.exists) {
          UserModel userModel =
              UserModel.fromJson(userSnapshot.data() as Map<String, dynamic>);
          for (String interest in interests) {
            userModel.addInterest(interest);
          }

          await userDoc.update(userModel.toJson());
        }
      }
    } catch (e) {
      print('Error updating user interests: $e');
    }
  }

  void _generatePOIs({List<String>? interests}) async {
    setState(() {
      _isLoading = true;
    });

    Position? position;

    if (useCurrentLocation) {
      try {
        position = await _determinePosition();
        if (_mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLng(
            LatLng(position.latitude, position.longitude),
          ));
        }
      } catch (e) {
        print('Error determining position: $e');
        setState(() {
          _isLoading = false;
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

    String location = useCurrentLocation && position != null
        ? '${position.latitude}, ${position.longitude}'
        : locationController.text;

    // Update user interests in Firestore
    if (interests != null && interests.isNotEmpty) {
      await updateUserInterests(interests);
    }

    print('Generating POIs for location: $location with interests: $interests');

    List<Map<String, dynamic>> pois = [];
    try {
      pois = await fetchPOIs(
          location, interests?.join(',') ?? ''); // Use the new function
    } catch (e) {
      print('Error fetching POIs: $e');
      _showErrorSnackBar('Locations not found, please try again');
    }

    print('POIs fetched: ${pois.length}');

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

  void _showAddToListDialog(Map<String, dynamic> poi) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return StreamBuilder<QuerySnapshot>(
              stream: _listsCollection.snapshots(),
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
                              _showNewListFields = value;
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
                          onPressed: () {
                            _createList(newListController.text);
                            newListController.clear();
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
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
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
                            _savePOIToList(poi);
                            Navigator.of(context).pop();
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

  void _showSuccessSnackBar(String message) {
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _selectList(String listId) {
    setState(() {
      _selectedListId = listId;
    });
  }

  void _createList(String listName) {
    if (listName.isNotEmpty) {
      _listsCollection.add({'list': listName}).then((docRef) {
        setState(() {
          _selectedListId = docRef.id;
          _selectedListName = listName;
          _showNewListFields = false;
        });
      });
    }
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

  void _updateCameraPosition() {
    if (_markers.isEmpty || _mapController == null) return;

    LatLngBounds bounds = _calculateBounds(_markers);

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
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
    final snackBar = SnackBar(content: Text(message));
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

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

  void _confirmAddPlace(
      String name, double lat, double lng, String description) {
    final poi = {
      'name': name,
      'latitude': lat,
      'longitude': lng,
      'description': description,
    };
    _showAddToListDialog(poi);
  }

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
                  ],
                ),

                // Second row: "Search by My Interests" button and "Custom Search" switch
                Row(
                  children: [
                    if (userInterests.isNotEmpty)
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
                                          2.0), // Space between icon and text
                                  const Text(
                                    'by my profile interests',
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
                                customSearch = value;
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
                          children: [
                            Expanded(
                              flex: 2,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton(
                                    onPressed: () => _generatePOIs(interests: [
                                      interestsController.text.trim()
                                    ]),
                                    child: const Icon(Icons.search,
                                        color: AppColors.secondaryColor),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),

                Expanded(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(51.509865, -0.118092), // Default location
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
              top: 200,
              left: 10,
              child: SizedBox(
                width: 150, // Adjust the width as needed
                child: ElevatedButton(
                  onPressed: () {
                    _showSearch(context);
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
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceSearchDelegate extends SearchDelegate<String> {
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
        onPressed: () => close(context, ''));
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
                onTap: () => close(context, prediction.fullText),
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

class UserModel {
  String uid;
  String email;
  String? name;
  String image;
  List<String> interests;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    this.image = '',
    this.interests = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      email: json['email'],
      name: json['name'],
      image: json.containsKey('image') ? json['image'] : '',
      interests: List<String>.from(json['interests'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'image': image,
      'interests': interests,
    };
  }

  void addInterest(String interest) {
    interest = interest.trim();
    if (!interests.any((i) => i.toLowerCase() == interest.toLowerCase())) {
      interests.insert(0, interest);
    }

    if (interests.length > 10) {
      interests = interests.sublist(0, 10);
    }
  }
}
