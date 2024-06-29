import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class LocationService {
  Future<List<Map<String, dynamic>>> fetchPOIs(
      String location, String interests) async {
    bool isValidLocation = await validateLocation(location);

    if (!isValidLocation) {
      print('Invalid location: $location. Requesting refinement from OpenAI.');
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

    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    var prompt = '''
Generate a list of points of interest for location: $location with interests: $interests. 
For each point of interest, provide the name, latitude, longitude, address, and a short description in the following format:
Name - Latitude, Longitude - Address - Description.
''';

    var body = jsonEncode({
      'model': 'gpt-3.5-turbo',
      'messages': [
        {'role': 'system', 'content': prompt},
      ],
      'max_tokens': 250,
      'temperature': 0.7,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      print('Response Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> pois =
            _parsePOIs(data['choices'][0]['message']['content']);

        List<Map<String, dynamic>> validPois = [];
        for (var poi in pois) {
          bool isValidPoi =
              await validatePoi(poi['name'], poi['latitude'], poi['longitude']);
          print('POI validation result for ${poi['name']}: $isValidPoi');
          if (isValidPoi) {
            validPois.add(poi);
          }
        }

        if (validPois.isEmpty) {
          validPois = await fetchGooglePlacesPOIs(location, interests);
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

  Future<List<Map<String, dynamic>>> fetchGooglePlacesPOIs(
      String location, String interests) async {
    String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
    if (googlePlacesApiKey == null) {
      throw Exception('Google Places API key is missing');
    }

    List<String> latLng = location.split(',');
    if (latLng.length != 2) {
      throw Exception('Invalid location format');
    }

    double latitude = double.tryParse(latLng[0].trim()) ?? 0.0;
    double longitude = double.tryParse(latLng[1].trim()) ?? 0.0;

    var url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=1000&keyword=$interests&key=$googlePlacesApiKey');

    try {
      final response = await http.get(url);

      print('Google Places POI response: ${response.body}');

      if (response.statusCode == 200) {
        Map<String, dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> pois = [];
        if (data['results'] != null) {
          for (var result in data['results']) {
            String formattedAddress =
                result['formatted_address'] ?? 'Unknown location';
            String cityAndPostcode = _extractCityAndPostcode(formattedAddress);
            pois.add({
              'id': result['place_id'],
              'name': result['name'],
              'latitude': result['geometry']['location']['lat'],
              'longitude': result['geometry']['location']['lng'],
              'description': result['vicinity'] ?? 'No description available',
              'address': cityAndPostcode,
            });
          }
        }
        return pois;
      } else {
        print('Failed to fetch Google Places POIs: ${response.body}');
        throw Exception('Failed to fetch Google Places POIs');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Failed to fetch Google Places POIs');
    }
  }

  String _extractCityAndPostcode(String formattedAddress) {
    // Split the address by commas and remove the country
    List<String> parts = formattedAddress.split(',');
    if (parts.length >= 3) {
      return '${parts[parts.length - 3].trim()}, ${parts[parts.length - 2].trim()}';
    }
    return formattedAddress;
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

  Future<bool> validatePoi(
      String name, double latitude, double longitude) async {
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

  List<Map<String, dynamic>> _parsePOIs(String responseText) {
    List<Map<String, dynamic>> pois = [];
    List<String> lines = responseText.split('\n');
    int id = 1;

    for (String line in lines) {
      if (line.trim().isNotEmpty) {
        List<String> parts = line.split(' - ');
        if (parts.length == 4) {
          List<String> latLng = parts[1].split(',');
          double latitude = double.tryParse(latLng[0].trim()) ?? 0.0;
          double longitude = double.tryParse(latLng[1].trim()) ?? 0.0;
          String cityAndPostcode = _extractCityAndPostcode(parts[2].trim());
          String cleanedName = _removePrefixNumber(parts[0].trim());
          pois.add({
            'id': id.toString(),
            'name': cleanedName,
            'latitude': latitude,
            'longitude': longitude,
            'address': cityAndPostcode,
            'description': parts[3].trim(),
          });
          id++;
        }
      }
    }
    print('Parsed POIs: $pois');
    return pois;
  }

  String _removePrefixNumber(String name) {
    final regex = RegExp(r'^\d+\.\s*');
    return name.replaceAll(regex, '');
  }
}
