import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final _db = FirebaseFirestore.instance;
  final _usersCollection = FirebaseFirestore.instance.collection('users');

  Future<Map<String, dynamic>?> getUserById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      print('Fetching user with uid: $uid'); // Debug log
      print('Document exists: ${doc.exists}'); // Debug log
      if (!doc.exists) return null;
      final data = doc.data();
      print('User data: $data'); // Debug log
      return data;
    } catch (e) {
      print('Error fetching user: $e'); // Debug log
      return null;
    }
  }

  Future<void> updateFcmToken(String uid, String? token) async {
    await _usersCollection.doc(uid).update({
      'fcmToken': token,
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> createUser(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    // Normalize role formatting for consistency
    String role = (userData['role'] ?? '').toString().toLowerCase();
    
    // Handle role normalization
    if (role == 'floorManager' || role == 'floor-manager') {
      role = 'floor_manager';
      print('Normalizing floor manager role: ${userData['role']} -> $role');
    }
    // Keep 'minister' role as is
    
    print('Creating user with role: $role, uid: $uid');
    
    // Prepare user document data
    final Map<String, dynamic> userDoc = {
      'firstName': userData['firstName'] ?? '',
      'lastName': userData['lastName'] ?? '',
      'email': userData['email'] ?? '',
      'phoneNumber': userData['phoneNumber'] ?? '',
      'role': role,
      'employeeNumber': userData['employeeNumber'] ?? '',
      'createdAt': userData['createdAt'] ?? FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      
      // Add clientType if provided (for client/minister users)
      if (userData['clientType'] != null) 'clientType': userData['clientType'],
      'isActive': true,
      'isSupervisor': (role ?? '') == 'operationalManager',
      'uid': uid ?? '',
      'fcmToken': userData['fcmToken'] ?? '',
    };
    
    await _usersCollection.doc(uid).set(userDoc);
    
    print('User created successfully: $uid with role: $role');
  }
}
