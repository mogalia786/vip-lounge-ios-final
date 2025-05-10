import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/enums/user_role.dart';

class StaffRegistrationService {
  final _db = FirebaseFirestore.instance;
  final _usersCollection = FirebaseFirestore.instance.collection('users');

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final querySnapshot = await _usersCollection
        .where('role', whereIn: ['staff', 'floorManager'])
        .get();
    
    return querySnapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> addStaff({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    required String role,
    required String employeeNumber,
    String? phoneNumber,
  }) async {
    await _usersCollection.doc(uid).set({
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role,
      'employeeNumber': employeeNumber,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'isSupervisor': false,
      'uid': uid,
      'fcmToken': null,
    });
  }

  Future<void> updateStaff(String uid, Map<String, dynamic> data) async {
    await _usersCollection.doc(uid).update(data);
  }

  Future<void> deleteStaff(String uid) async {
    await _usersCollection.doc(uid).delete();
  }

  Future<bool> isEmployeeNumberTaken(String employeeNumber) async {
    final querySnapshot = await _usersCollection
        .where('employeeNumber', isEqualTo: employeeNumber)
        .get();
    
    return querySnapshot.docs.isNotEmpty;
  }
}
