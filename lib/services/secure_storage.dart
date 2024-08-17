import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final _storage = const FlutterSecureStorage();

  // Save API keys securely
  Future<void> saveOpenAIKey(String apiKey) async {
    await _storage.write(key: 'OPENAI_API_KEY', value: apiKey);
  }

  Future<void> saveGoogleMapsKey(String apiKey) async {
    await _storage.write(key: 'GOOGLE_MAPS_API_KEY', value: apiKey);
  }

  Future<void> saveGooglePlacesKey(String apiKey) async {
    await _storage.write(key: 'GOOGLE_PLACES_API_KEY', value: apiKey);
  }

  // Retrieve API keys securely
  Future<String?> getOpenAIKey() async {
    return await _storage.read(key: 'OPENAI_API_KEY');
  }

  Future<String?> getGoogleMapsKey() async {
    return await _storage.read(key: 'GOOGLE_MAPS_API_KEY');
  }

  Future<String?> getGooglePlacesKey() async {
    return await _storage.read(key: 'GOOGLE_PLACES_API_KEY');
  }

  // Optionally, delete API keys
  Future<void> deleteOpenAIKey() async {
    await _storage.delete(key: 'OPENAI_API_KEY');
  }

  Future<void> deleteGoogleMapsKey() async {
    await _storage.delete(key: 'GOOGLE_MAPS_API_KEY');
  }

  Future<void> deleteGooglePlacesKey() async {
    await _storage.delete(key: 'GOOGLE_PLACES_API_KEY');
  }
}
