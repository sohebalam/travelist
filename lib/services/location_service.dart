import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<List<Map<String, dynamic>>> fetchPOIs(
    String location, String interests) async {
  bool isValidLocation = await validateLocation(location);

  if (!isValidLocation) {
    print('Invalid location: $location. Requesting refinement from OpenAI.');
    // If the location is not valid, make another call to OpenAI to refine the search
    location = await refineLocation(location, interests);
    isValidLocation = await validateLocation(location);
    if (!isValidLocation) {
      throw Exception('Invalid location provided and refinement failed.');
    }
  }

  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  if (openAiApiKey == null) {
    throw Exception('OpenAI API key is missing');
  }

  List<Map<String, dynamic>> validPois = [];
  int attempts = 0;
  const int maxAttempts = 5;

  while (validPois.length < 4 && attempts < maxAttempts) {
    String additionalPrompt = '';
    if (interests.toLowerCase().contains('food')) {
      additionalPrompt = ' Include restaurants in the list.';
    }

    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    var prompt = '''
Generate a list of points of interest for location: $location with interests: $interests.$additionalPrompt
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
            parsePOIs(data['choices'][0]['message']['content']);

        // Validate each POI
        for (var poi in pois) {
          bool isValidPoi =
              await validatePoi(poi['name'], poi['latitude'], poi['longitude']);
          print('POI validation result for ${poi['name']}: $isValidPoi');
          if (isValidPoi) {
            // Ensure uniqueness of POIs
            if (!validPois
                .any((existingPoi) => existingPoi['name'] == poi['name'])) {
              validPois.add(poi);
              if (validPois.length >= 4) break;
            }
          }
        }

        print('Valid POIs: ${validPois.length}');
      } else {
        print('Failed to load POIs: ${response.body}');
      }
    } catch (e) {
      print('Error: $e');
    }

    attempts++;
  }

  if (validPois.length < 4) {
    throw Exception('Failed to load at least 4 valid POIs');
  }

  return validPois;
}

Future<bool> validateLocation(String location) async {
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

Future<bool> validatePoi(String name, double latitude, double longitude) async {
  String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=500&keyword=$name&key=$googlePlacesApiKey');

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

Future<String> refineLocation(String location, String interests) async {
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
      {'role': 'user', 'content': 'Refine the location to ensure valid POIs.'}
    ],
    'max_tokens': 250,
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
  print('Parsed POIs: $pois');
  return pois;
}
