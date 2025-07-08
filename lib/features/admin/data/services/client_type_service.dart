import 'package:cloud_firestore/cloud_firestore.dart';

class ClientTypeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'client_types';

  // Default client types
  final List<Map<String, dynamic>> _defaultClientTypes = [
    {
      'name': 'Influencer/Celebrity',
      'description': 'Social media influencers, celebrities, and public figures',
      'code': 'influencer_celebrity',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'High-Profile Customer',
      'description': 'High-net-worth individuals and VIP customers',
      'code': 'high_profile_customer',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Corporate Executive',
      'description': 'C-level executives and senior management',
      'code': 'corporate_executive',
      'createdAt': FieldValue.serverTimestamp(),
    },
    {
      'name': 'Other',
      'description': 'Other types of clients',
      'code': 'other',
      'createdAt': FieldValue.serverTimestamp(),
    },
  ];

  // Initialize default client types if they don't exist
  Future<void> initializeDefaultClientTypes() async {
    try {
      // Check if client types already exist
      final existingTypes = await _firestore.collection(_collectionName).get();
      
      if (existingTypes.docs.isEmpty) {
        // Add default client types
        final batch = _firestore.batch();
        
        for (final type in _defaultClientTypes) {
          final docRef = _firestore.collection(_collectionName).doc();
          batch.set(docRef, type);
        }
        
        await batch.commit();
        print('Default client types initialized successfully');
      }
    } catch (e) {
      print('Error initializing default client types: $e');
      rethrow;
    }
  }

  // Get all client types
  Stream<QuerySnapshot> getClientTypes() {
    return _firestore
        .collection(_collectionName)
        .orderBy('name')
        .snapshots();
  }

  // Add a new client type
  Future<void> addClientType(Map<String, dynamic> clientType) async {
    await _firestore.collection(_collectionName).add({
      ...clientType,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Update a client type
  Future<void> updateClientType(String id, Map<String, dynamic> updates) async {
    await _firestore.collection(_collectionName).doc(id).update({
      ...updates,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Delete a client type
  Future<void> deleteClientType(String id) async {
    await _firestore.collection(_collectionName).doc(id).delete();
  }
}
