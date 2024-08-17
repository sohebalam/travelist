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
}
