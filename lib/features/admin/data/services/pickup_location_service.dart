import 'package:cloud_firestore/cloud_firestore.dart';

class PickupLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'pickup_locations';

  // Get all pickup locations
  Stream<QuerySnapshot> getPickupLocations() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots();
  }

  // Get a single pickup location by ID
  Future<DocumentSnapshot> getPickupLocation(String id) async {
    return await _firestore.collection(_collectionName).doc(id).get();
  }

  // Add a new pickup location
  Future<void> addPickupLocation(Map<String, dynamic> locationData) async {
    await _firestore.collection(_collectionName).add({
      ...locationData,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update an existing pickup location
  Future<void> updatePickupLocation(String id, Map<String, dynamic> updates) async {
    await _firestore.collection(_collectionName).doc(id).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a pickup location
  Future<void> deletePickupLocation(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }
}
