import 'package:cloud_firestore/cloud_firestore.dart';

class POI {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String address;
  final int order;
  final String? description; // Optional field

  POI({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.order,
    this.description, // Optional parameter
  });

  // Factory method to create a POI from Firestore document
  factory POI.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return POI(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: data['latitude'] ?? 0.0,
      longitude: data['longitude'] ?? 0.0,
      address: data['address'] ?? '',
      order: data['order'] ?? 0,
      description: data['description'], // Optional field
    );
  }

  // Method to convert POI to a map (useful for saving to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'order': order,
      'description': description, // Optional field
    };
  }

  // Static method to create a POI from a Map<String, dynamic>
  static POI fromMap(Map<String, dynamic> poi) {
    return POI(
      id: poi['id'] ?? '', // Ensure a default value
      name: poi['name'] ?? '',
      latitude: poi['latitude'] ?? 0.0,
      longitude: poi['longitude'] ?? 0.0,
      address: poi['address'] ?? '',
      order: poi['order'] ?? 0,
      description: poi['description'], // This can be null
    );
  }

  // Method to create a copy of the POI with an updated order
  POI copyWith({required int order}) {
    return POI(
      id: this.id,
      name: this.name,
      latitude: this.latitude,
      longitude: this.longitude,
      address: this.address,
      order: order, // Update the order
      description: this.description,
    );
  }
}
