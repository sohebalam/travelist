import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math';

import 'package:travelist/services/secure_storage.dart';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 3958.8; // Radius of the Earth in miles
  var dLat = (lat2 - lat1) * (pi / 180);
  var dLon = (lon2 - lon1) * (pi / 180);
  var a = sin(dLat / 2) * sin(dLon / 2) +
      cos(lat1 * (pi / 180)) *
          cos(lat2 * (pi / 180)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

Future<Map<String, String>> reverseGeocode(double lat, double lon) async {
  final storage = SecureStorage();
  String? googlePlacesApiKey = await storage.getGooglePlacesKey();
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googlePlacesApiKey');

  try {
    final response = await http.get(url);
    print('Google Places reverse geocode response: ${response.body}');

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);

      if (data['results'] != null && data['results'].isNotEmpty) {
        String formattedAddress = data['results'][0]['formatted_address'] ?? '';
        print('Formatted Address: $formattedAddress');
        return {
          'formattedAddress': formattedAddress,
        };
      }
    }
    return {'formattedAddress': 'No address available'};
  } catch (e) {
    print('Error in reverse geocoding: $e');
    throw Exception('Error in reverse geocoding');
  }
}

Future<List<Map<String, dynamic>>> fetchPOIs(
    String location, String interests) async {
  final storage = SecureStorage();
  String? openAiApiKey = await storage.getOpenAIKey();
  if (openAiApiKey == null) {
    throw Exception('OpenAI API key is missing');
  }

  List<Map<String, dynamic>> validPois = [];
  int attempts = 0;
  const int maxAttempts = 5;

  while (validPois.length < 4 && attempts < maxAttempts) {
    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    var prompt = '''
Generate a list of points of interest located within 15 miles of coordinates: $location. The POIs should be related to the following interests: $interests. 
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

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> pois =
            parsePOIs(data['choices'][0]['message']['content']);

        for (var poi in pois) {
          bool isValidPoi = await validatePoi(
              poi['name'], poi['latitude'], poi['longitude'], location);
          if (isValidPoi) {
            validPois.add(poi);
            if (validPois.length >= 4) break;
          }
        }
      } else {
        print('Failed to load POIs: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }

    attempts++;
  }

  if (validPois.isEmpty) {
    throw Exception('Locations not found, please try again');
  }

  return validPois;
}

Future<bool> validateLocation(String location) async {
  final storage = SecureStorage();
  String? googlePlacesApiKey = await storage.getGooglePlacesKey();
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

Future<bool> validatePoi(
    String name, double latitude, double longitude, String location) async {
  final storage = SecureStorage();
  String? googlePlacesApiKey = await storage.getGooglePlacesKey();
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=500&keyword=$name&key=$googlePlacesApiKey');

  try {
    final response = await http.get(url);

    // print('Google Places POI response: ${response.body}');

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      if (data['results'] != null && data['results'].isNotEmpty) {
        return true;
      } else {
        // Fallback check for name similarity
        var urlTextSearch = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$name in $location&key=$googlePlacesApiKey');
        final responseTextSearch = await http.get(urlTextSearch);

        // print('Google Places Text Search response: ${responseTextSearch.body}');

        if (responseTextSearch.statusCode == 200) {
          Map<String, dynamic> dataTextSearch =
              json.decode(responseTextSearch.body);
          if (dataTextSearch['results'] != null &&
              dataTextSearch['results'].isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false;
  } catch (e) {
    print('Error validating POI: $e');
    return false;
  }
}

Future<String> refineLocation(String location, String interests) async {
  final storage = SecureStorage();
  String? openAiApiKey = await storage.getOpenAIKey();
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
      {'role': 'user', 'content': 'Refine the location to ensure valid POIs.'}
    ],
    'max_tokens': 250,
    'temperature': 0.7,
  });

  try {
    final response = await http.post(url, headers: headers, body: body);

    // print('OpenAI refine response: ${response.body}');

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

Future<Map<String, double>> getCoordinates(String location) async {
  final storage = SecureStorage();
  String? googlePlacesApiKey = await storage.getGooglePlacesKey();
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$location&inputtype=textquery&fields=geometry&key=$googlePlacesApiKey');

  try {
    final response = await http.get(url);

    // print('Google Places coordinates response: ${response.body}');

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        var geometry = data['candidates'][0]['geometry']['location'];
        return {'lat': geometry['lat'], 'lon': geometry['lng']};
      }
    }
    throw Exception('Failed to get coordinates for location');
  } catch (e) {
    print('Error getting coordinates: $e');
    throw Exception('Error getting coordinates');
  }
}

List<Map<String, dynamic>> parsePOIs(String responseText) {
  List<Map<String, dynamic>> pois = [];
  List<String> lines = responseText.split('\n');

  for (String line in lines) {
    if (line.trim().isNotEmpty) {
      List<String> parts = line.split(' - ');
      if (parts.length == 3) {
        List<String> latLng = parts[1].split(',');
        double latitude = double.tryParse(latLng[0].trim()) ?? 0.0;
        double longitude = double.tryParse(latLng[1].trim()) ?? 0.0;
        String name = parts[0]
            .trim()
            .replaceFirst(RegExp(r'^\d+\.\s*'), ''); // Remove leading number
        pois.add({
          'name': name,
          'latitude': latitude,
          'longitude': longitude,
          'description': parts[2].trim(),
        });
      }
    }
  }
  // print('Parsed POIs: $pois');
  return pois;
}
