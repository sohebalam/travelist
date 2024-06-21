import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController locationController = TextEditingController();
  TextEditingController interestsController = TextEditingController();
  bool useCurrentLocation = false;
  List<Marker> _markers = [];
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    dotenv.load();
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
          infoWindow: InfoWindow(title: poi['name']),
        );
      }).toList();
    });

    _updateCameraPosition();
  }

  Future<List<Map<String, dynamic>>> _fetchPOIs(
      String location, String interests) async {
    String apiKey = dotenv.env['OPENAI_API_KEY']!;
    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    var prompt = '''
Generate a list of points of interest for location: $location with interests: $interests. 
For each point of interest, provide the name, latitude, and longitude in the following format:
Name, Latitude, Longitude.
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
        return pois;
      } else {
        print('Failed to load POIs: ${response.body}');
        throw Exception('Failed to load POIs');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to load POIs');
    }
  }

  List<Map<String, dynamic>> _parsePOIs(String responseText) {
    List<Map<String, dynamic>> pois = [];
    List<String> lines = responseText.split('\n');
    int id = 1;

    for (String line in lines) {
      if (line.trim().isNotEmpty) {
        List<String> parts = line.split(',');
        if (parts.length == 3) {
          double latitude = double.tryParse(parts[1].trim()) ?? 0.0;
          double longitude = double.tryParse(parts[2].trim()) ?? 0.0;
          pois.add({
            'id': id.toString(),
            'name': parts[0].trim(),
            'latitude': latitude,
            'longitude': longitude,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Travel Recommendation App'),
      ),
      body: Column(
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
                target: LatLng(51.509865, 0), // Default location
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
    );
  }
}
