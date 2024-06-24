import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:travelist/lists.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController locationController = TextEditingController();
  TextEditingController interestsController = TextEditingController();
  TextEditingController newListController = TextEditingController();
  bool useCurrentLocation = false;
  List<Marker> _markers = [];
  List<Map<String, dynamic>> _poiList = [];
  GoogleMapController? _mapController;
  String? _selectedListId;
  String? _selectedListName;
  bool _showNewListFields = false;

  final CollectionReference _listsCollection =
      FirebaseFirestore.instance.collection('lists');

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadEnv();
  }

  Future<void> _loadEnv() async {
    await dotenv.load();
    if (dotenv.env['GOOGLE_PLACES_API_KEY'] == null ||
        dotenv.env['OPENAI_API_KEY'] == null) {
      print('Missing API keys in .env file');
    }
  }

  void _generatePOIs() async {
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

    String location = useCurrentLocation
        ? '${position?.latitude}, ${position?.longitude}'
        : locationController.text;
    String interests = interestsController.text;

    print('Generating POIs for location: $location with interests: $interests');

    List<Map<String, dynamic>> pois = await _fetchPOIs(location, interests);

    print('POIs fetched: ${pois.length}');

    setState(() {
      _markers = pois.map((poi) {
        return Marker(
          markerId: MarkerId(poi['id']),
          position: LatLng(poi['latitude'], poi['longitude']),
          infoWindow: InfoWindow(
            title: poi['name'],
            snippet: poi['description'],
            onTap: () => _showAddToListDialog(poi),
          ),
        );
      }).toList();

      _poiList = pois;
    });

    _updateCameraPosition();
  }

  Future<List<Map<String, dynamic>>> _fetchPOIs(
      String location, String interests) async {
    bool isValidLocation = await _validateLocation(location);

    if (!isValidLocation) {
      print('Invalid location: $location. Requesting refinement from OpenAI.');
      // If the location is not valid, make another call to OpenAI to refine the search
      location = await _refineLocation(location, interests);
      isValidLocation = await _validateLocation(location);
      if (!isValidLocation) {
        throw Exception('Invalid location provided and refinement failed.');
      }
    }

    String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
    if (openAiApiKey == null) {
      throw Exception('OpenAI API key is missing');
    }

    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    var prompt = '''
Generate a list of points of interest for location: $location with interests: $interests. 
For each point of interest, provide the name, latitude, longitude, and a short description in the following format:
Name - Latitude, Longitude - Description.
''';

    var body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': prompt},
      ],
      'max_tokens': 150,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        print('Data received: ${data}');
        List<Map<String, dynamic>> pois =
            _parsePOIs(data['choices'][0]['message']['content']);

        // Validate each POI
        List<Map<String, dynamic>> validPois = [];
        for (var poi in pois) {
          bool isValidPoi = await _validatePoi(
              poi['name'], poi['latitude'], poi['longitude']);
          print('POI validation result for ${poi['name']}: $isValidPoi');
          if (isValidPoi) {
            validPois.add(poi);
          }
        }

        print('Valid POIs: ${validPois.length}');
        return validPois;
      } else {
        print('Failed to load POIs: ${response.body}');
        throw Exception('Failed to load POIs');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load POIs');
    }
  }

  Future<bool> _validateLocation(String location) async {
    String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (googlePlacesApiKey == null) {
      throw Exception('Google Places API key is missing');
    }

    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$location&inputtype=textquery&key=$googlePlacesApiKey');

    try {
      final response = await http.get(url);

      print('Google Places response: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error validating location: $e');
      return false;
    }
  }

  Future<bool> _validatePoi(
      String name, double latitude, double longitude) async {
    String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (googlePlacesApiKey == null) {
      throw Exception('Google Places API key is missing');
    }

    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=50&keyword=$name&key=$googlePlacesApiKey');

    try {
      final response = await http.get(url);

      print('Google Places POI response: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error validating POI: $e');
      return false;
    }
  }

  Future<String> _refineLocation(String location, String interests) async {
    String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
    if (openAiApiKey == null) {
      throw Exception('OpenAI API key is missing');
    }

    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    var prompt = '''
The location "$location" could not be validated. Suggest an alternative or correct it based on the following interests: $interests.
''';

    var body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': prompt},
      ],
      'max_tokens': 50,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      print('OpenAI refine response: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        return data['choices'][0]['message']['content'].trim();
      } else {
        print('Failed to refine location: ${response.body}');
        throw Exception('Failed to refine location');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to refine location');
    }
  }

  List<Map<String, dynamic>> _parsePOIs(String responseText) {
    List<Map<String, dynamic>> pois = [];
    List<String> lines = responseText.split('\n');
    int id = 1;

    for (String line in lines) {
      if (line.trim().isNotEmpty) {
        List<String> parts = line.split(' - ');
        if (parts.length == 3) {
          List<String> latLng = parts[1].split(',');
          double latitude = double.tryParse(latLng[0].trim()) ?? 0.0;
          double longitude = double.tryParse(latLng[1].trim()) ?? 0.0;
          pois.add({
            'id': id.toString(),
            'name': parts[0].trim(),
            'latitude': latitude,
            'longitude': longitude,
            'description': parts[2].trim(),
          });
          id++;
        }
      }
    }
    print('Parsed POIs: $pois');
    return pois;
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
                          onPressed: () {
                            _createList(newListController.text);
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
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _savePOIToList(poi);
                        Navigator.of(context).pop();
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

  void _savePOIToList(Map<String, dynamic> poi) {
    if (_selectedListId != null) {
      _listsCollection.doc(_selectedListId).collection('pois').add({
        'name': poi['name'],
        'latitude': poi['latitude'],
        'longitude': poi['longitude'],
        'description': poi['description']
      });
    }
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ListsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel Recommendation App'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Row(
                children: [
                  Checkbox(
                    value: useCurrentLocation,
                    onChanged: (value) {
                      setState(() {
                        useCurrentLocation = value!;
                      });
                    },
                  ),
                  Text('Use current location')
                ],
              ),
              if (!useCurrentLocation)
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(labelText: 'Enter location'),
                ),
              TextField(
                controller: interestsController,
                decoration: InputDecoration(labelText: 'Enter interests'),
              ),
              ElevatedButton(
                onPressed: _generatePOIs,
                child: Text('Generate POIs'),
              ),
              Expanded(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
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
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Lists',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
    );
  }
}
