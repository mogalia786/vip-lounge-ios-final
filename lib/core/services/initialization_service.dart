import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class InitializationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeApp() async {
    try {
      // Check if super user exists in users collection
      final superUserQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: 'super@vip.com')
          .get();

      if (superUserQuery.docs.isEmpty) {
        // Create super user in Firebase Auth
        final userCredential = await _auth.createUserWithEmailAndPassword(
          email: 'super@vip.com',
          password: 'super123',
        );

        // Create super user in users collection
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'email': 'super@vip.com',
          'password': 'super123',
          'role': 'superAdmin',
          'firstName': 'Super',
          'lastName': 'Admin',
          'isActive': true,
          'isSupervisor': true,
          'createdAt': FieldValue.serverTimestamp(),
          'uid': userCredential.user!.uid,
          'fcmToken': null,
        });

        debugPrint('Created super user in users collection');
      }

      await _createSupervisorIfNotExists();
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }
  }

  Future<void> _createSupervisorIfNotExists() async {
    final userDoc = await _firestore.collection('users').doc('EQp9o4CnUuRDklneVcoRHeuev1y2').get();
    
    if (!userDoc.exists) {
      await _firestore.collection('users').doc('EQp9o4CnUuRDklneVcoRHeuev1y2').set({
        'firstName': 'Supervisor',
        'lastName': 'Admin',
        'email': 'supervisor@gmail.com',
        'phoneNumber': null,
        'role': 'operationalManager',
        'employeeNumber': 'S1001',
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isSupervisor': true,
        'uid': 'EQp9o4CnUuRDklneVcoRHeuev1y2',
        'fcmToken': null,
      });
      print('Supervisor user created successfully!');
    } else {
      print('Supervisor user already exists');
    }
  }
}
