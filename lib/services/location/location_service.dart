// Importing the http package to perform HTTP requests
import 'package:http/http.dart' as http;
// Importing Dart's built-in JSON decoding and encoding utilities
import 'dart:convert';
// Importing dotenv package to manage environment variables
import 'package:flutter_dotenv/flutter_dotenv.dart';
// Importing Dart's math library to use mathematical functions and constants
import 'dart:math';
import 'package:logging/logging.dart';

final Logger _logger = Logger('HomePageLogger');

// Function to calculate the distance between two geographical coordinates using the Haversine formula
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 3958.8; // Radius of the Earth in miles
  // Converting latitude and longitude from degrees to radians
  var dLat = (lat2 - lat1) * (pi / 180);
  var dLon = (lon2 - lon1) * (pi / 180);
  // Haversine formula to calculate the great-circle distance between two points
  var a = sin(dLat / 2) * sin(dLon / 2) +
      cos(lat1 * (pi / 180)) *
          cos(lat2 * (pi / 180)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  var c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c; // Distance in miles
}

// Function to reverse geocode a given latitude and longitude into a human-readable address
Future<Map<String, String>> reverseGeocode(double lat, double lon) async {
  // Retrieve the Google Places API key from environment variables
  String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  // Construct the URL for the reverse geocoding request
  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$googlePlacesApiKey');

  try {
    // Perform the HTTP GET request
    final response = await http.get(url);

    // Check if the response was successful
    if (response.statusCode == 200) {
      // Decode the response body as JSON
      Map<String, dynamic> data = json.decode(response.body);

      // Replace "**" with a space in the response data if present
      data = data.toString().replaceAll('**', ' ') as Map<String, dynamic>;

      if (data['results'] != null && data['results'].isNotEmpty) {
        // Initialize variables to hold address components
        String city = '';
        String borough = '';
        String country = '';
        String neighborhood = '';

        // Iterate over the results to extract the address components
        for (var result in data['results']) {
          var addressComponents = result['address_components'] as List;
          for (var component in addressComponents) {
            if ((component['types'] as List).contains('locality')) {
              city = component['long_name'];
            } else if ((component['types'] as List).contains('sublocality')) {
              borough = component['long_name'];
            } else if ((component['types'] as List).contains('country')) {
              country = component['long_name'];
            } else if ((component['types'] as List).contains('neighborhood')) {
              neighborhood = component['long_name'];
            }
          }
        }

        // Construct the result map with the extracted components
        String latLong = '$lat,$lon';

        return {
          'city': city,
          'borough': borough,
          'country': country,
          'neighborhood': neighborhood,
          'latLong': latLong,
        };
      }
    }
    // Throw an exception if the response does not contain valid data
    throw Exception('Failed to get human-readable address');
  } catch (e) {
    // Handle any errors that occur during the request
    throw Exception('Error in reverse geocoding');
  }
}

// Function to fetch points of interest (POIs) based on a location and interests
Future<List<Map<String, dynamic>>> fetchPOIs(
    String location, String interests) async {
  // Validate the provided location
  bool isValidLocation = await validateLocation(location);

  // If the location is invalid, attempt to refine it
  if (!isValidLocation) {
    location = await refineLocation(location, interests);
    isValidLocation = await validateLocation(location);
    if (!isValidLocation) {
      throw Exception('Invalid location provided and refinement failed.');
    }
  }

  // Get the coordinates of the location
  var originalLocationCoords = await getCoordinates(location);
  double? originalLat = originalLocationCoords['lat'];
  double? originalLon = originalLocationCoords['lon'];

  // Reverse geocode the coordinates to get the human-readable address
  Map<String, String> humanReadableLocation =
      await reverseGeocode(originalLat!, originalLon!);

  // Construct a description of the location
  String locationDescription =
      '${humanReadableLocation['city']}, ${humanReadableLocation['borough']}, ${humanReadableLocation['neighborhood']}, ${humanReadableLocation['country']}, ${humanReadableLocation['latLong']}';

  // Retrieve the OpenAI API key from environment variables
  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  if (openAiApiKey == null) {
    throw Exception('OpenAI API key is missing');
  }

  // Initialize variables for the request
  List<Map<String, dynamic>> validPois = [];
  int attempts = 0;
  const int maxAttempts = 5;
  int poiCount = 0;

  // Loop to attempt fetching POIs with a maximum number of attempts
  while (poiCount < 4 && attempts < maxAttempts) {
    String additionalPrompt = '';
    if (interests.toLowerCase().contains('food')) {
      additionalPrompt = ' Include restaurants in the list.';
    }

    // Construct the OpenAI API request URL and headers
    var url = Uri.parse('https://api.openai.com/v1/chat/completions');
    var headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $openAiApiKey',
    };

    // Define the prompt to be sent to OpenAI
    var prompt = '''
Generate a list of points of interest for location: $locationDescription (within 15 miles) with interests: $interests.$additionalPrompt
For each point of interest, provide the name, latitude, longitude, and a short description in the following format:
Name - Latitude, Longitude - Description.
''';

    // Create the request body
    var body = jsonEncode({
      'model': 'gpt-4o',
      'messages': [
        {'role': 'system', 'content': prompt},
      ],
      'max_tokens': 150,
      'temperature': 0.7,
    });

    try {
      // Send the request to OpenAI
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        // Parse the response data
        Map<String, dynamic> data = json.decode(response.body);

        // Replace "**" with a space in the response data if present
        data = data.toString().replaceAll('**', ' ') as Map<String, dynamic>;

        _logger.info('Data received: $data');
        List<Map<String, dynamic>> pois =
            parsePOIs(data['choices'][0]['message']['content']);

        // Validate and filter the POIs
        for (var poi in pois) {
          bool isValidPoi = await validatePoi(
              poi['name'], poi['latitude'], poi['longitude'], location);
          double distance = calculateDistance(
              originalLat, originalLon, poi['latitude'], poi['longitude']);
          _logger.info(
              'POI validation result for ${poi['name']}: $isValidPoi, Distance: $distance miles');

          if (isValidPoi && distance <= 15) {
            if (!validPois
                .any((existingPoi) => existingPoi['name'] == poi['name'])) {
              validPois.add(poi);
              poiCount++;
              if (poiCount >= 4) break;
            }
          }
        }
      } else {
        _logger.warning('Failed to load POIs: ${response.body}');
      }
    } catch (e) {
      // Handle any errors that occur during the request
      _logger.severe('Error: $e');
    }

    attempts++;
  }

  if (validPois.isEmpty) {
    throw Exception('Locations not found, please try again');
  }

  return validPois; // Return the list of valid POIs
}

// Function to validate if a given location is valid using Google Places API
Future<bool> validateLocation(String location) async {
  // Retrieve the Google Places API key from environment variables
  String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  // Construct the URL for the request to validate the location
  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$location&inputtype=textquery&key=$googlePlacesApiKey');

  try {
    // Send the HTTP GET request
    final response = await http.get(url);

    _logger.info('Google Places response: ${response.body}');

    // Replace "**" with a space in the response data if present
    final bodyString = response.body.replaceAll('**', ' ');

    // Check if the response contains valid data
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(bodyString);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        return true;
      }
    }
    return false; // Return false if no valid data found
  } catch (e) {
    // Handle any errors that occur during the request
    _logger.severe('Error validating location:: $e');
    return false;
  }
}

// Function to validate a POI using Google Places API
Future<bool> validatePoi(
    String name, double latitude, double longitude, String location) async {
  // Retrieve the Google Places API key from environment variables
  String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  // Construct the URL for the request to validate the POI
  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=500&keyword=$name&key=$googlePlacesApiKey');

  try {
    // Send the HTTP GET request
    final response = await http.get(url);
    _logger.info('Google Places POI response: ${response.body}');
    // Replace "**" with a space in the response data if present
    final bodyString = response.body.replaceAll('**', ' ');

    // Check if the response contains valid data
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(bodyString);
      if (data['results'] != null && data['results'].isNotEmpty) {
        return true;
      } else {
        // Fallback check for name similarity using a text search
        var urlTextSearch = Uri.parse(
            'https://maps.googleapis.com/maps/api/place/textsearch/json?query=$name in $location&key=$googlePlacesApiKey');
        final responseTextSearch = await http.get(urlTextSearch);

        _logger.info(
            'Google Places Text Search response: ${responseTextSearch.body}');

        // Replace "**" with a space in the response data if present
        final bodyTextSearchString =
            responseTextSearch.body.replaceAll('**', ' ');

        if (responseTextSearch.statusCode == 200) {
          Map<String, dynamic> dataTextSearch =
              json.decode(bodyTextSearchString);
          if (dataTextSearch['results'] != null &&
              dataTextSearch['results'].isNotEmpty) {
            return true;
          }
        }
      }
    }
    return false; // Return false if no valid data found
  } catch (e) {
    // Handle any errors that occur during the request
    _logger.severe('Error validating POI: $e');
    return false;
  }
}

// Function to refine an invalid location using OpenAI API
Future<String> refineLocation(String location, String interests) async {
  // Retrieve the OpenAI API key from environment variables
  String? openAiApiKey = dotenv.env['OPENAI_API_KEY'];
  if (openAiApiKey == null) {
    throw Exception('OpenAI API key is missing');
  }

  // Construct the URL for the OpenAI API request
  var url = Uri.parse('https://api.openai.com/v1/chat/completions');
  var headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $openAiApiKey',
  };

  // Define the prompt to refine the location
  var prompt = '''
The location "$location" could not be validated. Suggest an alternative or correct it based on the following interests: $interests.
''';

  // Create the request body
  var body = jsonEncode({
    'model': 'gpt-4o',
    'messages': [
      {'role': 'system', 'content': prompt},
      {'role': 'user', 'content': 'Refine the location to ensure valid POIs.'}
    ],
    'max_tokens': 250,
    'temperature': 0.7,
  });

  try {
    // Send the request to OpenAI
    final response = await http.post(url, headers: headers, body: body);

    _logger.info('OpenAI refine response: ${response.body}');

    // Replace "**" with a space in the response data if present
    final responseBodyString = response.body.replaceAll('**', ' ');

    // Check if the response was successful
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(responseBodyString);
      return data['choices'][0]['message']['content'].trim();
    } else {
      throw Exception('Failed to refine location');
    }
  } catch (e) {
    // Handle any errors that occur during the request
    throw Exception('Failed to refine location');
  }
}

// Function to get the coordinates of a location using Google Places API
Future<Map<String, double>> getCoordinates(String location) async {
  // Retrieve the Google Places API key from environment variables
  String? googlePlacesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'];
  if (googlePlacesApiKey == null) {
    throw Exception('Google Places API key is missing');
  }

  // Construct the URL for the request to get the coordinates
  var url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input=$location&inputtype=textquery&fields=geometry&key=$googlePlacesApiKey');

  try {
    // Send the HTTP GET request
    final response = await http.get(url);

    _logger.info('Google Places coordinates response: ${response.body}');

    // Replace "**" with a space in the response data if present
    final bodyString = response.body.replaceAll('**', ' ');

    // Check if the response contains valid data
    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(bodyString);
      if (data['candidates'] != null && data['candidates'].isNotEmpty) {
        var geometry = data['candidates'][0]['geometry']['location'];
        return {'lat': geometry['lat'], 'lon': geometry['lng']};
      }
    }
    // Throw an exception if no valid data found
    throw Exception('Failed to get coordinates for location');
  } catch (e) {
    // Handle any errors that occur during the request
    throw Exception('Error getting coordinates');
  }
}

// Function to parse the POIs from the response text
List<Map<String, dynamic>> parsePOIs(String responseText) {
  List<Map<String, dynamic>> pois = [];
  List<String> lines = responseText.split('\n');

  // Iterate over each line to parse the POIs
  for (String line in lines) {
    if (line.trim().isNotEmpty) {
      // Replace "**" with a space in each line if present
      line = line.replaceAll('**', ' ');

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
  _logger.info('Parsed POIs: $pois');
  return pois; // Return the list of parsed POIs
}
