import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this line to import the dotenv package

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  List<Map<String, String>> _poiList = [];
  bool _useCurrentLocation = false;

  Future<void> _generatePOIs(String location, List<String> tags) async {
    String tagsString = tags.join(", ");
    String prompt =
        "Give me a list of tourist attractions in $location that include $tagsString.";
    String apiKey =
        dotenv.env['OPENAI_API_KEY']!; // Use the environment variable

    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };

    var body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': prompt},
      ],
      'max_tokens': 150,
      'temperature': 0.7,
    });

    try {
      var response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        String fullResponse = data['choices'][0]['message']['content'];

        // Parsing the response based on the specified format
        List<Map<String, String>> poiList =
            fullResponse.split('\n').map((line) {
          List<String> parts = line.split(' - ');
          if (parts.length > 1) {
            return {'title': parts[0].trim(), 'description': parts[1].trim()};
          } else {
            return {'title': parts[0].trim(), 'description': ''};
          }
        }).toList();

        setState(() {
          _poiList = poiList;
        });
      } else {
        setState(() {
          _poiList = [
            {'title': 'Failed to generate POIs', 'description': ''}
          ];
        });
      }
    } catch (e) {
      setState(() {
        _poiList = [
          {'title': 'Error: $e', 'description': ''}
        ];
      });
    }
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _poiList = [
          {'title': 'Location services are disabled.', 'description': ''}
        ];
      });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _poiList = [
            {'title': 'Location permissions are denied', 'description': ''}
          ];
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _poiList = [
          {
            'title':
                'Location permissions are permanently denied, we cannot request permissions.',
            'description': ''
          }
        ];
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    String location = '${position.latitude},${position.longitude}';
    List<String> tags =
        _tagsController.text.split(',').map((tag) => tag.trim()).toList();
    await _generatePOIs(location, tags);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POI Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CheckboxListTile(
              title: Text('Use current location'),
              value: _useCurrentLocation,
              onChanged: (bool? value) {
                setState(() {
                  _useCurrentLocation = value ?? false;
                });
              },
            ),
            if (!_useCurrentLocation)
              TextField(
                controller: _locationController,
                decoration: InputDecoration(labelText: 'Enter a location'),
              ),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                  labelText: 'Enter interests (comma separated)'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_useCurrentLocation) {
                  _determinePosition();
                } else {
                  List<String> tags = _tagsController.text
                      .split(',')
                      .map((tag) => tag.trim())
                      .toList();
                  _generatePOIs(_locationController.text, tags);
                }
              },
              child: Text('Generate POIs'),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _poiList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(_poiList[index]['title']!),
                    subtitle: Text(_poiList[index]['description']!),
                    onTap: () {
                      print('Clicked: ${_poiList[index]['title']}');
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
